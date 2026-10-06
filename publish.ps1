param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.50-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.50-test-en.zip', 'HD2-AutoReload-0.3.50-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.50-test

### 업데이트 내역

- 위치 제한이 있는 임무 스트라타젬은 해당 호출 구역에 도착했을 때만 휠에 표시하고, 구역을 벗어나면 숨깁니다.
- 게임의 현재 임무 단계, 활성 상태, 장치·하위 대상의 위치와 호출 반경을 읽습니다. 동적 기준 대상을 사용하는 시추 장비와 3차원 범위를 사용하는 탐사 자료 업로드도 별도로 판독합니다.
- 휠을 연 상태에서도 50ms 간격으로 목록을 갱신합니다. 표시 항목이 바뀌는 순간 이전 칸 번호로 다른 스트라타젬이 선택되는 것을 막고, 커맨드 전송 전·도중에도 위치를 다시 확인합니다.
- 장착한 스트라타젬 4개, 증원·SOS·보급 및 위치 제한이 없는 임무 항목은 기존 표시 설정을 유지합니다. 구역 안의 쿨다운 표시는 유지합니다.
- 자동재장전·차량 재장전·자동발사, 기존 옵션과 분:초 시간 표시는 변경하지 않았습니다. 게임 함수 호출이나 게임 메모리 변경 없이 읽기 전용으로 위치를 판독합니다.

### English

- Location-restricted mission stratagems appear only inside their current call area and disappear when leaving it.
- Reads the native objective stage, state, parent/child anchors and radius. Reference-linked drilling zones and Upload Discovery's 3D area are handled separately.
- The open wheel refreshes every 50ms. Membership changes invalidate stale sector indices; mission selections are rechecked before and during command input.
- Equipped slots, common calls and mission calls without a location limit retain their visibility options. Cooldowns remain visible inside an eligible area.
- Personal/vehicle reload, charged-weapon release, existing options and minutes:seconds countdowns are unchanged. Location checks use bounded read-only memory access, not native function calls or memory writes.

### 설치 / Installation

영어판 `HD2-AutoReload-0.3.50-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.50-test-ko.zip` 중 **하나만** 설치하세요. 게임을 종료한 상태에서 Arsenal에서 이전 버전을 교체하고 Purge / Deploy 후 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Install **one** language ZIP, replacing the previous version in Arsenal. Purge / Deploy with the game closed, then restart. Requires Bingus Shared Loader v18 / API 1.

개인용 차량 조종 수정본은 포함하지 않으며 공개 게시하지 않습니다. 설치된 모드와 실행 중인 게임은 개발·게시 과정에서 변경하지 않았습니다.

Personal vehicle-control modifications are not included or publicly published. Installed mods and the running game were not changed during development or publication.

### 검증 / Validation

LuaJIT 회귀 검사, 위치 경계·임무 단계·동적 기준 대상·낡은 선택 취소 및 영어/한국어 패키지 검사를 통과했습니다. 실행 중인 게임에서 실제 리더의 캐릭터 위치·목록 판독을 확인했습니다. 임무 호출 구역을 드나들 때의 실제 휠 표시는 아직 인게임 검증이 필요합니다.

LuaJIT regressions, location boundaries, objective stages, reference-linked anchors, stale-selection cancellation and both language package checks passed. The actual reader resolved the current character position and inventory in a read-only live check. Wheel visibility while entering/leaving mission areas still needs in-game testing.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.50-test (Mission Call Areas)';
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
