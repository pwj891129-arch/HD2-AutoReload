# HD2 Helper Auto Reload 0.3.15-test

Bingus Shared Loader / Arsenal additive addon. It does not replace the game's
boot script, the shared loader, or an installed HD2 Helper executable.

Source: https://github.com/pwj891129-arch/HD2-AutoReload
Test releases: https://github.com/pwj891129-arch/HD2-AutoReload/releases
Published separately from HD2 Helper.

## HD2 HUD Coexistence

Keep HD2 HUD enabled for its displays. This addon owns no HUD textures, GUI,
boot, Wwise replacement or HD2 HUD resource names. Its unique Lua resource is
`mods/hd2_helper/auto_reload`. Arsenal assigns each mod's patch index; the ZIP's
`patch_0` filename is not itself a resource conflict. Do not manually overwrite
one mod's archive with another mod's archive in the game's data folder.

The update/shutdown hooks preserve earlier callbacks and their return values.
Errors in the auto-reload callback are isolated so a HUD callback wrapping it
still runs. Win32 FFI symbols use private aliases and the reader clones its
mutable field map instead of modifying shared HUD definitions. It does not
change another mod's JIT options, input settings, GUI or configuration files.

Test coverage uses the installed HD2 HUD+ 0.1.2 callback implementation in both
hook orders, plus real Win32 symbol resolution and mock reload input. This is
not a live gameplay compatibility test of the latest HD2 HUD build.

Use HD2 HUD's game-compatible release; the installed 0.1.2 package is old. The
author lists 0.1.12 as the September 24 game-update fix:
https://www.nexusmods.com/helldivers2/mods/15298

Enable HD2 HUD, this addon and Bingus Shared Loader together. Keep Bingus as
the winning Wwise startup replacement (normally below other such replacements
in Arsenal), then purge/redeploy with the game closed and restart the game.
Do not turn off HD2 HUD; only disable other automatic-reload implementations.

## Reload Triggers

- Magazine weapons: usable ammunition changes from a positive count to zero.
- Heat weapons: the game's explicit overheat flag changes from false to true.
- The actual held weapon changes to an empty or overheated weapon.
- A new fire-key press attempts to fire an empty or overheated weapon.
- Number-row 1, 2, or 3 selects a known primary, sidearm, or support weapon.
  The addon waits 1.1 seconds, then rereads the requested weapon and its
  ammunition before attempting reload. Numpad keys are separate.

Requests require known zero ammo for magazine weapons or an explicit true
overheat flag for heat weapons, a known positive reserve, an unambiguous local
held weapon, and player movement/rotation control. The seated-passenger
exception requires right-click aim, recent fire, and an ordinary personal
weapon confirmed at the hand node. It does not apply to the cannon or a
merely carried weapon. A known idle reload state
is normally required. When a heat weapon's reload flag turns true with the
overheat flag, one attempt is allowed after 150 ms of persistent overheat and
unchanged reserve; a manual R press or reserve change cancels that attempt.
Only one input is sent per observed overheat episode, including across brief
weapon-recognition gaps. Cooling or a confirmed weapon change clears the guard.
Primary, sidearm (including the missile pistol), and support weapon classes
are supported.
After a new game or respawn, the addon refreshes its local weapon identity
cache when the avatar returns. A persistent missing weapon also triggers a
throttled cache refresh; a brief swap animation does not. It never reloads
from an unresolved weapon reading. The recovery path is covered by LuaJIT
tests but still needs confirmation in a live game.
The addon checks at most every 20 ms, plus game-frame scheduling. A 40 ms
reload-key pulse is sent through Windows SendInput. It does not write ammunition
or alter game state. An initial empty reading alone does not trigger a reload.
An event can wait up to 350 ms for complete data, with a 350 ms repeat guard.

Heat/laser weapons are identified from their heat metadata or declared heat
field. A red/near-full heat gauge and zero ammo alone do not trigger reload.
If the overheat flag or spare heat sink count is unavailable, no reload is sent.
Underbarrels, throwables, melee, vehicle and mounted weapons remain excluded.
Unknown data never counts as empty or overheated. The reader
is derived from HD2 HUD+ 0.1.2 with credit and its packaged reuse permission.
LAS-12 Sai is newer than this reader's equipment identity table and remains
unsupported until its runtime type and field mapping can be verified.
Its compatibility with the current game needs a live mission test. Schema checks
and Lua errors disable action instead of guessing. This does not certify that
mod use is accepted by the game or its anti-cheat.

## Experimental Diagnostics

Versions 0.3.9-test and 0.3.10-test added independent `SELF_` field scanning and
`CATALOG_API` checks. A game exit was reported on entering the ship with
0.3.10-test. The last addon log entry was during ship initialization, before a
`CATALOG_API` result; that is not enough to prove the crash's exact cause. Both
experimental diagnostics are disabled in this build. Their source and mock
tests remain for investigation, but they perform no live game-object reads.
The existing automatic reload path is otherwise unchanged. Unknown weapons
such as LAS-12 Sai still do not auto reload.

## Game Type Hash Check

In 0.3.12-test the one-shot `UNIT_LINK` check returned `no-synchronizer` on a
recognized Dagger. This build leaves that path inactive. It tests another
route: whether a game object's type can be matched using the hashed type ID
from the game's own `.network_config`, without the old reader's string alias.

In a mission, hold a weapon this version already recognizes, such as the
Dagger, and press F9 once. The addon checks that the known string alias still
matches, then asks `GameSession.game_object_is_type` about the same object
using `IdString32.from_hex`. It logs one `HASH_TYPE` result per session and
does not scan other objects or execute this check on an unrecognized weapon.
The F9 edge is logged as `HASH_TYPE requested` immediately and held until the
next reader tick; `0.3.13-test` could lose the edge during its 20 ms read gap.
`baseline=true hash=true` validates this type-matching step. A false/error
result does not. Do not press F9 on ship entry; run the check after landing.
The check does not reload unknown weapons or write game state.

## Unknown Weapon Discovery

This test adds an opt-in, read-only F10 comparison for finding an unregistered
weapon's game-object ID. After landing in a mission, hold a recognized weapon
such as the Dagger and press F10 once. Wait for `DISCOVERY baseline-ready` in
the log. Switch to LAS-12 Sai, press F10 again, and wait for
`DISCOVERY compare-ready`. The addon lists at most 24 changed, added, or
removed object IDs and a few numeric/boolean field changes for each. These
are **candidates**, not proof of weapon identity. Do not infer a type hash or
enable auto reload from a candidate line alone. The F10 scan reads at most 512
locally owned objects, 12 per 250 ms, only on explicit request. It does not
scan automatically on ship entry. Do not press F10 until the mission has loaded.

## Game Catalog Research

`inspect_game_catalog.cjs` reads the installed game's bundle index and locates
the `.network_config` asset without changing game files. Its current purpose is
diagnostic: that asset contains hashed game-object types and fields, but not the
string call names needed by the existing reader. If the F9 check succeeds,
parsing this asset and mapping a live unknown object to its type and held slot
are still separate work. The standalone script does not run inside the game.

## Installation

1. Close the game before deploying mods.
2. Import the release ZIP into Arsenal.
3. Enable this addon and Bingus Shared Loader v15+ / API 1, then deploy.
4. Disable the helper's existing screen-based automatic reload and the old Auto
   Reload diagnostic/helper scripts while testing to prevent double input.
5. Launch the game normally and test all three triggers in a mission.

HD2 HUD+ does not need to be installed/enabled. The read-only modules required
by this addon are embedded, but none of its display or startup code is included.

Default keys are left mouse for fire, R for reload, F8 for pause/resume, and
F9 for the one-shot read-only type check, and F10 for the two-stage unknown
weapon object comparison.
On first startup the addon creates `%APPDATA%\HD2AutoReload.ini` when possible:

```ini
enabled=true
fire_vk=1
reload_vk=82
pause_vk=119
```

These are Windows virtual-key numbers; restart the game after editing. Mouse
reload bindings are not supported. Enter tracks chat opening/sending; Escape
clears that chat guard. Holding Enter, Escape, or Tab blocks requests. Control
fields additionally gate menus and other non-player-control states, but their
actual game behavior must be tested. F8 is an emergency pause/resume toggle.

Diagnostics are written through the Bingus loader to
`%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\hd2_helper_auto_reload.log`.
Look for START, ready, RELOAD followed by
one of ammo-exhausted / overheated / weapon-swapped / fire-attempt, or a blocking reason.
RELOAD means an input was accepted by Windows, not confirmed completion by the
game. INPUT_FAILED or DISABLED means no further guessed action is taken.
For heat weapons, status lines also show the observed overheat flag, spare
count, reload flag and a heat-gauge snapshot. `SEAT_AIM` records the weapon
grip, control gates, and hand-node evidence when aiming from a suspected tank
seat. These are
read-only diagnostics and do not bypass an unknown safety condition.

## Tank Cannon Diagnostic

Tank cannon automatic reload is not enabled in this test. The existing weapon
reader stops when the player is seated and does not expose the cannon's loaded
round or remaining shells. This build records read-only `TANK_PROBE` snapshots
when player control is blocked. It also records a 20-second window after aiming
or firing while grip 70 has no recognized held object. Neither a seat hint nor
grip 70 alone confirms a tank or authorizes reload input. The probe rotates through up to 12
locally owned objects per 250 ms and logs only the first or changed bounded
small integer and boolean fields on each page, up to 120 lines per session.
It does not send a reload input from those snapshots.
PROBE_INPUT marks aim and fire edges so the rotating snapshots can be compared
against the actual shot. Repeated edges during one capture do not restart the
page rotation.

For field mapping, sit in the Bastion gunner seat with one shell loaded, fire
to show `0/1`, then manually reload to show `1/1`. Hold each state for at least
15 seconds so the rotating probe can see every page. Aim before firing to
start the probe when the held object is unresolved. Send the `TANK_PROBE` lines
from the log along with the screenshots. This is needed to distinguish the
cannon's loaded round and reserve from unrelated vehicle and personal-weapon
fields. The ordinary reload policy already blocks unknown or zero reserves;
it is not yet connected to tank data.

## Build And Test

Requires Node.js, PowerShell, and the game's LuaJIT `bin/lua51.dll`. Build reads
the licensed HD2 HUD+ 0.1.2 package, verifies its SHA-256, and extracts only the
non-rendering source modules. Tests run Lua in a separate process with mocked
game/input APIs, never attach to the game or send actual inputs.

```powershell
node build.cjs
./test.ps1 -LuaDll '<Helldivers 2 folder>/bin/lua51.dll'
Compress-Archive -Path './dist/HD2-AutoReload-0.3.15-test/*' -DestinationPath './dist/HD2-AutoReload-0.3.15-test.zip'
```

The credited reader sources and original permission README are in `vendor/`.
To re-extract the pinned installed package, pass its folder to `build.cjs`.
