param(
    [Parameter(Mandatory)][string[]]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.36-test'
)
$ErrorActionPreference = 'Stop'
$expectedNames = @('HD2-AutoReload-0.3.36-test-en.zip', 'HD2-AutoReload-0.3.36-test-ko.zip')
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
## HD2 Auto Reload + Stratagems 0.3.36-test

공용·임무 스트라타젬 전체 표시 제어와 원형 메뉴 크기 선택을 추가했습니다.

- 공용 스트라타젬 전체 ON/OFF 옵션을 추가했습니다. 증원·SOS·보급과 이글 재무장 등 기타 공용 항목을 한 번에 표시하거나 숨깁니다.
- 임무 스트라타젬 전체 ON/OFF 옵션을 추가했습니다. 현재 임무에 존재하는 등록된 임무 항목을 한 번에 표시하거나 숨깁니다.
- 공용·임무 스트라타젬 전체 ON/OFF 옵션을 추가했습니다. 두 그룹을 동시에 표시하거나 숨길 수 있습니다.
- 각 전체 옵션은 ‘개별 설정 사용(기본) / ON / OFF’를 제공합니다. 적용 우선순위는 ‘공용·임무 전체 > 해당 그룹 전체 > 개별 항목’입니다. 개별 선택값은 지우지 않으며 전체 옵션을 ‘개별 설정 사용’으로 돌리면 기존 선택값이 다시 적용됩니다. 개인 슬롯 1~4와 핫키 번호는 변경하지 않습니다.
- 원형 메뉴 크기를 100%(기본), 150%, 200%, 300%, 400% 중 선택할 수 있습니다. 아이콘·문구·선택 범위가 함께 조절되며 큰 배율은 화면 밖으로 잘리지 않도록 화면에 맞춰 제한합니다. 기존 130% 옵션은 교체되므로 크기 선택을 확인하세요.
- 기존 개별 토글의 위치·기본값·아이콘·배포 경로는 유지하고, 전체 옵션은 목록 마지막에 아이콘과 함께 추가했습니다. 자동재장전·레일건 90%·에포크 100% 자동발사 및 Hold/토글 입력 동작은 유지합니다.
- 영어판 `HD2-AutoReload-0.3.36-test-en.zip`과 한국어판 `HD2-AutoReload-0.3.36-test-ko.zip` 중 하나만 설치하세요.

### 설치

**언어별 ZIP 중 하나만 설치하세요.** 이전 Auto Reload 버전을 교체하고 Arsenal의 ON/OFF 설정을 확인한 뒤, 게임을 종료한 상태에서 Purge / Deploy하고 재시작하세요. Bingus Shared Loader v18 / API 1이 필요합니다.

전체 옵션의 기본값은 ‘개별 설정 사용’, 개별 공용·임무 항목의 기본값은 OFF입니다. 필요한 항목을 개별 ON으로 설정하거나 전체 옵션에서 ON을 선택하세요. 프로그램 설정 변경은 Arsenal에서만 가능하며 인게임 옵션 메뉴는 추가하지 않았습니다.

원형 메뉴를 사용하려면 **Stratagem Radial Menu / 스트라타젬 원형 오버레이 ON**을 선택하세요. 하나 이상의 ON/OFF 옵션이 선택되어야 공통 Core가 배포됩니다. 별도 HD2 Stratagem Hotkeys 모드와 중복 자동재장전 기능은 비활성화하거나 제거하세요. 스트라타젬 목록 열기의 Hold 및 토글(Press) 설정을 지원하며 조준·투척은 수동입니다.

### English

Adds Shared: All, Mission: All and Shared + Mission: All visibility controls, each with Individual Settings (default), ON and OFF. Combined takes priority over group controls, then individual choices. Overrides do not erase saved individual selections. Personal slots 1-4 and their number shortcuts are unchanged; unavailable calls are not invented.

Replaces the old 100%/130% menu toggle with 100%, 150%, 200%, 300% and 400%. Geometry, icons, labels and selection use one effective scale, limited to fit the screen. Review the size choice after replacing the old package. Existing individual toggle positions, default variants, icons and Include paths are preserved; bulk controls are appended with distinct previews. Reload, charge release and Hold/Toggle input behavior are unchanged.

Install **one** ZIP: `-en.zip` for English Arsenal options, or `-ko.zip` for Korean. Replace the previous version, review selections, then Purge / Deploy and restart with Bingus Shared Loader v18 / API 1. At least one setting must be selected.

### 검증

30,010개 LuaJIT 모의 검사와 언어판별 10,761가지 배포 시나리오를 통과했습니다. 전체 옵션 3개의 모든 생략·개별·ON·OFF 조합과 개별 값 복원, 비정상 옵션 차단을 검사했습니다. 320x240부터 3840x2160까지 100가지 해상도·항목 수·배율 조합의 도형·아이콘·문구 경계와 선택 범위를 검사했고, 44개 옵션 아이콘 및 두 언어판의 동일 본체를 확인했습니다. 실제 Arsenal UI 및 게임 테스트는 추가 확인이 필요하며 설치된 모드·게임 상태는 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload + Stratagems 0.3.36-test (Bulk visibility and menu sizes)';
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
