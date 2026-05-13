# CanisTemplate

Starter repository for a new Canis game.

This template includes the full build shape expected by Canis:

- `canis/` as the engine submodule
- `external/` as dependency submodules
- `game/` for gameplay code
- `project/` for runtime assets and editor-facing project files
- `project_settings/` as the source project settings copied into `project/` by the build
- `cmake/`, `scripts/`, `.gitmodules`, and root `CMakeLists.txt`

## Build

```bash
git submodule update --init --recursive
cmake -S . -B build
cmake --build build -j4
```

## Run

```bash
./project/c-engine
```

## Create A Script

```bash
./scripts/create-game-script.sh Gameplay/MyScript
```

The default project opens `project/assets/scenes/default.scene`, which contains a camera, light, and cube using the generic default assets.
