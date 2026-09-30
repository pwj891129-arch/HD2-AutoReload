param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.23-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.23-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload 0.3.23-test

게임이 발사 버튼을 누른 상태에서는 수동 장전을 받지 않는 동작에 맞춰 자동 장전 시점을 변경했습니다.

- 발사 버튼을 처음 누를 때 빈 탄창·완전 과열 여부를 한 번 확인하며, 실제 장전 입력은 버튼을 놓은 뒤 보냅니다.
- 발사 버튼을 계속 누르는 동안에는 추가 장전 검사와 입력을 중단합니다.
- 버튼을 놓는 순간 현재 무기를 다시 확인하고, 이후 1초 동안 50ms 간격으로 판독을 이어갑니다. 발사 중 거부되는 장전 입력으로 시도를 소진하던 문제를 수정했습니다.
- 재장전 플래그가 켜진 일반 탄창식 무기에서는 새 장전 시도를 중단하고 대기 중인 발사 시도도 지웁니다.
- 과열식 무기는 게임이 완전 과열만으로도 재장전 플래그를 켜는 경우가 있어 기존의 150ms 확인 및 1회 입력 제한을 유지합니다.
- 판독되지 않는 탄창·약실·과열·여분탄 값으로는 장전하지 않습니다. 탱크 주포 자동장전은 비활성입니다.

### 설치

게임을 종료한 상태에서 이전 테스트 버전을 제거하고 이 ZIP으로 교체한 뒤 Bingus Shared Loader와 함께 배포하세요. 기존 헬퍼 자동장전 및 이전 Auto Reload 보조 스크립트는 꺼서 중복 입력을 막으세요.
로그: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`

사용자가 LAS-12 사이의 실제 자동 재장전 성공을 확인했습니다. 이번 발사 버튼 해제 시점 변경은 모의 검사로 검증했습니다. 실제 게임에서 문제가 생기면 F8로 자동장전을 일시 정지하고 로그를 확인하세요.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.23-test (reload after fire release)';
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
