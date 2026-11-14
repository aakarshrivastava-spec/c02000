# Cosmos: Odyssey '2000 (Godot 4 version)

Godot 4 remake of the web game in `Cosmos-Odyssey-2000/`. Same rules, same events, same numbers.
Built and tested on Godot 4.3 (standard build, not .NET). It should open in 4.3, 4.4 and 4.5.

## Run
1. Open Godot 4, press **Import**, pick `project.godot`, then press **F5**.
2. Everything is built in code. There are no images or sounds to import.

## Controls
- Menus: click, or press the number shown on the option. **Enter** continues.
- Free camera at stops: drag with the left mouse button, mouse wheel to zoom.
- Asteroid fields: arrow keys / WASD, or hold the left mouse button and drag.
- **F11** toggles fullscreen. The **Sound** button (bottom right) turns the drone and beeps on.
- Crew screen has a **Quick start** button (Pilot + Engineer + Medic) for fast demos.

## Files
- `scripts/data.gd` stops, routes, crew, subsystems (from data.js)
- `scripts/state.gd` mission rules, damage, repair, re-entry, score (from state.js)
- `scripts/events.gd` malfunctions, solar flare, power drop (from events.js)
- `scripts/world.gd` Solar System scene, routes, labels (from world.js)
- `scripts/ship.gd` spacecraft that scorches and bends as it is damaged (from ship.js)
- `scripts/corridor.gd` hand-flown asteroid field (from corridor.js)
- `scripts/ui.gd` all menus and HUD
- `scripts/main.gd` game flow (from main.js)
- `shaders/` planet, disk, ring, glow shaders

## Automated test options (optional)
Run from a terminal: `godot --headless --path . -- --bot=smart --speed=25`
Bots: `smart`, `lazy`, `random`, `dumb`. It prints a `RESULT {...}` line at the end.

## Export for the demo (Windows)
1. Editor menu: Project > Export. Click "Manage Export Templates" and download the templates once.
2. Select the "Windows Desktop" preset and click Export Project. Untick "Export With Debug".
3. Test the .exe on the demo laptop, offline.

## Mission Campaign
The start screen offers **Mission Campaign** (5 levels, 20 stages, 5 special missions) or the classic Grand Tour.
- `scripts/campaign_data.gd` destinations (real science + game hazard severities), equipment, levels
- `scripts/mission.gd` spacecraft design, mission state, Environmental Damage Engine, operations, probe, scoring
- `scripts/challenges.gd` universal mission challenges, planetary events, engineering decisions
- `scripts/campaign.gd` campaign flow and screens (briefing, design, Mission Lab, assessment)
- Progress is saved in `user://campaign.cfg`.
- Test one stage: `godot --headless --path . -- --bot=smart --speed=40 --campaign=5 --diff=advanced` (prints `CAMPAIGN_RESULT {...}`). Special missions: `--campaign=sm1` to `sm5`. `--unlock` opens every stage.

## Differences from the web version
- Saturn moved from 165 to 120 degrees on its orbit. In the web version it sat exactly behind the comet.
- Menus accept number keys. Fullscreen on F11.

## Added on 14 Nov 2026
- **Mission Campaign reconnected.** After the title screen the game asks: Mission Campaign or Grand Tour.
- **Cinematic introductions.** Letterboxed camera sequence with captions before each briefing. A level introduction plays on the first stage of a level; every stage shows the approach to its destination. Enter, click or any controller button skips it.
- **Visual damage.** Dust builds up on the solar panels, impact marks appear on the hull as structure drops, five status lights on the fuselage (instruments, comms, power, navigation, thermal) and a light on each landing foot change colour with condition. The Grand Tour ship also shows impact marks and status lights.
- **Rover.** A six-wheeled rover is deployed after landing when the design has one. It drives on "drive" actions. Its wheels darken, bend, wobble and finally collapse as Rover Mobility drops.
- **Power redistribution.** Power management now also asks which systems keep power first: even share, thermal control, instruments or communications. Each has a cost (see `PRIORITIES` in `scripts/mission.gd`).
- **More rewards.** Level 01: compact camera and spacecraft model choice. Level 02: all-terrain rover. Level 03: low-power ice radar and the custom spacecraft builder. Level 04: adaptive thermal system and miniature mass spectrometer. Level 05: gold colours. Locked items are shown greyed out in the design screen.
- Test options: `--campvis` keeps camera moves and cinematics on during a bot run. `--shot=fx --cond=45` and `--shot=roverfx --cond=15` save a picture of the damage visuals to `/tmp`.
- The scripts as they were before these changes are in `_backup_2026-11-14/` (Godot ignores that folder).

## Added on 14 Nov 2026 (second update): assembly hall, launch pad, entry and landing

- **Assembly hall** (`scripts/assembly.gd`, `run_build`). After the design screen the player can build the
  spacecraft: 5 engine steps (combustion chamber, turbopumps and injector, bell nozzle, propellant tanks,
  hot-fire test), 5 spacecraft steps (main structure and engine fitting, power, thermal protection,
  communications, instruments and rover) and a test step (vibration, thermal-vacuum). Each step is one
  question. The parts fitted follow the player's own design. 11 of 11 earns one extra spare part.
  The player can skip the build at the start or at any question.
- **Launch pad** (`run_launch`). Readiness poll, T-10 countdown, lift-off, Max-Q, booster separation,
  stage separation, fairing separation and spacecraft separation. The rocket matches the launcher chosen
  (light, medium, heavy). Enter, Space, a click or a controller button skips it. The Grand Tour uses it too.
- **Entry and landing** (`surface.gd`, `descent`). Worlds with air: glowing entry, parachute, then powered
  descent. Airless worlds: engines only. Low-gravity worlds: slow approach and anchors. Captions explain each phase.
- Test: `--shot=pad --body=light|medium|heavy --snap=2` saves frames of the launch to /tmp.
