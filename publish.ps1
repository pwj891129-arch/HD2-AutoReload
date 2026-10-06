param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.51-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.51-test-en.zip', 'HD2-AutoReload-0.3.51-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.51-test

### 업데이트 내역

- 호출 구역에 도착해도 슈퍼지구 깃발 등 위치 제한 임무 스트라타젬이 휠에 나타나지 않던 문제를 수정했습니다.
- 임무 설정 표의 칸 수를 438로 잘못 계산하던 부분을 게임의 실제 값인 434(0x1b2)로 수정했습니다. 표 검색, 마지막 칸의 순환 검색, 설정 번호 범위도 같은 값으로 검사합니다.
- 켜 둔 임무 항목은 현재 호출 구역에서 표시되고, 구역을 벗어나거나 호출 단계가 끝나면 숨겨집니다. 기존 50ms 목록 갱신과 커맨드 전송 전·도중의 위치 재검사는 유지합니다.
- 레일건 자동발사 기준을 Arsenal에서 위험 게이지 90% 또는 95%(기본)로 선택할 수 있습니다. 기존 자동발사 ON/OFF는 유지하고 선택 항목을 목록 끝에 추가해 이전 옵션의 순서를 보존합니다. 에포크는 발사 충전 100%를 유지합니다.
- 장착한 4개, 공용 항목, 자동재장전·차량 재장전 및 나머지 옵션은 변경하지 않았습니다. 게임 함수 호출이나 게임 메모리 변경 없이 판독합니다.
- 95%를 선택하면 레일건의 폭발까지 여유가 줄어듭니다. 50ms 판독과 입력 지연으로 실제 해제가 설정 기준을 넘길 수 있어 폭발 방지를 보장하지 않습니다.

### English

- Fixes missing Super Earth Flag and other location-restricted mission calls despite being inside their permitted area.
- Corrects the objective table divisor from 438 to the native 434 (0x1b2), including collision wrap and record bounds.
- Enabled mission calls appear in the current permitted area and disappear outside it or after the call stage ends. Existing 50ms refresh and command-time revalidation are retained.
- Adds a Railgun automatic-release threshold choice in Arsenal: 90% or 95% (default) of its danger gauge. The default-on release checkbox remains independent; the new choice is appended to preserve existing option positions. Epoch remains at 100% full firing charge.
- Equipped slots, common calls, personal/vehicle reload and remaining settings are unchanged. Uses read-only memory access, without native game calls or memory writes.
- The 95% choice has less margin before explosion. The 50ms reader and input latency may release above the selected threshold; explosion prevention is not guaranteed.

### 설치 / Installation

영어판 `HD2-AutoReload-0.3.51-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.51-test-ko.zip` 중 **하나만** 설치하세요. 게임을 종료한 상태에서 Arsenal에서 이전 버전을 교체하고 Purge / Deploy 후 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Install **one** language ZIP, replacing the previous version in Arsenal. Purge / Deploy with the game closed, then restart. Requires Bingus Shared Loader v18 / API 1.

개인용 차량 조종 수정본은 포함하지 않으며 공개 게시하지 않습니다. 설치된 모드와 실행 중인 게임은 개발·게시 과정에서 변경하지 않았습니다.

Personal vehicle-control modifications are not included or publicly published. Installed mods and the running game were not changed during development or publication.

### 검증 / Validation

LuaJIT 회귀 검사, 실제 깃발 임무 해시·434칸 경계·순환 검색, 깃발 구역 진입·이탈·단계 종료, 레일건 90%/95% 선택값 연동·조기발사 차단·단발 해제·잘못된 설정 차단, 에포크 100% 유지와 영어/한국어 패키지 검사를 통과했습니다. 읽기 전용 실시간 검사에서 기존 리더가 찾지 못하던 임무 설정 3개를 수정 리더가 모두 찾는 것을 확인했습니다. 새 패키지 적용 후 실제 휠 표시와 레일건 선택 기준의 동작은 인게임 검증이 필요합니다.

LuaJIT regressions, the live flag hash, native bucket boundaries/wrap, flag entry/exit/completion, Railgun 90%/95% option integration, premature-release blocking, one-shot release, invalid options, unchanged Epoch 100% and both language packages passed. A read-only live probe resolved all three objective definitions rejected by the previous reader. Visual wheel testing and live Railgun threshold validation after applying the new package remain necessary.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.51-test (Mission Calls and Railgun Threshold Choice)';
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
