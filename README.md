# AETHERWING — Godot 4.6 port

A Godot 4.6 reimplementation of `AETHERWING_prototype_v11.html` (a recursive
arcade shooter). The original is a single 7,000-line HTML/Canvas prototype; this
project ports the core game to GDScript with a node-based architecture and the
same neon-vector look (drawn procedurally via `_draw`).

## Run it

Open the folder in Godot 4.6+ and press **F5**, or from the command line:

```
"<path>/Godot_v4.6.2-stable_win64.exe" --path .
```

## Controls

| Input | Action |
|-------|--------|
| Drag (mouse/touch) | Move ship |
| Quick tap | Dash (i-frames) |
| Swipe up **or** `Q` / `Tab` | Cycle weapon |
| Hold **» BOOST** button **or** `Shift` | Boost (drains Echo) |
| `Space` | Dash |

Pick **FOLLOW** or **DIRECT** control on the start screen.

## What's implemented (faithful to the prototype)

- **World-space camera** that follows the player with smoothing, screen shake and a zoom-pulse on hits.
- **Movement**: follow/direct modes, velocity smoothing, banking, engine trail, dash with i-frames.
- **4 weapons** — Pulse (single), Lance (pierce), Spread, Singularity (gravity-well bomb) — with auto-fire at the nearest threat.
- **4 enemy types** with their behaviors — Drone (drift), Diver (aim→dive), Bulwark (directional shield), Lancer (reposition→charge→beam) — plus spawn-protection and HP scaling by wave.
- **Survivor.io-style waves**: random / circle / line / vortex / cross spawn patterns scaling with wave number.
- **XP gems → level-ups** with a 3-card upgrade draft from the full 16-upgrade pool (rarity-weighted).
- **Echo systems**: Echo meter, Echo Phase (slow-mo + 2× score), and Echo Rewind on lethal hit.
- **Combo system** with crit hits, hit-pause and lifesteal.
- **Boost** (Echo-draining speed burst) with the Overdrive / Efficient-Boost upgrades.
- **Two bosses** — The Conductor (radial batons → direct fire) and The Spiral (spawning arms, phase spin reversal, collapse) — with phase transitions and a boss bar.
- **Elite enemies** every 30s and a timed boss every 60s.
- **Daily + weekly modifiers** (deterministic by date) with their gameplay effects (swarm/elite/speed/greed/explorer, hunt-day elites, etc.), shown as badges in-game and as pills on the start screen.
- **Procedural audio**: synthesized SFX (shoot/hit/kill/dash/damage/echo/boss/pickup/rewind…) and adaptive bass+arp music that scales with your combo — same design as the WebAudio original.
- **Radar minimap** (enemy/boss blips), **world-position readout**, and **high-score persistence** (`user://aetherwing.save`).
- **FX**: smooth radial-gradient neon glow, particles, scorch decals, floating damage numbers, parallax starfield + world grid, additive bloom.
- **HUD + overlays**: score/combo/HP/wave/weapon/echo/XP, boss bar, toasts, wave intro, start / game-over / level-up screens.

## Project layout

```
project.godot        Project config (Forward+, portrait 720×1280, touch emulation)
Main.tscn            Root scene (just attaches Main.gd; tree is built in code)
scripts/
  Data.gd            Autoload — colors + all constant tables (player, echo, enemies, weapons, upgrades)
  Main.gd            Central controller: state, simulation loop, spawning, collisions, camera
  Player.gd          Ship state + neon rendering
  Enemy.gd           Enemy behavior state machine + rendering
  Bullet.gd          Player/enemy projectiles (incl. singularity well)
  Boss.gd            The Conductor + The Spiral
  XpGem.gd           Magnet-collected XP gem
  Starfield.gd       Parallax stars + world grid (screen space)
  WorldFX.gd         Particles / decals / damage numbers renderer
  HUD.gd             HUD + overlays (built in code)
  Neon.gd            Layered-glow drawing helpers
```

- **World landmarks** (cache / healing station / XP ruins / beacon) spawned on a
  deterministic 900-unit grid as you roam, with discovery, claim effects, daily-
  modifier interactions (Cache Day double upgrade, Station Day shield, Ruins Day
  3× XP, Beacon Day 120s), and an expanded-radar beacon buff.
- **World mini-bosses** (Warden / Stalker / Sentry — chase / fast-zigzag / ranged)
  that guard ~25% of landmarks; defeat one to auto-claim the landmark. Own health
  bar, radar blip, and spawn protection.

## Mobile

The project targets the **Mobile renderer** and is built portrait-first with
touch input (drag move, tap dash, swipe-up weapon swap, on-screen boost button),
so the gameplay is mobile-appropriate. To actually ship to a device you still
need to: install the Android/iOS export templates, set up an export preset (and
Android SDK + JDK), and ideally handle safe-area insets so the HUD clears the
notch. See the chat summary for the full checklist.

## Still to port

Remaining prototype systems: off-screen enemy indicators + landmark direction
arrows, the daily missions card & login streak, the settings panel, and the
(mock) rewarded-revive / share-image monetization screens.
