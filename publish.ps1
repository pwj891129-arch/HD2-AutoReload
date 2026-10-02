param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.47-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.47-test-en.zip', 'HD2-AutoReload-0.3.47-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.47-test

차량 자동재장전을 별도 옵션으로 추가한 테스트 버전입니다.

- **Vehicle Automatic Reload / 차량 자동 재장전** 체크박스를 추가했습니다. 일반 자동재장전과 별도로 켜고 끌 수 있습니다. 기존 옵션의 저장 위치와 리소스 경로를 유지하기 위해 목록 끝에 배치했습니다.
- FRV·바스티온·마엘스트롬의 안정된 포수/파일럿석에 연결된 첫 번째 차량 무기를 판독합니다. 탱크 주포 등 장전 가능한 차량 무기가 대상이며, 모든 차량 무기 지원을 보장하는 버전은 아닙니다.
- 탄창과 약실이 모두 비어 있고 여분탄이 확인될 때만 장전합니다. 장전 중, 수동 장전 중, 좌석 전환, 차량 무기 입력 불가 상태에서는 시도하지 않습니다. 장전 불가·과열 방식·판독 불가 차량 무기는 제외합니다.
- 발사 버튼을 놓으면 장전을 확인합니다. 빈 차량 무기에 좌클릭을 다시 누르면 발사 입력을 해제한 뒤 장전을 시도할 수 있습니다. 탄 소진 1회당 자동 시도는 한 번으로 제한하며, 다시 클릭하면 재시도할 수 있습니다.
- 탱크 부사수석에서 몸을 내밀어 쓰는 개인 총기는 기존 일반 자동재장전 옵션을 따릅니다. 일반 무기 장전·배낭 장전·레일건/에포크 자동발사·스트라타젬 휠 설정은 유지합니다.
- 게임 메모리는 읽기 전용이며 탄약·차량 상태·운전 권한을 변경하지 않습니다. 다른 HUD 모드의 차량/무기 목록은 필요하지 않습니다.

### 설치

영어판 `HD2-AutoReload-0.3.47-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.47-test-ko.zip` 중 **하나만** 설치하세요. 이전 버전을 교체하고 차량 옵션 체크 상태를 확인한 뒤, 게임을 종료한 상태에서 Arsenal의 Purge / Deploy를 수행하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다. 새 체크박스는 처음 가져올 때 ON 상태일 수 있습니다. 차량 장전이 필요 없다면 새 옵션만 해제하세요. 개발·게시 과정에서는 설치된 모드와 실행 중인 게임을 변경하지 않았습니다.

### English

Adds an independent **Vehicle Automatic Reload** checkbox at the end of Arsenal options, preserving previous option positions and resource paths. The experimental path reads slot-0 reloadable mounts in settled FRV, Bastion and Maelstrom gunner/pilot seats. It requires an empty magazine AND chamber, known positive reserve, native vehicle weapon-control permission and no active reload. Native weapon-owner/animation links provide mounted reload state; personal avatar reload flags are not substituted for cannon state.

Held firing defers reload. Fire release or an empty left-mouse click can request it; a confirmed empty mount on seating can request one attempt. Automatic attempts are limited per empty episode, with explicit empty clicks able to retry. Passenger lean-out personal weapons continue to follow the personal reload checkbox. Unsupported seats, heat-only, non-reloadable and ambiguous mounts are excluded. All memory reads remain read-only and binary-hash pinned. Install one language ZIP and review the new checkbox before Purge / Deploy with the game closed.

### 검증 및 테스트 범위

LuaJIT 모의 검사, 차량/개인 옵션 독립성, 장전 중·여분탄 없음·탑승 전환·입력 차단 검사, 기존 게임 캡처의 네이티브 명령 확인 및 영어/한국어 배포 검사를 통과했습니다. 새 옵션 파일은 기존 휠 텍스처와 겹치지 않는 번호를 사용합니다. **실제 차량 장전과 멀티플레이·Solo Vehicle Driver 동시 사용은 아직 검증하지 않았습니다.** 탱크 주포와 FRV 포수석에서 탄 소진 후 장전, 여분탄 0일 때 미작동, 부사수 개인 총기의 기존 장전을 확인해 주세요.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.47-test (Vehicle Reload)';
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
