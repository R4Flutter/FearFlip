# FearFlip 3D Prototype

This is the first Godot 4 prototype for the FearFlip first-person horror maze.

## Current slice

- Deterministic 13x13 maze
- Physical 3D walls and floor
- First-person mouse look
- WASD movement and collision
- Flashlight
- Goal portal
- Moving devil marker and pursuit
- Fixed north-up minimap in the upper-left
- Explored-cell minimap state
- Full ceiling and layered wall trim
- Corridor lights, floor accents, and landmark pillars
- Visible trap pads and safe-zone markers
- Imported ambient audio, trap artwork, and exit portal artwork

## Run

1. Install Godot 4.3 or newer.
2. Open this `godot` folder as a project.
3. Run the project with `scenes/main.tscn` as the main scene.
4. Click the game window to capture the mouse.
5. Use WASD to move, mouse to look, and Escape to release/capture the mouse.

The prototype uses procedural geometry with the existing FearFlip assets layered in. The next implementation slice should port the existing trap state machine, seeded maze generation, stage rules, and proper devil pathfinding from the Flutter project.
