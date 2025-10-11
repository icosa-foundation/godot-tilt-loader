# Godot Setup Guide for Unity Scripts

This guide will help you get your Unity-based TiltBrush stroke generation code running in Godot.

## Project Structure

```
open-brush-stroke-gen-godot/
├── Scripts/
│   ├── UnityEngine/          # Unity→Godot compatibility layer
│   │   ├── UnityMathTypes.cs
│   │   ├── UnityMathf.cs
│   │   ├── UnityCore.cs
│   │   ├── UnityMesh.cs
│   │   ├── GodotMonoBehaviour.cs
│   │   └── README.md
│   ├── Brushes/              # Brush implementations
│   ├── Util/                 # Utility classes
│   └── *.cs                  # Core scripts
└── project.godot
```

## What's Been Done

### 1. Unity Compatibility Layer ✓

All Unity types now use Godot's native types:
- `Vector2/3/4` → Direct aliases to `Godot.Vector2/3/4`
- `Quaternion` → Direct alias to `Godot.Quaternion`
- `Color` → Direct alias to `Godot.Color`
- `Mathf`, `Debug`, `Time` → Wrapped to use Godot APIs

### 2. MonoBehaviour Implementation ✓

`MonoBehaviour` is implemented as a Godot `Node3D` that automatically:
- Maps Unity lifecycle methods to Godot
- Original Unity scripts work without modification
- Just requires `partial` keyword for Godot source generators

### 3. Coordinate System Wrapper ✓

The `Coords` class is preserved as-is and should work with the transform wrappers.

## Next Steps

### Step 1: Build the Project

In Godot Editor:
1. Open the project in Godot 4.5+ with .NET support
2. Go to **Project → Tools → C# → Create C# Solution**
3. Build the project: **Build → Build Project** (or click the hammer icon)
4. Check for compilation errors in the **Output** panel

### Step 2: Fix Any Remaining Issues

Look for these common issues:

#### Issue: Missing Types
If you see errors about missing Unity types:
- Check if the type is in the compatibility layer
- Add missing wrappers to the appropriate `UnityEngine/*.cs` file

#### Issue: Namespace Conflicts
If `Vector3` or other types are ambiguous:
```csharp
// Add explicit using at top of file
using Vector3 = Godot.Vector3;
```

#### Issue: Property vs Field Access
Unity uses properties differently than Godot:
```csharp
// Unity
transform.position = new Vector3(0, 1, 0);

// If this fails, the wrapper may need adjustment
```

### Step 3: Create a Test Scene

1. Create a new 3D scene in Godot
2. Add a `CanvasScript` node (Node3D with CanvasScript attached)
3. Add a `PointerScript` node (Node3D with PointerScript attached)
4. Configure the pointer to reference the canvas

Example scene structure:
```
Main (Node3D)
├── Canvas (Node3D) [CanvasScript.cs attached]
└── Pointer (Node3D) [PointerScript.cs attached]
    └── set Canvas property → reference to Canvas node
```

### Step 4: Initialize Brush System (AUTOMATIC)

**NEW**: The system now automatically loads Unity `.asset` files at runtime!

#### Setup Method 1: Using BrushSystemSetup (Recommended)

1. Add a `BrushSystemSetup` node to your scene:
   ```
   Main (Node3D)
   ├── BrushSystemSetup (Node3D) [BrushSystemSetup.cs]
   ├── Canvas (Node3D) [MinimalExample.cs or your script]
   └── Pointer (Node3D) [PointerScript.cs]
   ```

2. The `BrushSystemSetup` will automatically:
   - Load all `.asset` files from `Resources/Brushes/Basic/`
   - Parse brush descriptors (GUID, name, size range)
   - Initialize `BrushCatalog`

3. Reference it in your script:
   ```csharp
   using Godot;
   using TiltBrush;
   using UnityEngine;

   public partial class MinimalExample : MonoBehaviour
   {
       [Export] public BrushSystemSetup BrushSystem;
       [Export] public PointerScript Pointer;

       private CanvasScript m_Canvas;
       private BrushDescriptor m_DefaultBrush;

       void Start()
       {
           // Brushes already loaded - just get a reference
           m_DefaultBrush = BrushSystem.GetBrushByName("Ink")
                         ?? BrushSystem.GetDefaultBrush();

           GD.Print($"Using brush: {m_DefaultBrush?.m_DurableName}");

           m_Canvas = gameObject.AddComponent<CanvasScript>();
           Pointer.Canvas = m_Canvas;
       }
   }
   ```

#### Setup Method 2: Manual Loading

If you want more control:

```csharp
using Godot;
using TiltBrush;
using UnityEngine;

public partial class StrokeGenDemo : MonoBehaviour
{
    [Export] public PointerScript Pointer;
    [Export] public CanvasScript Canvas;

    public void Awake()
    {
        // Load brushes from Unity .asset files
        var brushesPath = UnityAssetLoader.GetDefaultBrushesPath();
        var manifest = UnityAssetLoader.CreateManifestFromDirectory(brushesPath);

        // Initialize brush catalog
        BrushCatalog.Init(manifest);

        // Get a specific brush by name
        var inkBrush = manifest.Brushes.FirstOrDefault(b => b.m_DurableName == "Ink");

        // Set up pointer
        if (Pointer != null && Canvas != null)
        {
            Pointer.Canvas = Canvas;
            Pointer.m_CurrentColor = new Color(1, 0, 0, 1); // Red
            Pointer.BrushSize01 = 0.5f;
        }
    }

    public void Update()
    {
        // Example: Enable drawing when pressing space
        if (Input.IsKeyPressed(Key.Space))
        {
            Pointer.DrawingEnabled = true;
        }
        else
        {
            Pointer.DrawingEnabled = false;
        }
    }
}
```

#### How It Works

The `UnityAssetLoader` class:
- Scans `Resources/Brushes/Basic/` for `.asset` files
- Parses YAML format to extract:
  - `m_Guid` - Brush unique identifier
  - `m_DurableName` - Human-readable name
  - `m_BrushSizeRange` - Min/max sizes
- Creates `BrushDescriptor` objects dynamically
- Populates `TiltBrushManifest.Brushes` array

**No manual asset conversion needed!** Your Unity brush `.asset` files work directly in Godot.

## Known Limitations

### Not Yet Implemented

1. **BrushDescriptor Loading** ✓ DONE
   - Unity `.asset` files are now loaded at runtime via `UnityAssetLoader`
   - Brush GUIDs, names, and properties are parsed automatically
   - **TODO**: Brush prefabs still need conversion to Godot scenes

2. **Material System**
   - Unity shaders need to be ported to Godot shaders
   - Material properties may need manual mapping

3. **Batch Rendering**
   - `BatchSubset` and batching system needs Godot implementation
   - For now, disable batching (`m_bCanBatch = false`)

4. **Mesh Finalization**
   - `FinalizeBatchedBrush()` is stubbed out
   - Only `FinalizeSolitaryBrush()` is partially implemented

5. **Component System**
   - `GetComponent<T>()` has basic implementation
   - May not find all Unity component types

### Coordinate System Notes

Unity and Godot have different conventions:
- Both are Y-up
- Unity is left-handed, Godot is right-handed
- You may need to negate Z-axis in some calculations

## Testing Strategy

### Phase 1: Compilation ✓
- Ensure all scripts compile without errors

### Phase 2: Basic Initialization
- Create scene with Canvas and Pointer
- Verify scripts initialize without crashes

### Phase 3: Simple Stroke
- Try creating a simple stroke with a basic brush
- Check if geometry is generated

### Phase 4: Full System
- Test with actual brush descriptors
- Verify all brush types work correctly

## Troubleshooting

### "Type 'Vector3' is ambiguous"
Add explicit using:
```csharp
using Vector3 = Godot.Vector3;
```

### "Cannot convert from 'Godot.Vector3' to 'UnityEngine.Vector3'"
This shouldn't happen with the current wrapper. If it does, ensure you're using the compatibility layer correctly.

### "BaseBrushScript.Create fails"
This likely means:
- Brush prefab/scene is missing
- Material is not set up
- GameObject instantiation isn't working

Check the `Create()` method in `BaseBrushScript.cs` and ensure:
```csharp
GameObject line = Instantiate(desc.m_BrushPrefab);
```
...has a valid prefab. You may need to create Godot scenes for brushes.

### MeshFilter/Renderer not found
Ensure your brush GameObject has a MeshInstance3D child node, or modify `GodotMonoBehaviour.GetComponent<T>()` to handle your scene structure.

## Next Development Steps

1. **Create Brush Scenes**
   - Convert Unity brush prefabs to Godot scenes
   - Each brush needs a scene with MeshInstance3D

2. **Port Shaders**
   - Convert Unity shaders to Godot shader language
   - Map material properties

3. **Implement BrushCatalog**
   - Load brush descriptors from JSON/resources
   - Initialize brush registry

4. **Test Each Brush Type**
   - Start with simplest brush (QuadStripBrush)
   - Work up to complex brushes (particles, etc.)

5. **Optimize Performance**
   - Profile mesh generation
   - Consider using Godot's immediate geometry for preview

## Additional Resources

- [Godot C# API Documentation](https://docs.godotengine.org/en/stable/classes/index.html)
- [Unity→Godot Migration Guide](https://docs.godotengine.org/en/stable/tutorials/migrating/index.html)
- See `Scripts/UnityEngine/README.md` for detailed wrapper documentation
