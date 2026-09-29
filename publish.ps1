param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.14-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.14-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload 0.3.14-test

게임 파일의 타입 해시로 장착 무기를 식별할 수 있는지 확인하는 테스트 빌드입니다. 이전 0.3.13-test에서 F9 입력이 20ms 읽기 간격에 걸리면 사라지던 문제를 수정했습니다.

- 임무에서 이미 인식되는 무기(예: 대거)를 들고 F9를 누르면 `HASH_TYPE requested`를 즉시 기록하고, 다음 읽기에서 기존 문자열 타입 검사와 게임 타입 해시 검사를 동일 객체에 대해 한 번씩 실행합니다. 두 번째 F9는 `already-checked`로 기록하며 추가 조회하지 않습니다.
- `baseline=true hash=true`이면 해시로 타입을 검사하는 단계가 성공한 것입니다. 이 결과만으로 미등록 무기의 장착 여부나 탄약 필드까지 식별된 것은 아닙니다.
- 함선 진입 중 종료가 보고된 전체 필드 스캔과 기존의 여러 API 동시 검사는 실행하지 않습니다. 직전 빌드의 `UNIT_LINK`는 실제 게임에서 `no-synchronizer`를 반환하여 이번 실행 경로에서 제거했습니다.
- 기존에 인식되는 무기의 자동장전 동작은 유지합니다. **LAS-12 사이 같은 목록 밖 무기는 아직 자동장전되지 않습니다.**
- **탱크 주포 자동장전은 아직 활성화하지 않았습니다.** 주포의 장탄, 예비탄, 장전 중 상태를 식별하기 전에는 R을 누르지 않습니다.

### 설치 및 제한

게임을 종료한 상태에서 이전 Auto Reload 버전을 이 ZIP으로 교체하세요.
HD2 HUD, Auto Reload, Bingus Shared Loader v15+ / API 1을 함께 활성화하세요.
Bingus가 Wwise 시작 스크립트 충돌에서 우선하도록 배치한 뒤 제거/재배포하고 게임을 다시 시작하세요.
HD2 HUD는 끄지 마세요. 기존 헬퍼 자동 재장전과 이전 Auto Reload 진단/보조 스크립트만 끄고 테스트하세요.
기본 키는 좌클릭 / R이며 `%APPDATA%\HD2AutoReload.ini`에서 변경할 수 있습니다.
활성 언더배럴, 차량/거치 무기는 이번 테스트에서 제외했습니다. Windows 입력 전송 성공은 게임 내 재장전 완료를 뜻하지 않습니다.
LuaJIT 모의 테스트를 통과했습니다. 실제 게임에서 함선 진입 안정성과 F9 조회를 확인해야 합니다. 이 빌드에서는 `CATALOG_API`, `SELF_INPUT`, `SELF_DELTA`를 수집하지 않습니다.

진단: 임무에 착륙한 뒤 대거처럼 이미 인식되는 무기를 들고 F9를 한 번 누르세요. `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`의 `HASH_TYPE` 한 줄을 확인하면 됩니다. 인식되지 않는 사이를 든 상태라면 게임 객체를 조회하지 않고 `skipped`로 기록합니다.

진단 로그: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`

### 출처

기존 자동장전의 탄약 읽기 코어는 DDRK1NG의 HD2 HUD+ 0.1.2에 포함된 명시적 재사용 허용 README에 따라 활용했습니다. 새 진단기는 이 무기 목록을 사용하지 않습니다.
원본 권한 README와 출처를 패키지에 포함했습니다. 원본 게임 부트/화면 표시 코드와 최신 HUD 버전은 복제하지 않았습니다.
[HD2 HUD+](https://www.nexusmods.com/helldivers2/mods/15298) · [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader)
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.14-test (F9 diagnostic latch)';
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
