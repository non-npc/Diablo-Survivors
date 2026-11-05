# Diablo II ranged enemy classification

Research date: 2026-10-13. This is an implementation reference, not a change to the current enemy roster.

Evidence: Blizzard's Arreat Summit bestiary and the selected classic English LoD 1.07 installation's `data/global/excel/monstats.txt`. Later-patch website statistics are not assumed to match this installation. Animation token alone does not identify behavior: SK covers melee skeletons, archers and mages; UM covers different knight roles.

## Confirmed ranged families

| Family | Projectile / role | Variants and implementation distinction |
| --- | --- | --- |
| Skeleton Archer | Arrows | Skeleton Archer, Returned Archer, Bone Warrior Archer, Burning Dead Archer, Horror Archer. Burning Dead uses fire arrows; Horror uses lightning arrows. Keep ordinary melee skeletons separate. |
| Skeleton Mage | Elemental bolts | Returned Mage, Bone Mage, Burning Dead Mage, Horror Mage; use the actual elemental variant. |
| Corrupt Rogue Archer | Arrows | Dark Ranger, Vile Archer, Dark Archer, Black Archer, Flesh Archer. Separate from melee rogue and spearwoman variants. |
| Spike Fiend / Quill Rat | Quills | Quill Rat, Spike Fiend, Thorn Beast, Razor Spine; local table also contains Jungle Urchin. Ranged-capable, with close-range melee fallback. |
| Fallen Shaman | Firebolts / resurrection support | Fallen, Carver, Devilkin, Dark and Warped shamans. Ordinary Fallen remain melee. |
| Vampire | Fire and life-steal spells | Banished, Ghoul Lord, Night Lord, Dark Lord, Blood Lord. Hybrid caster with melee fallback. Do not confuse this Blood Lord with LoD's melee frenzy family. |
| Greater Mummy | Magical missiles / resurrection support | Hollow One, Guardian, Unraveler, Horadrim Ancient; Radament is a separate boss profile. |
| Slinger / spear-throwing cats | Thrown javelins | Slinger, Spear Cat, Night Slinger, Hell Slinger. Ordinary sabre cats remain melee. |
| Blowdart Fetish | Darts | Ranged FC rows for Rat Man, Fetish, Flayer, Soul Killer and Stygian Doll. FE melee variants and undead Bone Fetishes must remain separate. |
| Willowisp / Gloam | Lightning | Gloam, Swamp Ghost, Burning Soul, Black Soul in local metadata. |
| Zakarum Priest | Spells / support | Spellcaster profile, distinct from Zakarum Zealots. |
| Abyss / Oblivion Knight | Elemental missiles; Oblivion also curses/support | Doom Knights remain melee. Skill-driven spell attacks are not always recorded in MissA1. |
| Finger Mage | Homing mana-draining magic | Separate caster profile. |
| Succubus / Stygian Fury (LoD) | Magic attacks / curses | Distinct variant profiles, not generic melee demons. Local expansion tokens 0B and 0C. |
| Demon Imp (LoD) | Fire projectiles | Teleporting caster; mounted/tower Inferno needs a separate behavior. |

## Ranged-capable enemies that need hybrid or special behavior

Local table missile assignments also identify the following; do not turn all of them into stationary archers:

- Tainted family: Afflicted, Tainted, Misshapen, Disfigured and Damned; secondary ranged attack alongside melee.
- Sand Maggots / queens: poison spit plus movement, burrowing or spawning behavior.
- Frog Demons: Swamp Dweller, Bog Creature and Slime Prince; ranged spit alongside their movement behavior.
- Tentacle Beast heads: Water Watcher, River Stalker and Stygian Watcher; specialized stationary/terrain-bound attackers.
- Regurgitators: Corpulent, Corpse Spitter and Maw Fiend; corpse-dependent ranged attack.
- Council Members: spell/summon behavior, not merely a generic projectile shooter.
- Megademons: Balrog, Pit Lord and Venom Lord; short-range breath/Inferno plus melee, not a long-range firing band.
- LoD catapults and lightning/fire traps: stationary hazards with separate targeting rules.
- Bosses and Ancients: custom profiles. For example, Madawc's throwing attack must not imply that every Ancient is ranged.

## Implementation rules

1. Identify the exact monster row, equipment/animation variant and attack skill. Never infer ranged behavior from shared sprite token or family name alone.
2. Read both missile assignments and skills. `65535` is the no-missile sentinel in this installation; a missing missile field does not prove melee-only behavior.
3. Use a preferred firing band and line of sight for ordinary ranged units. Approach when out of range; stop to shoot when a shot is possible. Let the player close the gap and use melee. Avoid universal automatic retreat, which would recreate the earlier enemy movement problem.
4. Implement close-range melee, breath, resurrection and teleport behavior only for appropriate profiles.
5. Original AI parameter meanings vary by family. Proposed screen-pixel min/max ranges must be labeled as survival balancing, not claimed as original D2 distances.
6. Limit projectile count and reuse the existing 300-enemy cap.

Implemented first batch: Skeleton Archer (bow composition), Skeleton Mage (lightning variant), Fallen Shaman and Quill Rat now have imported original animation sets, region rosters, challenges, and projectile behavior. Ordinary Skeleton, Zombie and Fallen remain melee. Shared firing-band behavior also applies to the existing D1 ranged profiles; D1 megademon breath uses a shorter band. Resurrection, teleporting, curses, and the remaining D2 caster families are future work. Range values are authored survival balancing.

## Sources

- [Blizzard: Skeleton Archer](https://classic.battle.net/diablo2exp/monsters/act1-skeleton-archer.shtml)
- [Blizzard: Skeleton Mage](https://classic.battle.net/diablo2exp/monsters/act1-skeleton-mage.shtml)
- [Blizzard: Corrupt Rogue Archer](https://classic.battle.net/diablo2exp/monsters/act1-corruptroguearcher.shtml)
- [Blizzard: Spike Fiend](https://classic.battle.net/diablo2exp/monsters/act1-spikefiend.shtml)
- [Blizzard: Fallen Shaman](https://classic.battle.net/diablo2exp/monsters/act1-fallenshaman.shtml)
- [Blizzard: Vampire](https://classic.battle.net/diablo2exp/monsters/act1-vampire.shtml)
- [Blizzard: Act II families](https://classic.battle.net/diablo2exp/monsters/act2.shtml)
- [Blizzard: Act III families](https://classic.battle.net/diablo2exp/monsters/act3.shtml)
- [Blizzard: Undead Horror / Knights](https://classic.battle.net/diablo2exp/monsters/act4-undeadhorror.shtml)
- [Blizzard: Willowisp](https://classic.battle.net/diablo2exp/monsters/act3-willowisp.shtml)
- [Blizzard: Succubus](https://classic.battle.net/diablo2exp/monsters/act5-succubus.shtml)
- [Blizzard: Demon Imp](https://classic.battle.net/diablo2exp/monsters/act5-demonimp.shtml)
- [Blizzard: Act V families](https://classic.battle.net/diablo2exp/monsters/act5.shtml)

No original game payloads are included in this document.
