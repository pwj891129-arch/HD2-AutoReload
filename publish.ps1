param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.31-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.31-test-en.zip', 'HD2-AutoReload-0.3.31-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.31-test

Arsenal 옵션 표시 언어를 영어판과 한국어판 ZIP으로 분리했습니다.

- **영어판(기본 배포):** `HD2-AutoReload-0.3.31-test-en.zip`
- **한국어판:** `HD2-AutoReload-0.3.31-test-ko.zip`
- 옵션 7개의 이름·설명, ON/OFF 설명과 기본값 표기를 각 언어로 제공합니다.
- 두 ZIP은 manifest 표시 문구만 다르며 모드 본체와 설정 파일은 바이트 단위로 동일합니다. 기능, 기본값, 옵션 순서, 배포 경로와 모드 GUID를 유지했습니다.
- 자동재장전, 레일건·에포크 90% 충전 자동발사, 스트라타젬 원형 메뉴와 숫자 핫키는 기본 ON입니다. 공용/임무 스트라타젬, 큰 원형 메뉴, 30ms 커맨드 입력은 기본 OFF입니다.
- 0.3.30-test의 공통 Core 포함 배포 수정과 기존 입력·판독 동작을 유지했습니다. 인게임 원형 메뉴 이름과 로그 언어는 변경하지 않았습니다.
- 현재 Arsenal은 모드 이름·설명을 그대로 표시하므로 OS 언어 자동 전환은 제공하지 않습니다. 언어 감지·적용 파일도 포함하지 않습니다.

### 설치

**두 ZIP 중 하나만 설치하세요.** 원하는 표시 언어의 파일로 이전 Auto Reload 버전을 교체하고 Arsenal의 ON/OFF 설정을 다시 확인하세요. 두 언어판은 같은 모드이므로 동시에 설치하는 별도 기능이 아닙니다.

게임 종료 후 Bingus Shared Loader v18 / API 1과 함께 Purge / Deploy하고 게임을 재시작하세요. 원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이 ON**을 선택하세요. 원하는 ON/OFF 옵션을 적어도 하나 선택해야 하며, 모두 선택 해제하면 본체도 배포되지 않습니다. 기존 OFF 설정이 유지될 수 있으므로 충전 자동발사 ON도 확인하세요.

별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 스트라타젬 목록 열기는 누르고 있기(Hold) 설정을 사용하며 커맨드만 자동 입력합니다. 조준·투척은 수동입니다. Mod Options Menu와 Mod Bindings Menu는 필요하지 않습니다.

### English

Choose **one** ZIP: `-en.zip` for English Arsenal options (default distribution), or `-ko.zip` for Korean. Both use the same mod GUID and byte-identical game payload. Replace the previous package, review ON/OFF settings, then Purge / Deploy and restart. At least one option must be selected to deploy the common core. No OS-language detection script is included. In-game labels and behavior are unchanged.

### 검증

4,757개 LuaJIT 모의 검사와 언어판별 2,187가지 설정 조합(총 4,374가지)을 검사했습니다. 두 패키지의 번역, 동일 GUID·기본값·Include 경로, manifest 외 모든 파일의 바이트 일치를 확인했습니다. 실제 Arsenal 화면과 인게임 동작은 추가 확인이 필요합니다. 설치된 모드와 게임 파일은 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.31-test (English / Korean packages)';
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
