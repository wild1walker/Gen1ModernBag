# Gen1ModernBag

Gen1ModernBag divides the Gen1Recomp inventory into seven modern-style pockets, automatically organizes items, adds Favorites, persistent pinned items, advanced TM/HM tools, quick search and removes both vanilla carrying limits while preserving item behavior.

## Pockets

- **FAVORITES** — items marked as favorites from any other pocket.
- **MEDICINE** — healing items, status cures, Revives, PP recovery, vitamins and Rare Candy.
- **BALLS** — every built-in or modded item registered as a Poké Ball.
- **TM HM** — all TMs and HMs.
- **BATTLE** — X items, Dire Hit, Guard Spec and Poké Doll.
- **KEY ITEMS** — non-tossable and key items.
- **OTHER** — stones, Repels, Escape Rope, fossils and everything not covered above.

The top row of the item window names the open pocket between the arrows that
change it — `◀ BALLS ▶` — so which page you are on and which way to go are both
visible at a glance. Pockets wrap around, so both arrows always apply.

Press **Left/Right** to change pocket. The opening pocket is now configurable in **MODS → Gen1ModernBag → Options**. The default remains **MEDICINE**, and **LAST USED** can be selected if you want the Bag to reopen on the pocket you used most recently. Up/Down, A and B keep their original meanings.

## Opening pocket and fast scrolling

Gen1ModernBag provides two runtime options:

- **Opening Pocket** — FAVORITES, MEDICINE, BALLS, TM/HM, BATTLE, KEY ITEMS, OTHER, or LAST USED.
- **Hold Scroll Speed** — OFF, NORMAL, FAST, or VERY FAST.

Holding **Up** or **Down** now repeats list movement automatically instead of requiring one press per item. **FAST** is the default. The implementation uses Gen1Recomp's native ListMenu key-repeat system, so remapped keyboard/controller inputs continue to work normally.

## Favorites and pinned items

Press **SELECT** while an item is highlighted to open **ITEM OPTIONS**:

- **ADD FAVORITE / REMOVE FAVORITE** — adds or removes the item from the FAVORITES pocket.
- **PIN TO TOP / UNPIN ITEM** — fixes the item above every unpinned item in its normal category.
- **MOVE ITEM** — starts manual item reordering; press SELECT on the destination item to complete the move.
- **CANCEL** — closes ITEM OPTIONS.

The row markers indicate item status:

- `F` — favorite.
- `P` — pinned.
- `PF` — both pinned and favorite.

Favorites and pins are persistent. If an item stack reaches zero, the item temporarily disappears from the Bag but keeps its saved Favorite and Pin status. It returns automatically when reacquired.

Pinned items are sorted before all unpinned items. Their position is not changed by alphabetical sorting; multiple pinned items follow the order in which they were pinned.

## Automatic sorting

Items are automatically sorted by pocket and display name whenever the Bag is opened. The order is refreshed when a new item type is added or an item stack disappears completely. TMs and HMs are kept in numerical order, with HMs before TMs.

Pinned items always remain at the top of their category. Manual SELECT reordering remains available through **ITEM OPTIONS → MOVE ITEM** for the current Bag session. Closing and reopening the Bag applies automatic sorting again without moving pinned items below unpinned items.

## Quick search

Press **START** from any pocket except TM/HM to open Quick Search.

- Use the D-pad to move across the on-screen keyboard, or tap/click an individual key when Gen1 Modern UI is active.
- Press **A** to enter a character or activate DEL, CLR, GO and EXIT.
- Press **B** to delete the last character; press it with an empty query to close search.
- Press **SELECT** to clear the full query.
- Press **START**, tap the Modern UI **SEARCH** button, or select **GO** to show all matching items.
- Choosing a result returns to the correct normal pocket with that item selected.

Search works across every pocket and matches both the displayed item name and its internal item identifier. An empty query lists the entire Bag alphabetically. Search results also show the `F`, `P` and `PF` status markers.

## Advanced TM/HM search and move information

The **TM HM** pocket has its own START menu instead of the general item search. It can:

- search by the name of the move contained in the machine;
- filter by elemental move type;
- filter by **PHYSICAL**, **SPECIAL** or **STATUS** damage class;
- sort by machine number, move name, highest power or lowest power;
- combine name, type and damage-class filters.

Generation I uses a type-based physical/special split. Normal, Fighting, Flying, Poison, Ground, Rock, Bug and Ghost attacks are shown as PHYSICAL. Fire, Water, Grass, Electric, Psychic, Ice and Dragon attacks are shown as SPECIAL. Moves with no base power are shown as STATUS.

Press **Y** on a controller or **I** on a keyboard while a TM/HM is highlighted to open **MOVE INFORMATION**. The screen shows:

- machine number and move name;
- elemental type;
- damage class;
- power;
- accuracy;
- PP;
- move effect.

The same Y/I information shortcut works inside filtered TM/HM results. Pinned machines remain above unpinned machines regardless of the selected sorting mode.

## Unlimited inventory

The Bag may contain an unlimited number of distinct item types, and each item stack may grow beyond 99 units. Counts remain finite values earned, bought or received during normal play.

The mod wraps the vanilla BagMenu rather than reimplementing item effects. Items are still used, consumed, taught, thrown and validated by Gen1Recomp's original menu. Pockets, Favorites, pinned items, automatic sorting and search are also available when the Bag is opened during battle.

## Installation

Import the ZIP in the MODS manager, enable **Gen1ModernBag**, then fully restart Gen1Recomp.

Replace older Gen1ModernBag versions instead of enabling multiple versions at the same time.

## Compatibility

Custom balls and machines are categorized from their registered item fields. Conventional custom medicines are detected from their effect identifiers; unknown items safely fall back to OTHER.

### Gen1 Modern UI

Gen1ModernBag implements the official `gen1ModernUi` compatibility contract (`apiVersion = 1`). With **Gen1 Modern UI 0.8.2 or newer** enabled, the normal seven-pocket Bag uses Modern UI's dedicated pocket-aware Bag presenter. Quick Search and TM/HM move-name search now expose a real keyboard-grid state, so Modern UI renders large individual keys instead of a list of keyboard rows. Move Information continues to use the compatibility contract. Modern UI 0.8.2 also exposes a dedicated **SEARCH** / **FILTER** touch button on the Bag and fixes the Key Items font fallback caused by the unsellable-price dash.

Modern UI remains optional. If it is absent or disabled, Gen1ModernBag keeps its original 160×144 presentation and all inventory behavior remains unchanged.
