param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.40-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.40-test-en.zip', 'HD2-AutoReload-0.3.40-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.40-test

재장전 중 이동할 수 없는 무기는 발사 버튼을 놓을 때 장전하지 않고, 빈 무기에서 다시 클릭했을 때 장전하도록 변경했습니다.

- 현재 손에 든 무기의 게임 설정 `WeaponReloadComponent.reload_allow_move`로 이동 가능 여부를 판독합니다. 무기 이름 목록이나 HD2 HUD+ 데이터에 의존하지 않습니다.
- 이동 불가 무기는 마지막 탄을 쏜 뒤 발사 버튼을 놓아도, 이후 1초의 확인 구간에서도 자동장전하지 않습니다.
- 빈 무기에서 다시 발사 버튼을 누르면 발사 입력을 한 번 해제하고 최소 60ms 후 탄창·완전 과열·여분 탄·장전 상태를 재확인해 장전합니다. 게임이 발사 버튼을 누른 동안 장전을 받지 않는 제약을 처리합니다. 마우스 누르기 입력은 자동 전송하지 않습니다.
- 이미 탄이 있는 상태에서 시작한 클릭이 도중에 탄을 모두 써도 발사 버튼을 강제로 해제하지 않습니다.
- 여분 탄 없음, 장전 중, 메뉴·채팅·스트라타젬 입력, 포커스 상실과 무기 변경 시 입력을 차단합니다. 이동 여부를 확실히 판독하지 못하면 버튼 해제 후 장전도 막으며, 빈 무기 클릭의 강제 해제는 하지 않습니다.
- 이동 가능한 무기의 장전과 무기교체 후 장전 검사는 유지합니다. 발사 키는 좌클릭이어야 합니다. 이전 토글 휠 선택·우클릭/중앙 취소 기능과 옵션 위치·아이콘도 유지합니다.
- 영어판 `HD2-AutoReload-0.3.40-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.40-test-ko.zip` 중 하나만 설치하세요.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 체크 상태를 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Arsenal은 새 옵션을 처음 가져올 때 체크합니다. 이제 체크된 개별 항목은 ON이므로 표시하지 않을 항목은 해제하세요. 새로 가져온 자동재장전·충전 자동발사도 체크된 ON 상태로 시작합니다. 이전 선택이 유지될 수 있으므로 교체 후 다시 확인하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

개별 체크값을 사용하려면 공용/임무 전체 표시 모드를 ‘개별 설정 사용’으로 두세요. 전체 ON/OFF 모드는 체크값을 덮어쓰되 지우지는 않습니다. 원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이**를 체크하세요. 하나 이상의 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 조준·투척은 수동입니다.

### English

Reads the held weapon's native reload_allow_move setting, preferring entity overrides over authored configuration. No weapon-name list or HUD+ lookup is required. Stationary reload weapons no longer reload on fire release or during the following one-second confirmation window.

Click the empty stationary weapon again to reload. That explicit empty click releases left mouse once, waits at least 60 ms, then revalidates ammo/complete overheat, reserve and input gates before sending reload. No mouse-down is synthesized, and a click that started with usable ammo cannot authorize release after exhaustion. Unknown movement settings also suppress post-release reload, without authorizing automatic mouse release. Moving reloads and weapon-switch checks remain unchanged. Fire must be bound to left mouse. Existing Toggle selection/cancellation, icons and option positions are retained.

Install **one** ZIP: `-en.zip` or `-ko.zip`. Arsenal initially checks new options, so review checkbox states and uncheck unwanted calls. Use Individual Settings in the bulk controls to honor individual checks. Replace the previous version, then Purge / Deploy and restart with the game closed and Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

30,665개 LuaJIT 모의 검사와 언어판별 5,067가지 배포 시나리오를 통과했습니다. 이동 가능/불가/판독 실패, 게임 설정 우선순위·인덱스·소유권 검증, 빈 무기 클릭의 해제/장전 순서, 여분 탄 없음, 장전 중, 메뉴·포커스·무기 변경과 기존 휠/충전 동작을 검사했습니다. 기존 로컬 게임 캡처로 네이티브 판독 위치를 확인하고 10,000개 해시 계산을 검증했습니다. 44개 미리보기와 기존 게임 아이콘 대응도 확인했습니다. 실제 Arsenal UI 및 게임 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.40-test (Stationary reload on empty click)';
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
