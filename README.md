# Cloudspire — The Ten Bells

A 3D jumping puzzle in a single HTML file, built with three.js.

**Play: https://chixaelm.github.io/cloudspire/**

Climb a 300 m mountain spire as a small monk. The slope is kind at first, then leans out over you. Ring the ten temple bells as checkpoints; you have three lives, and losing all of them sends you back to the foot. Glowing spirit stones mark harder side routes, each ending in a koi that banks a one-use perk (slow fall, double jump, undo, extra life).

Higher up the mountain gets stranger: turning beams you can only board when they point your way, shelves of blue ice that slide underfoot, lotus leaves that fade in and out, and a wind that gusts in pulses and pushes you sideways in the air — wait for the lull.

**Paths** set the stakes: *Pilgrim* (endless lives), *Monk* (three lives) and *Ascetic* (one). **Peaks** change the route: *Cloudspire*, the gale-swept *Windward Tooth* and the icy *Frozen Needle*. Best times are kept per peak and path, and the climb is saved at every bell, so you can close the game and continue later.

## Controls

| | Desktop | Touch |
|---|---|---|
| Move | W A S D | Left thumbstick |
| Look | Mouse | Drag the right side |
| Jump | Space (hold for height) | Jump button (hold for height; drag it to look) |
| Perks | Shift, Space in air, Z, X | Tap the perk |
| View | V | ◉ button |
| Graphics | G | Title screen |

Graphics has Low, High and Ultra settings. Phones start on Low.

On a phone it installs as a full-screen app: in Safari use Share → Add to Home Screen, in Chrome use the menu → Install app. Once loaded it also works offline. If a phone cannot hold the frame rate the game lowers its render resolution by itself.

The game is all in `index.html`; three.js loads from a CDN.

`?bot&fast` (main route) and `?bot=2&fast` (every koi route) run a headless bot up the mountain to prove each jump is makeable; add `&m=0..2` to pick the peak.
