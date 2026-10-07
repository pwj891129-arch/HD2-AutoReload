# HD2 Helper Auto Reload + Stratagems 0.3.61-test

## Dependencies

| Component | Required? | Purpose |
| --- | --- | --- |
| Bingus Shared Loader (API 1) | Yes | Loads the helper addon. Use v19 for the separate HD2H tab; v18 supports the legacy integration. |
| CowboyBingus Mod Options Menu 1.2 (API 1, version 3) | For in-game settings only | Provides editable settings and saved values. Without it, reload, charge release, the wheel and hotkeys use deployed defaults. |
| HD2 HUD+ / Mod Bindings Menu | No | Neither is needed to run the helper. |

**필수:** Bingus Shared Loader. **설정 변경에 필요:** Mod Options Menu 1.2.
옵션 메뉴가 없어도 자동재장전·자동발사·휠·단축키는 배포 기본값으로 작동한다.
독립 상단 **HD2H** 탭을 사용하려면 Loader v19와 옵션 메뉴가 모두 필요하다.
로더와 옵션 메뉴는 헬퍼 ZIP에 포함하지 않으므로 필요에 따라 별도로 설치한다.
옵션 메뉴: [CowboyBingus ModOptionsMenu](https://github.com/CowboyBingus/ModOptionsMenu).

## Weapon Runtime Recovery

0.3.61 removes the permanent runtime-error latch for automatic reload and charge
release. A Lua callback error releases owned inputs and retries with a bounded
1-5 second backoff. Failed key release or reset keeps input suspended. Recovery
invalidates stale identity, charge and firing history without changing user
options, pause/chat state, binary compatibility guards or drone ownership.

After recovery, weapon state continues to be sampled without sending inputs.
Actions resume on a **fresh fire-button press**, not its release. An already-held
button does not replay an old shot. The resumed press is retained for empty-weapon
checks; continued holding is available to Railgun/Epoch charge release. Normal
reload-on-release and the one-second post-release checks are unchanged.

Runtime errors, recovery and pause/chat/menu/focus/option gates are event-logged.
Reload log entries use append-and-close so they do not depend on a flush method.
Wheel/shortcut behavior, defaults, the 50ms weapon poll and hidden Arsenal options
are unchanged. This is a prerelease test package, not a stable release. Building
the package does not install it or publish it automatically.

2026-10-08 read-only inspection found reload/charge options ON, matching supported
game binary hashes, and a valid held-weapon sample (magazine 14, reserve 5).
Existing helper logs were empty, so the precise original runtime failure or
blocking gate could not be established. The permanent-error path is a confirmed
code defect, not yet a proven diagnosis of that session. Offline tests cover
cooldown, repeated errors, failed reset/release, clock resets and fresh-press
rearming. Actual in-game recovery still needs testing after application.

Release checks passed for the isolated LuaJIT suite, the 46-option / 14-language
schema, unified package scenarios, the installed Arsenal collector and HD2SDK
archive/font validation. The optional installed-menu-source fixture was skipped
because the expected API 1 version 3 fixture was unavailable. Mock-provider
regressions passed; this does not replace live HD2H menu validation.

오류 후 자동재장전·충전 자동발사가 영구 중단되지 않도록 수정했다.
입력을 정리하고 무기 상태를 재검사한 뒤, **사격 버튼을 새로 누르는 순간** 재개한다.
버튼을 놓는 동작으로 재개하지 않으며, 기존에 계속 누르고 있던 입력도 재사용하지 않는다.
복구 대기 중 무기 판독은 유지하고, 재개 후에는 레일건의 계속 누르는 충전도 감지한다.
기존 사격 종료 시 재장전 규칙, 설정값 및 드론 입력 협력은 유지한다.
이번 세션의 정확한 중단 원인은 로그가 비어 있어 아직 확정하지 못했다.
게임 종료 후 시험 ZIP을 교체·적용하고, 재실행해서 작동 및 새 로그를 확인해야 한다.

## Helper Runtime Overhead

0.3.60 reduces redundant work without changing feature defaults, weapon checks,
the 50ms reload poll, command timing or per-frame cursor selection. In-game
options still poll every 250ms so public API `set` calls without change callbacks
remain visible. Language changes, saved settings and multiplayer identity checks
are retained.

- Weapon reads reuse one 256-byte FFI buffer; wheel reads reuse a bounded buffer
  that grows for binding tables. Every read still calls ReadProcessMemory, resets
  its byte count, refuses failures/short reads, and returns an independent string.
- HD2H uses one fresh pre-update and one fresh post-update menu observation,
  sharing the latter with tab-count restoration. No native pointer observation
  survives a frame. Peer callback results, including nils and errors, are
  forwarded without allocating a return-value table every update.
- Icon resource lookups share common material/atlas results within one draw
  only. The next draw rechecks availability, including failed resources. Each
  icon retains its own UV region, colors and GUI-local material instance.
- An already closed wheel no longer enumerates game worlds or allocates empty
  cleanup tables. Live shapes and owned font/icon surfaces still receive normal
  cleanup and stale-world protection.
- Key edge tracking reuses its small state tables; unchanged reload status no
  longer formats an unused detail message. Input edges are not throttled.

Offline counters against the unmodified 0.3.59 working sources:

| Fixture | Before | After |
| --- | ---: | ---: |
| 2,000 weapon reads: additional FFI buffer allocations | 2,000 | 0 |
| 2,000 alternating small/binding-table reads: additional buffer allocations | 2,000 | 1 |
| 240 closed/helper-tab frames: menu queries, including provider work | 960 | 720 |
| 240 wheel frames, 8 icons sharing an atlas: image resource queries | 3,840 | 480 |
| 240 repeat-close calls: world enumerations | 480 | 0 |
| Same 240 hover frames: created shapes | 35,040 | 35,040 |

Buffer counts exclude initialization; the wheel count includes its one growth.
These are deterministic owned-memory/API fixtures, not measured game FPS or
render-time benchmarks. Actual improvement requires testing this version in
game. Existing deployed patches and the running game are not changed by a build.
`test.ps1` includes allocation, failed/short read, immutable result, resource
loss/recovery and tab/coexistence regressions. `test.ps1 -Performance` also writes
`dist/performance-comparison.json`; it requires the preserved baseline sources
under `dist/performance-before`, captured before these edits.

## Live Language Refresh

0.3.59 fixes returning from another language to Korean leaving stale option
texts. The log showed correct game-language detection, but Mod Options Menu
refreshed its text cache before the helper's poll on menu opening. The checked
provider translation model now refreshes after that poll, once per locale
change. Option IDs, values, registrations and subscriptions are unchanged.

All 46 option labels, descriptions, category names and custom choice labels
now cover the game's 14 supported text languages: English, Korean, Japanese,
French, German, Italian, Spanish (Spain / Latin America), Portuguese
(Portugal / Brazil), Polish, Russian and Chinese (Simplified / Traditional).
The list is based on the official Steam app details for app 553850, checked
2026-10-07. Game record aliases such as jp, mx, br, cn and tw select the right
locale. Unsupported or unreadable codes still fall back to English.

One ZIP contains every option translation; Arsenal options remain hidden.
The wheel's existing Korean/English name renderer is unchanged. Full native
in-game font/layout verification is still needed in each language. Offline
tests use the installed menu provider to cycle all locales back to Korean and
verify every label, description, custom choice and saved value. In-game size
and Railgun threshold descriptions now refer to APPLY, not Arsenal redeploy.

## HD2H Frame Callback Repair

The 0.3.57 runtime connected to the options provider, but never logged tab
placement. A regression that caches the engine update callback reproduces the
same failure: replacing the global callback during a frame leaves the cached
callback unchanged. 0.3.58 registers with Bingus Shared Loader v19's
`after_startup` hook and wraps the final mod update chain before the game can
cache it. Provider initialization and connection can still finish later.

The regression now passes with the actual installed Mod Options Menu source,
large HUD-style callback caches, delayed initialization and a fixed engine
callback. Tests also cover preserved BTO/HUD+ titles, escape-menu reopening,
helper-only category routing and saved values. Startup, first frame and screen
state are logged for live verification. Game rendering still needs testing
after installing this ZIP. Independent top-level tabs require Loader v19;
older loaders retain the legacy update integration.

## HD2H Tab Discovery Repair

0.3.57-test fixes the separate top-level tab connection failing in a large
HUD/mod update chain. The 0.3.56 live log reported `provider layout unavailable`
and retained the helper categories in MODS. An owned-memory fixture using the
installed Mod Options Menu reproduced the failure with HUD-style wrappers and
large unrelated callback caches.

Discovery now follows callback functions before cache tables, anchors to the
exact state exposed by Mod Options Menu, then inspects only that provider's
view graph. Temporary discovery failures retry after 120 eligible updates,
even when the outer callback has not changed. Unsupported private layouts and
full tab bars still retain MODS rather than guessing native pointers.

The tab title is `HD2H`. Its General, Common and Mission categories retain all
46 saved setting IDs, APPLY and automatic English/Korean texts. Existing MODS,
BTO and HUD+ titles remain intact. Arsenal options remain hidden; the unified
ZIP still deploys all 48 resources without selecting options.

Offline regressions verify noisy HUD chains, bounded retry, native tab placement,
peer titles/counts, unsupported stripped ABI refusal and saved values in owned
memory. Actual in-game top-level rendering remains unverified until installation.

## HD2H And Automatic Language

0.3.56-test fixes missing deployment in 0.3.55 and names the top-level tab `HD2H`.
The installed Arsenal 0.36.2 ignored top-level manifest Include and deployed
zero files for the optionless 0.3.55 package. The helper, its 46 default setting
resources and Korean glyph texture now ship together in the root patch_0.
The installed Arsenal collector confirms all 48 resources, with no duplicates
or option selections. HD2SDK serializers validate the merged payloads and DDS.

One ZIP reads the game's Text Language through the existing build-verified,
read-only channel. Korean selects Korean; English, unsupported languages and
unreadable settings select English. Changes refresh at 250ms intervals. Menu
labels, categories, descriptions, choices and wheel names follow this setting,
not the Windows or Steam UI language. Function-backed Mod Options Menu texts
preserve stable IDs, callbacks and saved values without re-registration.

The helper's three categories occupy a separate top-level `HD2H`
tab beside MODS, BTO and HUD+. All 46 stable setting IDs, APPLY, descriptions and
saved values remain owned by Mod Options Menu. Only helper categories leave MODS;
other mods remain there. The title is always `HD2H`, with no space.

게임을 종료하고 `HD2-AutoReload-0.3.61-test.zip`으로 이전 헬퍼를 교체한 뒤 Purge / Deploy한다.
ESC 상단의 `HD2H` 탭에서 일반·공용·임무 설정을 조절하고 APPLY로 적용한다.
언어별 ZIP은 분리하지 않는다. 옵션 메뉴는 게임 텍스트 언어에 맞춰 14개 언어로 표시한다.
미지원 언어나 판독 실패는 영어로 표시한다. 휠 이름은 기존 한국어·영어 표시를 유지한다.
기존 인게임 저장값은 그대로 유지된다. Arsenal에는 옵션 선택창이 표시되지 않는다.

Arsenal deploys the default settings automatically: reload, vehicle reload,
charge release, wheel, hotkeys and individual visibility toggles ON; 95% Railgun,
100% wheel, 15ms input and Individual bulk controls. Saved in-game values take
priority. The full Arsenal definitions, variants and icons are preserved in
source and `arsenal-options.hidden.json`, which Arsenal does not use as its entry
manifest. They are not deleted and can be restored for a later release. An
editor-enabled build must replace the merged default deployment too, rather
than enabling conflicting variants alongside it.

Requires Mod Options Menu v1.2 (API 1 version 3) for editable settings. Its public
API has no custom tab registration, so a bounded, version-checked view adapter
reuses the installed provider's verified native widgets. No provider source or
new native executable is bundled. Unknown provider layouts or a full eight-slot
tab bar retain the public MODS categories; missing providers retain deployed
defaults. Existing peer tabs are hidden only within their update scope and all
tab counts and titles are restored before native input/rendering continues.

Offline checks include the installed provider's actual closure layout and all
46 registrations, MODS/BTO/HUD+ coexistence, menu reopening, errors, nil return
values, covered menus, game-language refresh and hidden-editor root deployment. Native
game rendering, mouse/controller input and APPLY/restart persistence still need
an in-game test. Installed game archives were not changed.

## Live Settings (0.3.54 Foundation)

0.3.54-test exposes all 46 Arsenal settings in CowboyBingus Mod Options Menu
v1.2 (API 1, version 3). The optional menu is installed separately, together
with Bingus Shared Loader v18 / API 1. Without the menu, or with an older API,
the helper continues using deployed defaults. 0.3.55 adds the separate view adapter above.

게임을 종료하고 기존 헬퍼를 이 버전의 한국어 또는 영어 ZIP 하나로 교체한다.
Bingus Mod Options Menu 1.2도 설치·활성화한 뒤 Purge / Deploy하고 재시작한다.
ESC의 HD2H 탭에서 `HD2 헬퍼`, `HD2 헬퍼: 공용`, `HD2 헬퍼: 임무`를 선택한다.
값을 변경하고 APPLY를 누르면 재시작 없이 다음 업데이트에서 반영한다.
Arsenal은 초기값이며 인게임에서 저장한 값이 우선한다. 이 배포는 설치된 메뉴나 게임 파일을 수정하지 않았다.

The three stable categories respect the native menu's 32-row limit:
- HD2 Helper: 9 rows for personal/vehicle reload, automatic charge release,
  Railgun 90%/95%, radial/hotkeys, 100/125/150/200/300%, 15/30ms and the combined bulk control.
- HD2 Helper: Common: 5 rows for the shared bulk control, other calls and Reinforce/SOS/Resupply.
- HD2 Helper: Mission: 32 rows for the mission bulk control and all 31 individual calls.

The unified package keeps stable setting IDs and values. Settings labels
use the game language as native UTF-8 text, not raster text images. The menu
owns persistence in `%LOCALAPPDATA%/CowboyBingus/Helldivers2/Logs/ModOptionsMenu.values`;
the helper does not read or overwrite that file. Existing saved MODS values
override the deployed Arsenal baseline. Changing Arsenal does not overwrite them.
Bulk choices retain their priority and never erase individual toggles. A checked
mission option still requires the real call and its current permitted objective area.

APPLY is handled through public register/get/on_change APIs. Pending, unapplied
menu edits do not change the helper. Changes are batched before consumers update;
API set changes without callbacks are observed at 250ms intervals. Size, interval
or visibility changes cancel existing wheel selection/commands, release capture
and wait for a fresh list-key activation. Reload/charge changes reset transient
fire checks, release any owned reload pulse and wait for physical fire release.
Changing a checkbox from OFF to ON works without restarting its native reader.
Unknown/invalid menu values retain the applied setting; registration failures
keep the Arsenal baseline and retry. No Mod Options Menu source is bundled.

Drone Remote Control 0.2.1 input API 1 remains supported: changes do not steal
drone-owned focus or resume weapon automation while it is controlling or restoring.
Logs: `hd2_helper_mod_options.log`, the existing reload log and stratagem log.
Offline tests cover late menu loading, saved values, all categories, toggles,
choices, bulk priority, safe reconfiguration, callback/get failures and both
helper/drone load orders. Actual native menu rendering and gameplay after APPLY
still need validation with the updated menu installed.

The optional drone integration tests use the private sibling
`../DroneRemoteControl/src` fixture and are skipped when it is absent. No drone
source is bundled or published with this helper.

API reference: https://github.com/CowboyBingus/ModOptionsMenu#for-mod-authors

## 0.3.53 Changes

0.3.53-test adds input API 1 for Drone Remote Control 0.2.1. Keep both mods enabled.
Before drone control captures player input, the wheel cancels pending selections
and commands, restores its cursor and releases its owned keys. Reload/charge
automation releases its pending reload pulse and resets transient firing state.
During drone control and unfinished drone restoration these features are suspended
without changing saved Arsenal options. Resume requires released inputs; Toggle
wheel users must close the existing native list before reopening. Stale clicks,
number shortcuts and charge-release/reload requests are not replayed.

Replace the previous combined mod with one 0.3.53-test language package in Arsenal,
alongside one Drone 0.2.1 package, with the game closed. Older combined versions
lack the handshake and are refused by Drone 0.2.1. Offline coexistence tests do
not establish actual drone control, camera or multiplayer stability.

## 0.3.52 Changes

0.3.52-test replaces the permanent wheel-error latch with recoverable cleanup.
After a caught Lua error, pending selections and partial commands are cancelled,
owned inputs are released and the failed overlay is disposed. Recovery retries
after 0.5 seconds, backing off to 1, 2 and at most 4 seconds if cleanup still fails.
A clean wheel instance is created only after owned input and cursor release
complete. Successful GUI deletions are recorded immediately, so partial cleanup
can retry without double-destroying shapes or losing child GUI ownership.

Recovery does not replay the failed selection or automatically enter a command.
With Hold, release the list key and press it again. With Toggle, close the game's
existing stratagem list and open it again. An already held number shortcut is not
replayed. The original update callback continues during cooldown, and recovery
wait/success events are written to the stratagem log without per-frame error spam.
Actual game crashes or native access violations are not caught by Lua recovery.

Hold/Toggle, keyboard/XBUTTON1/XBUTTON2, persistent cleanup/factory errors,
partial command cancellation, failed key release, deferred cursor restoration
and partial shape/font GUI disposal have mock regression coverage. Live visual
and multiplayer recovery after installing this package still need validation.
Auto reload, charge thresholds, wheel visibility options and language defaults
are unchanged. Install one 0.3.52-test language ZIP using Arsenal with the game
closed. No installed patches or running game state are changed during development.

## 0.3.51 Changes

0.3.51-test fixes missing Super Earth Flag and other location-restricted mission
calls. The native objective hash table has 0x1b2 (434) buckets, not 438. The old
divisor prevented objective definitions from resolving and hid eligible calls.
The corrected divisor, probe wrap and record bounds now match the native table.

Mission calls retain their individual visibility options. Calls with a location
restriction appear only in the permitted current objective area and disappear
outside it or after its call stage finishes. Existing 50ms wheel refresh and
selection revalidation remain in place. Equipped slots, common calls and automatic
reload are unchanged.

Railgun automatic release now offers 90% or 95% (default) of its native danger
gauge in Arsenal; Epoch remains at 100% of its full firing charge. The existing
default-on checkbox and resource ID are retained, with English/Korean option
labels updated. The new threshold choice is appended without shifting existing
options. The higher threshold leaves less margin for sampling and input latency.

Lua regressions include the live flag objective hash, last-bucket collisions,
record bounds and flag entry/exit/completion. Native instruction checks pin the
434-bucket division and wrap. A bounded read-only live probe resolved all three
objective definitions that the old reader rejected. Installing the new package
and visually testing the wheel at a flag area remain necessary. Charge regressions
verify release at the selected 90% or 95% threshold, no premature release,
one-shot latching, invalid-option blocking, and unchanged Epoch full-charge
behavior. The new Railgun threshold still needs gameplay validation.

Install one of the English/Korean 0.3.51-test ZIPs using Arsenal with the game
closed. No installed patches or running game state are modified by development.

## Mission Location Detection

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

## Unified Language Package

The current test release has one asset: `HD2-AutoReload-0.3.61-test.zip`.

Both menu translations and wheel names are bundled. The game Text Language
setting selects Korean or English at runtime; other languages fall back to
English. The package GUID and all saved option IDs remain unchanged.

Replace the previous helper, then Purge / Deploy and restart with the game
closed. Arsenal has no settings editor for this package. Its English package
description is static; settings are edited in the game's HD2H tab.

The locale reader performs five guarded reads at most once per 250ms. No
game settings, Windows language or Steam configuration are modified. Runtime
logs remain English and record `LANGUAGE game=<code> helper=<en|ko>`.

게임의 텍스트 언어 설정으로 메뉴와 휠 이름이 전환된다. 별도의 언어 ZIP이나
OS 언어 감지 파일은 필요하지 않으며 기존 인게임 저장 설정도 유지된다.

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

Automatic reload, Railgun / Epoch charge release, radial and number
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

## Preserved Setting Definitions

Since 0.3.55-test Arsenal deploys initial feature settings without showing an
editor. Use HD2H with Mod Options Menu v1.2 to override them live. Mod Bindings
Menu is not required. Without a compatible provider, deployed defaults stay active.
The preserved legacy editor definitions below also describe the live controls.

- `Automatic Reload` / `자동재장전`: checked is ON; unchecked is OFF.
  Covers both magazine exhaustion and complete overheat.
- `Vehicle Automatic Reload` / `차량 자동 재장전`: independent checkbox.
  Experimental reloadable FRV/tank primary mounts; unchecked disables only vehicles.
- `Railgun / Epoch Automatic Release` / `레일건·에포크 자동발사`: checked is ON; unchecked is OFF.
  Independent of automatic reload.
- `Railgun Release Threshold` / `레일건 자동발사 기준`: 95% (default) or 90%.
  Appended after existing options. Does not enable an unchecked release feature or change Epoch's 100% threshold.
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

Size, interval, Railgun threshold and bulk choices are mutually exclusive. Boolean settings have
only a direct checkbox. Bulk controls do not erase saved
individual settings; restore Individual Settings to use them again. Review choices after
importing. Close the game, replace the previous package, Purge / Deploy, and
restart after replacing the package. In-game HD2H changes need APPLY, not
redeployment or a restart.
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

Railgun releases at or above the selected 90% or 95% (default) of the entire gauge
from zero to its explosion limit. Missing threshold resources default to 95%; an
invalid explicit threshold blocks Railgun release but does not disable Epoch.
Epoch releases at or above 100% of its Full firing charge, without
requiring an explosion flag; its Over charge time bounds valid readings.
Both send one Windows `MOUSEEVENTF_LEFTUP`. No mouse press, repeated firing or aiming is sent.
Release the physical button and click again for the next shot. Railgun safe
mode, which caps below that threshold, stays manual.

Fire must be bound to left mouse. Chat, menus, no control, reload, weapon draw,
stratagem input and unreadable charge data block release. Reserve is not required
to fire the last loaded shot. The post-release reload check remains available
when automatic reload is on.

50 ms reads and frame/input latency may release above the selected threshold;
explosion prevention is not guaranteed. The 95% threshold has less safety margin
than 90% and still needs gameplay validation.
Native layout research references
[FileDiver's charge component](https://github.com/xypwn/filediver/blob/master/datalibrary/weapon_charge_component.go)
and its [resource hash names](https://github.com/xypwn/filediver/blob/master/hashes/hashes.txt).

## Compatibility And Installation

1. Close the game before deploying.
2. Import the unified HD2-AutoReload-0.3.61-test.zip into Arsenal and replace the previous version.
3. Enable this addon and Bingus Shared Loader v19 / API 1 (v18 retains legacy integration).
4. For editable settings and the separate HD2H tab, also enable Mod Options Menu 1.2. Without it, deployed defaults remain active. Purge / Deploy and restart. Settings require APPLY; Arsenal options are hidden.
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
START reports enabled/charge90, railgun_threshold and bindings. NATIVE_SOURCE, RELOAD,
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
node menu-schema.test.cjs
node package.test.cjs
node tools/arsenal-collector.test.cjs # Optional installed-Arsenal fixture.
node tools/mission-location-layout.test.cjs
./test.ps1 -LuaDll '<Helldivers 2 folder>/bin/lua51.dll'
./tools/Read-MissionLocation.ps1 # Optional live read-only location diagnostic.
node tools/reload-layout.test.cjs
node tools/vehicle-layout.test.cjs
node tools/stratagem-names.cjs --check
Compress-Archive -Path './dist/HD2-AutoReload-0.3.61-test/*' -DestinationPath './dist/HD2-AutoReload-0.3.61-test.zip'
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
