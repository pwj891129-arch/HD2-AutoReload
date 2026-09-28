# HD2 Helper Auto Reload 0.3.2-test

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

Requests require known zero ammo for magazine weapons or an explicit true
overheat flag for heat weapons, a known positive reserve, a known idle reload
state, an unambiguous local held weapon, and player movement/rotation control.
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
Its compatibility with the current game needs a live mission test. Schema checks
and Lua errors disable action instead of guessing. This does not certify that
mod use is accepted by the game or its anti-cheat.

## Installation

1. Close the game before deploying mods.
2. Import the release ZIP into Arsenal.
3. Enable this addon and Bingus Shared Loader v15+ / API 1, then deploy.
4. Disable the helper's existing screen-based automatic reload and the old Auto
   Reload diagnostic/helper scripts while testing to prevent double input.
5. Launch the game normally and test all three triggers in a mission.

HD2 HUD+ does not need to be installed/enabled. The read-only modules required
by this addon are embedded, but none of its display or startup code is included.

Default keys are left mouse for fire, R for reload, and F8 for pause/resume.
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

## Build And Test

Requires Node.js, PowerShell, and the game's LuaJIT `bin/lua51.dll`. Build reads
the licensed HD2 HUD+ 0.1.2 package, verifies its SHA-256, and extracts only the
non-rendering source modules. Tests run Lua in a separate process with mocked
game/input APIs, never attach to the game or send actual inputs.

```powershell
node build.cjs
./test.ps1 -LuaDll '<Helldivers 2 folder>/bin/lua51.dll'
Compress-Archive -Path './dist/HD2-AutoReload-0.3.2-test/*' -DestinationPath './dist/HD2-AutoReload-0.3.2-test.zip'
```

The credited reader sources and original permission README are in `vendor/`.
To re-extract the pinned installed package, pass its folder to `build.cjs`.
