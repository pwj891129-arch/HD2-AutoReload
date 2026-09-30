param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.27-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.27-test.zip') { throw 'Unexpected addon package name.' }
if ($Commit -notmatch '^[0-9a-f]{40}$') { throw 'A full source commit hash is required.' }
if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid repository name.' }
$credentialLines = "protocol=https`nhost=github.com`n`n" | git -c "safe.directory=$PSScriptRoot" credential fill
if ($LASTEXITCODE -ne 0) { throw 'GitHub Git authentication is unavailable.' }
$credential = @{}
foreach ($line in $credentialLines) {
    $parts = $line.Split('=', 2)
    if ($parts.Length -eq 2) { $credential[$parts[0]] = $parts[1] }
}
if (-not $credential['password']) { throw 'GitHub Git authentication is unavailable.' }
$headers = @{ Authorization = 'Bearer ' + $credential['password']; Accept = 'application/vnd.github+json';
    'User-Agent' = 'HD2-Helper-Addon-Release'; 'X-GitHub-Api-Version' = '2022-11-28' }
$api = "https://api.github.com/repos/$Repository/releases"
$notes = @'
## HD2 Auto Reload 0.3.27-test

게임 시작 시 작은 아스날 옵션 패키지의 읽기가 실패하던 문제를 수정했습니다.

- 옵션 파일의 크기를 기존 224바이트에서 HD2SDK와 같은 최소 256바이트로 확보합니다. Lua 내용과 옵션 값은 그대로이며 뒤에 0만 채웁니다.
- 이전 크기 결함을 검출하는 회귀 검사와 배포 패키지의 크기·내용 검사를 추가했습니다.
- 자동재장전, 50ms 판독, 발사키 해제 후 1초 검사, 레일건·에포크 90% 충전 자동발사의 동작은 변경하지 않았습니다.
- 아스날 설정만 사용하며 인게임 설정 메뉴는 추가하지 않았습니다.

최근 NxStorage 로그에서 이 모드의 옵션 파일에 `0x89240007`(파일 크기를 넘는 읽기) 오류가 확인됐습니다. 스트라타젬 모드를 꺼도 이전 자동재장전 옵션 파일을 남겨두면 같은 읽기 문제가 남을 수 있습니다. 확인된 패키지 크기 결함을 수정했으며 실제 게임 시작은 재검증이 필요합니다.

### 설치

게임을 종료하고 Arsenal에서 이전 버전을 교체한 뒤 체크박스를 확인하여 Bingus Shared Loader와 함께 반드시 Purge / Deploy 하세요. 옵션을 바꾼 후에도 재배포와 게임 재시작이 필요합니다. 이전 옵션 파일이 남지 않도록 해야 합니다. 기존 헬퍼 자동장전 및 이전 Auto Reload 보조 스크립트는 꺼서 중복 입력을 막으세요.
**스트라타젬 모드도 사용한다면 HD2 Stratagem Hotkeys 0.1.3-test로 같이 교체해야 합니다.** 두 모드의 이전 옵션 파일 모두 크기 결함이 있습니다.
로그: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`

669개 LuaJIT 모의 검사와 최소 패키지 크기 검사를 통과했습니다. 실제 게임 시작과 레일건·에포크 게임 검증은 아직 하지 않았습니다. 50ms 판독과 프레임·입력 지연으로 실제 발사 해제 시점은 90%를 넘을 수 있으며 폭발 방지를 보장하지 않습니다. 설치된 모드 파일은 자동으로 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.27-test (option archive size fix)';
            body = $notes; draft = $true; prerelease = $true } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    }
    $expectedHash = (Get-FileHash -LiteralPath $AssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $existing = $release.assets | Where-Object name -eq $assetName | Select-Object -First 1
    if ($existing) {
        if ($existing.digest -ne "sha256:$expectedHash") { throw 'Existing package differs; not replacing it.' }
    } else {
        $uri = $release.upload_url.Split('{')[0] + '?name=' + [Uri]::EscapeDataString($assetName)
        $uploaded = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/zip' -InFile $AssetPath
        if ($uploaded.state -ne 'uploaded' -or $uploaded.digest -ne "sha256:$expectedHash") {
            throw 'Asset upload verification failed; leaving draft unpublished.'
        }
    }
    if ($release.draft) {
        $body = @{ draft = $false; prerelease = $true; make_latest = 'false' } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Patch -Uri ($api + '/' + $release.id) -Headers $headers -ContentType 'application/json' -Body $body
    }
    $verified = Invoke-RestMethod -Uri ($api + '/tags/' + $Tag) -Headers $headers
    $asset = $verified.assets | Where-Object name -eq $assetName | Select-Object -First 1
    if ($verified.draft -or -not $verified.prerelease -or $asset.digest -ne "sha256:$expectedHash") {
        throw 'Published release verification failed.'
    }
    [ordered]@{ url = $verified.html_url; prerelease = $verified.prerelease; asset = $asset.name;
        sha256 = $expectedHash; sourceCommit = $Commit } | ConvertTo-Json
} finally {
    $headers.Clear(); $credential.Clear(); $credentialLines = $null
}
