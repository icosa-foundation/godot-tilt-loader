# Unity to Godot Compatibility Layer

This compatibility layer allows Unity C# scripts to run in Godot with minimal modifications.

## How It Works

The wrapper uses **Godot's native types directly** via global type aliases, rather than creating duplicate types. This means:

- `Vector3` → `Godot.Vector3` (global type alias)
- `Quaternion` → `Godot.Quaternion` (global type alias)
- `Color` → `Godot.Color` (global type alias)
- Extension methods add Unity-specific APIs where needed

These global aliases are defined in `Scripts/GlobalUsings.cs` and apply to all files in the project automatically.

## Files Included

### Core Math Types (`UnityMathTypes.cs`)
- Type aliases for Vector2, Vector3, Vector4, Quaternion, Color
- Matrix4x4 wrapper (thin wrapper around Transform3D)
- Color32 struct (byte-based color for Unity compatibility)
- Extension methods for Unity-style API access

### Math Utilities (`UnityMathf.cs`)
- Static Mathf class with all common Unity math functions
- Wraps System.Math for most operations

### Core Unity Classes (`UnityCore.cs`)
- `Debug` - Logging wrapper (maps to GD.Print, GD.PushWarning, etc.)
- `Time` - Time utilities (maps to Godot.Time)
- `Transform` - Wrapper around Node3D for transform operations
- `GameObject` - Wrapper around Node3D with component system
- `MonoBehaviour` - Base class for Unity-style scripts (non-Godot version)
- `Object` - Static methods like Instantiate, Destroy

### Mesh & Rendering (`UnityMesh.cs`)
- `Mesh` - Wrapper around ArrayMesh
- `MeshFilter` - Component for mesh rendering
- `Renderer` - Component for material/visibility control
- `Material` - Wrapper around Godot materials

### MonoBehaviour (`MonoBehaviour.cs`)
- Unity's MonoBehaviour base class implemented as a Godot Node3D
- Automatically bridges Unity lifecycle (Awake, Start, Update) to Godot (_Ready, _Process)
- Provides GameObject and Transform access
- Handles component system integration
- Original Unity scripts using `MonoBehaviour` work without modification

### Localization Stub (`UnityLocalization.cs`)
- Minimal pass-through implementation of `LocalizedString`
- No actual localization - just stores plain strings
- Provides async API compatibility with Unity's Localization package

### Unity Attributes (`UnityAttributes.cs`)
- Stub implementations of Unity inspector attributes
- `[SerializeField]`, `[Range]`, `[Tooltip]`, `[Header]`, etc.
- These don't affect Godot's inspector - use `[Export]` for that
- Present only for compilation compatibility


## Usage

### For Unity Scripts (New or Existing)

Unity scripts work directly without modification! Just inherit from `MonoBehaviour` as usual:

```csharp
using UnityEngine;

namespace MyNamespace
{
    public partial class MyScript : MonoBehaviour
    {
        // Must use 'partial' keyword for Godot source generators

        public void Awake()
        {
            Debug.Log("Script initialized!");
        }

        public void Update()
        {
            transform.position += Vector3.Forward * Time.deltaTime;
        }
    }
}
```

**Key points:**
- Use `MonoBehaviour` just like in Unity
- Add `partial` keyword to class declaration (required by Godot)
- `using UnityEngine;` brings in the compatibility layer
- Lifecycle methods work automatically (Awake, Start, Update, etc.)

### Attaching Scripts in Godot

1. Create a Node3D in your scene
2. Attach your script (drag .cs file or use "Attach Script" button)
3. The script will automatically integrate with Godot's scene system

## Current Limitations

### Not Yet Implemented
- Prefab instantiation (Object.Instantiate for prefabs)
- Physics (Rigidbody, Collider, etc.)
- UI system (Canvas, Button, etc.)
- Audio system (AudioSource, AudioClip)
- Input system (Input class)
- Coroutines
- Animation system
- Particle systems (beyond the brush particle scripts)

### Partial Implementation
- Component system (basic GetComponent/AddComponent only)
- Material system (limited property access)
- Mesh operations (core functionality present)

## Type Mapping Reference

| Unity Type | Godot Type | Notes |
|------------|------------|-------|
| Vector2 | Godot.Vector2 | Direct alias |
| Vector3 | Godot.Vector3 | Direct alias |
| Vector4 | Godot.Vector4 | Direct alias |
| Quaternion | Godot.Quaternion | Direct alias |
| Color | Godot.Color | Direct alias |
| Matrix4x4 | Custom wrapper | Wraps Transform3D |
| Transform | Custom wrapper | Wraps Node3D |
| GameObject | Custom wrapper | Wraps Node3D |
| MonoBehaviour | GodotMonoBehaviour | Extends Node3D |
| Mesh | Custom wrapper | Wraps ArrayMesh |

## Coordinate System Differences

Unity and Godot use different coordinate systems:

- **Unity**: Y-up, left-handed
- **Godot**: Y-up, right-handed

This wrapper does NOT automatically convert coordinates. You may need to adjust:
- Z-axis directions (Forward/Back may need negation)
- Cross product operations
- Mesh winding orders

## Performance Notes

- Type aliases have zero overhead (compile-time only)
- Transform/GameObject wrappers have minimal overhead
- Component lookups cache results where possible
- Mesh operations map directly to Godot's ArrayMesh

## Extending the Wrapper

To add missing Unity APIs:

1. For math operations: Add to `UnityMathf.cs`
2. For type extensions: Add to `UnityMathExtensions` class
3. For new components: Add wrapper in appropriate file
4. For lifecycle methods: Extend `GodotMonoBehaviour`
