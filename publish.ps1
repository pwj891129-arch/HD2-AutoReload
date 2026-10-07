param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.54-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.54-test-en.zip', 'HD2-AutoReload-0.3.54-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.54-test

### 업데이트 내역

- 기존 Arsenal 옵션 46개를 CowboyBingus Mod Options Menu 1.2의 ESC > MODS 탭에서도 조절할 수 있습니다.
- 일반 설정 9개, 공용 스트라타젬 5개, 임무 스트라타젬 32개를 세 카테고리로 분리했습니다. 개별 표시 설정은 직접 켜고 끄는 토글입니다.
- APPLY로 적용한 설정은 다음 업데이트에 반영됩니다. 옵션 메뉴가 저장한 값이 Arsenal 기본값보다 우선하며, 다른 모드의 저장값을 지우거나 수정하지 않습니다.
- 자동재장전, 차량 재장전, 레일건 90%/95%, 에포크 자동발사, 휠 크기 100/125/150/200/300%, 커맨드 딜레이, 숫자 단축키와 공용/임무 표시 옵션을 지원합니다.
- 설정 변경 중 진행하던 휠 선택과 미완료 커맨드는 취소하고 모드가 누른 입력을 해제합니다. 다음 사용은 키를 놓았다가 다시 눌러 시작하며, 이전 입력을 재생하지 않습니다.
- 영어 ZIP은 영어, 한국어 ZIP은 한국어로 옵션을 표시합니다. Arsenal 옵션 순서와 기존 기본값은 유지했습니다.
- 드론 원격 조종 0.2.1과의 입력 소유권 협력을 유지합니다. 드론 조종 중 휠 및 자동재장전 입력을 잠시 중단하고, 복귀 후 새 입력부터 처리합니다. 드론 모드 자체는 이 패키지에 포함되지 않습니다.
- 옵션 메뉴가 없거나 구버전이면 Arsenal 설정으로 계속 작동합니다. 일시적인 등록·판독 실패는 재시도하며, 이미 적용한 값을 보존합니다.
- 오프라인 회귀 및 패키지 검사는 통과했습니다. 새 버전의 실제 인게임 옵션 표시·APPLY·재실행 저장값 및 멀티 동작은 적용 후 확인이 필요합니다.

### English

- All 46 existing Arsenal settings are also available through ESC > MODS with CowboyBingus Mod Options Menu 1.2.
- Three categories contain 9 general settings, 5 common-call settings and 32 mission-call settings. Individual visibility settings are direct toggles.
- APPLY takes effect on the next update. Saved menu values override Arsenal defaults; other mods' saved values are never removed or edited.
- Includes personal/vehicle reload, Railgun 90%/95%, Epoch auto release, wheel scale 100/125/150/200/300%, command delay, number hotkeys and common/mission visibility.
- Setting changes cancel stale wheel selections and partial commands and release owned inputs. A fresh key activation is required; previous commands are not replayed.
- EN and KO ZIPs use their respective menu language, retaining Arsenal option order and defaults.
- Retains input-owner cooperation with Drone Remote Control 0.2.1: wheel and reload automation pause during drone control and rearm for fresh input after return. The drone mod is not bundled.
- Missing/older option menus fall back to Arsenal settings. Temporary registration/read failures retry while preserving applied values.
- Offline regressions and package checks passed. Live menu rendering, APPLY, saved values after restart and multiplayer behavior still require testing after installation.

### 설치 / Installation

영어판 `HD2-AutoReload-0.3.54-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.54-test-ko.zip` 중 **하나만** 설치하세요. 게임을 종료한 상태에서 Arsenal에서 이전 버전을 교체하고 Purge / Deploy 후 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다. 인게임 설정에는 별도 [CowboyBingus Mod Options Menu 1.2](https://github.com/CowboyBingus/ModOptionsMenu)가 필요합니다. 기존 API version 2 메뉴에서는 새 카테고리가 등록되지 않으므로 메뉴를 업데이트하세요.

Install **one** language ZIP, replacing the previous version in Arsenal. Purge / Deploy with the game closed, then restart. Requires Bingus Shared Loader v18 / API 1. In-game settings additionally require [CowboyBingus Mod Options Menu 1.2](https://github.com/CowboyBingus/ModOptionsMenu), public API 1 version 3 or newer. Older API version 2 menus do not support the required category IDs.

개인용 차량 조종 수정본과 드론 모드는 포함하지 않으며 공개 게시하지 않습니다. 설치된 모드와 실행 중인 게임은 개발·게시 과정에서 변경하지 않았습니다.

Personal vehicle-control modifications and the drone mod are not bundled or publicly published here. Installed mods and the running game were not changed during development or publication.

### 검증 / Validation

LuaJIT 회귀 검사, 46개 메뉴 옵션 스키마 및 영어/한국어 패키지 검사를 통과했습니다. 로드 순서, 저장값 우선순위, 일시적인 등록·판독·구독 실패, 잘못된 값 거부, 적용값 실시간 변경, Arsenal 전체 OFF에서 인게임 활성화, 기존 드론 연동과 휠 복구를 모의 검증했습니다. 설치된 모드나 실행 중인 게임은 변경하지 않았습니다.

LuaJIT regressions, all 46 menu schema entries and both language packages passed. Mock tests cover load order, saved-value precedence, transient registration/read/subscription failures, invalid values, live changes, enabling an Arsenal-disabled feature, retained drone cooperation and wheel recovery. Installed mods and the running game were not changed.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.54-test (In-Game MODS Settings)';
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
