param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.35-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.35-test-en.zip', 'HD2-AutoReload-0.3.35-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.35-test

에포크 완충 자동발사를 수정하고 스트라타젬 토글 방식을 지원합니다.

- 에포크를 레일건과 같은 폭발 위험 게이지로 처리하여 충전값이 거부되던 문제를 수정했습니다. 에포크는 현재 무기 객체의 발사 충전값을 읽고 완충 100%에서 좌클릭을 한 번 해제합니다. 고정 2.5초 타이머를 사용하는 방식이 아닙니다.
- 레일건은 기존 위험 게이지 90% 자동발사를 유지합니다. 두 기능은 기본 ON이며 조준과 다음 충전은 수동입니다. 발사키는 좌클릭이어야 합니다.
- 키보드와 마우스 엄지버튼의 스트라타젬 토글 설정을 지원합니다. 실제 게임 목록과 원형 메뉴가 함께 켜지고 꺼지며, 버튼을 놓아도 토글 메뉴는 유지됩니다. 마우스로 항목을 선택한 뒤 목록 버튼을 다시 누르면 커맨드만 입력하며 중앙에서 닫으면 취소합니다.
- 토글 메뉴가 열린 동안 숫자열 1~4 핫키도 사용할 수 있습니다. 키를 누르고 있지 않아도 실제 게임 메뉴가 활성화되어 있으면 자동재장전·충전 자동발사를 차단합니다.
- 엄지버튼의 닫기 입력이 커서 캡처 때문에 누락되면 물리 버튼 해제와 커서 복원 뒤 한 번만 재전송하고 실제 메뉴 종료를 확인합니다. 커맨드용 토글 재개는 짧은 누르기·떼기 입력으로 처리하며 버튼을 계속 눌러두지 않습니다.
- 기존 Hold 방식, 옵션 순서·기본값·아이콘·배포 경로는 유지합니다. 충전 자동발사와 원형 메뉴·핫키의 안내 문구를 양 언어판에 갱신했습니다.
- 영어판 `HD2-AutoReload-0.3.35-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.35-test-ko.zip` 중 하나만 설치하세요.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 ON/OFF 설정을 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

공용·임무 항목의 기본값은 OFF입니다. 필요한 증원·SOS·보급·임무 항목을 각각 ON으로 설정하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이 ON**을 선택하세요. 하나 이상의 ON/OFF 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 스트라타젬 목록 열기의 Hold 및 토글(Press) 설정을 지원하며 조준·투척은 수동입니다.

### English

Fixes Epoch being rejected by an explosive-charge-only check. Epoch releases left mouse once at 100% of the held weapon's native Full firing-charge time; Railgun retains 90% of its explosion limit. No fixed Epoch timer, mouse press, automatic aiming or repeat firing is added. Charge release remains default ON and requires left-mouse fire.

Supports keyboard and mouse-thumb Toggle/Press Stratagem List bindings alongside Hold. The radial follows the actual local character menu, stays open after key release and closes on the next toggle. Choose a sector then toggle closed to enter only its command; close at center to cancel. Number-row 1-4 also works while the native toggle menu is open. Toggle command reopening uses a bounded press/release pulse. A captured thumb close can be replayed once after physical release and cursor restoration, with native closure verification. Reload and charge release are blocked throughout the native menu, even without a held button.

Install **one** ZIP: `-en.zip` for English Arsenal options, or `-ko.zip` for Korean. Replace the previous version, review ON/OFF selections, then Purge / Deploy and restart with Bingus Shared Loader v18 / API 1. At least one setting must be selected. Existing option IDs, defaults, order, icons and deployment paths are retained.

### 검증

5,174개 LuaJIT 모의 검사와 언어판별 8,112가지 배포 시나리오를 통과했습니다. 에포크 완충·100% 미만·반복 방지·비정상 판독, 레일건 기존 기준, 키보드·양쪽 엄지버튼 토글, 중앙·쿨다운·메뉴 취소, 입력 누락 복구, 숫자 핫키와 기존 Hold 방식을 검사했습니다. 두 언어 패키지의 동일 본체·아이콘 경로·옵션 기본값도 확인했습니다. 실제 게임의 에포크 및 토글 동작은 추가 테스트가 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.35-test (Epoch full charge and toggle menus)';
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
