param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.42-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.42-test-en.zip', 'HD2-AutoReload-0.3.42-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.42-test

한국어판 스트라타젬 이름이 보이지 않던 문제를 수정하고, 아이콘과 글자를 휠 안에 정리했습니다.

- 한글 이름 데이터는 정상인데 화면에서 비어 있던 렌더링 경로를 수정했습니다. 한글 글꼴의 실제 글자 아틀라스를 모드 소유의 GUI 전용 재질에 연결합니다. 기존 재질의 빈 텍스처 슬롯만으로 표시를 시도하던 문제를 해결했습니다.
- 게임 HUD의 공용 재질은 변경하지 않습니다. 이미 로드된 게임 한글 글꼴·아틀라스만 사용하며 원본 폰트·텍스처·UI 패키지는 배포하지 않습니다. 리소스가 없거나 연결이 실패하면 영문 이름으로 대체합니다.
- 아이콘 최대 크기를 100% 기준 72px에서 44px로 줄이고, 표시 항목이 많으면 추가 조절합니다.
- 아이콘·이름·상태·기존 슬롯 번호를 각각의 부채꼴 안에 배치했습니다. 긴 이름은 최대 두 줄로 나누고 폭에 맞춰 조절합니다. 선택한 항목의 이름도 휠 밖이 아닌 가운데에 표시합니다.
- 실제 글꼴의 기준선과 좌우 여백을 반영해 한글 이름의 정렬을 보정했습니다. 연결한 글꼴과 아틀라스를 로그에 기록합니다.
- 스트라타젬 선택 방향·커맨드·장착 슬롯 번호·표시 옵션 및 자동재장전/배낭 장전 동작은 그대로 유지합니다.
- 영어판 `HD2-AutoReload-0.3.42-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.42-test-ko.zip` 중 하나만 설치하세요. 옵션 순서·기본값·저장 경로는 유지했습니다. 한글 표시를 위해 게임 UI도 한국어로 설정하는 것을 권장합니다.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 체크 상태를 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Arsenal은 새 옵션을 처음 가져올 때 체크합니다. 이제 체크된 개별 항목은 ON이므로 표시하지 않을 항목은 해제하세요. 새로 가져온 자동재장전·충전 자동발사도 체크된 ON 상태로 시작합니다. 이전 선택이 유지될 수 있으므로 교체 후 다시 확인하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

개별 체크값을 사용하려면 공용/임무 전체 표시 모드를 ‘개별 설정 사용’으로 두세요. 전체 ON/OFF 모드는 체크값을 덮어쓰되 지우지는 않습니다. 원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이**를 체크하세요. 하나 이상의 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 조준·투척은 수동입니다.

### English

Fixes invisible Korean wheel names by binding each native Korean font's matching MSDF atlas on an owned GUI-local material. The previous stock runtime_font material had an empty texture slot. Native glyph bearings are included in alignment; missing resources/bindings fall back to English. No shared HUD material is modified and no original font/atlas/UI binaries are shipped.

Icons are capped at 44px instead of 72px at 100% scale. Smaller adaptive icons, balanced two-line labels, readiness and original hotkey numbers stay inside each sector. The selected name is shown in the center. Command input, selection angles, visibility options and automatic/backpack reload remain unchanged. Korean game UI language is recommended.

Install **one** ZIP: `-en.zip` or `-ko.zip`. Arsenal initially checks new options, so review checkbox states and uncheck unwanted calls. Use Individual Settings in the bulk controls to honor individual checks. Replace the previous version, then Purge / Deploy and restart with the game closed and Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

LuaJIT 모의 검사와 언어판별 배포 검사를 통과했습니다. 한글/영문·1~16개 항목·320x240~3840x2160·100~400% 크기에서 각 영역 내부 배치와 아이콘/글자 겹침을 검사했습니다. 글꼴은 로드됐지만 아틀라스가 없는 경우, 재질 연결 실패, 대체 글꼴, 기준선 보정과 GUI 정리도 검사했습니다. 설치된 게임 아틀라스에서 실제 한글 글자를 오프라인으로 렌더링해 두 글꼴/아틀라스 조합을 대조했습니다. 실제 Arsenal UI 및 게임 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.42-test (Korean font fix + Compact wheel)';
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
