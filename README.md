<p align="center">
  <a href="https://wild1walker.github.io/Gen1Wild/"><img src="docs/banner.png" alt="Gen1Wild" width="400"></a>
</p>

<h1 align="center">Gen1ModernBag</h1>

<p align="center">
  <a href="https://wild1walker.github.io/Gen1Wild/"><img src="docs/lineup.png" alt="Check out my other mods!" width="880"></a>
</p>

<p align="center">
  <b>Seven pockets, sorted, searchable, and never full</b>
</p>

Gen1ModernBag divides the Gen1Recomp inventory into seven modern-style pockets,
sorts items automatically, and adds Favorites, persistent pinned items, quick
search, advanced TM/HM tools and unlimited carrying capacity — while leaving
every item effect to the vanilla Bag menu.

## Attribution

Gen1ModernBag is a derivative of the **Modern Bag** mod by **FAFF0x**, taken
from <https://github.com/FAFF0x/gen1recomp> at upstream version **1.6.0**.
Modern Bag is MIT licensed; the original copyright and permission notice is
retained verbatim in [`LICENSE`](LICENSE), with the derivative grant appended
below it.

Essentially all of the functionality described here is upstream's work. The
substantive change in Gen1ModernBag is a corrected machine-label width — one
constant, described under [The change from upstream](#the-change-from-upstream).

This is an independent, parallel project. It is not endorsed by or affiliated
with FAFF0x or the gen1recomp project, and it is not a replacement, successor,
or official continuation of Modern Bag.

## The change from upstream

In upstream 1.6.0, long TM/HM labels in the TM/HM pocket render past the right
edge of the item window. The truncation helper was budgeted for 15 characters,
but the drawable run inside the window is 13 glyphs:

- The item window spans tiles 4–20 of the 160×144 screen; its inner right edge
  lands at roughly x = 152.
- Item names are drawn from x = 48 — eight pixels inside the window, because the
  selection cursor occupies the column at x = 40.
- That leaves 152 − 48 = 104px, and Gen 1 glyphs are 8px wide: 104 / 8 = 13.

Because the helper only truncates when the label is *longer* than the budget, a
15-character label passed through untouched and clipped mid-word. A
17-character label was cut to 15, which put the ellipsis itself off-screen — so
the label looked untruncated and simply lost its tail.

Gen1ModernBag sets the unmarked budget to 13 and the marked budget (which
reserves room for the `P` / `F` / `PF` row markers) to 9, preserving upstream's
4-character offset between the two:

| Label               | Length | Upstream 1.6.0               | Gen1ModernBag    |
|---------------------|--------|------------------------------|------------------|
| `TM01 MEGA PUNCH`   | 15     | untruncated, clips to `PUNC` | `TM01 MEGA PU.`  |
| `TM11 BUBBLEBEAM`   | 15     | untruncated, clips           | `TM11 BUBBLEB.`  |
| `TM34 BIDE`         | 9      | correct                      | `TM34 BIDE`      |
| `TM45 THUNDER WAVE` | 17     | cut to 15, `.` off-screen    | `TM45 THUNDER.`  |

The constants sit at the top of `compactMachineLabel` in
[`gen1_modern_bag/main.lua`](gen1_modern_bag/main.lua); lower them if a display
still clips.

The quantity column is not affected. Counts are drawn right-aligned on a second
line below the name, which is vanilla Gen 1 behaviour; it only appeared to
overlap because overflowing names were colliding with it.

## Installation

1. Download `gen1_modern_bag_v1.0.0.zip` from the releases page.
2. Import the ZIP in the Gen1Recomp **MODS** manager.
3. Enable **Gen1ModernBag**.
4. Fully restart Gen1Recomp.

Replace older versions rather than enabling several at once.

## Migrating from Modern Bag

Gen1ModernBag uses the mod id `gen1_modern_bag`, so its preferences are stored
separately from Modern Bag's. **Saved Favorites, pinned items and sort
preferences do not carry over** — they will need to be set again after
switching. Item stacks themselves live in the save file and are unaffected.

The manifest declares `"conflicts": ["modern_bag"]`. Both mods decorate the same
`src.ui.BagMenu`, so they must not be enabled together; enable one or the other.

## Features

### Pockets

- **FAVORITES** — items marked as favorites from any other pocket.
- **MEDICINE** — healing items, status cures, Revives, PP recovery, vitamins and Rare Candy.
- **BALLS** — every built-in or modded item registered as a Poké Ball.
- **TM HM** — all TMs and HMs.
- **BATTLE** — X items, Dire Hit, Guard Spec and Poké Doll.
- **KEY ITEMS** — non-tossable and key items.
- **OTHER** — stones, Repels, Escape Rope, fossils and everything not covered above.

Press **Left/Right** to change pocket. Up/Down, A and B keep their original
meanings.

### Opening pocket and fast scrolling

Two options are available under **MODS → Gen1ModernBag → Options**:

- **Opening Pocket** — FAVORITES, MEDICINE, BALLS, TM/HM, BATTLE, KEY ITEMS,
  OTHER, or LAST USED. The default is MEDICINE; LAST USED reopens the Bag on the
  pocket used most recently.
- **Hold Scroll Speed** — OFF, NORMAL, FAST (default), or VERY FAST. Holding
  Up/Down repeats list movement instead of requiring one press per item, using
  Gen1Recomp's native ListMenu key-repeat, so remapped inputs keep working.

### Favorites and pinned items

Press **SELECT** on a highlighted item to open **ITEM OPTIONS**:

- **ADD FAVORITE / REMOVE FAVORITE** — adds or removes the item from FAVORITES.
- **PIN TO TOP / UNPIN ITEM** — fixes the item above every unpinned item in its
  normal category.
- **MOVE ITEM** — manual reordering; press SELECT on the destination to finish.
- **CANCEL** — closes ITEM OPTIONS.

Row markers show item status: `F` favorite, `P` pinned, `PF` both.

Favorites and pins persist. If a stack reaches zero the item leaves the Bag but
keeps its saved status, and returns when reacquired. Pinned items sort above
unpinned items and are not moved by alphabetical sorting; multiple pinned items
keep the order in which they were pinned.

### Automatic sorting

Items sort by pocket and display name whenever the Bag opens, and re-sort when a
new item type is added or a stack disappears. TMs and HMs stay in numerical
order with HMs before TMs. Manual SELECT reordering remains available for the
current Bag session; reopening the Bag re-applies automatic sorting without
moving pinned items below unpinned ones.

### Quick search

Press **START** from any pocket except TM/HM.

- D-pad moves across the on-screen keyboard; individual keys can be tapped or
  clicked when Gen1 Modern UI is active.
- **A** enters a character or activates DEL, CLR, GO and EXIT.
- **B** deletes the last character, or closes search when the query is empty.
- **SELECT** clears the query.
- **START**, the Modern UI **SEARCH** button, or **GO** shows all matches.

Search covers every pocket and matches both the displayed name and the internal
item identifier. An empty query lists the whole Bag alphabetically. Results show
the `F`, `P` and `PF` markers, and choosing one returns to the correct pocket
with that item selected.

### TM/HM search and move information

The **TM HM** pocket has its own START menu instead of the general search. It
can search by the name of the move in the machine, filter by elemental type,
filter by **PHYSICAL** / **SPECIAL** / **STATUS** damage class, sort by machine
number, move name, highest power or lowest power, and combine those filters.

Generation I uses a type-based physical/special split: Normal, Fighting, Flying,
Poison, Ground, Rock, Bug and Ghost are PHYSICAL; Fire, Water, Grass, Electric,
Psychic, Ice and Dragon are SPECIAL; moves with no base power are STATUS.

Press **Y** (controller) or **I** (keyboard) on a highlighted TM/HM to open
**MOVE INFORMATION**, showing machine number, move name, type, damage class,
power, accuracy, PP and effect. The same shortcut works inside filtered results,
and pinned machines stay above unpinned ones under every sorting mode.

### Unlimited inventory

The Bag holds an unlimited number of distinct item types, and stacks may exceed
99 units. Counts remain finite values earned, bought or received in normal play.

The mod wraps the vanilla BagMenu rather than reimplementing item effects —
items are still used, consumed, taught, thrown and validated by Gen1Recomp's
original menu. Pockets, Favorites, pins, sorting and search are also available
when the Bag is opened during battle.

## Compatibility

Custom balls and machines are categorized from their registered item fields.
Conventional custom medicines are detected from their effect identifiers, and
unknown items fall back to OTHER.

### Gen1 Modern UI

Gen1 Modern UI is an optional dependency. Gen1ModernBag implements the
`gen1ModernUi` compatibility contract (`apiVersion = 1`). With **Gen1 Modern UI
0.8.2 or newer** enabled, the seven-pocket Bag uses Modern UI's pocket-aware Bag
presenter, and Quick Search and TM/HM move-name search expose a keyboard-grid
state so Modern UI renders large individual keys rather than a list of rows.
Move Information uses the compatibility contract. Modern UI 0.8.2 also provides
a dedicated **SEARCH** / **FILTER** touch button on the Bag.

If Modern UI is absent or disabled, Gen1ModernBag keeps its 160×144
presentation and all inventory behaviour is unchanged.

## Development

Requires Lua 5.4.

    luac5.4 -p gen1_modern_bag/main.lua
    cd gen1_modern_bag && lua5.4 tests/gen1_modern_bag_test.lua
    cd gen1_modern_bag && lua5.4 tests/modern_ui_compat_test.lua

The tests stub the engine modules they need, so no Gen1Recomp checkout is
required. Both suites pass on Lua 5.4 for the 1.0.0 tree; behaviour on-device
has not been verified in this repository.

To build a release archive matching the shape the in-game importer expects
(`gen1_modern_bag/` at the archive root):

    zip -r gen1_modern_bag_v1.0.0.zip gen1_modern_bag -x '*.zip'

Releases are cut by `.github/workflows/release.yml`, from the Actions tab or by
pushing a `v*` tag. It runs the checks above, refuses a version that disagrees
with `manifest.json`, verifies the archive by extracting it and re-running the
tests from the extracted copy, and attaches it to the release.

## License

MIT — see [`LICENSE`](LICENSE). The upstream Modern Bag notice is retained
there and must travel with any copy or substantial portion of this code.
