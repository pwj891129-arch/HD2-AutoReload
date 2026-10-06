# HD2 Helper Auto Reload + Stratagems 0.3.50-test

0.3.50-test hides location-restricted mission calls outside their current native
objective area. It reads the game's current objective stage, active/passive state,
call anchor or child units and configured horizontal radius. Reference-linked drill
areas use the native reference entity and nearest eligible active target. Upload Discovery
uses its native local permission and three-dimensional radius. There are no
native function calls, hooks, game-memory writes or fixed per-stratagem distances.

The wheel refreshes every 50ms. Location changes do not alter the equipped four
slots or their hotkeys; common calls and mission calls without a location limit
keep their existing visibility options. Cooldowns remain visible inside an
eligible area. A failed location read hides only the affected mission call.
Selections are revalidated before and during command input. When membership
changes on a release frame, an old sector index cannot select a different call.

Offline tests cover range boundaries, height, current stages, inactive/completed
objectives, child/override anchors, destroyed or reused engine units,
multiplayer local identity, unreadable data, stale selections and Discovery.
Live mission-area visibility still needs an in-game test. Install only one of
the English/Korean 0.3.50-test ZIPs using Arsenal with the game closed.

## Wheel Countdown Format

0.3.49-test shows wheel cooldown/call-in countdowns as `minutes:seconds`, with
two-digit seconds (`0:03`, `1:05`, `12:30`). Positive fractions still round up
before display, and minutes may exceed 59. Internal seconds, availability and
command input are unchanged; `READY`, `EMPTY` and `UNKNOWN` retain their meanings.
Both language packages use the same format. Vehicle reload logic is unchanged.

## Vehicle Reload Correction

0.3.48-test corrects the mounted reload input-state check. The old check used
the firing-only flag and an incorrect row-origin offset. The new read mirrors
the native seated-input predicate (bit 50 at avatar manager +0x53e888,
stride 0x1238), independently of the firing flag. No game function is called.

Verified mounted samples no longer depend on personal hand/grip recognition or
its network avatar result. Native local-unit, avatar, seat, weapon, reload,
reserve and empty chamber checks remain required; a disagreeing network avatar
blocks input. Personal weapons retain their existing identity/control gates.
Vehicle read failures are now logged as `vehicle-...` instead of being hidden
behind a personal `grip` or `no-on-body-object` message.

Offline tests cover firing permission OFF with seated permission ON, missing
personal identity, blocked native input and identity changes during reads.
The previous gameplay log had vehicle ON but no accepted mounted samples, so
the exact remaining in-game blocker is not established. Actual Bastion reload
and multiplayer behavior must be retested. This package does not change or
include the separately maintained private Solo Vehicle Driver replacement.

## Vehicle Automatic Reload

0.3.47-test adds a separate `Vehicle Automatic Reload` / `차량 자동 재장전`
checkbox at the end of the Arsenal options. It is independent of the existing
personal Automatic Reload checkbox. Previous option positions, resource paths
and the package GUID are retained. New checkboxes start checked on a fresh
Arsenal import; review the new option before deploying.

The test path targets the first mounted weapon in settled FRV (0x1a), Bastion
(0x2b) and Maelstrom (0x2c) gunner/pilot seats. It binds the local avatar,
SeatComponent collection/current seat index and WeaponWielderComponent slot 0.
It reads magazine/rounds and chamber ammunition from that weapon. A verified
WeaponReloadComponent and positive weapon-local reserve are required. Passenger
lean-out personal weapons still use the existing personal option. Other vehicle
types, driver-only seats, seat transitions, unknown feeds, non-reloadable and
heat-only mounts are excluded; this is not universal support for all vehicles.

Mounted reload activity follows the native weapon-owner/animation relation and
the configured reload animation state, rather than assuming the personal
avatar's reload flag covers the cannon. Native seated-input permission
is required. Links, seat state and ownership are rechecked before accepting a
sample. Two coherent empty readings are required, including an empty chamber.

A confirmed empty mount on seating, observed ammo exhaustion, fire release or
an empty-weapon click can request reload. A held fire button defers R. With
left-mouse firing, an explicit empty click may release fire before R, as for the
existing stationary-weapon path. There is only one automatic R attempt per
empty episode; another explicit empty click can retry, and observed loaded
ammo rearms it. No spare ammo, active/manual reload, focus loss, chat,
stratagem input and unavailable vehicle control block requests.

The existing 50 ms reader cadence and 40 ms configured reload-key pulse are
retained. No vehicle state, ammunition or driving rights are written, and no
internal game function is invoked. The same binary-hash pin remains required.
The new option marker uses patch_57, avoiding the wheel texture's patch_56.

Vehicle fixtures, option independence, native instruction layout and both
language packages pass offline tests. Actual FRV/tank reload, solo-driver
compatibility and multiplayer behavior remain unverified. Install one language
ZIP, check the vehicle option, close the game and Purge / Deploy before testing.
Development and publishing do not apply the mod or operate the running game.

## Wheel Scale Choices

Radial Menu Size now offers 100% (default), 125%, 150%, 200% and 300%.
125% replaces the removed 400% choice. English/Korean manifests, descriptions,
deployment markers, runtime validation and geometry tests use the same values.
An old deployed 400% marker is rejected and falls back to the 100% default.
The four retained scale values keep their resource paths. The top-level option
position, package GUID, other settings and defaults are unchanged, but Arsenal
may retain a suboption by position; review the scale after replacing the ZIP.
Purge / Deploy with the game closed to remove the previous version's files.

The 0.3.45 labels, native Korean rendering, icons, input, automatic/backpack
reload and charge-release behavior are unchanged. No game configuration value
or installed mod is modified by this update's development tools.

## Readable Wheel Labels

0.3.44's user screenshot now shows Korean names and its runtime log records
native resource-text rendering without bitmap fallback. The names were too small
and cooldown names were unnecessarily dim. 0.3.45 raises the nominal name height
from 14px to 24px, status height from 12px to 16px and center-label height from
16px to 20px. Actual sizes still adapt to sector count, resolution, menu scale
and long names. Names remain fully opaque and bright even during cooldown;
icons retain their existing ready/unavailable tint.

Native Korean, English and fallback glyphs receive an opaque dark offset shadow.
The foreground and shadow are fitted together inside the reserved text bounds.
Native/bitmap failures remove both partial layers before fallback. Slot numbers
move beside the status rather than reducing the name's available width. Each
sector reserves two name lines, an icon up to 84px and separate status space.
The base radius grows by 25px to accommodate the larger content; viewport clamps
and menu scaling are retained. The normal nine-sector layout reserves at least
18px nominal name height without shrinking its icons below 63px at 100% scale.

Geometry checks cover 1-16 rows, five resolutions and all menu scales, including
native Korean bearings, actual fallback glyphs and shadows. The offline preview
is an illustration of the actual Lua layout through the bitmap fallback, not a
live game screenshot. The new size/contrast needs gameplay confirmation. Input,
reload, visibility, option defaults and installed mods are not changed.

## Korean Font Resource Routing

In 0.3.42, Korean names and the matching native font/atlas were available, but
the screenshot showed no Korean text. 0.3.43's raster route was not tested live
before 0.3.44 restored visible native Korean labels in the user's test.

Review found that 0.3.42 bound an owned GUI's font material, then passed the
Material instance pointer to Gui.text. Icons and English text instead draw by
material resource. 0.3.44 uses the same resource-based contract for Korean text:
the texture is bound on the owned GUI, and Gui.text resolves that GUI's
`content/fonts/core_sans` resource, not the instance pointer. The font and its
matching atlas stay paired. This is a targeted correction to a differing call
path, not a proven diagnosis of the game's invisible output. The generic
[Stingray API](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/lua_ref/obj_stingray_Gui.html)
documents both resource and pointer arguments; this game's rendering must still
be checked live. No game native function is invoked through FFI.

Native Korean text is preferred only when its font, atlas, material and glyph
coverage are available. Binding/measurement/draw failures disable that route for
the current opening and fall back to the 0.3.43 raster glyphs, then English if
those are also unavailable. A successful API return is not proof of visible
pixels, so silent native rendering failure cannot be automatically detected.
Logs now identify `native-font-drawn` with the font, atlas, resource, primitive ID,
font size and screen-space bounds, or a binding/measurement/draw error. Reports
are bounded per font/opening. Nonfinite bearings and second, resized measurements
are guarded. English rendering, icons, inputs, settings and reload remain unchanged.

Regression tests distinguish a resource handle from a Material instance, cover
both native pairs, reuse/cleanup, missing glyphs/resources, failures and recovery,
and the actual raster fallback. The user later confirmed visible Korean labels
and 0.3.44 logs used native resource-text without fallback. No installed mod,
game state or input was changed during development.

## Korean Raster Glyphs And Larger Icons

The 0.3.42 native Korean font/atlas binding attempt still produced invisible names
in the user's game. 0.3.43-test introduced an independent fallback drawing path, not just a
font choice. A mod-owned coverage texture contains 296 raster glyphs generated
from Noto Sans CJK KR Regular (SIL Open Font License 1.1). Korean text is drawn as
retained UV bitmaps using the same native mask material as the working icons.
This fallback does not call the game's font renderer, native font extents or MSDF
shader, and does not depend on Korean game UI resources. English text keeps its existing
debug-font renderer. Missing glyphs/resources or failed draws fall back to English;
partial glyph draws are cleaned up. Only owned GUI material instances are changed.

In 0.3.43 icons grew to 72px at 100% scale where space permits, rather than being capped
at 44px. A cached geometric search fits taller content blocks inside each actual
polygonal sector, allowing larger icons without enlarging the wheel or overlapping
names, status or slot numbers. Icons adapt for dense wheels/small screens. Long labels are
balanced at spaces (or UTF-8 character boundaries), then fitted to the available
width. The highlighted name stays in the center instead of below the wheel.
Selection angles, slot mapping, command input, visibility and reload behavior
are unchanged. English and Korean ZIPs retain the same option paths/defaults.

Core now includes a second patch with the mod-owned texture and its GPU payload.
Every existing option still includes the same Core folder. Both language packages
include WHEEL-FONT-LICENSE.txt and WHEEL-FONT-SOURCES.json; no original game fonts,
textures or UI binaries are shipped. Font source SHA256:
`6bcb2a0703aa137e874fc2dffa85f6c21ba9a67fa329e81b8c801663af7e992a`.
The downloaded source OTF is build-only and is not included in releases. Normal
builds use the checked-in mask PNG, glyph metrics and compressed native mipmaps.
Regenerate them with `tools/wheel-glyphs.py` (Pillow) and `tools/wheel-texture.cjs`
(Sharp); `tools/wheel-glyphs.test.cjs` verifies actual pixel coverage and deployment.

Offline tests cover all 149 Korean names, exact DDS/GPU mipmap sizes, atlas binding,
glyph bearing alignment, fallback/partial draw cleanup, 1-16 calls, 320x240 through
3840x2160 and every supported menu size. Actual Lua draw geometry and glyph UVs were
exported and rendered offline together with native icons for visual verification.
Logs distinguish `glyph-source`, `glyph-drawn` and `glyph-draw-failed`. Actual gameplay
still needs verification; no installed mod, game process or game input was changed.

## Backpack Reserve And Korean Wheel Labels

0.3.41-test includes the player's equipped ammo backpack when the held weapon
has no personal spare ammo. The read-only native path follows the game's
`WeaponAssistedReloadComponent`, local inventory backpack slot, support-backpack
equipment class and `DepositComponent` compatibility/quantity. The pack must
match the weapon and contain at least the native per-reload requirement. No
weapon-name list or HUD+ lookup is used; other players' or dropped packs are
never searched. Empty/incompatible/unreadable packs cannot authorize reload.
Weapon, avatar, backpack identity and quantity are rechecked; a changed pack or
GOID requires a new pair of coherent readings. Stationary reload behavior from
0.3.40-test remains: release does not reload, but a new empty click can reload.
Logs include `BACKPACK_RESERVE` with the source, quantity, requirement and reason.

The Korean ZIP also displays Korean stratagem wheel names. Of the 149 pinned
native definitions, 141 use installed Korean game strings and eight use explicit
fallback labels for entries with no translated name. Names are matched to both
kind and native definition name; mismatches use a generic Korean label. Commands,
readiness, visibility, icons and hotkey slot numbers are not localized or changed.
The English ZIP keeps its previous English wheel labels.

The initial native-font path in 0.3.41 and the atlas-binding attempt in 0.3.42 have
been replaced by the OFL bitmap path described above. Original game translations
retain their original rights; the new glyph artwork carries its separate OFL notice.

Offline tests cover the native backpack path, instance/authored compatibility,
empty/insufficient ammo, dropped/stale/replaced packs, missing data, confirmation
reset, stationary click behavior, Korean identity matching and font fallbacks.
Existing saved binary/assets provide layout and glyph evidence only. No running
game was inspected, controlled or redeployed; actual gameplay remains unverified.

## Stationary Reload Weapons

0.3.40-test reads the held weapon's native `WeaponReloadComponent`
`reload_allow_move` setting. Entity overrides take precedence over the game's
authored configuration. No weapon-name list or HUD+ lookup is needed for this
classification. Layouts remain guarded by the existing two binary hashes;
indices, component ownership, booleans and held identity are validated.

When that setting is false, releasing fire does not initiate reload during
the one-second post-release window. Click the empty weapon again to request
reload. Because the game ignores reload while fire is held, that explicit
empty click releases left mouse once, waits at least 60 ms, then revalidates
ammo/overheat, reserve, reload state and input gates before sending reload.
It never injects a mouse-down. A click that began with usable ammo does not
authorize release when the magazine later empties. The physical button must
be released before another click. Weapon-switch reload checks are unchanged.

If movement metadata cannot be read coherently, fire-release reload is also
suppressed rather than guessing that movement is allowed. No automatic mouse
release is authorized without an explicit stationary classification. Existing
empty-click/manual/switch behavior otherwise remains. Logs report
`RELOAD_MOVEMENT` and authorized `RELOAD_PRESS_RELEASE` events.

Offline LuaJIT mocks cover stationary/moving/unknown settings, override/authored
lookup, empty-click confirmation, focus/menu/weapon changes, no reserve and
reload already in progress. The local pinned binary capture validates the
native layout without reading a running game. Actual gameplay remains unverified.
Native field research references the
[HelldiversData reload component definition](https://raw.githubusercontent.com/shalzuth/HelldiversData/master/data/components/WeaponReloadComponent.json).

## Toggle Click Selection And Cancellation

0.3.39-test repairs Toggle List synchronization after cursor capture. Runtime
logs showed click selection waiting for native closure until timeout, with a
second physical List press needed to continue. A mock reproduces that symptom
when the original List key-up is lost: another DOWN alone has no fresh edge.
Selection now releases stale List input, waits 60 ms, and sends one 60 ms
close pulse only if the actual game menu is still open. Commands wait for
observed, stable native closure before reopening the menu. Reopening also
allows delayed native activation. Direction input intervals remain unchanged.

While a Toggle wheel is open, right-click cancels even over a ready sector.
It overrides an outstanding left-click selection. Center left-click also
cancels. Both cancel the wheel and the actual game List toggle after the
mouse buttons are released; neither reopens the menu or sends a command.
No fire/aim clicks are synthesized. Holding either click blocks reload/charge
automation. Hold mode, direct Arsenal checkboxes, icons and option positions
are unchanged. Focus/chat/ownership/binding checks and bounded timeouts remain.

Offline tests cover swallowed List release, delayed native updates, failed
input, keyboard/thumb bindings, mixed-click priority and native closure.
Live Arsenal/game verification still requires replacing the package and
Purge / Deploy with the game closed. Build/publication does not change
installed mods or game inputs.

## Direct Checkboxes And Toggle Click Selection

0.3.38-test removes the ON/OFF submenus from 39 boolean settings. A checked
Arsenal option now directly deploys its ON marker; an unchecked option deploys
no marker and is OFF, including reload, charge release, radial and number hotkeys.
This fixes the confusing two-level setting: previously a checked parent could
still deploy its default OFF child, so the wheel showed only the four personal
slots. All individual shared/mission visibility controls now follow their own
checkbox. Their native icons, positions and ON resource paths are retained.

Arsenal initially checks newly imported options. Checked calls are therefore
visible if they exist in the current mission; uncheck unwanted calls before
Deploy. Reload and charge release start checked on a fresh import. Existing
options may be retained during replacement; review the actual checkbox states.
The three bulk modes still offer Individual Settings / ON / OFF, because they
also need to restore individual choices. Menu size remains a multi-value choice.
Command Input Interval now explicitly offers 15 ms (default) or 30 ms rather
than disguising the interval as another ON/OFF menu.

With a Toggle List binding, left-click a wheel sector to confirm it, or press
the List key again as before. The sector is captured at mouse-down; command
input waits until physical left-mouse release before closing/reopening the
native menu. Center clicks cancel; 0.3.39-test also adds right-click cancellation.
No left-mouse down/up is synthesized, and
aim/throw remain manual. Hold-mode behavior is unchanged. Readiness, loadout,
character ownership, bindings and direction input are revalidated; focus/chat
loss, a changed character, a second List press or a 10-second unreleased click
cancel selection. Reload/charge automation remains blocked during selection.

Runtime logs now report each visibility checkbox and its effective bulk-filter
result. Offline click/checkbox regressions pass; actual Arsenal and gameplay
verification still needs a fresh Purge / Deploy with the game closed. Building
and publishing do not modify installed mods or running game inputs.

## Native Arsenal Stratagem Previews

0.3.37-test replaces 23 individual Arsenal option previews with the actual
Helldivers 2 UI texture masks and per-definition palette colors. Reinforce,
SOS, Resupply, Hellbomb, flag, SEAF artillery and other assigned native icons
are converted to 256x256 PNG previews with a dark contrast plate. The shape,
orientation and native color selection come from the game, not a redrawn symbol.
Native duplicate artwork is preserved: several mission calls share the same
game icon. Multi-variant toggles use their first variant with an assigned icon.

11 mission toggles have no icon assigned in the captured native definitions:
Extraction Beacon, Jammed Pinata, Remote Explosives, Emergency Extraction,
Carpet Bombing, Scrambler, Immediate Extraction, SEAF Squad, Spire Sterilizer,
Drilling Charge and Nuke. They retain their existing explicit Lucide fallback,
not another call's artwork. Their descriptions explain that limitation in both
languages. The 10 functional settings also keep their existing library symbols.

Previews are manifest-only Arsenal images, never in deployed patch Include
folders. GAME-ICON-SOURCES.json records native kind/texture/palette identities
and DDS/PNG digests. GAME-ARTWORK.txt distinguishes game artwork from the
remaining Lucide/Feather symbols; the library license does not relicense game
artwork. Original DDS, material/shader binaries and memory captures are not
bundled. The in-game wheel already uses loaded native icons and is unchanged.

Option names, order, paths, defaults, bulk-control precedence, menu sizes and
all reload/charge/input behavior remain unchanged. Package regression compares
the previous core after replacing only version strings. Assets were checked
against 34 native definition mappings and as 32px thumbnails; real Arsenal
display still needs confirmation. Building/publishing does not install patches.

## Bulk Visibility And Menu Sizes

0.3.36-test adds three Arsenal controls: Shared: All, Mission: All and
Shared + Mission: All. Each offers Individual Settings (default), ON and OFF.
The combined control has highest priority, followed by the corresponding group
control and then each individual setting. Bulk controls override only visibility;
they do not erase individual choices. Return both relevant controls to Individual
Settings to restore those choices. Omitted bulk controls also use individual
settings. Invalid or unreadable bulk markers hide their affected group.

Shared: All includes Reinforce, SOS, Resupply and unclassified shared calls such
as Eagle Rearm. Mission: All covers the 31 registered mission types. Combined
ON includes all shared calls, including unclassified entries; combined OFF hides
them all. Calls still must exist in the local current mission. Personal slots
1-4 and their hotkeys are never hidden or renumbered by these controls.

Radial Menu Size replaces the old 100%/130% toggle with 100% (default), 125%,
150%, 200% and 300%. Geometry, native icons, labels and the selection dead zone
use the same effective scale. Large sizes are limited to fit the viewport;
the requested size may be reduced on smaller displays.
The obsolete `large` marker is ignored. Review the size selection after replacing
the package; Arsenal may retain a former size choice by its option position.

Existing individual toggle positions, default variants, icons, Lua resource IDs
and Include paths are retained. Bulk controls are appended after the existing
calls and have distinct Lucide previews. The size selector stays in the former
size option's position. Reload, charge-release and Hold/Toggle behavior are
unchanged. Both language ZIPs are provided; no installed game mods are changed
by building or publishing. Actual Arsenal/gameplay testing is still required.

## Epoch Full Charge And Toggle Menus

0.3.35-test fixes Epoch being rejected as a nonexplosive charge weapon. Epoch
now releases left mouse at 100% of the native Full charge time, whereas Railgun
retains 90% of its explosion limit. No fixed Epoch timer is embedded: instance
overrides and authored configuration are read from the held weapon. Exact full
charge, a clamped plateau and slightly late reads below the configured maximum
are accepted; invalid data and repeat firing remain blocked.

The game's keyboard and mouse-thumb Press/Toggle List bindings are now accepted
alongside Hold. Toggle wheels follow the actual local character menu rather
than physical key duration. Toggle open, choose a sector, then toggle closed to
enter its command; closing at the center cancels. A lost thumb close is replayed
only after physical release and cursor restoration, and its resulting native
closure must be observed. Command reopening uses a bounded press/release pulse,
never a permanently held Toggle button. Number-row shortcuts also work while
the native Toggle menu is open. Native menu closure without a user toggle
cancels rather than dispatching a hovered item. Both reload and charge release
remain blocked while the native menu is active, including after key release.

Option resource IDs, default values, icons, order and Include paths are retained;
charge/radial/hotkey descriptions are updated in both language packages. Offline
tests cover charge boundaries, native toggle observation, keyboard/thumb modes,
center/cooldown cancellation, lost thumb clicks, binding changes, unavailable
character state and combined reload coordination. Live gameplay is unverified.

## Arsenal Option Icons

0.3.34-test adds 41 distinct 256x256 PNG previews to the existing Arsenal
options and their ON/OFF choices. Bright cyan identifies general features,
yellow identifies shared calls and mint identifies mission calls. Each symbol
uses an opaque dark contrast plate and remains legible as a small thumbnail.
These are functional Lucide symbols for the settings UI, not the game's native
stratagem artwork. In-game wheel art is unchanged.

In 0.3.34-test, option order, labels, default values and Include paths were retained.
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

- `HD2-AutoReload-0.3.50-test-en.zip`: English Arsenal options and wheel names (default distribution).
- `HD2-AutoReload-0.3.50-test-ko.zip`: Korean Arsenal options and wheel names.

Install only one ZIP. Both share the same mod GUID, option order, default values,
include paths and game logic. Only manifest text and the wheel language flag differ.
Changing package language replaces the same mod, not an additional addon. Review
checkbox states after replacement, then Purge / Deploy and restart the game.

Arsenal 0.36.2 displays mod-provided names and descriptions literally; its UI
language packs do not translate these fields. There is no OS-language detection
script or automatic language switch in this release. Choose the ZIP yourself.
The wheel language follows the ZIP, not OS detection. Runtime logs remain English.

한국어 옵션과 휠 이름을 표시하려면 `-ko.zip` 파일만 설치하세요. 영어판은 `-en.zip`입니다.
두 언어판을 동시에 설치하지 마세요. 언어판 교체 후 ON/OFF 설정을 확인하고
Purge / Deploy 및 게임 재시작을 진행하세요. OS 언어 자동 감지 파일은 포함하지 않습니다.

## Combined Mod

0.3.30-test fixes a deployment failure in 0.3.29-test: the current Arsenal
0.36.2 BETA imported the root addon but deployed only seven setting markers.
The loader listed neither helper component, and both feature logs were stale.
The executable addon now lives in Core/, explicitly included by every selected
checkbox or choice. Selected options share one common addon, not duplicate resources.
Choose at least one setting in Arsenal; all options unchecked now intentionally
deploys nothing. Unchecked boolean options are OFF even when another selected
setting deploys the core.

This package includes the Stratagem Hotkeys 0.1.13-test implementation alongside
automatic reload. Import only this ZIP: disable/remove the separate HD2
Stratagem Hotkeys package and the previous Auto Reload package before Purge /
Deploy. There is one loader addon resource, with independently guarded startup
for both features. Stratagem input updates its gate before reload and charge
processing in the same frame; both retain existing callback return values.

Automatic reload, Railgun 90% / Epoch 100% charge release, radial and number
hotkeys are ON only when their checkboxes are checked. Missing markers mean OFF.
Fresh Arsenal imports initially check options, including these features. Review
the retained states when replacing an earlier version. No deployed files are
changed by building.

## Default-On Reload And Diagnostic Removal

Automatic reload starts checked on a fresh Arsenal import; unchecking it is OFF. The package
uses explicit Core includes instead of depending on root-file auto-deployment.
Arsenal's documented root-file behavior did not match the observed option-based
deployment in 0.36.2 BETA. At least one checkbox or choice must be selected.

The separate ammo-OFF and heat-OFF checkboxes have been removed. Old option
resources do not control this version. F9 type checks, tank field scanning,
seat research, and the legacy diagnostic reader are no longer bundled or
called. F9 and F10 have no addon function. Offline research sources and
automated developer tests remain in the repository, not the release ZIP.
Normal reload/error logs remain available.

## Arsenal Options

Feature settings are configured only in Arsenal. No in-game MODS menu is
registered; Mod Options Menu and Mod Bindings Menu are not dependencies.

- `Automatic Reload` / `자동재장전`: checked is ON; unchecked is OFF.
  Covers both magazine exhaustion and complete overheat.
- `Vehicle Automatic Reload` / `차량 자동 재장전`: independent checkbox at the end.
  Experimental reloadable FRV/tank primary mounts; unchecked disables only vehicles.
- `Railgun 90% / Epoch 100% Release` / `레일건 90%·에포크 100% 자동발사`: checked is ON; unchecked is OFF.
  Independent of automatic reload.
- `Stratagem Radial Menu` / `스트라타젬 원형 오버레이`: checked is ON; uncheck to disable the radial only.
- `Stratagem Number Hotkeys` / `스트라타젬 숫자 핫키`: checked is ON; uncheck to disable number shortcuts only.
- `Other Shared / Mission Calls` / `기타 공용/임무 스트라타젬 표시`: checked is ON; controls only types without an individual toggle.
- `Radial Menu Size` / `원형 메뉴 크기`: 100% by default; 125%, 150%, 200% or 300%, limited to fit the screen.
- `Command Input Interval` / `커맨드 입력 간격`: 15 ms by default; choose 30 ms for a longer press/release interval.
- `Shared: Reinforce`, `Shared: SOS Beacon`, `Shared: Resupply` / `공용: 증원`, `공용: SOS 신호기`, `공용: 보급`: check to show, uncheck to hide. No ON/OFF submenu.
- `Mission: ...` / `임무: ...`: 31 independent direct checkboxes. Includes Hellbomb, SEAF artillery, flag, drills, data upload, extraction variants and other native mission calls. Unavailable mission calls are never invented by enabling an option.
- `Shared: All` / `공용 스트라타젬 전체`: Individual Settings (default), ON or OFF for all shared calls, including other shared calls.
- `Mission: All` / `임무 스트라타젬 전체`: Individual Settings (default), ON or OFF for all registered mission calls.
- `Shared + Mission: All` / `공용·임무 스트라타젬 전체`: Individual Settings (default), ON or OFF for both categories together; takes priority over the two group controls.

Size, interval and bulk choices are mutually exclusive. Boolean settings have
only a direct checkbox. Bulk controls do not erase saved
individual settings; restore Individual Settings to use them again. Review choices after
importing, especially if Arsenal automatically enables new options. Close the
game, replace the previous package, Purge / Deploy, and restart after changes.
Old deployed option files must not be left behind. Building and publishing
do not change installed game patches.

F8 temporarily pauses reload and charge release, not the stratagem menu; it is
not a saved setting.

## Stratagem Radial And Hotkeys

Hold the game's configured Stratagem List button, move toward an icon sector,
then release to enter the command. Release at the center to cancel. With Toggle,
press to open, choose a sector and left-click (then release) or press List again
to close and enter its command. Center left-click or right-click cancels and
closes the actual game List toggle after both mouse buttons are released.
Keyboard and front/back mouse thumb Hold and
Press/Toggle bindings are supported; direction bindings are read from the game.
Wheel, long-press and controller mappings are not supported. Aim and throw
manually. While List is open, number-row 1-4 matches the personal
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

The wheel does not redistribute original texture, shader, material or GUI
binaries, or modify another mod's HUD instances. The package's game-derived PNG
previews are Arsenal-only and documented separately. English labels retain internal
development names; Korean labels use the localized catalog described above.
The existing icon fix still needs gameplay confirmation.

## Reload Behavior

All personal weapons use the held-object native reader, without requiring a
HUD+ weapon-name list. Reads are limited to one per 50 ms, plus frame/input
scheduling. Unknown game binaries or ambiguous data block input.

- An observed magazine transition from positive usable ammo to zero, or an
  explicit complete-overheat transition, can request reload.
- A new fire-key press checks once. While the fire button stays held, reload
  checks and reload input are deferred, except for the explicitly empty
  stationary-reload click described above.
- Release immediately rereads the current held weapon and opens a one-second
  confirmation window with further reads every 50 ms. Stationary or unknown
  reload-movement settings suppress reload from this window.
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
a reload. An initial personal-weapon empty reading alone is not an event;
the separate vehicle path can request one attempt on confirmed empty seating.

The seated-passenger exception requires right-click aim, recent fire and a
personal held weapon. Mounted primaries use the independent vehicle path
described above. Underbarrels, throwables, melee and unsupported vehicle weapons
remain excluded; no tank field discovery runs in this package.
A controlled on-foot grip70 weapon can use the native reader. Identity recovery
after a new game or respawn and the seated-personal-weapon path are retained.

## Charge Release

For RS-422 Railgun and PLAS-45 Epoch, the default-on feature reads the native
WeaponChargeComponent elapsed charge and per-weapon charge configuration. It uses
the instance override or authored type registry, not ordinary heat, OCR or a
fixed timer. Two coherent reads are required.

Railgun releases at or above 90% of the entire gauge from zero to its explosion
limit. Epoch releases at or above 100% of its Full firing charge, without
requiring an explosion flag; its Over charge time bounds valid readings.
Both send one Windows `MOUSEEVENTF_LEFTUP`. No mouse press, repeated firing or aiming is sent.
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
CHARGE_SOURCE, CHARGE_RELEASE and blocking/error logs remain. Stratagem CONFIG
logs include each individual checkbox and effective bulk result; research scans
and research hotkeys have been removed.

## Build And Test

Requires Node.js, PowerShell and the game's `bin/lua51.dll`. Tests use mocked
game/input APIs in a separate LuaJIT process, never attach to the game or send
actual inputs. Package checks enforce the HD2SDK minimum of 256 bytes per
single-resource archive. Per language, deployment checks exhaust all 288 base-control
combinations, every pair of settings in all omitted/variant states, and all-ON,
all-OFF and all-default configurations (5,067 scenarios).
They also verify localized text, identical option structure and game payloads
that differ only in their wheel-language flag. Individual kind filters,
explicit OFF precedence, hidden command rejection, slot numbering and coherent
shared/personal membership reads have regression coverage. The pinned native
catalog checks all mission kinds when local reference captures are available.
Manifest checks also confirm that every parent/variant choice has a valid PNG
reference and that existing individual toggle positions/icons/ON paths are
unchanged when the previous local package is available. Separate image checks verify 44 previews, 256x256
dimensions, nonblank pixels, full opacity and 32px thumbnail brightness.
23 use native artwork, 11 are documented fallbacks and 10 are functional
settings. Duplicate PNGs are allowed only for the same native texture and
palette. PNG digests, native kind mappings, color-mask channel conversion and
unassigned native references are checked. There are 36 distinct previews.
Bulk tests cover all three controls in omitted/individual/ON/OFF states, mixed
individual choices, restoration, query/load failure and invalid values. Size
tests check 100 viewport/count/scale combinations from 320x240 to 3840x2160:
sector/icon/text bounds, redraw, retention and aligned hit testing. The full
LuaJIT suite passes 30,766 assertions without sending OS input.
Direct-checkbox tests require missing markers to be OFF. Click tests cover
keyboard/thumb bindings, held clicks, current cursor hit testing, cancellation,
cooldown changes, character/loadout replacement and no synthetic fire/throw.
Tests cover both feature runtimes, shared-VM input declarations, callback order,
default/explicit settings, initialization isolation and input blocking/resumption.
These are offline mocks; actual combined gameplay and Arsenal UI remain unverified.

```powershell
node build.cjs
node package.test.cjs
node tools/mission-location-layout.test.cjs
./test.ps1 -LuaDll '<Helldivers 2 folder>/bin/lua51.dll'
node tools/reload-layout.test.cjs
node tools/vehicle-layout.test.cjs
node tools/stratagem-names.cjs --check
Compress-Archive -Path './dist/HD2-AutoReload-0.3.50-test-en/*' -DestinationPath './dist/HD2-AutoReload-0.3.50-test-en.zip'
Compress-Archive -Path './dist/HD2-AutoReload-0.3.50-test-ko/*' -DestinationPath './dist/HD2-AutoReload-0.3.50-test-ko.zip'
```

PNG assets are committed, so ordinary builds do not require an image library.
To regenerate the functional/fallback Lucide symbols, install Sharp for Node
and run `node tools/option-icons.cjs`, then `node tools/option-icons.test.cjs`.
The script preserves assigned native PNGs and includes them in the contact sheet.
The optional `--import <Arsenal app.asar or lucide.min.js>` refresh path requires the pinned
Lucide 0.544.0 bundle and does not modify Arsenal or installed game patches.

Native preview regeneration additionally requires the sibling
`BingusStratagemHotkeys/tools` read-only archive helpers, its pinned local
`scratch/game-module.bin` and `scratch/stratagem-settings.bin` captures, the
matching installed game bundles/DLL, Sharp and a Python executable with Pillow.
Run `node tools/native-option-icons.cjs '<Python executable>'`, then the two
option-icons scripts above. Pillow decodes DDS from stdin in a hidden child
process; no game process is accessed and no installed resource is written.
Only committed PNGs/provenance are needed for a normal build or release.

Credited HD2 HUD+ 0.1.2 reader sources and original reuse permission are in
`vendor/` and THIRD_PARTY.txt. Only non-rendering identity support is used at
runtime; the legacy diagnostic provider is not invoked.

Source and test releases:
https://github.com/pwj891129-arch/HD2-AutoReload
Published separately from HD2 Helper.
