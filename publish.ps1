param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.41-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.41-test-en.zip', 'HD2-AutoReload-0.3.41-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.41-test

탄약 배낭을 사용하는 무기의 자동재장전을 지원하고, 한국어판 스트라타젬 휠 이름을 한국어로 표시하도록 변경했습니다.

- 무기 본체의 여분 탄이 없을 때 실제 착용한 호환 탄약 배낭의 남은 탄약을 확인합니다. 게임의 지원 장전 설정·배낭 장착 슬롯·배낭 종류·무기 호환성·장전 1회 필요량을 읽기 전용으로 검사하며, 무기 이름 목록이나 HD2 HUD+ 데이터에 의존하지 않습니다.
- 배낭 탄약이 부족하거나 비어 있을 때, 다른 무기용 배낭·보급 팩일 때, 배낭을 버렸거나 데이터를 확인할 수 없을 때는 자동장전하지 않습니다. 다른 플레이어나 바닥의 배낭을 검색하지 않습니다.
- 배낭을 바꾸거나 게임 객체가 바뀌면 재확인하며, 장전 입력 전 무기·착용자·배낭·탄약의 일치 여부를 재검사합니다.
- 이동 불가 무기의 기존 동작은 유지합니다. 발사 버튼을 놓을 때는 장전하지 않고, 빈 무기에서 다시 클릭하면 장전합니다. 무기교체 검사와 메뉴·채팅·장전 중 차단도 유지합니다.
- 한국어판 휠은 스트라타젬 이름도 한국어로 표시합니다. 현재 149개 게임 정의 중 141개는 게임의 한국어 이름, 이름이 없는 8개는 대체 이름을 사용합니다. 영어판은 기존 영어 표시를 유지합니다. 커맨드·장착 슬롯 번호·가용 상태·아이콘·표시 옵션은 변경하지 않습니다.
- 한글은 게임에 이미 로드된 한국어 글꼴로 표시합니다. 한글 글꼴이 없으면 깨진 글자 대신 영어 대체 이름을 표시하고 로그를 남깁니다. 게임 UI도 한국어로 설정하는 것을 권장합니다. 원본 폰트·UI 패키지는 배포하지 않습니다.
- 영어판 `HD2-AutoReload-0.3.41-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.41-test-ko.zip` 중 하나만 설치하세요. 옵션 순서·기본값·저장 경로는 유지했습니다.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 체크 상태를 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Arsenal은 새 옵션을 처음 가져올 때 체크합니다. 이제 체크된 개별 항목은 ON이므로 표시하지 않을 항목은 해제하세요. 새로 가져온 자동재장전·충전 자동발사도 체크된 ON 상태로 시작합니다. 이전 선택이 유지될 수 있으므로 교체 후 다시 확인하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

개별 체크값을 사용하려면 공용/임무 전체 표시 모드를 ‘개별 설정 사용’으로 두세요. 전체 ON/OFF 모드는 체크값을 덮어쓰되 지우지는 않습니다. 원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이**를 체크하세요. 하나 이상의 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 조준·투척은 수동입니다.

### English

Supports compatible equipped ammo backpacks when the held weapon has no personal spare ammo. Reads the game's self-assisted reload requirement, inventory backpack slot, equipment class and DepositComponent compatibility/count without a weapon list or HUD+ data. Empty, insufficient, incompatible, dropped or unreadable backpacks do not authorize reload. Identity/count changes require fresh coherent readings. Existing stationary empty-click reload, weapon-switch checks and input gates remain unchanged.

The Korean ZIP localizes wheel names as well as Arsenal options: 141 installed game translations and eight explicit fallback names across the 149 pinned definitions. The English ZIP retains English labels. Commands, readiness, slot numbers, icons and visibility are unchanged. Text uses already-loaded native Korean fonts; missing fonts fall back to readable English with a log message. No original font or UI-package binaries are shipped. Korean game UI language is recommended.

Install **one** ZIP: `-en.zip` or `-ko.zip`. Arsenal initially checks new options, so review checkbox states and uncheck unwanted calls. Use Individual Settings in the bulk controls to honor individual checks. Replace the previous version, then Purge / Deploy and restart with the game closed and Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

30,766개 LuaJIT 모의 검사와 언어판별 5,067가지 배포 시나리오를 통과했습니다. 배낭 종류·호환성·필요 탄약량·설정 우선순위·판독 실패·장착 해제·객체 교체·재확인, 이동 불가 무기 클릭 장전, 한국어 이름 대응·커맨드/슬롯 유지·한글 폰트 대체와 기존 휠/충전 동작을 검사했습니다. 기존 로컬 캡처로 네이티브 판독 위치를 확인하고 40,000개 해시 계산을 검증했습니다. 설치된 게임 파일의 한국어 이름과 한글 글리프 범위, 44개 미리보기도 확인했습니다. 실제 Arsenal UI 및 게임 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.41-test (Backpack reload + Korean wheel)';
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
