param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.52-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.52-test-en.zip', 'HD2-AutoReload-0.3.52-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.52-test

### 업데이트 내역

- 일시적인 Lua 오류가 한 번 발생하면 스트라타젬 휠이 이후 계속 차단되던 문제를 수정했습니다.
- 오류 후 이전 선택과 미완료 커맨드는 취소하고, 모드가 누른 입력 및 커서 소유권을 해제한 뒤 깨끗한 휠을 다시 만듭니다. 실패한 커맨드를 자동으로 이어 보내지 않습니다.
- 0.5초 후 복구를 재시도합니다. 정리가 계속 실패하면 1초, 2초, 최대 4초로 재시도 간격을 늘리고, 회복 후에는 다시 사용할 수 있습니다. 프레임마다 오류 로그를 반복하지 않습니다.
- GUI 정리가 중간에 실패해도 이미 삭제된 요소를 다시 삭제하지 않고, 남은 아이콘·폰트 GUI의 소유권을 보존해 다음 시도에서 정리합니다.
- 홀드 방식은 스트라타젬 키를 놓았다가 다시 누르세요. 토글 방식은 열려 있던 기본 스트라타젬 목록을 닫고 다시 열어야 합니다. 복구 중 누르고 있던 숫자키는 재실행하지 않습니다.
- 자동재장전, 레일건 90%/95% 선택, 에포크 100% 충전, 임무 표시 옵션과 영어/한국어 설정 기본값은 변경하지 않았습니다.
- 게임 충돌이나 네이티브 접근 위반은 Lua 복구로 처리할 수 없습니다. 모의 검증은 완료했으며 적용 후 실제 게임 및 멀티에서 복구 확인이 필요합니다.

### English

- Fixes permanent wheel blocking after a temporary caught Lua error.
- Cancels stale selections and partial commands, releases owned input/cursor state and recreates a clean wheel. Failed commands are never resumed automatically.
- Retries after 0.5 seconds, backing off to 1, 2 and at most 4 seconds while cleanup fails. Recovery remains possible after persistent errors clear, without per-frame error log flooding.
- Records successful GUI deletions immediately and retains remaining icon/font GUI ownership for safe partial-cleanup retries.
- Hold users must release and press the list key again. Toggle users must close the existing native list and reopen it. Already held number shortcuts are not replayed.
- Auto reload, Railgun 90%/95%, Epoch 100%, mission visibility and both language option defaults are unchanged.
- Lua recovery cannot catch game crashes or native access violations. Mock regressions passed; live visual and multiplayer recovery still need validation after installation.

### 설치 / Installation

영어판 `HD2-AutoReload-0.3.52-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.52-test-ko.zip` 중 **하나만** 설치하세요. 게임을 종료한 상태에서 Arsenal에서 이전 버전을 교체하고 Purge / Deploy 후 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

Install **one** language ZIP, replacing the previous version in Arsenal. Purge / Deploy with the game closed, then restart. Requires Bingus Shared Loader v18 / API 1.

개인용 차량 조종 수정본은 포함하지 않으며 공개 게시하지 않습니다. 설치된 모드와 실행 중인 게임은 개발·게시 과정에서 변경하지 않았습니다.

Personal vehicle-control modifications are not included or publicly published. Installed mods and the running game were not changed during development or publication.

### 검증 / Validation

LuaJIT 회귀 검사와 영어/한국어 패키지 검사를 통과했습니다. 홀드·토글, 키보드·마우스 엄지버튼 2종, GUI 정리·생성 실패 후 재복구, 재시도 간격 상한, 미완료 입력 취소, 입력 해제 실패, 포커스 복귀 후 커서 복원 및 부분적인 도형·폰트 GUI 삭제를 모의 검증했습니다. 실제 게임과 멀티의 복구 동작은 새 패키지 적용 후 확인이 필요합니다.

LuaJIT regressions and both language packages passed. Mock tests cover Hold/Toggle, keyboard and both thumb buttons, cleanup/factory failure recovery, capped backoff, partial command cancellation, failed key release, focus-dependent cursor restoration and partial shape/font GUI disposal. Live and multiplayer recovery after applying the new package remain unverified.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.52-test (Recoverable Wheel Errors)';
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
