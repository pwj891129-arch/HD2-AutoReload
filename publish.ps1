param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.8-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.8-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload 0.3.8-test

HD2 HUD와 함께 사용할 수 있는 Arsenal / Bingus용 별도 자동 재장전 애드온 테스트입니다.

- 숫자키 줄의 1·2·3으로 무기를 선택하면 1.1초 기다린 후 해당 주무기·보조무기·지원무기가 실제로 손에 있고 탄창이 빈 상태인지 다시 확인합니다. 숫자패드는 이 입력으로 취급하지 않습니다.
- 탱크 부사수석에서 우클릭으로 몸을 내밀어 일반총기를 발사할 때, 발사 중 및 직후 짧은 구간에 한해 개인 무기 탄약을 읽도록 했습니다. 무기가 실제 손 위치에서 확인되지 않으면 차단합니다.
- `SEAT_AIM`에는 손 위치 판독 이유를 추가하고, grip 70 진단에는 조준·발사 시점 `PROBE_INPUT`을 기록합니다.
- 탱크 진단 중 조준·발사 입력이 반복되어도 12개씩 순환하는 탐색 페이지가 처음부터 다시 시작되지 않도록 했습니다.
- 대거의 완전 과열 재장전은 이전 테스트에서 실제 동작이 확인됐습니다.
- **탱크 주포 자동장전은 아직 활성화하지 않았습니다.** 주포의 장탄, 예비탄, 장전 중 상태를 식별하기 전에는 R을 누르지 않습니다.
- **LAS-12 사이는 아직 장비 식별 데이터가 없어 자동장전 대상이 아닙니다.**

### 설치 및 제한

게임을 종료한 상태에서 이전 Auto Reload 버전을 이 ZIP으로 교체하세요.
HD2 HUD, Auto Reload, Bingus Shared Loader v15+ / API 1을 함께 활성화하세요.
Bingus가 Wwise 시작 스크립트 충돌에서 우선하도록 배치한 뒤 제거/재배포하고 게임을 다시 시작하세요.
HD2 HUD는 끄지 마세요. 기존 헬퍼 자동 재장전과 이전 Auto Reload 진단/보조 스크립트만 끄고 테스트하세요.
기본 키는 좌클릭 / R이며 `%APPDATA%\HD2AutoReload.ini`에서 변경할 수 있습니다.
활성 언더배럴, 차량/거치 무기는 이번 테스트에서 제외했습니다. Windows 입력 전송 성공은 게임 내 재장전 완료를 뜻하지 않습니다.
분리된 LuaJIT 테스트 375개 검증 항목이 통과했습니다. 이번 숫자키·부사수석 변경은 실제 게임에서 재확인이 필요합니다.

탱크 진단: 사수석에서 장탄 `1/1` 상태로 조준해 15초 유지한 다음 발사하여 `0/1`을 15초 유지하고, 수동 장전 뒤 `1/1`을 다시 15초 유지해 주세요. 기록된 `TANK_PROBE` 값을 비교합니다.
부사수석 진단: 우클릭으로 몸을 내민 뒤 일반총기 탄약을 소진하고 `seated_fire=true` 및 `RELOAD ammo-exhausted`를 확인해 주세요.

진단 로그: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`

### 출처

탄약 읽기 코어는 DDRK1NG의 HD2 HUD+ 0.1.2에 포함된 명시적 재사용 허용 README에 따라 활용했습니다.
원본 권한 README와 출처를 패키지에 포함했습니다. 원본 게임 부트/화면 표시 코드와 최신 HUD 버전은 복제하지 않았습니다.
[HD2 HUD+](https://www.nexusmods.com/helldivers2/mods/15298) · [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader)
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.8-test (weapon swap and passenger reload)';
            body = $notes; draft = $true; prerelease = $true } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    }
    $expectedHash = (Get-FileHash -LiteralPath $AssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $existing = $release.assets | Where-Object name -eq $assetName | Select-Object -First 1
    if ($existing) {
        if ($existing.digest -ne "sha256:$expectedHash") { throw 'Existing package differs; not replacing it.' }
    } else {
        $uri = $release.upload_url.Split('{')[0] + '?name=' + [Uri]::EscapeDataString($assetName)
        $uploaded = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/zip' -InFile $AssetPath
        if ($uploaded.state -ne 'uploaded' -or $uploaded.digest -ne "sha256:$expectedHash") {
            throw 'Asset upload verification failed; leaving draft unpublished.'
        }
    }
    if ($release.draft) {
        $body = @{ draft = $false; prerelease = $true; make_latest = 'false' } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Patch -Uri ($api + '/' + $release.id) -Headers $headers -ContentType 'application/json' -Body $body
    }
    $verified = Invoke-RestMethod -Uri ($api + '/tags/' + $Tag) -Headers $headers
    $asset = $verified.assets | Where-Object name -eq $assetName | Select-Object -First 1
    if ($verified.draft -or -not $verified.prerelease -or $asset.digest -ne "sha256:$expectedHash") {
        throw 'Published release verification failed.'
    }
    [ordered]@{ url = $verified.html_url; prerelease = $verified.prerelease; asset = $asset.name;
        sha256 = $expectedHash; sourceCommit = $Commit } | ConvertTo-Json
} finally {
    $headers.Clear(); $credential.Clear(); $credentialLines = $null
}
