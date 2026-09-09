# Scene-scoped Entity values

`Entity` is the sole entity reference type. Its only data members are `entt::entity` and `Scene&`. There is no separate entity handle, per-reference allocation, shared entity lifetime record, or registration of variable addresses.

```cpp
auto player = scene.CreateEntity("Player");
player.AddComponent<Canis::Transform>()->position = Canis::Vector3(0, 1, 0);
player.SetTag(Tags::Player);

Canis::Entity target = player;
player.Destroy();
assert(!target.IsValid());
assert(target.TryGetComponent<Canis::Transform>() == nullptr);
```

Copying a value copies its versioned EnTT identity and scene reference. Destroying a wrapper does not destroy its entity. `Destroy()` requests scene-managed deletion; pending subtree deletion immediately invalidates public reference lookup. Deleted IDs remain in variables but fail validation. EnTT generations are preserved across scene reloads, so slot reuse does not revive old values.

Every use of a nonempty value must occur while its Scene exists. Reset or discard references before destroying their scene. `Entity` does not provide protection against a dangling `Scene&`.

## Empty values and assignment

```cpp
Canis::Entity target;       // entt::null, bound to a shared empty scene
if (!target) { /* no target */ }
target = scene.CreateEntity("Target");
target = nullptr;           // or target.Reset()
std::vector<Canis::Entity> targets;
```

A reference cannot be null or rebound by ordinary member assignment. Default empty values therefore bind to a shared inert Scene; assigning another Entity reconstructs the two-field wrapper to bind the destination scene. This neither registers the variable nor changes the underlying entity. Equality compares scene identity and the complete EnTT ID. Comparison with nullptr tests validity.

`TryGet()` and the transitional pointer conversion return a short-lived scene-owned borrow. The pointer constructor requires a live borrow. Prefer storing values. Existing script constructors and component owner pointers use a stable scene-owned wrapper, so attaching through a temporary Entity value does not retain its address.

## Registry data

`EntityMetadata` stores UUID, name, numeric tag, active state, and editor lock. Access it through `GetMetadata()` or the metadata accessors (`GetName`, `SetName`, `GetUUID`, `GetTag`, `Active`, `EditorLocked`). Scene owns ordering and its lookup: `scene.GetEntityIndex(entity)` returns a transient slot, never persistent identity.

`Entity.hpp` contains the wrapper and script base/API. `Components.hpp` contains built-in component definitions. Include the latter when using Transform, renderers, colliders, or UI components.

`GetComponent<T>()` throws for a missing component. `TryGetComponent<T>()` returns null for an invalid reference or missing component. `AddComponent<T>()` returns a pointer; `GetOrAddComponent<T>()` returns a reference. Plain data components do not need an owner field.

## Multiple scripts

```cpp
auto movement = player.AddScriptHandle<FPSController>();
auto inventory = player.AddScriptHandle<Inventory>();
player.RemoveScript(movement);
assert(!movement && inventory);
```

`AddScript`, `GetScript`, `GetScripts`, and removal stay on Entity. The first script creates an optional `ScriptComponent`; the last removal deletes it. Lookup never creates storage. Multiple different script types are supported; repeated instances of the same type are not added by this migration.

`ScriptHandle<T>` remains a separate script-instance reference so removing and reattaching a script does not revive a cached script pointer. Script callback mutation is deferred until callbacks finish; iteration uses snapshots.

## Serialization and editor

Scene/prefab files retain UUID references and readable tag names. Loading creates every entity first and then decodes properties, so forward references and prefab remapping resolve immediately. Reference vectors can move without leaving pending writes to their old addresses.

Scene keeps missing/deleted-reference UUIDs in serialization maps keyed by invalid versioned EnTT IDs. Entity values contain no cached UUID or fixup pointer. This history is retained until scene unload. The inspector displays missing targets safely and allows clearing/replacement; saving preserves the missing UUID. Undo/Redo reload scene snapshots and restore authored references, while old runtime values remain invalid.

Tags use stable 64-bit IDs matching generated `Tags` enum values. Enum checks compare integers; string overloads hash once per query. Reordering project tags does not renumber IDs. Projectile target-tag lists also use numeric IDs.
