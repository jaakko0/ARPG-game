
# Game data

`item_catalog.tres` is the authoritative current equipment catalog and shared
prototype equipment drop pool. It references the definitions in `equipment/`.

Each equipment definition is an `EquipmentItemData` Resource with a stable,
non-empty `item_id`. Inventory, equipment and save data refer to that ID.
`ItemCatalog` safely returns `null` for unknown IDs and reports invalid or duplicate
definitions while keeping the first valid definition.

Enemy-specific drop overrides remain possible through LootDropper, but ordinary
enemies use the catalog's default pool. Item instances, rarity and random affixes
are future systems and are not represented by the current data model.
