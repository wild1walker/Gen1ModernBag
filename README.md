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
files items on first open, and adds Favorites, persistent pinned items, quick
search, TM/HM move data and unlimited carrying capacity — while leaving
every item effect to the vanilla Bag menu.

## Attribution

Gen1ModernBag is a derivative of the **Modern Bag** mod by **FAFF0x**, taken
from <https://github.com/FAFF0x/gen1recomp> at upstream version **1.6.0**.
Modern Bag is MIT licensed; the original copyright and permission notice is
retained verbatim in [`LICENSE`](LICENSE), with the derivative grant appended
below it.

Essentially all of the functionality described here is upstream's work. The
changes in Gen1ModernBag are a corrected machine-label width — one constant —
the pocket header, and the presentation of the money line and of the
menus this mod draws over the Bag, all described under
[The changes from upstream](#the-changes-from-upstream).

This is an independent, parallel project. It is not endorsed by or affiliated
with FAFF0x or the gen1recomp project, and it is not a replacement, successor,
or official continuation of Modern Bag.

## The changes from upstream

### Machine-label width

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

### Pocket header

Upstream titles the Bag `MEDICINE 2/7`: the pocket name and its position in the
ring. Gen1ModernBag heads it `MEDICINE` instead — just the name, on the item
window's own top border. Left and Right still change pocket and still wrap
around; nothing on screen spells them out, the same way nothing spells out
START and SELECT. Up to 1.3.1 the header carried a `◀` and a `▶` around the
name.

The header is drawn by the mod rather than set as the list's title, because a
title set on the Bag is never drawn. `BagMenu` builds its `ListMenu` with
`itemBox = true`, and that branch of `ListMenu:draw` paints the LIST_MENU_BOX,
its rows, the quantities and the cursor and then returns; the
`Font.draw(Strings(self.title), 8, 4)` line lives in the plain full-screen
branch below it, which the Bag never reaches. Setting `title` is still worth
doing — Gen1 Modern UI and this mod's compatibility contract read it — but it
does not put anything on screen. Gen1ModernBag 1.1.0 shipped a header that way
and it was invisible; 1.1.1 draws it.

It goes on the item window's own top border, which is where Gen 1 titles a
window: the border line runs up to the label and continues after it.
`LIST_MENU_BOX` is tiles 4,2–19,12, so that border is the row at y = 16 and its
corners are the columns at x = 32 and x = 152. The fourteen columns between
them are the label's. The longest pocket labels (`FAVORITES`, `KEY ITEMS`) are
nine, which leaves rule on both sides; the arrows used to take the outermost
column at each end, and those two names were left with a single column of it.

Drawing onto a border needs the line knocked out from under the label first.
Glyphs are drawn as a mask — `Font.draw` paints them in whatever colour is set,
which is how black text lands on a box's white fill — so a label drawn straight
onto the line would have it running through the letters. The header knocks out
one run, under the name, so the line survives either side of it.

The label is also drawn a pixel lower than the tile it sits on. The frame
carries a one-pixel white margin around the whole window, outside its rule, and
on a top border that margin is the border tile's first pixel row; Gen 1 glyphs
ink rows 0 to 6 of their cell and leave the last blank, so a label drawn at the
tile's own y puts ink on the margin. A pixel down lands it between the margin
and the rule. A bottom border needs no shift — its margin is the tile's last
pixel row, which is the row the glyphs already leave empty, so the money stays
where it is.

Each run is a tile wider than the glyphs it covers, at both ends. Knocking out
exactly the width of the text — which is what `src/ui/Menu.lua` does with its
own title — leaves the rule ending flush against the first glyph and restarting
flush against the last, and that reads as the frame touching the letters. The
label does not move; the clearance is bought in tiles either side of it, and is
clamped so it can never rub out a corner glyph. The same applies to every
window this mod titles, so a popup is sized for its title *plus* that
clearance: a title wider than `tw - 4` tiles has nowhere to put it and would
run into a corner — the same defect at the other end.

Before 1.3.0 the header sat on the empty interior row below the border instead:
the box interior starts at y = 24 and the first item name is drawn at y = 32, so
the row at y = 24 is unused.

The geometry is the `HEADER_*` constants at the top of
[`gen1_modern_bag/main.lua`](gen1_modern_bag/main.lua). Labels wider than the
field are trimmed to fit, with room kept for the clearance at each end.

### Money, and the menus drawn over the Bag

The control hints and the money line had the same problem as the header and
1.1.1 fixed it the same way: `ListMenu:draw` paints a footer only in the branch
the Bag returns before reaching, so `START SEARCH`, `SEL TOOLS` and the money
were set on `list.footer` and never drawn. 1.1.1 put them in the standard
bottom text box, `TEXT_BOX` at tiles 0,12–19,17 — a full-width white bar under
the item window. It read as a second screen rather than as part of the Bag, and
most of what it carried was a legend for two buttons.

1.2.0 dropped the legend and the bar with it, and gave the amount a little
window of its own tucked under the item window's bottom-right corner. 1.3.0
puts it on that window's bottom border instead, right-aligned, the same way the
pocket name sits on the top one — so there is no second frame at all and the
amount lands exactly where the bottom-right of the item window is.
`LIST_MENU_BOX` ends on tile row 12, so that border is the row at y = 96, and
its last column before the corner ends at x = 152. The geometry is the
`MONEY_*` constants in
[`gen1_modern_bag/main.lua`](gen1_modern_bag/main.lua).

The menus this mod opens on top of the Bag had a related problem. `ITEM
OPTIONS` and the sort picker were plain `ListMenu`s, and
`ListMenu`'s full-screen branch fills all 160×144 white, draws the title and
the rows, and paints no frame at all — four options were covering the game with
an undecorated white page.

They are now [`src/ui/Menu.lua`](https://github.com/FAFF0x/gen1recomp), the
engine's own framed menu widget, which is what was wanted all along: it draws
the frame, the title on its top border and the more-arrow on the bottom one,
and it owns the cursor, the scrolling and the input. The mod hands it rows of
`{ label, onSelect }` and a corner to open into, and a row marked `keepOpen`
leaves the menu standing — which is how the sort picker opens without closing
what opened it.

Titles are not handed to Menu. Menu draws its own at the border tile's own `y`
and knocks out exactly its width, which puts ink on the frame's outer white
margin and ends the rule flush against the first and last letter — so they go
through the same `drawBorderLabel` as every other title here instead, a pixel
lower and with a tile of clearance knocked out at each end. Only `draw` is
wrapped, so the frame, the rows, the cursor and the more-arrow all stay Menu's.
A menu whose rows name themselves takes no title at all: **ITEM OPTIONS** is
four such rows.

Menu still grows `tw` to the widest label + 3 while never accounting for the
title, so the width is asked for explicitly — the title plus its two clearance
tiles has to fit between the corners, which is `tw - 4` — and labels are
trimmed to it, since a long row label would otherwise grow a menu off the
screen.

The search keyboard was the worst of them. It had no frame either; its three
header lines sat on a 12px pitch the 8px font does not land on; and its last
row — `DEL`, `CLR`, `GO` and `EXIT`, which are words rather than single glyphs
— was laid out on the same 16px pitch as the letters, so the four keys were
drawn on top of one another and read as `DECLBOEXIT`. It is now one framed
window with everything on the 8px grid: the letters keep a cell each with the
cursor in the column to their left, and the action row is measured and centred
so no two words can share a column whatever the font.

`MOVE INFORMATION` had the same two problems — no frame, and eleven lines on a
14px pitch, so every row but one fell between the rows the rest of the game
draws on. It takes the same screen-filling window, with the sixteen interior
rows spent on the title, the machine and its move, the five stats, the effect
over three wrapped lines, and the way out, each block separated by a blank row.
It also used to escape through an early return when a machine had no move data,
before the line that puts the draw colour back, leaving black set for whatever
drew next; that path now takes the same window as every other.

## Installation

1. Download `gen1_modern_bag_v1.7.0.zip` from the releases page.
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

Each pocket is headed by its own name on the top border of the item window —
`BALLS` — the way Gen 1 titles a window. Pockets wrap around in both
directions.

Press **Left/Right** to change pocket. Up/Down, A and B keep their original
meanings.

Your money sits on the item window's bottom border, right-aligned under its
bottom-right corner. Nothing else is drawn below the list: **SELECT** opens the open pocket's search
and **START** opens the item tools, and neither is spelled out on screen.

### Opening pocket and fast scrolling

Two options are available under **MODS → Gen1ModernBag → Options**:

- **Opening Pocket** — FAVORITES, MEDICINE, BALLS, TM/HM, BATTLE, KEY ITEMS,
  OTHER, or LAST USED. The default is MEDICINE; LAST USED reopens the Bag on the
  pocket used most recently.
- **Hold Scroll Speed** — OFF, NORMAL, FAST (default), or VERY FAST. Holding
  Up/Down repeats list movement instead of requiring one press per item, using
  Gen1Recomp's native ListMenu key-repeat, so remapped inputs keep working.

### Favorites and pinned items

Press **START** on a highlighted item to open the item tools:

- **SORT** — re-sorts the open pocket once and then leaves it alone, so MOVE
  ITEM adjusts what it produced. It rewrites only the slots that pocket already
  occupies, so the others keep their own order. `A-Z`, `Z-A` and `MOST FIRST`
  are offered on every pocket; `TM/HM NUMBER`, `POWER HIGH` and `POWER LOW`
  only on a pocket that holds a machine. `A-Z` sorts a machine by its move
  rather than by `TM24`.
- **ADD FAVORITE / REMOVE FAVORITE** — adds or removes the item from FAVORITES.
- **PIN TO TOP / UNPIN ITEM** — fixes the item above every unpinned item in its
  normal category.
- **MOVE ITEM** — picks the item up and carries it. **Up/Down** walk it through
  the pocket a row at a time, with the list reordering under it as it goes and
  the cursor drawn hollow to show you are holding it. **A** places it, **B**
  puts it back where you picked it up, and changing pocket drops it. Up to
  1.5.0 this was a two-ended swap confirmed with START, which showed nothing
  moving and left the cursor solid throughout.
- **CANCEL** — closes the menu.

Row markers show item status: `F` favorite, `P` pinned, `PF` both.

Favorites and pins persist. If a stack reaches zero the item leaves the Bag but
keeps its saved status, and returns when reacquired. Pinned items sort above
unpinned items and are not moved by alphabetical sorting; multiple pinned items
keep the order in which they were pinned.

### The Bag's order is yours

The Bag is filed once, the first time this version opens it: by pocket and
display name, TMs and HMs in numerical order with HMs before TMs. After that
the order is whatever you make of it. **SORT** re-sorts a pocket on demand and
**MOVE ITEM** rearranges it by hand, and both last — opening the Bag only drops
what you no longer carry.

Up to 1.8.0 the whole order was re-sorted alphabetically on every open, which
undid every manual move and every one-shot SORT the moment the Bag was closed,
so no ordering you chose ever survived. Something newly acquired is appended,
which puts it at the bottom of its own pocket rather than at the end of the
Bag; `A-Z` tidies the pocket up again whenever you want it.

Pinned items float to the top of their pocket when the rows are drawn, so
pinning does not disturb the order underneath.

### Quick search

Press **SELECT** from any pocket, TM/HM included — it is the same search
everywhere.

- D-pad moves across the on-screen keyboard; individual keys can be tapped or
  clicked when Gen1 Modern UI is active.
- **A** enters a character or activates DEL, CLR, GO and EXIT.
- **B** deletes the last character, or closes search when the query is empty.
- **SELECT** clears the query.
- **START**, the Modern UI **SEARCH** button, or **GO** shows all matches.
Ordering the results is the item tools' **SORT**, pressed on the results page
itself. That page has no order of its own to rewrite — it is rebuilt from the
query every time — so SORT there sets the saved preference the rebuild reads,
rather than re-sorting in place the way it does on a real pocket. Up to 1.7.0
this was a key on the keyboard.

Search covers every pocket and matches both the displayed name and the internal
item identifier. An empty query lists the whole Bag alphabetically. The
keyboard shows the query and nothing else: it carried a live
match count up to 1.3.1, which was the results page's job done twice over, and
the only reason the search re-ran on every keystroke.

A machine is found by its code, its move, and that move's elemental type and
damage class — so `SURF`, `HM03`, `WATER`, `SPECIAL` and `STATUS` are all
things you type. Machine results are listed by their move rather than as a bare
`TM35`. Up to 1.4.1 those were pickers in a TM/HM filter hub that SELECT opened
instead of the keyboard when you happened to be on the TM/HM pocket; folding
them into the query retired the hub, its two pickers and its own move-name
keyboard.

**SORT** stays a choice rather than a term, because it is an ordering — but it
lives in the item tools, not on the keyboard. `NAME` orders everything by
displayed name, and a machine by its move rather than by `TM24`; `NUMBER`,
`POWER HIGH` and `POWER LOW` group the machines first in that order and leave
everything else after them by name, a POTION having no machine number and no
base power.

The matches do not open a page of their own. They are handed back to the Bag,
which grows a **RESULTS** pocket for them and puts you on it — so they are read
in the item window with the pocket header, the counts and the `F` / `P` / `PF`
markers, like every other pocket, and every Bag control works on them. Before
1.3.0 they were listed on a separate full-screen `ListMenu` with no frame.

RESULTS only exists while a search is loaded into it. Left and Right step over
it before the first search of a Bag session, it is rebuilt from the search
rather than held as a snapshot — so its counts follow the Bag as items are used
up — it is never what **LAST USED** reopens the Bag on, and it is gone the next
time the Bag opens. It is not a pocket an item can be filed in, and
`exports.pockets()` does not list it.

### TM/HM move information

Generation I uses a type-based physical/special split: Normal, Fighting, Flying,
Poison, Ground, Rock, Bug and Ghost are PHYSICAL; Fire, Water, Grass, Electric,
Psychic, Ice and Dragon are SPECIAL; moves with no base power are STATUS. Each
machine is findable by whichever of those its move is.

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
presenter, and Quick Search exposes a keyboard-grid
state so Modern UI renders large individual keys rather than a list of rows.
Move Information uses the compatibility contract. Modern UI 0.8.2 also provides
a dedicated **SEARCH** touch button on the Bag.

If Modern UI is absent or disabled, Gen1ModernBag keeps its 160×144
presentation and all inventory behaviour is unchanged.

## Development

Requires Lua 5.4.

    luac5.4 -p gen1_modern_bag/main.lua
    cd gen1_modern_bag && lua5.4 tests/gen1_modern_bag_test.lua
    cd gen1_modern_bag && lua5.4 tests/modern_ui_compat_test.lua

The tests stub the engine modules they need, so no Gen1Recomp checkout is
required. Both suites pass on Lua 5.4 for the 1.7.0 tree; behaviour on-device
has not been verified in this repository.

To build a release archive matching the shape the in-game importer expects
(`gen1_modern_bag/` at the archive root):

    zip -r gen1_modern_bag_v1.7.0.zip gen1_modern_bag -x '*.zip'

Releases are cut by `.github/workflows/release.yml`, from the Actions tab or by
pushing a `v*` tag. It runs the checks above, refuses a version that disagrees
with `manifest.json`, verifies the archive by extracting it and re-running the
tests from the extracted copy, and attaches it to the release.

## License

MIT — see [`LICENSE`](LICENSE). The upstream Modern Bag notice is retained
there and must travel with any copy or substantial portion of this code.
