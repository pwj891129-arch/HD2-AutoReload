param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.6-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.6-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload 0.3.6-test

HD2 HUD와 함께 사용할 수 있는 Arsenal / Bingus용 별도 자동 재장전 애드온 테스트입니다.

- 에너지 무기 상태 로그에 과열 판정, 방열판 예비분, 장전 중 여부, 열 게이지를 추가했습니다.
- 보조석에서 우클릭할 때 `SEAT_AIM` 로그로 무기 그립과 조작 가능 판정을 수집합니다. 좌석 힌트만으로 장전을 시도하지 않습니다.
- 탱크 진단이 첫 12개 객체에 머물지 않고, 250ms마다 12개씩 순환하면서 바뀐 수치만 기록합니다.
- 좌석 전환 힌트가 달라지면 탄약 필드가 같아도 새로운 힌트를 기록하고, 게임 세션이 바뀌면 진단 상태를 초기화합니다.
- 새 게임 진입 또는 리스폰 뒤 아바타가 복귀하면 무기 식별 캐시를 갱신합니다.
- 보조·지원무기 탐색 실패가 일시적인 무기 교체 구간을 넘어 지속되면 2초 간격으로 제한해 재탐색합니다.
- 무기를 확실히 식별하지 못한 프레임에서는 재장전 입력을 보내지 않습니다. 실제 게임에서 복구 효과는 추가 검증이 필요합니다.
- 진단 로그에 `IDENTITY_RECOVERY`와 원시 소유 객체 수를 남겨 캐시 문제와 게임 데이터 부재를 구별할 수 있게 했습니다.
- 탱크 주포의 장전 상태와 여분 탄약 필드를 찾기 위한 **읽기 전용 진단**을 추가했습니다.
- TankSeatKit의 마지막 좌석 전환 힌트가 있고 기존 무기 리더가 탑승 상태로 차단될 때만 `TANK_PROBE` 로그를 기록합니다. 힌트는 현재 좌석의 확증이 아닙니다.
- 이번 빌드는 탱크 주포 자동 장전을 활성화하지 않습니다. 필드가 확인되기 전에는 추측으로 R을 누르지 않습니다.
- 기존 개인 무기의 여분 탄약이 0이거나 불명확하면 재장전하지 않는 조건은 유지됩니다.

진단하려면 게임을 종료하고 이 빌드를 설치한 뒤, 에너지 무기의 정확한 이름과 과열 시 로그를 확인해 주세요.
탱크에서는 좌석 전환 키를 한 번 사용한 다음 주포의 장탄 `1/1`, 발사 직후 `0/1`, 수동 장전 후 `1/1` 상태를 각각 15초 이상 유지하고 `TANK_PROBE` 로그를 비교해 주세요.
보조석에서는 우클릭으로 몸을 내밀 때 `SEAT_AIM` 로그를 확인해 주세요.

- 미사일 권총을 포함한 보조무기가 자동 재장전 대상에서 누락되던 분류 오류를 수정했습니다.
- 과열식 무기는 게임의 실제 과열 상태값이 `true`일 때만 재장전합니다. 탄약 0이나 붉은 열 게이지만으로는 재장전하지 않습니다.
- 과열 전환 직후, 과열 무기로 교체한 직후, 과열 중 발사 시도에 반응합니다.
- 과열 상태 또는 예비 열 교체분을 읽을 수 없거나 예비분이 0이면 입력하지 않습니다.

- HD2 HUD의 업데이트 콜백과 반환값을 유지합니다. HUD가 먼저 연결되거나 나중에 연결되는 경우를 모두 검증했습니다.
- 자동 재장전 콜백 오류가 HUD 업데이트나 기존 종료 콜백을 중단하지 않도록 격리했습니다.
- 다른 모드의 Win32 FFI 선언을 변경하지 않도록 함수 심볼에 전용 별칭을 사용합니다.
- HUD와 공유할 수 있는 탄약/표시 정의를 변경하지 않고 별도 필드 맵을 사용합니다.
- HUD의 GUI, 텍스처, 설정 파일, 시작 스크립트와 Wwise 리소스를 덮어쓰지 않습니다.
- 기존 세 가지 재장전 시점(탄 소진, 실제 무기 교체, 빈 무기로 발사 시도)은 유지합니다.

### 설치 및 제한

게임을 종료한 상태에서 이전 Auto Reload 버전을 이 ZIP으로 교체하세요.
HD2 HUD, Auto Reload, Bingus Shared Loader v15+ / API 1을 함께 활성화하세요.
Bingus가 Wwise 시작 스크립트 충돌에서 우선하도록 배치한 뒤 제거/재배포하고 게임을 다시 시작하세요.
HD2 HUD는 끄지 마세요. 기존 헬퍼 자동 재장전과 이전 Auto Reload 진단/보조 스크립트만 끄고 테스트하세요.
기본 키는 좌클릭 / R이며 `%APPDATA%\HD2AutoReload.ini`에서 변경할 수 있습니다.
활성 언더배럴, 차량/거치 무기는 이번 테스트에서 제외했습니다.
분리된 LuaJIT 테스트 339개 검증 항목이 통과했습니다. HD2 HUD+ 0.1.2의 실제 콜백 구현을 테스트 참조로 사용했습니다.
현재 게임에서 최신 HD2 HUD와의 실제 동시 실행 및 재장전 동작은 아직 확인하지 못했습니다.
HD2 HUD는 게임 버전에 맞는 빌드를 사용해야 합니다. 저자는 0.1.12를 9월 24일 게임 업데이트 대응 버전으로 안내합니다.
Windows 입력 전송 성공은 게임 내 재장전 완료를 뜻하지 않습니다.
모드의 게임/안티치트 허용 여부는 보증하지 않습니다.

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
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.6-test (heat and tank diagnostics)';
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
