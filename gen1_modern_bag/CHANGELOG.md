# Changelog

## 1.10.0

- **Every item has a picture, in the column left of its name.** A POTION looks
  like a potion, the five stones are five different colours, and a machine is
  a disc in the colour of the type of the move it teaches -- which is the
  whole of what tells TM24 from TM25 in a pocket of fifty-five four-letter
  rows. The art is Pokemon Polished Crystal's; see `CREDITS.md`, which is the
  part of this release that matters most. The SURFBOARD is the one
  placeholder -- nothing anywhere has ever drawn Gen 1's, so it is drawn here
  in the set's own idiom.
- **The item window is one tile wider to hold them.** An icon is sixteen
  pixels, which is two tile columns, and the engine's window has one to spare:
  a picture in that one column would have cost every twelve-glyph name its
  last letter, and SUPER POTION, HYPER POTION, FULL RESTORE, THUNDERSTONE,
  HELIX FOSSIL, BIKE VOUCHER and OAK's PARCEL are most of a starting Bag. So
  the window grows at the left instead -- tiles 3,2-19,12 rather than
  4,2-19,12 -- and the cursor moves with it. It is still the same pop-up over
  the overworld, two tiles in from the screen edge rather than four, and the
  name column, the quantity column, the more-arrow, the pocket name and the
  money are all exactly where they were. Nothing is truncated that was not
  truncated before.
- **`ITEM ICONS`, a new setting, ships on.** Off is the window 1.9.4 drew, to
  the pixel: the engine draws it, this mod draws nothing, and the setting
  takes effect on the next frame rather than the next boot.
- A machine's label is now budgeted from the window it is going into --
  thirteen glyphs in the plain one, twelve with the icons -- rather than from
  a pair of constants that only knew about the plain one. Same numbers as
  1.9.4 wherever the icons are off.
- An item may name its own icon. `data.items[id].icon`, if it is a string, is
  a path and it wins, so a sprite pack or a mod that adds an item can hand its
  own art to the Bag without this mod being told. `mod.exports.itemIcon` and
  `mod.exports.drawItemIcon` publish the set the other way, for a sibling with
  somewhere to put one.
- **Fixed: the money was printed twice.** Gen1Recomp's item-box path opens the
  standard full-width text box under the window for any list carrying a
  footer, and this mod parked the amount there while also drawing it on the
  window's bottom border -- so the Bag grew back the box 1.2.0 removed, with
  the same number in it. The footer is left empty now and the amount is read
  off the save.

---

## 1.9.4

- **Hold Scroll Speed defaults to `OFF`.** 1.9.3 moved it from `FAST` to
  `NORMAL`, which halved the rate but kept the thing that made it feel wrong:
  a threshold. Any hold-to-scroll setting has one, and a press either crosses
  it or does not — so the same press is one row or a run of them depending on
  how long a finger rests, which reads as the list moving by itself rather
  than as a speed being too high. `OFF` means a press is a row.
- `NORMAL`, `FAST` and `VERY FAST` are all still there. None of them is what
  an unconfigured Bag does now.
- A saved choice is still untouched.

---

## 1.9.3

- **Hold Scroll Speed defaults to NORMAL rather than FAST.** FAST starts
  repeating after 10 frames held and then moves a row every 2 -- thirty rows a
  second, off a press about a sixth of a second long. A press meant as one
  step lands a pocketful further down, and because the threshold is what
  decides it, the same press does one thing or the other depending on how long
  a finger rests: it reads as the Bag scrolling by itself. NORMAL is
  Gen1Recomp's own ListMenu cadence -- 16 frames, then one row every 4 -- and
  FAST is still one row down the option for anyone who wants it.
- Only a default, so it moves for players who never chose a speed. A saved
  choice is still theirs and is not touched.

---

## 1.9.2

- Declares `games: ["gen1"]` in the manifest. The mod replaces `src.ui.BagMenu`
  and drives `src.inventory.Bag`, which are the Gen 1 modules -- Gen 2 has its
  own under `src/ui/gen2` that this never touches -- so Red, Blue and Yellow is
  what it is. Nothing about the Bag itself changes.

---

## 1.9.1

- Corrects the 1.9.0 release notes, which described an earlier design of this
  change -- `Z-A` and `MOST FIRST` orders, and a Bag filed once on open -- none
  of which shipped. The 1.9.0 section of this changelog is what 1.9.0 actually
  does. The mod itself is unchanged from 1.9.0: this version carries the
  corrected notes, the README and a version bump, and no code.

---

## 1.9.0

- **Every tab has its own order, and stays in it.** Choosing one is a setting
  for that tab, saved and kept until it is changed again -- not a one-off
  rearrangement. Up to 1.8.0 there was a single ordering carried over from the
  TM/HM search, which is why SORT appeared to work only on TM/HM: everywhere
  else the only choice was the order the Bag was already in.
- The orders are **A-Z**, **QUANTITY** and **CUSTOM**, offered on every tab.
  A tab holding a machine is also offered **TM/HM NUMBER**, **POWER HIGH** and
  **POWER LOW**.
- `A-Z` and `QUANTITY` are worked out from the items every time the rows are
  built, so they hold as the Bag changes rather than decaying. `CUSTOM` is the
  order you arranged by hand, and is the only one the Bag stores.
- `A-Z` sorts a machine by its move rather than by `TM24`.
- **MOVE ITEM puts the tab into CUSTOM**, freezing what is on screen as the
  starting point, so nothing jumps when you begin arranging and the pocket is
  not re-ordered out from under the move on the next redraw.
- Switching to `CUSTOM` from the sort menu does the same, so the hand-arranged
  order starts from the one you were just looking at.
- The results page keeps its own order too, but is not offered `CUSTOM`: there
  is nothing to arrange on a page rebuilt from the query every time.
- **Nothing is re-sorted when the Bag opens.** The whole order used to be
  rewritten alphabetically on every open, which undid every arrangement. A-Z
  is now a mode rather than something done to the order, so a Bag that has
  never been sorted looks exactly as it did while the order underneath is left
  alone.
- Pinning no longer re-sorts the Bag. Pinned rows lead their tab whatever the
  mode says, worked out when the rows are drawn.

---

## 1.8.0

- **The search keyboard carries the query and the keys, and nothing else.**
  The `A TYPE / B DEL-EXIT / SEL CLR / START GO` legend is gone -- every one of
  those is a key on the grid or the button you would reach for anyway -- and so
  is the SORT key and the `SORT:` line above the grid.
- **Ordering is the item tools' SORT on every page, including the results.**
  The results page has no order of its own to rewrite -- it is rebuilt from the
  query every time -- so SORT there sets the saved preference the rebuild
  reads, which is what the keyboard's SORT key used to do. Nothing was lost by
  taking the key off the keyboard.
- SORT on the results page now applies however few rows the search came back
  with. The "nothing to reorder" guard was running first, so a one-row page
  silently ignored it, even though the preference outlives that search.
- Respaced the keyboard for what is left: a row above `FIND`, two between
  `FIND` and the letters, two between the letters and the action row, and two
  below it.
- **SORT in the item tools re-sorts the open pocket once and then leaves it
  alone.** It rewrites the order the pocket is drawn from, and MOVE ITEM
  adjusts what it produced. In 1.6.0 it set a saved preference, which only
  showed on the TM/HM pocket and the results page and did nothing visible
  anywhere else.
- Only the slots the pocket already occupies are rewritten, in place, so every
  other pocket keeps its own order.
- A pocket with no machines in it is offered `NAME` and nothing else: machine
  number and base power mean nothing to a pocket of potions.
- **The TM/HM pocket follows the bag order like every other pocket.** It was
  drawn in the saved sort, which won over every manual move -- so it was the
  one pocket MOVE ITEM could never arrange, and the one pocket a one-shot
  re-sort would have been redrawn over. Its default order is unchanged:
  automatic sorting already files machines HM-first by number.
- `NAME` sorts a machine by its move rather than by `TM24`.

---

## 1.6.0

- **MOVE ITEM carries the item now.** Up and Down walk it through the pocket a
  row at a time and the list reorders under it as it goes, so the move is what
  you see rather than something that happens once you finally commit. Up to
  1.5.0 it was a two-ended swap: pick one item, move the cursor, press START on
  a second, and the two traded places with nothing on screen between.
- **A places the carried item, B puts it back where it was picked up.** START
  no longer ends a move -- it is swallowed while one is in progress, so the
  item tools cannot open on top of a carry. Left/Right still change pocket, and
  that drops the carry as before.
- **The carried item wears the hollow cursor.** 1.5.0 set `list.hollowIndex`
  for it, which the engine's item-box path does not read, so nothing ever
  looked picked up. It is drawn by the mod, over the solid cursor the engine
  has already painted on that row.
- **SORT is the first row of the item tools**, opening the same picker as the
  search keyboard's SORT key. It is the Bag's saved ordering preference, so it
  orders the TM/HM pocket and the results page; the other pockets are in the
  order you arrange them in.
- A step that the pocket's own order will not accept -- TM/HM is drawn in SORT
  order, and pinned items sort above unpinned ones -- puts the bag order back
  rather than leaving it quietly rearranged underneath a list that will never
  show it.

---

## 1.5.0

- **SELECT opens the same search on every pocket.** There is no separate TM/HM
  search any more: the filter hub, its type and damage-class pickers and its
  move-name keyboard are all gone, and with them ~250 lines.
- The filters are folded into the query instead. A machine's search key now
  carries its move's elemental type and damage class alongside its code, its
  move name and its item id, so `SURF`, `HM03`, `WATER`, `SPECIAL` and
  `STATUS` are all things you type into the one search box.
- Machine results are listed by their move rather than as a bare `TM35`, and
  carry their machine data, so Y/I reads them from the results page.
- **SORT is the one filter that stays a choice**, because it is an ordering
  rather than a term. It is a key on the keyboard, below `DEL CLR GO EXIT`,
  with its current value on the line under `FIND`. It still writes the Bag's
  saved preference and still orders the TM/HM pocket.
- Sort orders the whole result list: `NAME` by displayed name, and the machine
  modes group the machines first in that order, leaving everything else after
  them by name -- a POTION has no machine number and no base power.
- `mod.exports.machineRows` is unchanged, so the type and damage-class filters
  are still available to other mods.
- Pop-up titles are drawn by the mod rather than handed to `src/ui/Menu.lua`.
  Menu draws its own at the border tile's own y and knocks out exactly its
  width, which puts ink on the frame's outer white margin and ends the rule
  flush against the first and last letter. They now go through the same
  `drawBorderLabel` as every other title here -- a pixel lower, with a tile of
  clearance at each end. Only `draw` is wrapped, so the frame, the rows, the
  cursor and the more-arrow all stay Menu's.
- **TM HM is written TM/HM.** The pocket header, the search title and the sort
  picker all carry the slash now.
- **ITEM OPTIONS lost its title.** Four rows that name themselves do not need
  one, and the window is a row shorter for it.

---

## 1.4.0

- **The Left/Right arrows are gone from the pocket header.** The pocket name is
  now the only thing on the item window's top border, so it is drawn by the
  same code every other window title is: centred between the corners, a tile of
  clearance at each end, the rule running up to it and on after it.
- That also gives the longest pocket names room. The arrows took the outermost
  column at each end, which left `FAVORITES` and `KEY ITEMS` a single column of
  rule to sit in; every pocket now has rule on both sides.
- Left and Right still change pocket, and still wrap around. Nothing on screen
  spells them out any more, the same way nothing spells out START and SELECT.
- **The search keyboard's match count is gone.** The results page shows the
  matches themselves, so counting them first was work done twice -- and it was
  the only reason the search re-ran on every keystroke.
- `FIND` moved down a row, off the title it was crowded against.

---

## 1.3.1

- Border labels are drawn a pixel lower, so they stay off the frame's outer
  white margin. That margin runs around the whole window outside the rule, and
  on a top border it is the border tile's first pixel row; Gen 1 glyphs ink
  rows 0 to 6 of their cell, so a label drawn at the tile's own y put ink on
  it. This is the pocket header and its arrows on the item window, and the
  titles of the search keyboard and MOVE INFORMATION.
- The money is unchanged: it sits on a bottom border, whose margin is the
  tile's last pixel row -- the row the glyphs already leave empty.
- The knock-out under each label still covers the whole border tile, so the
  rule is taken out from under the label as before.

Pop-up menu titles are drawn by `src/ui/Menu.lua` itself, at the tile's y, so
this shift does not reach them.

---

## 1.3.0

- **Search results are a page of the Bag now, not a page of their own.** A
  search hands its matches back to the Bag, which grows a **RESULTS** pocket
  for them and puts you on it, so they are read in the item window with the
  pocket header, the counts and the row markers -- and every Bag control works
  on them. They used to be listed on a separate full-screen `ListMenu` with no
  frame.
- RESULTS only exists while a search is loaded into it: Left and Right step
  over it before the first search, it is never what LAST USED reopens the Bag
  on, and it is gone the next time the Bag opens. It is not a pocket an item
  can be filed in, and `exports.pockets()` does not list it.
- The page is rebuilt from the search rather than held as a snapshot, so its
  counts follow the Bag as items are used up and reacquired.
- The TM/HM filters' **SHOW RESULTS** fills the same page, which retires the
  last of the undecorated result lists.
- Y/I opens move information wherever a machine is reached -- the results page
  and FAVORITES included -- rather than only in the TM/HM pocket.
- **Window titles moved onto the window's own top border**, which is where Gen
  1 titles a box: the border line runs up to the label and continues after it.
  This is the pocket header on the item window, and the titles of ITEM OPTIONS,
  the TM/HM filters and their pickers, the search keyboard and MOVE
  INFORMATION.
- Drawing onto a border needs the line knocked out from under the label first.
  Glyphs are drawn as a mask, painted in whatever colour is set, so a label
  drawn straight onto the line would have it running through the letters. The
  pocket header knocks out one run per glyph group -- under each arrow and
  under the name -- so the line survives in the gaps between them.
- Every border label knocks out a tile of clearance at each end. Knocking out
  exactly the width of the text -- which is what `src/ui/Menu.lua` does with
  its own title -- leaves the rule ending flush against the first glyph and
  restarting flush against the last, which reads as the frame touching the
  letters. The clearance is clamped so it can never rub out a corner glyph,
  and a popup is sized for its title plus that clearance: a title wider than
  `tw - 4` tiles would run into a corner, the same defect at the other end.
- Labels too wide for their window are trimmed by glyphs rather than by bytes,
  through the engine's own `Font.split`. A label can carry a multi-byte
  character or a Gen 1 control code, and half of one of those is not a
  character. A build without `Font.split` still trims the old way.
- The money moved to the item window's bottom border, right-aligned under its
  bottom-right corner, instead of the little window 1.2.0 hung under that
  corner. There is no second frame on the Bag screen at all now.
- Popup menus lost the title row and the blank row under it, so a four-option
  menu is a four-option window.
- MOVE INFORMATION gained a row from the same change and spends it on the
  effect, which now wraps over four lines instead of three.

---

## 1.2.0

- **SELECT now searches and START now opens ITEM OPTIONS.** The two were the
  other way round. In the TM/HM pocket SELECT opens that pocket's filter hub,
  which is its search; START opens the item tools there too.
- Removed the full-width text box under the item window. 1.1.1 put the money
  line and a legend for START and SELECT in it, and the bar read as a second
  screen rather than as part of the Bag.
- The money is now drawn in a window sized to the amount, tucked under the item
  window's bottom-right corner. It starts a tile row below that window instead
  of sharing its bottom border: sharing puts two frames on one tile, and a box
  that also owns tile 19,12 draws its own top-right corner where the item
  window's bottom-right corner belongs.
- Dropped the on-screen legend entirely. Nothing spells out START and SELECT
  any more; the labels are still published for Gen1 Modern UI, which puts a
  touch button on each.
- The TM/HM sort mode is no longer printed on the Bag. It is a row in the TM/HM
  tools, `SORT: NUMBER`, and is still published as `machineSortLabel`.
- **ITEM OPTIONS is a window over the Bag instead of a full-screen page.** It
  and the TM/HM filter hub, MOVE TYPE, DAMAGE CLASS and SORT TM HM were plain
  `ListMenu`s, and `ListMenu`'s full-screen branch fills all 160x144 white and
  paints no frame at all: four options were covering the game with an
  undecorated white page. They are now `src/ui/Menu.lua`, the engine's own
  framed menu widget -- it draws the frame, the title on its top border and the
  more-arrow on the bottom one, and owns the cursor, the scrolling and the
  input. The mod hands it rows of `{ label, onSelect }` and a corner.
- Menu knocks out exactly its title's width, so its rule would end flush
  against the first and last letter. Every title is padded with a space at each
  end, at the call site rather than inside the string: a title is a catalog key
  elsewhere in the engine, and padding inside would make the padding part of
  the key. Menu also grows `tw` to the widest label + 3 and never accounts for
  the title, so the width is asked for explicitly and labels are trimmed to it
  -- a twelve-glyph TM/HM query would otherwise grow the hub off the screen.
- **Rebuilt the search keyboard.** It had no frame; its header lines sat on a
  12px pitch the 8px font does not land on; and its `DEL` / `CLR` / `GO` /
  `EXIT` row was laid out on the same 16px pitch as the single-glyph letters,
  so the four words were drawn on top of one another and read as `DECLBOEXIT`.
  It is now one framed window with everything on the 8px grid, and the action
  row is measured and centred so no two words can share a column whatever the
  font. The TM/HM move-name keyboard is the same screen and gets the same fix.
- **Rebuilt MOVE INFORMATION**, the last screen still drawn as a bare white
  page. It had no frame either, and its eleven lines sat on a 14px pitch the
  8px font does not land on, so every row but one fell between the rows the
  rest of the game draws on. It is now the same screen-filling window as the
  search keyboard, with the sixteen interior rows spent on the title, the
  machine and its move, the five stats, the effect over three wrapped lines,
  and the way out.
- Fixed MOVE INFORMATION leaving the draw colour black when a machine had no
  move data. That path returned early, before the line that puts the colour
  back, so whatever drew next inherited the text colour.
- The match count on Quick Search is recomputed when the query changes rather
  than on every frame.
- No change to pocket contents, sorting, Favorites, pins, search results or
  inventory behaviour.

---

## 1.1.1

- Fixed the pocket header, which 1.1.0 never drew. The header was written to
  the Bag list's `title`, but the engine only draws a list title on its plain
  full-screen path; the Bag is an item-box list, and that path paints the box,
  its rows and the cursor and no title at all. The pocket name is now drawn by
  the mod, on the empty row at the top of the item box.
- Replaced the `<` and `>` around the name with the engine's own arrow glyph,
  the Left one mirrored. Angle brackets are not characters in Gen 1 text --
  they delimit control tokens like `<PK>` and `<PLAYER>` -- so they could not
  have been drawn even on a screen that draws a title.
- Fixed the footer the same way. `START SEARCH`, `SEL TOOLS`, the money line
  and the TM/HM hints were never drawn either, for the same reason: the
  item-box path paints no footer. They now appear in the standard bottom text
  box, one hint per line.
- Re-broke the footer text so every line fits the box's eighteen columns.
  `START FILTER  Y/I INFO` was twenty-one and would have wrapped mid-phrase;
  it is now two lines. No hint was dropped.

---

## 1.1.0

- Added a pocket header: the open pocket's name centered between `<` and `>`,
  the Left/Right keys that change pocket, in a fixed 18-glyph field so the
  arrows stay in the same columns on every pocket.
- Replaced the old `MEDICINE 2/7` title with that header. The pocket position
  is no longer spelled out; the arrows show that pockets continue in both
  directions, and they wrap around as before.
- No change to pocket contents, sorting, Favorites, pins, search or TM/HM
  tools.

---

## 1.0.0

First release of Gen1ModernBag, derived from FAFF0x's Modern Bag 1.6.0.
Version numbering restarts here; this is a new project, not a continuation of
upstream's release line.

- Corrected the TM/HM machine-label width from 15 to 13 characters (9 with row
  markers), so long labels truncate with a visible ellipsis instead of clipping
  past the item window border.
- Renamed the mod id to `gen1_modern_bag` and the display name to
  `Gen1ModernBag`, including the `_G` dispatch, unlimited-inventory and
  move-info input patch keys, so the two mods cannot share dispatch state.
- Declared `"conflicts": ["modern_bag"]`; both mods decorate `src.ui.BagMenu`
  and must not run together.
- Everything else is inherited unchanged from upstream 1.6.0.

**Migrating from Modern Bag:** the new mod id means saved Favorites, pinned
items and sort preferences do not carry over.

---

## Upstream history

The entries below are the release history of **Modern Bag** by FAFF0x, retained
for reference. They describe upstream's work, not changes made in this project.

## 1.6.0

- Added an **Opening Pocket** mod option with FAVORITES, MEDICINE, BALLS, TM/HM, BATTLE, KEY ITEMS, OTHER and LAST USED choices.
- Kept MEDICINE as the default opening pocket for backwards-compatible behavior.
- Added persistent LAST USED pocket memory.
- Added hold-to-scroll for Up/Down using Gen1Recomp's native `ListMenu` key-repeat support.
- Added **Hold Scroll Speed** options: OFF, NORMAL, FAST and VERY FAST.
- FAST is the new default repeat profile.
- Kept pocket switching, Favorites, pins, TM/HM filtering, search and Modern UI compatibility unchanged.

## 1.5.2

- Reworked Quick Search and TM/HM move-name search into true grid keyboards that Gen1 Modern UI can present with its native naming-keyboard layout.
- Added large pointer/touch keyboard cells for every letter, number, DEL, CLR, GO and EXIT action.
- Published `searchAvailable` and `startActionLabel` on the live Gen1ModernBag state so Gen1 Modern UI 0.8.2+ can expose a dedicated SEARCH/FILTER touch button instead of requiring a hard-to-hit START control.
- Added an explicit START SEARCH hint to normal pockets.
- Kept the existing Move Information compatibility adapter and all inventory/search behavior unchanged.
- Recommended Gen1 Modern UI 0.8.2+ for the Key Items font fix and dedicated SEARCH/FILTER touch control.

## 1.5.1

- Added official Gen1 Modern UI compatibility through the `gen1ModernUi` API v1 contract.
- Kept the seven-pocket Bag on Modern UI's native pocket-aware Bag presenter.
- Added Modern UI presentation for Quick Search and its keyboard.
- Added Modern UI presentation for the TM/HM move-name search keyboard.
- Added Modern UI presentation for the TM/HM Move Information screen.
- Added pointer/click semantic actions without changing inventory, Favorite, pin, sorting, search or machine logic.
- Gen1 Modern UI remains an optional dependency with automatic classic-UI fallback.

## 1.5.0

- Added a dedicated START search panel for the TM/HM pocket.
- Added move-name search using the move contained inside each TM or HM.
- Added elemental-type filters.
- Added PHYSICAL, SPECIAL and STATUS filters using Generation I damage rules.
- Added sorting by machine number, move name, descending power and ascending power.
- Added a full move-information screen opened with controller Y or keyboard I.
- Move information includes type, class, power, accuracy, PP and effect.
- Added Y/I move information inside filtered results.
- Kept pinned machines above every unpinned machine under all sorting modes.
- Preserved Favorites, normal item actions, general Quick Search and unlimited inventory.

## 1.4.0

- Added a seventh **FAVORITES** pocket containing items selected from any normal pocket.
- Added persistent **PIN TO TOP** support for every item category.
- Pinned items remain above unpinned items regardless of automatic alphabetical sorting.
- Replaced direct SELECT reordering with an **ITEM OPTIONS** menu containing Favorite, Pin and Move actions.
- Added `F`, `P` and `PF` row markers for favorite and pinned items.
- Favorites and pins remain saved when an item stack reaches zero and return when the item is reacquired.
- Preserved Quick Search, battle-bag use, normal item actions and unlimited inventory.

## 1.3.0

- Added automatic sorting by pocket and item name whenever the Bag opens.
- Re-sorts automatically when item types are added or removed.
- Keeps HMs and TMs in numerical order.
- Added START-button Quick Search with an on-screen keyboard.
- Search covers every pocket and jumps directly to the selected result.
- Preserved manual SELECT reordering during the current Bag session.

## 1.2.0

- Removed the 99-unit maximum from individual item stacks.
- Kept the unlimited number of distinct bag item types.
- Added compatibility handling for both current and older Bag implementations.

## 1.1.1

- Removed the visible `L/R POCKET` hint from the bag footer.
- Kept Left/Right pocket switching unchanged.

## 1.1.0

- Removed the vanilla 20-slot limit for distinct bag items.
- Kept the independent vanilla limit of 99 units per item stack.
- Updated package metadata and documentation.

## [1.0.0] - 2026-07-30

### Added
- Six Left/Right inventory pockets.
- Pocket-aware cursor memory and item reordering.
- Automatic classification for built-in and modded items.
- Overworld and battle bag support.
- Vanilla item-action delegation.
