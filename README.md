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
cmake --preset debug
cmake --build --preset debug -j24
```

Project identity lives in `project_settings/project.canis`:

```yaml
gameName: Canis Game
executableName: c-engine
```

`gameName` is the human-facing window title. `executableName` must not contain
spaces and is read by root CMake to name the executable target and output file.
Reconfigure CMake after changing `executableName`.

## Run

```bash
./project/c-engine
```

The editor's **Launch** button starts a separate game-only process. An empty
`launchExecutablePath` is recommended because Canis then launches the currently
running product executable from the correct runtime directory.

## Runtime validation

Canis supports deterministic, offscreen scene capture. After building:

```bash
./scripts/capture-runtime-scene.sh \
  assets/scenes/default.scene validation/default.png 1280 720 1
```

## Native package

```bash
JOBS=24 ./scripts/package-native.sh
```

The relocatable package is written to `build-native-release/package`.

## Web build

```bash
CANIS_SKIP_EMSDK_BOOTSTRAP=1 JOBS=24 ./scripts/build-web.sh web-release
```

The template includes a generic Emscripten shell and IDBFS persistence setup in
`project/web/`. Customize the HTML title and loading presentation for the game.

## Prefabs

Prefab instances retain a source link in the editor. **Rebuild All Prefabs In
Scene** now refreshes outer prefabs before recursively rebuilding nested prefab
instances, so nested UI and model prefabs are not overwritten by a stale parent
expansion.

## Create A Script

```bash
./scripts/create-game-script.sh Gameplay/MyScript
```

The default project opens `project/assets/scenes/default.scene`, which contains a camera, light, and cube using the generic default assets.
