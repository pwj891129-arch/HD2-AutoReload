# HD2 Helper Auto Reload + Stratagems 0.3.34-test

## Arsenal Option Icons

0.3.34-test adds 41 distinct 256x256 PNG previews to the existing Arsenal
options and their ON/OFF choices. Bright cyan identifies general features,
yellow identifies shared calls and mint identifies mission calls. Each symbol
uses an opaque dark contrast plate and remains legible as a small thumbnail.
These are functional Lucide symbols for the settings UI, not the game's native
stratagem artwork. In-game wheel art is unchanged.

The current option order, labels, default values and Include paths are retained.
Individual toggles remain independent: no mutually exclusive mission group is
introduced. Arsenal's [option documentation](https://docs.rsnl.gg/mod-builder/options)
limits sub-options to one level and exclusive variants, so it cannot contain a
further independent ON/OFF group for every mission call. This release adds
icons while retaining the existing arrangement.

Preview PNGs are referenced only by manifest Image fields, not by Lua or patch
Include paths. They do not add game resources or change reload, charge release
or stratagem behavior. The Lucide/Feather license is bundled unchanged as
LUCIDE-LICENSE.txt. Live Arsenal thumbnail display still needs confirmation.

## Individual Shared And Mission Toggles

0.3.33-test replaces the all-in-one shared/mission visibility switch with
independent Arsenal ON/OFF settings for Reinforce, SOS Beacon and Resupply,
plus 31 mission call types. All default to OFF. Each enabled call appears only
when it actually exists in your current local loadout. Related native variants
(reinforcement, flag, cargo and ordinary extraction) share the same type toggle.
Filtering never changes personal slots 1-4 or their number hotkeys, and hidden
shared calls cannot be selected through the radial command path.

`Other Shared / Mission Calls` controls shared calls without a dedicated toggle.
Its default is OFF, and it never overrides any known type's individual
OFF setting. The retired `shared` master marker is ignored. After replacing an
older package, review the individual choices: the old master ON selection is
not copied to all new toggles. Purge / Deploy with the game closed and restart.
Reload and charge-release defaults are unchanged. Real Arsenal UI and mission
testing remain required.

## Multiplayer Roster Fix

0.3.32-test fixes a single-player-only assumption in stratagem menu and loadout
reads. The total player roster count is now accepted from 1 to 4; exactly one
local player is still required. The first local peer/unit follows the game's
native getters, not an arbitrary remote teammate. Character ownership, avatar
identity, actual menu activation, local-peer loadout matching and coherent
snapshot checks remain required. Roster changes during a read cancel that
snapshot; later attempts can use the updated roster. No input is sent based on
another player's menu or equipment.

This also applies when joining another player's mission in progress. Live
host/client and late-join confirmation is still required. Automatic reload,
charge release and feature defaults are unchanged.

## Language Packages

Release assets are provided separately:

- `HD2-AutoReload-0.3.34-test-en.zip`: English Arsenal option names and descriptions (default distribution).
- `HD2-AutoReload-0.3.34-test-ko.zip`: Korean Arsenal option names and descriptions.

Install only one ZIP. Both share the same mod GUID, option order, default values,
include paths and byte-identical game payload. Only manifest display text differs.
Changing package language replaces the same mod, not an additional addon. Review
ON/OFF choices after replacement, then Purge / Deploy and restart the game.

Arsenal 0.36.2 displays mod-provided names and descriptions literally; its UI
language packs do not translate these fields. There is no OS-language detection
script or automatic language switch in this release. Choose the ZIP yourself.
The in-game radial labels and runtime logs are unchanged.

한국어로 옵션을 표시하려면 `-ko.zip` 파일만 설치하세요. 영어판은 `-en.zip`입니다.
두 언어판을 동시에 설치하지 마세요. 언어판 교체 후 ON/OFF 설정을 확인하고
Purge / Deploy 및 게임 재시작을 진행하세요. OS 언어 자동 감지 파일은 포함하지 않습니다.

## Combined Mod

0.3.30-test fixes a deployment failure in 0.3.29-test: the current Arsenal
0.36.2 BETA imported the root addon but deployed only seven setting markers.
The loader listed neither helper component, and both feature logs were stale.
The executable addon now lives in Core/, explicitly included by every ON/OFF
variant. Selected variants share one common addon, not duplicate resources.
Choose at least one setting in Arsenal; all options unchecked now intentionally
deploys nothing. OFF still includes the core and disables only that setting.

This package includes the Stratagem Hotkeys 0.1.13-test implementation alongside
automatic reload. Import only this ZIP: disable/remove the separate HD2
Stratagem Hotkeys package and the previous Auto Reload package before Purge /
Deploy. There is one loader addon resource, with independently guarded startup
for both features. Stratagem input updates its gate before reload and charge
processing in the same frame; both retain existing callback return values.

Automatic reload and Railgun/Epoch 90% charge release default to ON when the
core is deployed and their individual settings are omitted. The radial and number hotkeys
also default to ON. Explicit OFF settings are honored. Arsenal may retain the
previous charge-OFF selection for this mod's existing GUID; review and select
ON when replacing an earlier version. No deployed files are changed by building.

## Default-On Reload And Diagnostic Removal

Automatic reload defaults to ON unless explicitly set to OFF. The package
uses explicit Core includes instead of depending on root-file auto-deployment.
Arsenal's documented root-file behavior did not match the observed option-based
deployment in 0.36.2 BETA. At least one ON/OFF setting must be selected.

The separate ammo-OFF and heat-OFF checkboxes have been removed. Old option
resources do not control this version. F9 type checks, tank field scanning,
seat research, and the legacy diagnostic reader are no longer bundled or
called. F9 and F10 have no addon function. Offline research sources and
automated developer tests remain in the repository, not the release ZIP.
Normal reload/error logs remain available.

## Arsenal Options

Feature settings are configured only in Arsenal. No in-game MODS menu is
registered; Mod Options Menu and Mod Bindings Menu are not dependencies.

- `Automatic Reload` / `자동재장전`: `ON (Default)` / `ON (기본)` or `OFF`. An unselected option also means ON.
  Covers both magazine exhaustion and complete overheat.
- `Railgun / Epoch 90% Charge Release` / `레일건·에포크 90% 충전 자동발사`: ON by default or OFF.
  An unselected option means ON. Independent of automatic reload.
- `Stratagem Radial Menu` / `스트라타젬 원형 오버레이`: ON by default; OFF disables the radial only.
- `Stratagem Number Hotkeys` / `스트라타젬 숫자 핫키`: ON by default; OFF disables number shortcuts only.
- `Other Shared / Mission Calls` / `기타 공용/임무 스트라타젬 표시`: OFF by default; controls only types without an individual toggle.
- `Large Radial Menu` / `큰 원형 메뉴`: OFF (100%) by default; ON uses 130%.
- `30 ms Command Input` / `커맨드 입력: 30ms`: OFF (15 ms) by default; ON uses at least 30 ms per edge.
- `Shared: Reinforce`, `Shared: SOS Beacon`, `Shared: Resupply` / `공용: 증원`, `공용: SOS 신호기`, `공용: 보급`: each has its own ON/OFF setting, default OFF.
- `Mission: ...` / `임무: ...`: 31 independent type toggles, default OFF. Includes Hellbomb, SEAF artillery, flag, drills, data upload, extraction variants and other native mission calls. Unavailable mission calls are never invented by enabling an option.

Each option's ON/OFF variants are mutually exclusive. Review the choices after
importing, especially if Arsenal automatically enables new options. Close the
game, replace the previous package, Purge / Deploy, and restart after changes.
Old deployed option files must not be left behind. Building and publishing
do not change installed game patches.

F8 temporarily pauses reload and charge release, not the stratagem menu; it is
not a saved setting.

## Stratagem Radial And Hotkeys

Hold the game's configured Stratagem List button, move toward an icon sector,
then release to enter the command. Release at the center to cancel. Keyboard
and front/back mouse thumb Hold bindings are supported; direction bindings
are read from the game. Press/toggle, wheel and controller mappings are not
supported. Aim and throw manually. List + number-row 1-4 matches the personal
slot numbers shown in the radial; Numpad is distinct. F6 is not a separate key.

The radial opens only after the character's native List menu activates and
reads equipped calls, cooldowns and remaining uses. Unavailable entries cannot
be selected. Chat, other menus, focus loss, loadout/binding changes and fire
cancel input. Commands require observation of the game's direction actions.

Native icons use read-only atlas regions and the game's RGB-mask palette on
isolated owned GUIs; missing/unreadable metadata falls back to names. The
0.1.13-test atlas overflow-row correction and lost thumb-release cleanup are
included. A physically released thumb button whose native action is still held
gets an up-only repair after cursor restoration, including center cancellation.
Selected commands wait for native release before reacquiring List. A held
physical button and other foreground applications do not receive repair input.
Neither a normal left/right mouse press nor automatic throwing is sent.

The package does not redistribute game images, shaders, materials or GUI
binaries, or modify another mod's HUD instances. Labels retain internal English
development names. The existing icon fix still needs gameplay confirmation.

## Reload Behavior

All personal weapons use the held-object native reader, without requiring a
HUD+ weapon-name list. Reads are limited to one per 50 ms, plus frame/input
scheduling. Unknown game binaries or ambiguous data block input.

- An observed magazine transition from positive usable ammo to zero, or an
  explicit complete-overheat transition, can request reload.
- A new fire-key press checks once. While the fire button stays held, reload
  checks and reload input are deferred.
- Release immediately rereads the current held weapon and opens a one-second
  confirmation window with further reads every 50 ms.
- Number-row 1, 2, or 3 waits 1.1 seconds for draw completion, then verifies
  the changed held weapon. Numpad keys are separate.
- A known positive reserve and coherent empty/overheat readings are required.
  A warm/red heat gauge alone never means a damaged heat sink.
- Active/manual reload, chat, menus, missing player control, focus loss and
  stratagem/radial input block requests.

Two coherent empty readings are required. Magazine weapons stop detection while
reloading. For heat weapons that raise the reload flag upon overheat, one attempt
is allowed after 150 ms of persistent overheat with unchanged reserve.
Manual R or reserve changes cancel that attempt. There is only one attempt per
observed overheat episode; cooling or confirmed weapon change rearms it.

Requests use a 40 ms Windows SendInput reload-key pulse. The game state and
ammunition are never written. Input success does not confirm the game performed
a reload. An initial empty reading alone is not an event.

The seated-passenger exception requires right-click aim, recent fire and a
personal held weapon. Tank cannons, mounted weapons, underbarrels, throwables
and melee remain excluded; no tank field discovery runs in this package.
A controlled on-foot grip70 weapon can use the native reader. Identity recovery
after a new game or respawn and the seated-personal-weapon path are retained.

## 90% Charge Release

For RS-422 Railgun and PLAS-45 Epoch, the default-on feature reads the native
WeaponChargeComponent elapsed charge and configured explosion limit. It uses
the instance override or authored type registry, not ordinary heat, OCR or a
fixed timer. Two coherent reads are required.

At or above 90% of the entire gauge from zero to the explosion limit, send one
Windows `MOUSEEVENTF_LEFTUP`. No mouse press, repeated firing or aiming is sent.
Release the physical button and click again for the next shot. Railgun safe
mode, which caps below that threshold, stays manual.

Fire must be bound to left mouse. Chat, menus, no control, reload, weapon draw,
stratagem input and unreadable charge data block release. Reserve is not required
to fire the last loaded shot. The post-release reload check remains available
when automatic reload is on.

50 ms reads and frame/input latency may release above 90%; explosion prevention
is not guaranteed. Actual Railgun/Epoch gameplay remains unverified.
Native layout research references
[FileDiver's charge component](https://github.com/xypwn/filediver/blob/master/datalibrary/weapon_charge_component.go)
and its [resource hash names](https://github.com/xypwn/filediver/blob/master/hashes/hashes.txt).

## Compatibility And Installation

1. Close the game before deploying.
2. Import one language ZIP into Arsenal and replace the previous version.
3. Enable this addon and Bingus Shared Loader v18 / API 1.
4. Select the desired ON/OFF variants (at least one), ensure radial is ON, then Purge / Deploy and restart.
5. Disable/remove separate Stratagem Hotkeys and other automatic-reload implementations to prevent double input.

HD2 HUD+ is optional. This addon replaces no HUD texture, GUI, boot script,
Wwise startup resource, or HD2 Helper executable. Keep Bingus as the winning
startup replacement. Update/shutdown wrappers preserve earlier callbacks and
return values, and Win32 FFI symbols use private aliases.

The included Stratagem Hotkeys component announces input and the configured list key
to block reload/switch tracking. Left/right Alt also block these actions.
External helper features that intercept the same keys can still conflict.

Default bindings are left mouse for fire, R for reload, and F8 for pause/resume.
Existing `%APPDATA%\HD2AutoReload.ini` key entries remain supported; the addon
does not create the file or use it for feature settings:

```ini
fire_vk=1
reload_vk=82
pause_vk=119
```

These are Windows virtual-key numbers. Restart after changes. Mouse reload
bindings are not supported.

Logs: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`.
Stratagem log: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_stratagem_hotkeys.log`.
Isolated startup failures: `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_combined.log`.
START reports enabled/charge90 and bindings. NATIVE_SOURCE, RELOAD,
CHARGE_SOURCE, CHARGE_RELEASE and blocking/error logs remain; research scans
and research hotkeys have been removed.

## Build And Test

Requires Node.js, PowerShell and the game's `bin/lua51.dll`. Tests use mocked
game/input APIs in a separate LuaJIT process, never attach to the game or send
actual inputs. Package checks enforce the HD2SDK minimum of 256 bytes per
single-resource archive. Per language, deployment checks exhaust all 729 base-control
combinations, every pair of settings in all omitted/ON/OFF states, and all-ON,
all-OFF and all-default configurations (8,112 scenarios).
They also verify localized text, identical option structure and byte-identical
game payloads across the English and Korean packages. Individual kind filters,
explicit OFF precedence, hidden command rejection, slot numbering and coherent
shared/personal membership reads have regression coverage. The pinned native
catalog checks all mission kinds when local reference captures are available.
Manifest checks also confirm that every parent/ON/OFF choice has a valid PNG
reference and that the previous option layout is unchanged when its local
package is available. Separate image checks verify 41 unique glyphs, 256x256
dimensions, nonblank pixels, full opacity and 32px thumbnail brightness.
Tests cover both feature runtimes, shared-VM input declarations, callback order,
default/explicit settings, initialization isolation and input blocking/resumption.
These are offline mocks; actual combined gameplay and Arsenal UI remain unverified.

```powershell
node build.cjs
node package.test.cjs
./test.ps1 -LuaDll '<Helldivers 2 folder>/bin/lua51.dll'
Compress-Archive -Path './dist/HD2-AutoReload-0.3.34-test-en/*' -DestinationPath './dist/HD2-AutoReload-0.3.34-test-en.zip'
Compress-Archive -Path './dist/HD2-AutoReload-0.3.34-test-ko/*' -DestinationPath './dist/HD2-AutoReload-0.3.34-test-ko.zip'
```

PNG assets are committed, so ordinary builds do not require an image library.
To regenerate from the committed Lucide vector subset, install Sharp for Node
and run `node tools/option-icons.cjs`, then `node tools/option-icons.test.cjs`.
The optional `--import <Arsenal app.asar>` refresh path requires the pinned
Lucide 0.544.0 bundle and does not modify Arsenal or installed game patches.

Credited HD2 HUD+ 0.1.2 reader sources and original reuse permission are in
`vendor/` and THIRD_PARTY.txt. Only non-rendering identity support is used at
runtime; the legacy diagnostic provider is not invoked.

Source and test releases:
https://github.com/pwj891129-arch/HD2-AutoReload
Published separately from HD2 Helper.
