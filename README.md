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
python3 -m pip install -r game/tools/requirements-input.txt
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

## Input actions and entity values

The Input Actions editor edits `project_settings/input.canis`. Rebuild after changing action names or IDs to regenerate `InputActions.generated.hpp`. Gameplay starts enabled; enable the UI map when opening menus. Default glyph sheets cover English keyboards, Xbox, PlayStation, Switch, and Steam controllers.

```cpp
#include <InputActions.generated.hpp>
#include <Canis/InputManager.hpp>

auto& input = scene.GetInputManager();
auto jump = input.Action(InputAction::Jump);
// Select a controller with input.Action(InputAction::Jump, controllerIndex).
```

Steam Input is optional and disabled by default. Native builds can enable it with `-DCANIS_ENABLE_STEAM_INPUT=ON -DCANIS_STEAMWORKS_SDK=/path/to/sdk`. Generated Steam manifests are placed under the build directory's `game/generated/steam`; published controller configurations remain project-specific.

Project tags generate `Tags.generated.hpp` with stable numeric IDs. Add uppercase-leading tag names in Project Settings, then rebuild. Include `Canis/Components.hpp` when using built-in components. Store entity references as `Canis::Entity` values and check validity before access; their owning scene must still exist. Multiple different scripts live in an optional `ScriptComponent`, managed through Entity's script methods. See [entity API](docs/entities.md).

Run the engine and generator checks with `ctest --test-dir build --output-on-failure`. Native GCC/Clang builds can enable AddressSanitizer and UndefinedBehaviorSanitizer with `-DCANIS_ENABLE_SANITIZERS=ON`.
