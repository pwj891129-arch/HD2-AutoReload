param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.46-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.46-test-en.zip', 'HD2-AutoReload-0.3.46-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.46-test

스트라타젬 휠의 확대 배율 선택지를 조정한 테스트 버전입니다.

- 원형 메뉴 크기 옵션을 **100%, 125%, 150%, 200%, 300%**로 변경했습니다. 125%를 추가하고 400%를 제거했습니다.
- 영어·한국어 옵션 이름/설명과 실제 게임 적용값을 함께 변경했습니다. 기본값은 100%이며, 화면 밖으로 잘리지 않도록 제한하는 기능은 유지합니다.
- 이전 400% 설정 파일이 남아 있으면 100% 기본값으로 처리합니다. 하위 선택지 순서가 바뀌었으므로 ZIP 교체 후 Arsenal에서 원하는 배율을 다시 확인하세요. 유지된 네 배율의 리소스 경로와 나머지 옵션의 위치·기본값은 그대로입니다.
- 0.3.45의 글자 크기·그림자·한글 폰트 표시·아이콘 배치와 스트라타젬 입력, 자동재장전/배낭 장전, 충전 자동발사 동작은 유지합니다. 게임의 정지 재장전 설정값을 변경하는 기능은 추가하지 않았습니다.
- 영어판 `HD2-AutoReload-0.3.46-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.46-test-ko.zip` 중 하나만 설치하세요.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 체크 상태를 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Arsenal은 새 옵션을 처음 가져올 때 체크합니다. 이제 체크된 개별 항목은 ON이므로 표시하지 않을 항목은 해제하세요. 새로 가져온 자동재장전·충전 자동발사도 체크된 ON 상태로 시작합니다. 이전 선택이 유지될 수 있으므로 교체 후 다시 확인하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

개별 체크값을 사용하려면 공용/임무 전체 표시 모드를 ‘개별 설정 사용’으로 두세요. 전체 ON/OFF 모드는 체크값을 덮어쓰되 지우지는 않습니다. 원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이**를 체크하세요. 하나 이상의 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 조준·투척은 수동입니다.

### English

Radial Menu Size now offers **100%, 125%, 150%, 200% and 300%**. 125% is added and 400% is removed in both manifests, descriptions, deployment markers and runtime validation. The default stays at 100%, with the existing viewport clamp. An old deployed 400% marker falls back to 100%. Retained scale resource paths and other option positions/defaults are unchanged, but Arsenal may preserve a suboption by position: review the size selection after replacing the ZIP, then Purge / Deploy with the game closed.

The 0.3.45 label contrast, native Korean text, icons, input, slot matching, visibility, automatic/backpack reload and charge release are retained. This update does not change any weapon's in-game movement/reload configuration.

Install **one** ZIP: `-en.zip` or `-ko.zip`. Arsenal initially checks new options, so review checkbox states and uncheck unwanted calls. Use Individual Settings in the bulk controls to honor individual checks. Replace the previous version, then Purge / Deploy and restart with the game closed and Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

LuaJIT 모의 검사와 언어판별 배포 검사를 통과했습니다. 새 다섯 배율을 모두 적용하고 400% 값이 거부되는지 검사했습니다. 125%를 포함하여 1~16개 항목과 여러 해상도에서 이름·그림자·아이콘·번호가 겹치지 않고 화면 안에 들어가는지 검사했습니다. 두 언어판의 선택지 순서·설명·적용값과 기존 설정 경로, DDS/GPU 배포 검사도 통과했습니다. 실제 게임 및 Arsenal UI 적용은 사용자가 확인해야 하며, 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.46-test (125 percent wheel scale)';
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
