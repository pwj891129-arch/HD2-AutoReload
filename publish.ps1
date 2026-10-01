param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.33-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.33-test-en.zip', 'HD2-AutoReload-0.3.33-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.33-test

공용·임무 스트라타젬의 원형 메뉴 표시를 개별 ON/OFF 옵션으로 나눴습니다.

- 증원, SOS 신호기, 보급을 각각 독립적으로 켜고 끌 수 있습니다.
- 헬밤·SEAF 포격·깃발·발굴 장비·정보 업로드·탈출 등 임무 스트라타젬 31종도 각각 설정할 수 있습니다. 동일 종류의 게임 내부 변형은 같은 토글을 사용합니다.
- 개별 항목의 기본값은 OFF입니다. ON으로 설정해도 현재 임무에 실제로 존재하는 항목만 표시하며, 개인 슬롯 1~4 번호와 핫키는 유지됩니다.
- 이글 재무장 등 개별 옵션이 없는 항목은 별도의 '기타 공용/임무 스트라타젬 표시'로 설정합니다. 이 옵션을 켜도 개별 OFF 항목은 다시 표시되지 않습니다.
- 숨긴 공용·임무 항목은 원형 메뉴의 커맨드 전송 단계에서도 제외합니다. 판독 중 공용/개인 구분이 바뀌면 해당 판독을 취소합니다.
- 자동재장전·충전 자동발사와 기능 기본값은 변경하지 않았습니다.
- 영어판 `HD2-AutoReload-0.3.33-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.33-test-ko.zip`을 별도로 제공합니다. 표시 언어만 다르고 게임 본체는 동일합니다.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 ON/OFF 설정을 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

이전 '공용/임무 스트라타젬 표시'의 일괄 ON 선택은 새 개별 토글에 자동 적용되지 않습니다. 필요한 증원·SOS·보급·임무 항목을 각각 ON으로 설정하세요. 이전 master 설정 파일은 이 버전에서 무시합니다.

원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이 ON**을 선택하세요. 하나 이상의 ON/OFF 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 스트라타젬 목록 열기는 누르고 있기(Hold)로 설정하며 조준·투척은 수동입니다.

### English

Adds independent Arsenal ON/OFF visibility settings for Reinforce, SOS Beacon, Resupply and 31 mission call types. All default to OFF. Related native variants share a type toggle. Other Shared / Mission Calls controls only unlisted types and never overrides an explicit individual OFF. Filtering preserves personal slots 1-4 and rejects hidden shared calls before command input.

Install **one** ZIP: `-en.zip` for English Arsenal options, or `-ko.zip` for Korean. Replace the previous version, review ON/OFF selections, then Purge / Deploy and restart with Bingus Shared Loader v18 / API 1. At least one setting must be selected. Reload, charge release and default settings are unchanged.

### 검증

개별 필터, OFF 우선 적용, 숨긴 항목의 커맨드 차단, 개인 슬롯 번호 유지와 판독 중 공용 구분 변경 검사를 추가했습니다. 전체 LuaJIT 모의 검사, 언어판별 8,112가지 배포 시나리오와 두 언어 패키지의 동일 본체 검사를 통과했습니다. 로컬 참조 데이터로 기본 공용 식별값과 게임의 모든 임무 종류를 확인했습니다. 실제 Arsenal UI 및 임무 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.33-test (individual stratagem toggles)';
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
