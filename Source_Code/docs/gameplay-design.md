# Gameplay milestone plan

M0 demo: bounded arena, original SVG hero, WASD/arrow movement, orbiting visual effects, Escape exit, explicit manifest and headless movement smoke. Props are decorative; no combat, collision navigation or progression is claimed.

M1: shared data-driven actors, auto-target/attack, pursuing enemies, paced waves, pickups/XP, three upgrade choices, summons, death/victory/restart and saved settings. Add seeded combat tests and a ten-minute manual run. Imported art is not required for the vertical slice.

A separate generic import-preview scene now demonstrates external actor sheets and composed floor tiles in Godot. It has movement and authored preview animation timing, with no combat/progression. This provides a validated resource handoff for the later shared survival runtime; it does not replace M1 acceptance requirements.
