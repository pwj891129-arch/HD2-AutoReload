param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.30-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.30-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload + Stratagems 0.3.30-test

0.3.29-test 통합 버전에서 모드 본체가 Arsenal 배포에서 빠져 스트라타젬 휠과 자동재장전이 시작되지 않는 문제를 수정했습니다.

- 현재 Arsenal 0.36.2 BETA에서는 가져온 ZIP에 본체가 있었지만 실제 게임에는 설정 파일 7개만 배포된 것을 확인했습니다. Shared Loader에도 통합 모드의 로드 기록이 없었습니다.
- 본체를 공통 Core 폴더로 옮기고 모든 ON/OFF 선택에 명시적으로 포함했습니다. 여러 설정을 선택해도 본체는 공통 폴더에서 한 번만 포함됩니다. OFF는 해당 기능만 끄고 본체 포함은 유지합니다.
- 원형 오버레이 ON 등 원하는 설정을 하나 이상 선택해야 합니다. 모든 옵션을 선택 해제하면 배포할 파일이 없습니다. 본체가 배포된 상태에서 선택하지 않은 개별 기능은 기존 기본값을 사용합니다.
- 별도 HD2 Stratagem Hotkeys 모드를 설치할 필요는 없습니다. 최신 0.1.13-test의 아이콘 조회 수정과 엄지버튼 해제 보완을 유지했습니다.
- 자동재장전과 레일건·에포크 90% 충전 자동발사는 기본 ON입니다. 옵션을 선택하지 않아도 켜지며, 각각 OFF로 끌 수 있습니다. 충전 자동발사는 좌클릭을 한 번 놓는 방식이며 조준과 다음 충전은 수동입니다.
- 원형 메뉴와 숫자 핫키도 기본 ON입니다. 공용/임무 스트라타젬 표시, 큰 메뉴(130%), 30ms 커맨드 입력은 기본 OFF이며 Arsenal에서 선택할 수 있습니다. 기본 커맨드 입력 간격은 15ms입니다.
- 스트라타젬 입력 상태를 같은 프레임의 자동재장전·충전 검사보다 먼저 갱신해 두 기능의 입력이 끼어들지 않도록 했습니다. 한 기능의 초기화 실패나 OFF 설정이 다른 기능을 막지 않도록 분리했습니다.
- 기존 50ms 판독, 발사키 해제 후 1초 검사, 무기 교체 대기, 잔탄·과열·예비탄 안전 조건과 게임에 저장된 스트라타젬 방향키를 유지했습니다. 스트라타젬은 커맨드만 자동이며 조준·투척은 수동입니다.
- 인게임 설정 메뉴 없이 Arsenal에서만 설정합니다. 시험용 진단 기능과 F9/F10 입력은 추가하지 않았습니다. Lua-only 패키지이며 게임 이미지·재질·셰이더·글꼴을 포함하지 않습니다.

탱크 주포의 자동재장전은 이번 버전에서도 제외됩니다. 몸을 내밀고 사용하는 개인 무기의 장전 조건은 유지했습니다. F8은 자동재장전·충전 자동발사만 임시로 중지하며 스트라타젬 메뉴는 유지합니다.

### 설치

게임을 종료하고 Arsenal에서 이전 Auto Reload 버전을 이 통합 ZIP으로 교체하세요. **별도 HD2 Stratagem Hotkeys 모드는 비활성화하거나 제거**한 뒤 Bingus Shared Loader v18 / API 1과 함께 반드시 Purge / Deploy 하세요. 이전 옵션 파일이 남지 않도록 해야 합니다.
Arsenal에서 **스트라타젬 원형 오버레이 ON을 선택**하고 원하는 다른 설정도 선택하세요. 적어도 하나 이상의 ON/OFF 선택이 필요합니다. 자동재장전·충전 자동발사·원형 메뉴·숫자 핫키의 기본값은 ON입니다. 이전에 선택했던 충전 OFF가 유지될 수 있으므로 **90% 충전 자동발사 ON**도 확인하세요. 명시한 OFF 설정을 자동으로 덮어쓰지 않습니다. 옵션 변경 후에도 재배포와 게임 재시작이 필요합니다.
게임의 스트라타젬 목록 열기 버튼은 **누르고 있기(Hold)**로 설정하세요. 키보드와 앞·뒤 마우스 엄지버튼을 지원합니다. 기존 외부 헬퍼의 동일 기능과 다른 자동장전 스크립트는 꺼서 중복 입력을 막으세요. Mod Options Menu와 Mod Bindings Menu는 필요하지 않습니다.
자동재장전 로그: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`
스트라타젬 로그: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_stratagem_hotkeys.log`

총 4,757개 LuaJIT 모의 검사와 설정 조합 2,187가지 패키지 검사를 통과했습니다. 모든 ON/OFF 선택의 본체 포함, 공통 본체 중복 방지와 모두 선택 해제한 상태를 확인했습니다. 현재 배포 기록과 설치 파일은 읽기 전용으로 확인했으며 변경하지 않았습니다. 새 패키지의 실제 Arsenal 재배포와 인게임 동작은 확인이 필요합니다. 기존 50ms 판독과 프레임·입력 지연으로 충전 해제 시점은 90%를 넘을 수 있으며 폭발 방지를 보장하지 않습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.30-test (explicit core deployment fix)';
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
