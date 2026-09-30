param(
    [Parameter(Mandatory)][string]$AssetPath,
    [Parameter(Mandatory)][string]$Commit,
    [string]$Repository = 'pwj891129-arch/HD2-AutoReload',
    [string]$Tag = 'auto-reload-0.3.26-test'
)
$ErrorActionPreference = 'Stop'
$AssetPath = (Resolve-Path -LiteralPath $AssetPath).Path
$assetName = [IO.Path]::GetFileName($AssetPath)
if ($assetName -ne 'HD2-AutoReload-0.3.26-test.zip') { throw 'Unexpected addon package name.' }
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
## HD2 Auto Reload 0.3.26-test

레일건과 에포크의 90% 충전 자동발사 테스트 기능을 추가했습니다.

- 아스날의 `레일건·에포크 90% 충전 자동발사 ON`을 체크하여 활성화합니다. 옵션 모듈이 없으면 OFF이며, 가져오기 직후 체크 상태를 확인하세요.
- 게임의 손에 든 무기객체에서 충전 경과값과 폭발 한계값을 직접 읽습니다. HUD+의 무기목록이나 일반 발열량에 의존하지 않습니다.
- 전체 게이지의 0~폭발 한계 구간에서 90% 이상이 확인되면 좌클릭 해제 신호를 한 번 보내 발사하도록 합니다. 빨간 구간만의 90%가 아닙니다.
- 발사키가 좌클릭이어야 합니다. 자동으로 좌클릭을 다시 누르지 않으며 다음 사격은 버튼을 놓고 다시 눌러 시작하세요. 조준은 수동입니다.
- 레일건 안전 모드처럼 90%까지 충전되지 않는 경우에는 기존 수동 사격을 유지합니다.
- 채팅·메뉴·스트라타젬 입력 중, 장전 중, 무기 전환 대기 중, 창 포커스 이탈 또는 판독 실패 시에는 발사 해제 신호를 보내지 않습니다.
- 자동재장전과 독립적으로 켤 수 있습니다. 기존 자동재장전 및 발사 버튼 해제 후 1초 확인 동작을 유지합니다.
- F8은 두 기능을 함께 일시정지합니다. 인게임 설정 메뉴나 추가 설정 메뉴 모드는 필요하지 않습니다.
- 탱크 주포 자동장전은 기존과 같이 비활성입니다.

### 설치

게임을 종료하고 Arsenal에 ZIP을 가져온 뒤 체크박스를 확인하여 Bingus Shared Loader와 함께 Purge / Deploy 하세요. 옵션을 바꾼 후에도 재배포와 게임 재시작이 필요합니다. 기존 헬퍼 자동장전 및 이전 Auto Reload 보조 스크립트는 꺼서 중복 입력을 막으세요.
로그: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`

669개 LuaJIT 모의 검사를 통과했습니다. 실제 레일건·에포크 게임 검증은 아직 하지 않았습니다. 50ms 판독과 프레임·입력 지연으로 실제 해제 시점은 90%를 넘을 수 있으며, 심한 지연이나 게임의 입력 거부 시 폭발 방지를 보장하지 않습니다. 로그의 `CHARGE_SOURCE`와 `CHARGE_RELEASE`로 판독 여부와 입력 결과를 확인할 수 있습니다. 설치된 모드 파일은 자동으로 변경하지 않았습니다.
'@
try {
    $releases = Invoke-RestMethod -Uri ($api + '?per_page=100') -Headers $headers
    $release = $releases | Where-Object tag_name -eq $Tag | Select-Object -First 1
    if (-not $release) {
        $body = @{ tag_name = $Tag; target_commitish = $Commit; name = 'HD2 Auto Reload 0.3.26-test (90% charge release)';
            body = $notes; draft = $true; prerelease = $true } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Post -Uri $api -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    }
    $expectedHash = (Get-FileHash -LiteralPath $AssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $existing = $release.assets | Where-Object name -eq $assetName | Select-Object -First 1
    if ($existing) {
        if ($existing.digest -ne "sha256:$expectedHash") { throw 'Existing package differs; not replacing it.' }
    } else {
        $uri = $release.upload_url.Split('{')[0] + '?name=' + [Uri]::EscapeDataString($assetName)
        $uploaded = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/zip' -InFile $AssetPath
        if ($uploaded.state -ne 'uploaded' -or $uploaded.digest -ne "sha256:$expectedHash") {
            throw 'Asset upload verification failed; leaving draft unpublished.'
        }
    }
    if ($release.draft) {
        $body = @{ draft = $false; prerelease = $true; make_latest = 'false' } | ConvertTo-Json
        $release = Invoke-RestMethod -Method Patch -Uri ($api + '/' + $release.id) -Headers $headers -ContentType 'application/json' -Body $body
    }
    $verified = Invoke-RestMethod -Uri ($api + '/tags/' + $Tag) -Headers $headers
    $asset = $verified.assets | Where-Object name -eq $assetName | Select-Object -First 1
    if ($verified.draft -or -not $verified.prerelease -or $asset.digest -ne "sha256:$expectedHash") {
        throw 'Published release verification failed.'
    }
    [ordered]@{ url = $verified.html_url; prerelease = $verified.prerelease; asset = $asset.name;
        sha256 = $expectedHash; sourceCommit = $Commit } | ConvertTo-Json
} finally {
    $headers.Clear(); $credential.Clear(); $credentialLines = $null
}
