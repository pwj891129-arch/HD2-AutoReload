param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.32-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.32-test-en.zip', 'HD2-AutoReload-0.3.32-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.32-test

멀티플레이에서 스트라타젬 원형 메뉴가 표시되지 않을 수 있는 플레이어 인원 검사 오류를 수정했습니다.

- 전체 플레이어 수와 로컬 플레이어 수를 구분하지 않고 둘 다 1명이어야 한다고 검사하던 조건을 수정했습니다. 전체 인원은 1~4명, 로컬 플레이어는 1명인 상태를 허용합니다.
- 다른 사람의 임무에 중도 합류해도 본인 캐릭터의 실제 스트라타젬 메뉴와 본인 peer에 해당하는 장착 장비를 확인합니다. 다른 팀원의 캐릭터·장비로 대체하지 않습니다.
- 캐릭터 소유·아바타 신원·메뉴 활성화 검증은 유지했습니다. 판독 도중 인원 정보나 장비가 바뀌면 해당 판독을 취소합니다.
- 자동재장전·충전 자동발사와 기능 기본값은 변경하지 않았습니다.
- 영어판 `HD2-AutoReload-0.3.32-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.32-test-ko.zip`을 별도로 제공합니다. 두 ZIP의 표시 언어만 다르고 게임 본체와 설정 파일은 동일합니다.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 ON/OFF 설정을 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이 ON**을 선택하세요. 하나 이상의 ON/OFF 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 스트라타젬 목록 열기는 누르고 있기(Hold)로 설정하며 조준·투척은 수동입니다.

### English

Fixes a single-player-only roster check that could block the stratagem radial in multiplayer. Allows a total roster of 1-4 players while still requiring one local player, the local character's active menu and a matching local-peer loadout. Coherent snapshots reject roster changes during a read; no remote-player fallback is used.

Install **one** ZIP: `-en.zip` for English Arsenal options, or `-ko.zip` for Korean. Replace the previous version, review ON/OFF selections, then Purge / Deploy and restart with Bingus Shared Loader v18 / API 1. At least one setting must be selected. Reload, charge release and default settings are unchanged.

### 검증

1~4명 인원별 본인 메뉴·장비 판독, 로컬 플레이어 부재·모호성, 잘못된 인원 수와 판독 중 인원 변경에 대한 회귀 검사를 추가했습니다. 전체 LuaJIT 모의 검사와 언어판별 2,187가지 설정 조합, 두 언어 패키지의 동일 본체 검사를 통과했습니다. 실제 멀티 호스트·참가자·중도 합류 테스트는 추가 확인이 필요합니다. 실행 중인 게임 정보는 읽기 전용으로 확인했으며 설치된 모드·게임 상태를 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.32-test (multiplayer roster fix)';
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
