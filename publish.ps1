param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.37-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.37-test-en.zip', 'HD2-AutoReload-0.3.37-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.37-test

Arsenal 옵션의 스트라타젬 미리보기를 게임 원본 아이콘으로 교체했습니다.

- 증원·SOS·보급·헬밤·깃발·SEAF 포격 등 원본 아이콘이 지정된 개별 항목 23개를 실제 게임의 텍스처와 색상값으로 변환했습니다. 아이콘을 새로 그리지 않고 원본 도형을 사용합니다.
- 게임에서 같은 그림을 쓰는 임무들은 옵션에서도 같은 그림을 표시합니다. 하나의 토글에 여러 변형이 있으면 원본이 있는 대표 항목의 아이콘을 사용합니다.
- 탈출 신호기·교란 장치·원격 폭발물·긴급 탈출·융단 폭격·교란기·즉시 탈출·SEAF 분대·첨탑 살균 장치·발굴 폭약·핵폭탄 등 11개 임무 항목은 확인한 게임 정의에 아이콘이 지정되어 있지 않아 기존 대체 심볼을 유지합니다. 양 언어판 설명에 이 제한을 표시했습니다.
- 전체 ON/OFF·메뉴 크기 등 기능 설정 10개의 공통 아이콘은 유지합니다. 옵션 이름·순서·기본값·배포 경로와 개별 설정값은 변경하지 않았습니다.
- 게임 아이콘 PNG는 Arsenal 미리보기 전용이며 게임에 배포되는 패치 폴더에는 넣지 않습니다. 원형 메뉴의 게임 아이콘 표시와 자동재장전·충전 자동발사·Hold/토글 입력 동작은 변경하지 않았습니다.
- 영어판 `HD2-AutoReload-0.3.37-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.37-test-ko.zip` 중 하나만 설치하세요.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 ON/OFF 설정을 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

전체 옵션의 기본값은 ‘개별 설정 사용’, 개별 공용·임무 항목의 기본값은 OFF입니다. 필요한 항목을 개별 ON으로 설정하거나 전체 옵션에서 ON을 선택하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이 ON**을 선택하세요. 하나 이상의 ON/OFF 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 스트라타젬 목록 열기의 Hold 및 토글(Press) 설정을 지원하며 조준·투척은 수동입니다.

### English

Replaces 23 individual Arsenal previews with the game's native UI texture masks and definition palettes, including Reinforce, SOS, Resupply, Hellbomb, flag and SEAF artillery. Native duplicate artwork is intentionally preserved. Multi-variant toggles use a representative assigned icon.

11 mission definitions have no assigned icon and retain documented Lucide fallback symbols; the 10 functional settings retain their existing symbols. PNGs are Arsenal-only manifest previews, never in deployed patch folders. Original DDS/shader/material binaries and captures are not bundled. GAME-ICON-SOURCES.json records provenance, and GAME-ARTWORK.txt distinguishes game artwork from the library license. Names, order, defaults, paths, sizes, bulk visibility and runtime behavior are unchanged.

Install **one** ZIP: `-en.zip` for English Arsenal options, or `-ko.zip` for Korean. Replace the previous version, review selections, then Purge / Deploy and restart with Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

30,010개 LuaJIT 모의 검사와 언어판별 10,761가지 배포 시나리오를 통과했습니다. 44개 미리보기의 이미지 경계·불투명 배경·축소 가시성, 34개 항목의 게임 종류·텍스처·색상값 대응과 PNG 해시를 확인했습니다. 이전 버전과의 본체 비교로 버전 문자열 외에 실행 로직 변경이 없음을 확인했습니다. 실제 Arsenal UI 표시 및 게임 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.37-test (Native Arsenal stratagem icons)';
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
