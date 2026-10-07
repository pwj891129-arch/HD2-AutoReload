param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.61-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.61-test.zip')
$assets = @($AssetPath | ForEach-Object {
    $resolved = (Resolve-Path -LiteralPath $_).Path
    [ordered]@{
        path = $resolved
        name = [IO.Path]::GetFileName($resolved)
        sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})
if ($assets.Count -ne 1 -or @($assets.name | Select-Object -Unique).Count -ne 1 -or
    @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject @($assets.name)).Count -ne 0) {
    throw 'The unified-language addon package is required.'
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
## HD2 Auto Reload + Stratagems 0.3.61-test

### 업데이트 내역

- 자동재장전·레일건/에포크 자동발사가 일시적인 실행 오류 후 영구 중단되는 경로를 수정했습니다. 모드가 누른 입력을 정리하고 1~5초 간격으로 복구를 재시도합니다. 복구 후 사격 버튼을 새로 누르는 순간 재개하며, 이미 누르던 입력이나 이전 사격은 재사용하지 않습니다.
- 복구 대기 중 무기 판독을 유지하고 오류·복구·차단 상태를 로그에 남깁니다. 기존 사격 종료 시 재장전 및 1초 추가 검사, 50ms 무기 판독, 설정값은 유지합니다. 실제 게임에서의 오류 복구는 아직 검증이 필요합니다.
- 기능과 판독 주기는 유지하면서 반복 비용을 줄였습니다. 네이티브 읽기 버퍼를 재사용하고, 같은 프레임의 메뉴·아이콘 리소스 조회를 공유하며, 닫힌 휠의 빈 정리와 입력 상태 테이블 생성을 줄였습니다. 50ms 자동장전 판독과 매 프레임 휠 선택은 그대로입니다.
- 오프라인 비교에서 240프레임 메뉴 조회는 960에서 720회, 같은 아틀라스의 8개 아이콘 조회는 3840에서 480회였습니다. 메모리 읽기 횟수와 호버 그리기 결과는 같으며, 실제 FPS 개선은 적용 후 확인해야 합니다.
- 다른 언어에서 한국어로 복귀할 때 이전 옵션 문구가 남는 갱신 순서 문제를 수정했습니다. 언어 판독 후 메뉴의 번역 캐시를 갱신합니다.
- 46개 옵션 이름·설명·선택값·카테고리를 게임의 지원 언어 14개로 번역했습니다. 미지원 또는 판독 실패 시 영어로 표시하며 저장값은 유지합니다. 휠 이름은 기존 한국어·영어 표시를 유지합니다.
- 0.3.57에서 설정 모듈 연결 후에도 탭이 추가되지 않던 문제를 수정했습니다. Bingus Shared Loader v19의 after_startup에서 최종 업데이트 연결을 감싸, 게임이 이전 콜백을 저장한 경우에도 상단 탭 처리를 실행합니다.
- 여러 HUD·모드가 연결된 환경의 탐색과 일시적 실패 후 재시도를 유지합니다. 콜백을 고정한 실제 제공자 코드 회귀 검사를 추가했습니다.
- 0.3.55에서 Arsenal이 배포 파일을 찾지 못하던 문제를 수정했습니다. 헬퍼와 기본 설정, 한글 글꼴의 48개 리소스를 ZIP 최상위의 단일 패치로 배포합니다.
- ESC 상단에 별도 HD2H 탭을 추가했습니다. 기존 헬퍼 설정 46개를 이 탭에서 조절하며, 다른 모드 설정은 MODS에 남습니다.
- Arsenal 옵션 선택창은 숨겼습니다. 기존 옵션 정의·변형 파일·아이콘은 소스와 arsenal-options.hidden.json에 보존하며, 기본 설정을 자동 배포합니다.
- 일반 설정 9개, 공용 스트라타젬 5개, 임무 스트라타젬 32개를 세 카테고리로 분리했습니다. 개별 표시 설정은 직접 켜고 끄는 토글입니다.
- APPLY로 적용한 설정은 다음 업데이트에 반영됩니다. 옵션 메뉴가 저장한 값이 Arsenal 기본값보다 우선하며, 다른 모드의 저장값을 지우거나 수정하지 않습니다.
- 자동재장전, 차량 재장전, 레일건 90%/95%, 에포크 자동발사, 휠 크기 100/125/150/200/300%, 커맨드 딜레이, 숫자 단축키와 공용/임무 표시 옵션을 지원합니다.
- 설정 변경 중 진행하던 휠 선택과 미완료 커맨드는 취소하고 모드가 누른 입력을 해제합니다. 다음 사용은 키를 놓았다가 다시 눌러 시작하며, 이전 입력을 재생하지 않습니다.
- 언어별 ZIP을 하나로 통합했습니다. 옵션은 게임 텍스트 언어를 따르며, 기존 인게임 설정 ID와 저장값을 유지합니다.
- 드론 원격 조종 0.2.1과의 입력 소유권 협력을 유지합니다. 드론 조종 중 휠 및 자동재장전 입력을 잠시 중단하고, 복귀 후 새 입력부터 처리합니다. 드론 모드 자체는 이 패키지에 포함되지 않습니다.
- 옵션 메뉴가 없으면 배포 기본값으로 계속 작동합니다. 미지원 탭 구조나 탭 공간 부족은 MODS 표시로 복귀하며, 메뉴의 오류 정지·재개를 존중합니다.
- 오프라인 회귀 및 패키지 검사는 통과했습니다. 새 버전의 실제 인게임 옵션 표시·APPLY·재실행 저장값 및 멀티 동작은 적용 후 확인이 필요합니다.

### English

- Fixes the permanent runtime-error latch in automatic reload and Railgun/Epoch release. Releases owned inputs and retries recovery with a bounded 1-5 second backoff. Automation resumes on a fresh fire-button press, never on release or an already-held input; stale shots are not replayed.
- Keeps weapon sampling during recovery and event-logs errors, recovery and blocking gates. Normal release-triggered reload, one-second post-release checks, the 50ms weapon poll and user settings are unchanged. Live recovery still requires gameplay validation.
- Reduces helper overhead without changing features or polling/input timing: reusable native read buffers, frame-local menu/icon resource deduplication, idle wheel cleanup and key-state reuse. The 50ms reload poll and per-frame wheel selection remain unchanged.
- Offline 240-frame counters reduce menu queries from 960 to 720 and shared-atlas image queries from 3840 to 480. Read counts and hover rendering stay identical; this is not a measured game FPS result.
- Fixes stale cached option text when returning to Korean from another language. Refreshes the checked provider translation model after the helper's language poll.
- Translates all 46 option names, descriptions, custom choices and category titles into the game's 14 supported languages. Unsupported or unreadable codes fall back to English. The wheel's existing Korean/English names are unchanged.
- Fixes tab processing never running after provider connection in 0.3.57. Bingus Shared Loader v19's after_startup hook wraps the final mod chain before the game can cache its update callback.
- Retains noisy HUD-chain discovery and bounded retries. Adds actual-provider regression coverage with a cached engine callback.
- Fixes missing Arsenal deployment in 0.3.55. One root archive deploys all 48 helper, default-setting and Korean-font resources without option selections.
- Adds a separate top-level HD2H tab for all 46 helper settings, leaving other mods in MODS.
- Hides the Arsenal editor without deleting its definitions, variants or icons. Defaults deploy automatically; the legacy editor is preserved in arsenal-options.hidden.json.
- Three categories contain 9 general settings, 5 common-call settings and 32 mission-call settings. Individual visibility settings are direct toggles.
- APPLY takes effect on the next update. Saved menu values override Arsenal defaults; other mods' saved values are never removed or edited.
- Includes personal/vehicle reload, Railgun 90%/95%, Epoch auto release, wheel scale 100/125/150/200/300%, command delay, number hotkeys and common/mission visibility.
- Setting changes cancel stale wheel selections and partial commands and release owned inputs. A fresh key activation is required; previous commands are not replayed.
- One ZIP follows the game's Text Language for options. Stable in-game IDs and saved values are retained.
- Retains input-owner cooperation with Drone Remote Control 0.2.1: wheel and reload automation pause during drone control and rearm for fresh input after return. The drone mod is not bundled.
- Missing option menus retain deployed defaults. Unsupported private tab layouts or exhausted tab capacity keep MODS categories. The provider's safety pause and resume are respected.
- Offline regressions and package checks passed. Live menu rendering, APPLY, saved values after restart and multiplayer behavior still require testing after installation.

### 설치 / Installation

통합판 `HD2-AutoReload-0.3.61-test.zip`을 설치하세요. 게임을 종료한 상태에서 Arsenal에서 이전 버전을 교체하고 Purge / Deploy 후 재시작하세요. Bingus Shared Loader / API 1은 필수이며 v19를 권장합니다. [CowboyBingus Mod Options Menu 1.2](https://github.com/CowboyBingus/ModOptionsMenu)는 인게임 설정을 바꿀 때 필요하고, 없어도 헬퍼 기능은 배포 기본값으로 작동합니다. 독립 HD2H 상단 탭에는 Loader v19와 옵션 메뉴 API 1 version 3이 모두 필요합니다. 로더와 옵션 메뉴는 별도로 설치하세요. HUD+와 Mod Bindings Menu는 필요하지 않습니다.

Install the unified `HD2-AutoReload-0.3.61-test.zip`, replacing the previous version in Arsenal. Purge / Deploy with the game closed, then restart. Bingus Shared Loader / API 1 is required; v19 is recommended. [CowboyBingus ModOptionsMenu 1.2](https://github.com/CowboyBingus/ModOptionsMenu) is needed only for editable in-game settings; without it, helper features retain deployed defaults. The separate HD2H tab requires Loader v19 and menu API 1 version 3. Install these dependencies separately. HD2 HUD+ and Mod Bindings Menu are not required. Older loaders retain legacy update integration; unsupported menu layouts retain MODS.

개인용 차량 조종 수정본과 드론 모드는 포함하지 않으며 공개 게시하지 않습니다. 설치된 모드와 실행 중인 게임은 개발·게시 과정에서 변경하지 않았습니다.

Personal vehicle-control modifications and the drone mod are not bundled or publicly published here. Installed mods and the running game were not changed during development or publication.

### 검증 / Validation

LuaJIT 회귀 검사, 14개 언어의 46개 메뉴 옵션 스키마 및 통합 패키지 검사를 통과했습니다. 설치된 Arsenal의 수집 코드로 48개 배포 리소스를 확인했고, HD2SDK로 패치와 한글 글꼴을 검증했습니다. 모의 옵션 제공자로 언어 전환·설정 저장값·탭 연결을 검사했습니다. 현재 설치된 옵션 메뉴의 실소스 추가 검사는 예상 API 1 version 3 검사 자료가 맞지 않아 건너뛰었습니다. 실제 인게임 메뉴·복구·멀티 검증은 필요합니다. 설치된 모드나 실행 중인 게임은 변경하지 않았습니다.

LuaJIT regressions, all 46 menu schema entries across 14 languages and the unified package passed. The installed Arsenal collector confirms 48 deployment resources; HD2SDK validates archive payloads and the Korean font. Mock-provider tests cover language refresh, saved values and tab integration. The optional installed-menu-source check was skipped because the expected API 1 version 3 fixture was unavailable. Live menu, recovery and multiplayer validation remain necessary. Installed mods and the running game were not changed.
'@
try {
    $remoteCommit = Invoke-RestMethod -Uri ("https://api.github.com/repos/$Repository/commits/$Commit") -Headers $headers
    if ($remoteCommit.sha -ne $Commit) { throw 'Source commit is not available on GitHub.' }
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.61-test (Runtime Recovery)';
            body = $notes; draft = $true; prerelease = $true } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    } elseif ($release.target_commitish -ne $Commit) {
        throw 'Existing release targets a different source commit; not replacing it.'
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
    $tagCommit = Invoke-RestMethod -Uri ("https://api.github.com/repos/$Repository/commits/$Tag") -Headers $headers
    if ($tagCommit.sha -ne $Commit) { throw 'Published tag does not match the source commit.' }
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
