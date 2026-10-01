param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.38-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.38-test-en.zip', 'HD2-AutoReload-0.3.38-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.38-test

개별 옵션을 직접 체크하는 방식으로 바꾸고 토글 휠의 좌클릭 선택을 추가했습니다.

- 공용·임무 개별 표시와 자동재장전·충전 자동발사·원형 메뉴·숫자 핫키 등 39개 ON/OFF 옵션의 하위 메뉴를 없앴습니다. 체크하면 ON, 해제하면 OFF입니다.
- 예전에는 상위 옵션을 체크해도 하위 기본값 OFF가 적용되어 개인 스트라타젬 4개만 보일 수 있었습니다. 이제 개별 체크값이 바로 표시 여부가 됩니다. 임무에 없는 항목을 새로 만들어 표시하지는 않습니다.
- 체크 해제 시 설정 파일이 없더라도 자동재장전·자동발사·원형 메뉴·핫키가 기본 ON으로 돌아가지 않도록 수정했습니다.
- 토글 방식에서는 항목을 가리킨 뒤 좌클릭으로 선택할 수 있습니다. 기존 목록 키 재입력도 유지합니다. 좌클릭을 놓은 뒤 커맨드를 시작하고 중앙 클릭은 취소합니다. 좌클릭/투척 입력은 자동 전송하지 않습니다.
- 선택 중 자동재장전과 충전 자동발사를 차단하며, 커맨드 전송 전 현재 캐릭터·장착 목록·쿨다운·키 설정을 다시 확인합니다.
- 메뉴 크기와 전체 표시 모드는 다중 선택을 유지합니다. 커맨드 입력 간격은 15ms(기본)/30ms로 직접 표시합니다. 옵션 위치와 게임 아이콘은 유지합니다.
- 영어판 `HD2-AutoReload-0.3.38-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.38-test-ko.zip` 중 하나만 설치하세요.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 체크 상태를 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Arsenal은 새 옵션을 처음 가져올 때 체크합니다. 이제 체크된 개별 항목은 ON이므로 표시하지 않을 항목은 해제하세요. 새로 가져온 자동재장전·충전 자동발사도 체크된 ON 상태로 시작합니다. 이전 선택이 유지될 수 있으므로 교체 후 다시 확인하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

개별 체크값을 사용하려면 공용/임무 전체 표시 모드를 ‘개별 설정 사용’으로 두세요. 전체 ON/OFF 모드는 체크값을 덮어쓰되 지우지는 않습니다. 원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이**를 체크하세요. 하나 이상의 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 조준·투척은 수동입니다.

### English

Replaces 39 two-level ON/OFF options with direct checkboxes: checked means ON, unchecked means OFF. This includes individual shared/mission visibility and reload/charge/radial/hotkey features. Missing markers no longer silently re-enable unchecked features. Existing positions, native previews and ON resource paths are retained.

Toggle wheels accept left-click selection in addition to a second List press. The sector is captured on click-down, but command input waits for physical release. Center clicks cancel. No fire/throw click is synthesized; aim and throw manually. Held clicks block weapon automation and selection is revalidated before input. Hold behavior is unchanged. Size and bulk modes retain their choices; the interval selector now explicitly shows 15 ms (default) / 30 ms.

Install **one** ZIP: `-en.zip` or `-ko.zip`. Arsenal initially checks new options, so review checkbox states and uncheck unwanted calls. Use Individual Settings in the bulk controls to honor individual checks. Replace the previous version, then Purge / Deploy and restart with the game closed and Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

30,265개 LuaJIT 모의 검사와 언어판별 5,067가지 배포 시나리오를 통과했습니다. 실제 ON 마커 및 체크 해제 시 미배포 상태, 좌클릭 유지/해제·취소·캐릭터/장착 목록 변경·키보드/엄지버튼·자동재장전/충전과의 입력 차단을 검사했습니다. 44개 미리보기와 기존 게임 아이콘 대응도 확인했습니다. 실제 Arsenal UI 및 게임 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.38-test (Direct toggles and click selection)';
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
