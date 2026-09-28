param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.3-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.3-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload 0.3.3-test

HD2 HUD와 함께 사용할 수 있는 Arsenal / Bingus용 별도 자동 재장전 애드온 테스트입니다.

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
분리된 LuaJIT 테스트 301개 검증 항목이 통과했습니다. HD2 HUD+ 0.1.2의 실제 콜백 구현을 테스트 참조로 사용했습니다.
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
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.3-test (missile pistol reload)';
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
