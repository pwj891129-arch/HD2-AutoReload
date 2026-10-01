param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.45-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.45-test-en.zip', 'HD2-AutoReload-0.3.45-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.45-test

한글 이름이 정상 표시된 0.3.44를 바탕으로, 스트라타젬 휠의 글자 크기와 대비를 개선한 테스트 버전입니다.

- 이름의 기준 크기를 14px → 24px, 상태 표시를 12px → 16px, 중앙 선택 이름을 16px → 20px로 늘렸습니다. 실제 크기는 항목 수·화면 크기·메뉴 배율·이름 길이에 맞춰 조정됩니다.
- 이름을 밝고 불투명하게 표시하고 어두운 그림자를 추가했습니다. 쿨다운 중에도 이름을 지나치게 흐리게 표시하지 않으며, 아이콘과 상태 표시로 사용 가능 여부를 구분합니다.
- 슬롯 번호를 이름 옆에서 상태 표시 줄로 옮겨 이름이 사용할 수 있는 너비를 늘렸습니다. 긴 이름은 두 줄로 나누어 휠 안에 표시합니다.
- 커진 글씨와 아이콘이 겹치지 않도록 배치를 조정했습니다. 아이콘은 공간에 따라 최대 84px까지 표시하며, 기본 반지름을 25px 늘리고 화면 밖으로 나가지 않도록 크기 제한을 유지했습니다.
- 한국어는 게임 한글 폰트로 우선 표시합니다. 이미지 대체 경로에도 같은 크기·그림자 규칙을 적용했으며, 그리기 실패 시 남은 그림자와 글자를 정리한 뒤 대체 표시합니다. 공용 HUD 재질과 원본 게임 파일은 변경하지 않습니다.
- 스트라타젬 선택 방향·커맨드·장착 슬롯 번호·표시 옵션 및 자동재장전/배낭 장전 동작은 그대로 유지합니다.
- 영어판 `HD2-AutoReload-0.3.45-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.45-test-ko.zip` 중 하나만 설치하세요. 옵션 순서·기본값·저장 경로는 유지했습니다. 한글 이름은 한국어 ZIP에서 표시합니다.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 체크 상태를 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Arsenal은 새 옵션을 처음 가져올 때 체크합니다. 이제 체크된 개별 항목은 ON이므로 표시하지 않을 항목은 해제하세요. 새로 가져온 자동재장전·충전 자동발사도 체크된 ON 상태로 시작합니다. 이전 선택이 유지될 수 있으므로 교체 후 다시 확인하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

개별 체크값을 사용하려면 공용/임무 전체 표시 모드를 ‘개별 설정 사용’으로 두세요. 전체 ON/OFF 모드는 체크값을 덮어쓰되 지우지는 않습니다. 원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이**를 체크하세요. 하나 이상의 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 조준·투척은 수동입니다.

### English

The user confirmed visible native Korean text in 0.3.44. This build raises nominal name/status/center sizes from 14/12/16px to 24/16/20px, adds opaque dark shadows and keeps cooldown names bright. Actual text still fits sector count, viewport, scale and long names. Slot numbers move beside status so names can use the full width. Icons grow up to 84px; the base radius grows by 25px while retaining viewport clamps. Shadows and foregrounds are fitted together and partial draws are removed before fallback. Native Korean remains preferred, with the existing OFL raster fallback retained. No original game font/atlas/UI binary or shared HUD material is changed.

Command input, selection angles, slot matching, visibility, settings and automatic/backpack reload remain unchanged.

Install **one** ZIP: `-en.zip` or `-ko.zip`. Arsenal initially checks new options, so review checkbox states and uncheck unwanted calls. Use Individual Settings in the bulk controls to honor individual checks. Replace the previous version, then Purge / Deploy and restart with the game closed and Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

LuaJIT 모의 검사와 언어판별 배포 검사를 통과했습니다. 1~16개 항목, 여러 화면 해상도와 배율에서 한글 폰트·영문·이미지 대체 경로의 글자/그림자/아이콘/번호가 각 칸 안에 들어가고 서로 겹치지 않는지 검사했습니다. 글자와 그림자 그리기 실패 시 정리·대체 표시와 DDS/GPU 배포 검사도 통과했습니다. 오프라인 미리보기의 가독성을 확인했으며, 이번 변경의 실제 게임 가독성은 적용 후 확인이 필요합니다. 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.45-test (Readable wheel labels)';
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
