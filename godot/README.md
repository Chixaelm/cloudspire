# Monk's Edge — Godot mock-up

A first-person, physics-led version of the game for Godot 4. This is a feel test: one level, blocked out in
plain shapes, with the full movement set.

## Run it

1. Install Godot 4.6 or newer (standard build, not .NET) from godotengine.org.
2. In Godot's project list choose **Import**, pick this folder's `project.godot`, then press **F5**.

Click the window to capture the mouse. A controller works as soon as it is connected.

## Controls

| | Keyboard / mouse | Controller |
|---|---|---|
| Run | W A S D | Left stick |
| Look | Mouse | Right stick |
| Jump (hold for a full leap, tap for a hop; again in the air) | Space | A / LB |
| Crouch · slide · ricochet | Shift, C, Ctrl or right mouse | B / LT / click right stick |
| Back to last checkpoint | R | Y |
| Pause | Esc | Start |

## The physics

Units are metres and seconds, gravity is 16 (heavier than real so jumps feel snappy), and the body is 1.8 m tall. The second jump is the only cheat.

- **Pace**: you reach a 5.5 m/s jog almost at once and build to an 8.5 m/s sprint over about two seconds of
  not stopping. Stopping from a sprint takes under a tenth of a second, and turning round is about as quick.
- **Jumping**: a held jump rises about 1 m; a jog carries it about 4.4 m. You can steer firmly in the air (up to 5 m/s in a new direction),
  and pulling back brakes you.
- **Slide**: crouch while running. You get a shove of about 1.3 m/s, then friction (coefficient 0.36) takes
  roughly 5.8 m/s off every second. On a slope steeper than about 20° gravity wins and the slide speeds up.
- **Wall run**: jump into a wall at a shallow angle while sprinting. Your feet carry at most 85% of your weight,
  less the slower you go, and the grip fades to nothing over 1.6 s. Jump to kick off.
- **Ricochet**: hit a surface angled between 12° and 80° at speed and press crouch within 0.14 s of the impact,
  before or after. Instead of sticking, 80% of the speed you drove into the surface comes back out.

Every number above is an exported property on the player (`scripts/player.gd`). While the game runs, select
the `Player` node in the editor's **Remote** scene tree and change them live in the Inspector.

## Level one — the Courtyard of First Steps

Run, jump, build pace, second jump; three checkpoints; ring the bell. Through the gate behind the bell is a
**proving yard**, which is not part of level one: a tower with a 28° slope for slides, a wedge for ricochets
and a long wall for wall runs, so the later moves can be judged now.

## Layout

- `scripts/player.gd` — the body and all movement
- `scripts/level_01.gd` — the level, the sun, sky and fog
- `scripts/build.gd` — helpers that make a mesh and its matching collision shape together
- `scripts/hud.gd` — speed read-out, timer, messages, and the touch controls
- `scripts/main.gd` — controls and start-up
- `scripts/selftest.gd` — headless checks

The level is built in code rather than as an editor scene, so nothing appears in the 3D editor until you press
play. That was the quickest way to block it out; it can move to editable scenes once the feel is settled.

## Self-test

```
godot --headless --fixed-fps 120 --path . -- --selftest
```

Drives the real controls and prints measured pace, jump arcs, slide drag, slope slide, ricochet and wall run,
then sends a simple runner through the level to the bell.
