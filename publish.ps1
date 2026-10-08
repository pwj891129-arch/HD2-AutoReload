param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.64-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.64-test.zip')
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

## HD2 Helper 0.3.64-test

### 변경점 (0.3.63 대비)
- 첫 블록의 **중심이 아닌 시작 경계가 12시**에 오도록 휠 배치를 변경했습니다.
- 기본 반시계방향에서는 12시 경계의 왼쪽으로, 시계방향에서는 오른쪽으로 1번 블록이 이어집니다.
- 마우스 선택 판정도 새 블록 경계에 맞췄습니다. **장착 1~4 → 임무 → 공용** 순서와 숫자 핫키 대상은 그대로입니다.
- HD2H의 방향 선택·저장값, 자동재장전·자동발사, 50ms 무기 판독 및 숨긴 Arsenal 옵션은 유지합니다.

### Changes (since 0.3.63)
- Moves the **leading boundary of the first block**, not its center, to twelve o'clock.
- The first block extends left from that boundary for the default Counterclockwise direction, or right for Clockwise.
- Cursor hit testing follows the new block boundaries. The **equipped 1-4 → mission → common** order and numeric hotkey targets are unchanged.
- Retains the saved HD2H direction option, reload/charge release, 50ms weapon polling and hidden Arsenal options.

### 설치 / Installation
통합판 `HD2-AutoReload-0.3.64-test.zip`을 사용하세요. 게임 종료 후 Arsenal에서 이전 헬퍼를 교체하고 Purge / Deploy 후 재시작하세요.
Bingus Shared Loader / API 1은 필수입니다. 별도 HD2H 탭과 인게임 설정에는 Loader v19 및 [Mod Options Menu 1.2](https://github.com/CowboyBingus/ModOptionsMenu) (API 1 version 3)가 필요합니다. 옵션 메뉴가 없으면 배포 기본값으로 작동합니다. HUD+와 Mod Bindings Menu는 필요하지 않습니다.

Replace the previous helper in Arsenal with the unified ZIP; Purge / Deploy with the game closed, then restart. Bingus Shared Loader / API 1 is required. The separate HD2H tab and editable settings need Loader v19 and Mod Options Menu 1.2 (API 1 version 3). Without the options menu, deployed defaults remain active. Dependencies are not bundled.

### 검증 / Validation
오프라인 LuaJIT, 47개 옵션·14개 언어, 양방향 배치·선택·경계값·저장·복구 검사 및 패키지 검사를 통과했습니다. Arsenal 수집 코드와 HD2SDK로 최상위 49개 리소스를 확인했습니다. 현재 설치된 옵션 메뉴 실소스 검사는 예상 API 버전과 달라 건너뛰었습니다. 실제 인게임·멀티플레이 검증은 적용 후 필요합니다.

Offline LuaJIT regressions, 47 options across 14 languages, both-direction layout/hit tests, persistence/recovery and package checks passed. The Arsenal collector and HD2SDK validate 49 deployed resources. The optional installed-provider fixture was skipped due to an API version mismatch. Live gameplay and multiplayer validation remain necessary.

개인용 드론·차량 조종 모드와 게임 메모리 캡처는 포함하거나 공개하지 않습니다. 설치된 모드는 변경하지 않았습니다.
Personal drone/vehicle-control mods and game-memory captures are not bundled or published. Installed mods were not changed.
'@
try {
    $remoteCommit = Invoke-RestMethod -Uri ("https://api.github.com/repos/$Repository/commits/$Commit") -Headers $headers
    if ($remoteCommit.sha -ne $Commit) { throw 'Source commit is not available on GitHub.' }
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.64-test (Wheel Start Edge)';
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
