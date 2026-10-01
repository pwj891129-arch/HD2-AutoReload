param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.34-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.34-test-en.zip', 'HD2-AutoReload-0.3.34-test-ko.zip')
$assets = @($AssetPath | ForEach-Object {
    $resolved = (Resolve-Path -LiteralPath $_).Path
    [ordered]@{
        path = $resolved
        name = [IO.Path]::GetFileName($resolved)
        sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})
if ($assets.Count -ne 2 -or @($assets.name | Select-Object -Unique).Count -ne 2 -or
    @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject @($assets.name)).Count -ne 0) {
    throw 'Both English and Korean addon packages are required.'
}
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
## HD2 Auto Reload + Stratagems 0.3.34-test

Arsenal의 각 옵션에 구분하기 쉬운 설정용 아이콘을 추가했습니다.

- 자동재장전·충전 자동발사·원형 메뉴·핫키와 공용·임무 항목을 포함한 41개 옵션에 서로 다른 아이콘을 표시합니다. 각 ON/OFF 선택에도 해당 아이콘을 표시합니다.
- 일반 기능은 하늘색, 공용 항목은 노란색, 임무 항목은 민트색으로 구분합니다. 작은 썸네일에서도 알아보기 쉽도록 선명한 선과 어두운 배경을 사용했습니다.
- 현재 옵션 순서와 개별 ON/OFF 구조는 그대로 유지합니다. 옵션 이름·기본값·배포 경로도 변경하지 않았습니다.
- 아이콘은 Arsenal 설정 화면용 Lucide 심볼이며 게임 고유 스트라타젬 이미지가 아닙니다. 인게임 휠 아이콘, 자동재장전과 커맨드 입력 동작은 변경하지 않았습니다.
- 영어판 `HD2-AutoReload-0.3.34-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.34-test-ko.zip`에 동일한 아이콘을 포함했습니다. 언어별 ZIP 중 하나만 설치하세요.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 ON/OFF 설정을 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

공용·임무 항목의 기본값은 OFF입니다. 필요한 증원·SOS·보급·임무 항목을 각각 ON으로 설정하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이 ON**을 선택하세요. 하나 이상의 ON/OFF 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 스트라타젬 목록 열기는 누르고 있기(Hold)로 설정하며 조준·투척은 수동입니다.

### English

Adds distinct, high-contrast PNG symbols to all 41 Arsenal options and their ON/OFF choices. Existing order, labels, default values and deployment paths are preserved. Cyan denotes general features, yellow shared calls and mint mission calls. These Lucide symbols are settings previews, not native game artwork; in-game wheel rendering and all feature behavior are unchanged. The Lucide/Feather license is included.

Install **one** ZIP: `-en.zip` for English Arsenal options, or `-ko.zip` for Korean. Replace the previous version, review ON/OFF selections, then Purge / Deploy and restart with Bingus Shared Loader v18 / API 1. At least one setting must be selected. Reload, charge release and default settings are unchanged.

### 검증

전체 LuaJIT 모의 검사, 언어판별 8,112가지 배포 시나리오, 이미지 경로와 두 언어 패키지의 동일 본체 검사를 통과했습니다. 이전 옵션 구조의 유지와 41개 PNG의 크기·비어 있지 않은 픽셀·대비·작은 썸네일 가독성도 검사했습니다. 실제 Arsenal UI 표시 및 임무 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.34-test (Arsenal option icons)';
            body = $notes; draft = $true; prerelease = $true } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    }
    foreach ($asset in $assets) {
        $existing = $release.assets | Where-Object name -eq $asset.name | Select-Object -First 1
        if ($existing) {
            if ($existing.digest -ne ("sha256:" + $asset.sha256)) { throw 'Existing package differs; not replacing it.' }
        } else {
            $uri = $release.upload_url.Split('{')[0] + '?name=' + [Uri]::EscapeDataString($asset.name)
            $uploaded = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/zip' -InFile $asset.path
            if ($uploaded.state -ne 'uploaded' -or $uploaded.digest -ne ("sha256:" + $asset.sha256)) {
                throw 'Asset upload verification failed; leaving draft unpublished.'
            }
        }
    }
    if ($release.draft) {
        $body = @{ draft = $false; prerelease = $true; make_latest = 'false' } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Patch -Uri ($api + '/' + $release.id) -Headers $headers -ContentType 'application/json' -Body $body
    }
    $verified = Invoke-RestMethod -Uri ($api + '/tags/' + $Tag) -Headers $headers
    if ($verified.draft -or -not $verified.prerelease) { throw 'Published release verification failed.' }
    $verifiedAssets = @()
    foreach ($expected in $assets) {
        $asset = $verified.assets | Where-Object name -eq $expected.name | Select-Object -First 1
        if ($asset.state -ne 'uploaded' -or $asset.digest -ne ("sha256:" + $expected.sha256)) {
            throw 'Published asset verification failed.'
        }
        $verifiedAssets += [ordered]@{ name = $asset.name; sha256 = $expected.sha256; url = $asset.browser_download_url }
    }
    [ordered]@{ url = $verified.html_url; prerelease = $verified.prerelease; assets = $verifiedAssets;
        sourceCommit = $Commit } | ConvertTo-Json -Depth 4
} finally {
    $headers.Clear(); $credential.Clear(); $credentialLines = $null
}
