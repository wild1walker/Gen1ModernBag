# Changelog

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
