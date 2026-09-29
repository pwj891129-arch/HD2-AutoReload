param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.11-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.11-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload 0.3.11-test

함선 진입 중 종료 문제 대응을 위한 긴급 테스트 빌드입니다.

- `0.3.10-test`에서 함선 진입 중 게임 종료가 보고되었습니다. 로그는 `CATALOG_API` 호출 전에 끊겼으므로 원인은 아직 확정되지 않았습니다.
- 함선의 여러 소유 객체를 읽던 독립 필드 탐색기와 새 해시 API 검증을 모두 자동 실행하지 않도록 했습니다.
- 기존에 인식되는 무기의 자동장전 동작은 유지합니다. **LAS-12 사이 같은 목록 밖 무기는 아직 자동장전되지 않습니다.**
- **탱크 주포 자동장전은 아직 활성화하지 않았습니다.** 주포의 장탄, 예비탄, 장전 중 상태를 식별하기 전에는 R을 누르지 않습니다.

### 설치 및 제한

게임을 종료한 상태에서 이전 Auto Reload 버전을 이 ZIP으로 교체하세요.
HD2 HUD, Auto Reload, Bingus Shared Loader v15+ / API 1을 함께 활성화하세요.
Bingus가 Wwise 시작 스크립트 충돌에서 우선하도록 배치한 뒤 제거/재배포하고 게임을 다시 시작하세요.
HD2 HUD는 끄지 마세요. 기존 헬퍼 자동 재장전과 이전 Auto Reload 진단/보조 스크립트만 끄고 테스트하세요.
기본 키는 좌클릭 / R이며 `%APPDATA%\HD2AutoReload.ini`에서 변경할 수 있습니다.
활성 언더배럴, 차량/거치 무기는 이번 테스트에서 제외했습니다. Windows 입력 전송 성공은 게임 내 재장전 완료를 뜻하지 않습니다.
분리된 LuaJIT 테스트 402개 항목을 통과했습니다. 실제 게임에서 함선 진입이 정상적으로 되는지 먼저 확인해야 합니다. 이 빌드에서는 `CATALOG_API`, `SELF_INPUT`, `SELF_DELTA`를 수집하지 않습니다.

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
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.11-test (disable experimental probes)';
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
