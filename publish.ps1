param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.44-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.44-test-en.zip', 'HD2-AutoReload-0.3.44-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.44-test

한글 폰트 표시 경로를 수정하고, 표시 실패를 구분할 수 있도록 보완한 테스트 버전입니다. 현재 게임 로그는 0.3.42이며 0.3.43의 이미지 방식은 아직 게임에서 테스트되지 않았습니다.

- 한글 이름과 폰트·글자 이미지가 정상적으로 확인되는데 화면에서 이름이 보이지 않던 0.3.42 코드를 조사했습니다. 글자 그리기에 재질 포인터를 넘기던 부분을, 실제 연결한 GUI의 재질 리소스로 그리는 방식으로 통일했습니다. 이 호출 차이가 미표시의 원인인지는 게임 테스트가 필요합니다.
- 한글 폰트와 해당 글자 이미지가 로드되어 있고 필요한 글자를 모두 포함하면 게임 폰트로 우선 표시합니다. 공용 HUD 재질과 원본 게임 파일은 변경하지 않습니다.
- 연결·크기 계산·그리기 호출이 실패하면 0.3.43의 모드 전용 글자 이미지로 대체하며, 이것도 사용할 수 없으면 영문 이름을 표시합니다. 호출 성공 후 화면에서만 보이지 않는 문제는 자동 감지할 수 없습니다.
- 사용한 폰트·글자 이미지·재질·실제 표시 크기·화면 위치·그리기 반환값을 로그에 기록합니다. 창을 열 때마다 같은 폰트의 기록이 중복으로 쌓이지 않도록 제한했습니다.
- 0.3.43의 커진 아이콘과 휠 내부 배치, 스트라타젬 선택 방향·커맨드·장착 슬롯 번호·표시 옵션 및 자동재장전/배낭 장전 동작은 유지합니다.
- 스트라타젬 선택 방향·커맨드·장착 슬롯 번호·표시 옵션 및 자동재장전/배낭 장전 동작은 그대로 유지합니다.
- 영어판 `HD2-AutoReload-0.3.44-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.44-test-ko.zip` 중 하나만 설치하세요. 옵션 순서·기본값·저장 경로는 유지했습니다. 한글 이름은 한국어 ZIP에서 표시합니다.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 체크 상태를 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Arsenal은 새 옵션을 처음 가져올 때 체크합니다. 이제 체크된 개별 항목은 ON이므로 표시하지 않을 항목은 해제하세요. 새로 가져온 자동재장전·충전 자동발사도 체크된 ON 상태로 시작합니다. 이전 선택이 유지될 수 있으므로 교체 후 다시 확인하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

개별 체크값을 사용하려면 공용/임무 전체 표시 모드를 ‘개별 설정 사용’으로 두세요. 전체 ON/OFF 모드는 체크값을 덮어쓰되 지우지는 않습니다. 원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이**를 체크하세요. 하나 이상의 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 조준·투척은 수동입니다.

### English

0.3.42 had valid Korean names and a matching font/atlas, but invisible text. This build changes Gui.text from a Material-instance argument to the same owned GUI's material resource, matching the working icon/English resource-based path. Native Korean text is preferred when its font/atlas and glyph coverage are available. Bind, measure or draw-call failures fall back to the retained 0.3.43 OFL raster glyphs, then English. This call-path difference is a root-cause candidate, not a confirmed live diagnosis: the generic Stingray API permits both resource and pointer arguments, and a successful draw call cannot detect invisible pixels. Logs include resource IDs, font size, screen bounds and primitive ID. No original game font/atlas/UI binary is modified or shipped, and no shared HUD material is changed.

The larger icons and adaptive layout from 0.3.43 are retained. Command input, selection angles, visibility, settings and automatic/backpack reload remain unchanged.

Install **one** ZIP: `-en.zip` or `-ko.zip`. Arsenal initially checks new options, so review checkbox states and uncheck unwanted calls. Use Individual Settings in the bulk controls to honor individual checks. Replace the previous version, then Purge / Deploy and restart with the game closed and Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

LuaJIT 모의 검사와 언어판별 배포 검사를 통과했습니다. 재질 리소스와 인스턴스 포인터를 구분한 검사, 두 한글 폰트와 글자 이미지의 연결, 자원·글자 누락, 연결·크기 계산·그리기 실패, 한글 이미지 대체, GUI 정리와 다음 열기에서 복구를 검사했습니다. 기존 이름·아이콘 배치와 DDS/GPU 배포 검사도 유지했습니다. 실제 Arsenal UI 및 게임 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.44-test (Korean font resource routing)';
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
