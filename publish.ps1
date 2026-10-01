param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.28-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.28-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload 0.3.28-test

자동재장전을 기본 활성 상태로 변경하고 시험용 진단 기능을 제거했습니다.

- 모드를 켜면 별도 옵션을 선택하지 않아도 자동재장전이 작동하도록 본체를 기본 배포 파일로 옮겼습니다.
- 자동재장전 설정은 ON(기본) / OFF 선택으로 정리했습니다. 실탄 OFF·과열 OFF 체크박스는 제거했으며, 이전 OFF 설정이 새 버전의 장전을 끄지 않습니다.
- F9 진단 옵션, 무기 종류 확인, 탱크 필드 탐색과 좌석 진단, 이전 진단용 판독 경로를 배포 파일에서 제거했습니다. F9/F10은 모드에서 사용하지 않습니다.
- 레일건·에포크 90% 충전 자동발사는 유지합니다. OFF(기본) / ON을 선택할 수 있으며 자동재장전과 독립적입니다.
- 기존 50ms 판독, 발사키 해제 후 1초 검사, 무기 교체 대기, 잔탄·과열·예비탄 안전 조건을 유지했습니다.
- 옵션 패키지는 최소 256바이트를 유지합니다. 인게임 설정 메뉴 없이 Arsenal에서만 설정합니다.

탱크 주포의 자동재장전은 이번 버전에서도 제외됩니다. 탱크 시험용 탐색만 제거했으며, 몸을 내밀고 사용하는 개인 무기의 장전 조건은 유지했습니다. 스트라타젬 커맨드가 게임에 수신되지 않는 문제를 수정한 버전은 아닙니다.

### 설치

게임을 종료하고 Arsenal에서 이전 버전을 교체한 뒤 Bingus Shared Loader와 함께 반드시 Purge / Deploy 하세요. 자동재장전은 ON(기본), 충전 자동발사는 OFF(기본)입니다. 옵션을 바꾼 후에도 재배포와 게임 재시작이 필요합니다. 이전 옵션 파일이 남지 않도록 해야 합니다. 기존 헬퍼 자동장전 및 이전 Auto Reload 보조 스크립트는 꺼서 중복 입력을 막으세요.
로그: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`

734개 LuaJIT 모의 검사와 패키지 크기·내용·설정 조합 9가지 검사를 통과했습니다. 기본 설정의 실탄 소진과 완전 과열 장전 입력, OFF 설정, 시험용 탐색 미실행을 확인했습니다. 실제 게임과 Arsenal 화면에서의 재검증은 남아 있습니다. 50ms 판독과 프레임·입력 지연으로 충전 발사 해제 시점은 90%를 넘을 수 있으며 폭발 방지를 보장하지 않습니다. 설치된 모드 파일은 자동으로 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.28-test (default-on reload, diagnostics removed)';
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
