param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.49-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.49-test-en.zip', 'HD2-AutoReload-0.3.49-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.49-test

### 업데이트 내역

- 스트라타젬 휠의 남은 대기/호출 시간을 초 숫자 대신 **분:초** 형식으로 표시합니다. 예: `3s` → `0:03`, `65s` → `1:05`, `399s` → `6:39`.
- 사용 가능 여부와 시간 계산은 유지합니다. 자동재장전, 차량 자동재장전, 자동발사, 스트라타젬 입력 및 기존 옵션은 변경하지 않았습니다.

### English

- Stratagem wheel countdowns now use **minutes:seconds**, for example `0:03`, `1:05` and `6:39`, instead of raw seconds.
- Readiness and countdown calculations are unchanged. Personal/vehicle reload, charged-weapon release, stratagem input and existing options remain unchanged.

### 설치 / Installation

영어판 `HD2-AutoReload-0.3.49-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.49-test-ko.zip` 중 **하나만** 설치하세요. 게임을 종료한 상태에서 Arsenal에서 이전 버전을 교체하고 Purge / Deploy 후 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Install **one** language ZIP, replacing the previous version in Arsenal. Purge / Deploy with the game closed, then restart. Requires Bingus Shared Loader v18 / API 1.

개인용 Solo Vehicle Driver 수정본은 포함하지 않으며 공개 게시하지 않습니다. 설치된 모드와 실행 중인 게임은 개발·게시 과정에서 변경하지 않았습니다.

The personal Solo Vehicle Driver modification is not included or publicly published. Installed mods and the running game were not changed during development or publication.

### 검증 / Validation

LuaJIT 회귀 검사와 분 전환 경계값, 영어/한국어 배포 검사를 통과했습니다. 실제 게임의 새 시간 표시와 개인용 운전 수정본의 실제 주행/멀티플레이는 아직 검증하지 않았습니다.

LuaJIT regression tests, countdown boundary cases and both language package checks passed. The new display and the separate personal driving modification still need in-game testing.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.49-test (Minutes:Seconds)';
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
