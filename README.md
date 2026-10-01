# HD2 Helper Auto Reload + Stratagems 0.3.29-test

## Combined Mod

This package includes the Stratagem Hotkeys 0.1.13-test implementation alongside
automatic reload. Import only this ZIP: disable/remove the separate HD2
Stratagem Hotkeys package and the previous Auto Reload package before Purge /
Deploy. There is one loader addon resource, with independently guarded startup
for both features. Stratagem input updates its gate before reload and charge
processing in the same frame; both retain existing callback return values.

Automatic reload and Railgun/Epoch 90% charge release now default to ON,
including when no option modules are deployed. The radial and number hotkeys
also default to ON. Explicit OFF settings are honored. Arsenal may retain the
previous charge-OFF selection for this mod's existing GUID; review and select
ON when replacing an earlier version. No deployed files are changed by building.

## Default-On Reload And Diagnostic Removal

Automatic reload is now ON whenever this mod is enabled. Its Lua archive lives
at the package root, so leaving every Arsenal feature option unchecked still
deploys the addon. See
[Arsenal's always-on file documentation](https://docs.rsnl.gg/mod-builder/creating-mods#always-on-files-vs-option-files).

The separate ammo-OFF and heat-OFF checkboxes have been removed. Old option
resources do not control this version. F9 type checks, tank field scanning,
seat research, and the legacy diagnostic reader are no longer bundled or
called. F9 and F10 have no addon function. Offline research sources and
automated developer tests remain in the repository, not the release ZIP.
Normal reload/error logs remain available.

## Arsenal Options

Feature settings are configured only in Arsenal. No in-game MODS menu is
registered; Mod Options Menu and Mod Bindings Menu are not dependencies.

- `자동재장전`: `ON (기본)` or `OFF`. An unselected option also means ON.
  Covers both magazine exhaustion and complete overheat.
- `레일건·에포크 90% 충전 자동발사`: `ON (기본)` or `OFF`.
  An unselected option means ON. Independent of automatic reload.
- `스트라타젬 원형 오버레이`: ON by default; OFF disables the radial only.
- `스트라타젬 숫자 핫키`: ON by default; OFF disables number shortcuts only.
- `공용/임무 스트라타젬 표시`: OFF by default; ON includes shared/mission calls.
- `큰 원형 메뉴`: OFF (100%) by default; ON uses 130%.
- `커맨드 입력: 30ms`: OFF (15 ms) by default; ON uses at least 30 ms per edge.

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
2. Import the release ZIP into Arsenal and replace the previous version.
3. Enable this addon and Bingus Shared Loader v18 / API 1.
4. Review reload, charge release and stratagem options, then Purge / Deploy and restart.
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
single-resource archive and all 2,187 valid Arsenal setting combinations.
Tests cover both feature runtimes, shared-VM input declarations, callback order,
default/explicit settings, initialization isolation and input blocking/resumption.
These are offline mocks; actual combined gameplay and Arsenal UI remain unverified.

```powershell
node build.cjs
node package.test.cjs
./test.ps1 -LuaDll '<Helldivers 2 folder>/bin/lua51.dll'
Compress-Archive -Path './dist/HD2-AutoReload-0.3.29-test/*' -DestinationPath './dist/HD2-AutoReload-0.3.29-test.zip'
```

Credited HD2 HUD+ 0.1.2 reader sources and original reuse permission are in
`vendor/` and THIRD_PARTY.txt. Only non-rendering identity support is used at
runtime; the legacy diagnostic provider is not invoked.

Source and test releases:
https://github.com/pwj891129-arch/HD2-AutoReload
Published separately from HD2 Helper.
