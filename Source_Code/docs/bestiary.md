# Bestiary coverage

Validated against the locally installed original classic assets on 2026-10-13.

| Pack | Enemy profiles | Combat areas | Named unique profiles |
| --- | ---: | ---: | ---: |
| Diablo I GOG 1.0.9.2 | 95 | 22 | Included in floor/quest import |
| Diablo II base assets (expansion excluded) | 236 | 101 | 31 |
| Diablo II + LoD 1.07 | 309 | 124 | 46 |

Profiles count distinct identities/variants and bosses, not unique sprite families. Reusable compositions and decoded assets are cached locally. Only the selected area's sprites are loaded. Diablo II uses its own area names and Acts; towns and empty noncombat areas are excluded, and the cow map stays a portal event.

D1 population comes from the shipped original monster floor ranges and quest DUN conversions. D2 Acts I–IV use the installed Normal population and special-population tables, with explicit boss and named-unique placements. Normal population is used across our Easy/Hard/Legendary modes; these are survival difficulties, not original D2 Nightmare/Hell roster rules.

LoD 1.07 contains pre-release Act V placeholders. Act V uses explicitly authored native-family rosters and named-unique mappings, labeled in each area's provenance. These are themed survival assignments, not verified reproduction of the original hardcoded/preset population. Unused/debug monsters and unplaced uniques are not presented as playable enemies.

Original graphics and family audio are imported. Melee/ranged behavior, elemental projectiles, and stationary original profiles are supported. Original resurrection, spawning offspring, burrowing, teleporting, curses, unique modifiers, and full boss skill sets are not reproduced. Areas use original regional floor art in survival layouts; they are not original-map clones.

Bundled catalogs contain metadata and compatibility hashes only. A matching installation uses that roster template; different table hashes fall back to the supported local table reader. Original sprites, audio, raw tables, MPQs and local databases are never included in the release.

The local asset database includes `bestiary_monsters` and `bestiary_areas`; `bestiary.json` and `survival.json` sit beside it.

Family reference: [Blizzard's Arreat Summit bestiary](https://classic.battle.net/diablo2exp/monsters/). The installed tables control version-specific data; later website statistics are not copied into balance values.

Boss-only chambers use a survival endurance adaptation: the first boss appears after five seconds, with one active main boss. After it dies, a sixty-second recovery precedes the next encounter, until the selected difficulty timer ends. Named uniques still appear only once per run, including the other Ancients.

## Diablo II + LoD area roster

| Area | Enemies |
| --- | --- |
| Act 1 — Blood Moor | Zombie, Fallen, Quill Rat |
| Act 1 — Cold Plains | Gargantuan Beast, Dark Hunter, Fallen Shaman, Dark Spearwoman, Bishibosh |
| Act 1 — Stony Field | Skeleton, Hungry Dead, Foul Crow, Moon Clan, Dark Ranger, Foul Crow Nest, Rakanishu |
| Act 1 — Dark Wood | Carver, Vile Hunter, Spike Fiend, Vile Lancer, Skeleton Archer, Treehead WoodFist |
| Act 1 — Black Marsh | Returned, Blood Hawk, Brute, Night Clan, Carver Shaman, Vile Archer, Blood Hawk Nest |
| Act 1 — Tamoe Highland | Dark Stalker, Thorn Beast, Dark Lancer, Returned Archer, Returned Mage |
| Act 1 — Den of Evil | Zombie, Gargantuan Beast, Fallen Shaman, Corpsefire |
| Act 1 — Cave Level 1 | Skeleton, Hungry Dead, Dark Ranger, Coldcrow |
| Act 1 — Underground Passage Level 1 | Misshapen, Carver, Vile Hunter, Skeleton Archer |
| Act 1 — Hole Level 1 | Misshapen, Carver, Brute, Vile Archer |
| Act 1 — Pit Level 1 | Bone Warrior, Devilkin, Dark Stalker, Dark Archer |
| Act 1 — Cave Level 2 | Skeleton, Hungry Dead, Dark Ranger |
| Act 1 — Underground Passage Level 2 | Misshapen, Carver, Vile Hunter, Skeleton Archer |
| Act 1 — Hole Level 2 | Misshapen, Carver, Brute, Vile Archer |
| Act 1 — Pit Level 2 | Bone Warrior, Devilkin, Dark Stalker, Dark Archer |
| Act 1 — Burial Grounds | Skeleton, Hungry Dead, Blood Raven |
| Act 1 — Crypt | Skeleton, Hungry Dead, Bonebreaker |
| Act 1 — Mausoleum | Skeleton, Hungry Dead |
| Act 1 — Tower Cellar Level 1 | Devilkin, Ghost, Blood Clan, Dark Archer |
| Act 1 — Tower Cellar Level 2 | Devilkin, Ghost, Blood Clan, Dark Archer |
| Act 1 — Tower Cellar Level 3 | Devilkin, Ghost, Blood Clan, Dark Archer |
| Act 1 — Tower Cellar Level 4 | Devilkin, Ghost, Blood Clan, Dark Archer |
| Act 1 — Tower Cellar Level 5 | Devilkin, Ghost, Blood Clan, Dark Archer, The Countess |
| Act 1 — Monastery Gate | Disfigured, Dark Stalker, Returned Archer, Returned Mage |
| Act 1 — Outer Cloister | Yeti, Black Rogue, Devilkin Shaman, Razor Spine |
| Act 1 — Barracks | Black Rogue, Death Clan, Devilkin Shaman, Bone Archer, Bone Mage, The Smith |
| Act 1 — Jail Level 1 | Dark One, Wraith, Death Clan, Bone Archer, Bone Mage, Pitspawn Fouldog |
| Act 1 — Jail Level 2 | Dark One, Wraith, Death Clan, Bone Archer, Bone Mage |
| Act 1 — Jail Level 3 | Dark One, Wraith, Death Clan, Bone Archer, Bone Mage |
| Act 1 — Inner Cloister | Dark One, Black Archer, Bone Mage |
| Act 1 — Cathedral | Tainted, Wraith, Dark Shaman, Bone Ash |
| Act 1 — Catacombs Level 1 | Tainted, Dark Shaman, Rat Man |
| Act 1 — Catacombs Level 2 | Tainted, Dark Shaman, Arach |
| Act 1 — Catacombs Level 3 | Ghoul, Afflicted, The Banished |
| Act 1 — Catacombs Level 4 | Ghoul, Afflicted, Andariel |
| Act 1 — Tristram | Returned, Night Clan, Carver Shaman, Skeleton Archer, Griswold |
| Act 2 — Rocky Waste | Sand Leaper, Huntress, Dung Soldier, Carrion Bird, Slinger |
| Act 2 — Dry Hills | Cave Leaper, Saber Cat, Undead Scavenger, Spear Cat |
| Act 2 — Far Oasis | Black Raptor, Sand Maggot, Itchies, Death Beetle, Undead Scavenger, Black Raptor Nest, Beetleburst |
| Act 2 — Lost City | Plague Bearer, Marauder, Tomb Creeper, Night Tiger, Night Slinger, Dark Elder |
| Act 2 — Valley of Snakes | Claw Viper, Salamander, Embalmed, Guardian |
| Act 2 — Canyon of the Magi | Crusher, Devourer, Hell Cat, Steel Scarab, Hell Slinger |
| Act 2 — Sewers Level 1 | Burning Dead, Sand Raider, Dried Corpse, Burning Dead Archer |
| Act 2 — Sewers Level 2 | Burning Dead, Sand Raider, Dried Corpse, Burning Dead Archer |
| Act 2 — Sewers Level 3 | Burning Dead, Huntress, Dried Corpse, Burning Dead Mage, Radament |
| Act 2 — Harem Level 2 | Invader, Dune Beast, Horror Archer, Blunderbore, Horror Mage |
| Act 2 — Palace Cellar Level 1  | Invader, Dune Beast, Horror Archer, Blunderbore, Horror Mage |
| Act 2 — Palace Cellar Level 2 | Invader, Dune Beast, Horror Archer, Blunderbore, Horror Mage |
| Act 2 — Palace Cellar Level 3 | Invader, Dune Beast, Horror Archer, Blunderbore, Horror Mage, Fire Eye |
| Act 2 — Stony Tomb Level 1 | Horror, Dung Soldier, Burning Dead Mage |
| Act 2 — Halls of the Dead Level 1 | Decayed, Hollow One, Desert Wing, Spear Cat, Bloodwitch the Wild |
| Act 2 — Halls of the Dead Level 2 | Decayed, Hollow One, Desert Wing, Spear Cat |
| Act 2 — Claw Viper Temple Level 1 | Claw Viper, Salamander, Embalmed, Guardian |
| Act 2 — Stony Tomb Level 2 | Horror, Dung Soldier, Burning Dead Mage, Creeping Feature |
| Act 2 — Halls of the Dead Level 3 | Decayed, Hollow One, Desert Wing, Spear Cat |
| Act 2 — Claw Viper Temple Level 2 | Claw Viper, Salamander, Embalmed, Guardian, Fangskin |
| Act 2 — Maggot Lair Level 1 | Sand Maggot, Rock Worm, Black Locusts, Death Beetle, Scarab |
| Act 2 — Maggot Lair Level 2 | Sand Maggot, Rock Worm, Black Locusts, Death Beetle, Scarab |
| Act 2 — Maggot Lair Level 3 | Sand Maggot, Rock Worm, Black Locusts, Death Beetle, Scarab, Coldworm the Burrower |
| Act 2 — Ancient Tunnels | Plague Bearer, Invader, Embalmed, Horror Mage |
| Act 2 — Tal Rasha's Tomb | Apparition, Steel Scarab, Preserved Dead, Unraveler, Ghoul Lord, Gorebelly |
| Act 2 — Tal Rasha's Tomb | Apparition, Steel Scarab, Preserved Dead, Unraveler, Ghoul Lord, Gorebelly |
| Act 2 — Tal Rasha's Tomb | Apparition, Steel Scarab, Preserved Dead, Unraveler, Ghoul Lord, Gorebelly |
| Act 2 — Tal Rasha's Tomb | Apparition, Steel Scarab, Preserved Dead, Unraveler, Ghoul Lord, Gorebelly |
| Act 2 — Tal Rasha's Tomb | Apparition, Steel Scarab, Preserved Dead, Unraveler, Ghoul Lord, Gorebelly |
| Act 2 — Tal Rasha's Tomb | Apparition, Steel Scarab, Preserved Dead, Unraveler, Ghoul Lord, Gorebelly |
| Act 2 — Tal Rasha's Tomb | Apparition, Steel Scarab, Preserved Dead, Unraveler, Ghoul Lord, Gorebelly, Ancient Kaa the Soulless |
| Act 2 — Duriel's Lair | Apparition, Steel Scarab, Preserved Dead, Unraveler, Ghoul Lord, Gorebelly, Duriel |
| Act 2 — Arcane Sanctuary | Specter, Hell Clan, Ghoul Lord, The Summoner |
| Act 3 — Spider Forest | Jungle Hunter, Sucker, Thorned Hulk, Fetish, Cloud Stalker |
| Act 3 — Great Marsh | Swamp Dweller, Bog Creature, Bramble Hulk, Drowned Carcass, Fetish Shaman, Gloam |
| Act 3 — Flayer Jungle | Flayer, Flayer Shaman, Soul Killer, Soul Killer Shaman, Winged Nightmare, Slime Prince |
| Act 3 — Lower Kurast | Doom Ape, Tree Lurker, Hell Buzzard, Zakarumite, Stormtree |
| Act 3 — Kurast Bazaar | Thrasher, Hell Swarm, Faithful, Sexton |
| Act 3 — Upper Kurast | Winged Nightmare, Zealot, Cantor, Thrasher |
| Act 3 — Kurast Causeway | Infidel, Temple Guard, Heirophant |
| Act 3 — Travincal | Heirophant, Night Lord, Ismail Vilehand, Geleb Flamefinger, Toorc Icefist |
| Act 3 — Spider Cave | Poison Spinner, Flame Spider, Fiend, Giant Lamprey |
| Act 3 — Spider Cavern | Poison Spinner, Flame Spider, Fiend, Giant Lamprey, Sszark the Burning |
| Act 3 — Swampy Pit Level 1 | Preserved Dead, Soul Killer-skeleton, Fiend, Gloam, Stygian Doll-skeleton |
| Act 3 — Swampy Pit Level 2 | Soul Killer-skeleton, Drowned Carcass, Fiend, Gloam, Stygian Doll-skeleton |
| Act 3 — Flayer Dungeon Level 1 | Flayer, Flayer Shaman, Soul Killer, Soul Killer Shaman, Gloombat, Dark Shape, Flayer-skeleton |
| Act 3 — Flayer Dungeon Level 2 | Flayer, Flayer Shaman, Soul Killer, Soul Killer Shaman, Gloombat, Dark Shape, Flayer-skeleton |
| Act 3 — Swampy Pit Level 3 | Soul Killer-skeleton, Stygian Doll-skeleton, Fiend, Gloam |
| Act 3 — Flayer Dungeon Level 3 | Flayer, Flayer Shaman, Soul Killer, Soul Killer Shaman, Gloombat, Dark Shape, Flayer-skeleton, Witch Doctor Endugu |
| Act 3 — Sewers Level 1 | Preserved Dead, Feeder, Gloombat, Horadrim Ancient, Soul Killer-skeleton, Icehawk Riftwing |
| Act 3 — Sewers Level 2 | Preserved Dead, Horadrim Ancient, Blood Wing, Slime Prince, Soul Killer-skeleton |
| Act 3 — Ruined Temple | Wailing Beast, Flesh Hunter, Spider Magus, Night Lord, Battlemaid Sarina |
| Act 3 — Disused Fane | Wailing Beast, Flesh Hunter, Spider Magus, Night Lord |
| Act 3 — Forgotten Reliquary | Wailing Beast, Flesh Hunter, Spider Magus, Night Lord |
| Act 3 — Forgotten Temple | Serpent Magus, Bone Scarab, Blood Diver, Flesh Archer |
| Act 3 — Ruined Fane | Serpent Magus, Bone Scarab, Blood Diver, Flesh Archer |
| Act 3 — Disused Reliquary | Serpent Magus, Bone Scarab, Blood Diver, Flesh Archer |
| Act 3 — Durance of Hate Level 1 | Cadaver, Dark Lord, Mauler, Stygian Doll-skeleton |
| Act 3 — Durance of Hate Level 2 | Cadaver, Dark Lord, Mauler, Stygian Doll-skeleton |
| Act 3 — Durance of Hate Level 3 | Blood Lord, Mephisto, Bremm Sparkfist, Wyand Voidbringer, Maffer Dragonhand |
| Act 4 — Outer Steppes | Cliff Lurker, Flesh Spawner, Doom Caster, Corpulent, Doom Knight, Venom Lord |
| Act 4 — Plains of Despair | Burning Soul, Flesh Spawner, Doom Caster, Corpulent, Doom Knight, Venom Lord, Izual |
| Act 4 — City of the Damned | Damned, Dark Familiar, Stygian Hag, Strangler, Corpse Spitter, Abyss Knight, Pit Lord |
| Act 4 — River of Flame | Blood Maggot, Urdar, Grotesque, Strangler, Maw Fiend, Abyss Knight, Pit Lord |
| Act 4 — Chaos Sanctuary | Storm Caster, Oblivion Knight, Venom Lord, Diablo, Infector of Souls, Lord De Seis, Grand Vizier of Chaos |
| Act 5 — Bloody Foothills | Minion, Overseer, Imp, Shenk the Overseer, Dac Farren |
| Act 5 — Frigid Highlands | Slayer, Lasher, Imp, Death Mauler, Eldritch the Rectifier, Sharptooth Slayer, Eyeback the Unleashed |
| Act 5 — Arreat Plateau | Ice Boar, Overlord, Seige Beast, Imp, Thresh Socket |
| Act 5 — Crystalline Passage | Rot Walker, Snow Drifter, Frozen Horror, Blood Lord |
| Act 5 — Frozen River | Reanimated Horde, Abominable, Frozen Horror, Frozenstein |
| Act 5 — Glacial Trail | Prowling Dead, Chilled Froth, Frozen Horror, Blood Lord, Bonesaw Breaker |
| Act 5 — Drifter Cavern | Unholy Corpse, Frozen Abyss, Frozen Horror |
| Act 5 — Frozen Tundra | Fire Boar, Blood Boss, Crush Beast, Imp |
| Act 5 — Ancients' Way | Defiled Warrior, Succubus, Blood Lord |
| Act 5 — Icy Cellar | Hell Spawn, Vile Temptress, Siren, Snapchip Shatter |
| Act 5 — Arreat Summit | Talic, Madawc, Korlic |
| Act 5 — Nihlathaks Temple | Unholy Corpse, Blight Wing, Stygian Fury, Pindleskin |
| Act 5 — Halls of Anguish | Defiled Warrior, Blood Witch, Mage Wing |
| Act 5 — Halls of Pain | Defiled Warrior, Blood Witch, Hell Bitch |
| Act 5 — Halls of Vaught | Defiled Warrior, Blood Witch, Hell Bitch, Nihlathak outside town |
| Act 5 — Abaddon | Hell Spawn, Blood Boss, Blood Bringer, Imp |
| Act 5 — Pit of Acheron | Hell Spawn, Blood Boss, Blood Bringer, Imp |
| Act 5 — Infernal Pit | Hell Spawn, Blood Boss, Gore Bearer, Imp |
| Act 5 — The Worldstone Keep Level 1 | Defiled Warrior, Putrid Defiler, Blood Lord |
| Act 5 — The Worldstone Keep Level 2 | Greater Hell Spawn, Putrid Defiler, Blood Lord |
| Act 5 — The Worldstone Keep Level 3 | Greater Ice Spawn, Putrid Defiler, Blood Lord |
| Act 5 — Throne of Destruction | Death Mage, Baal High Priest, Venom Lord, Baals Minion1, Colenzo the Annihilator, Achmel the Cursed, Bartuc the Bloody, Ventar the Unholy, Lister the Tormentor |
| Act 5 — Worldstone Chamber | Baal |
