// Setup script for initializing the brush system in Godot
using TiltBrush;
using UnityEngine;

/// <summary>
/// Helper script to set up the brush system.
/// Attach this to a node in your scene to automatically load brushes.
/// </summary>
public partial class BrushSystemSetup : MonoBehaviour
{
	[Godot.Export] public bool AutoLoadBrushes = true;
	[Godot.Export] public string BrushesPath = ""; // Leave empty for default

	private TiltBrushManifest _manifest;

	public TiltBrushManifest Manifest => _manifest;

	public override void Awake()
	{
		base.Awake();

		if (AutoLoadBrushes)
		{
			LoadBrushes();
		}
	}

	/// <summary>
	/// Loads brushes from manifest files.
	/// </summary>
	public void LoadBrushes()
	{

		var projectPath = Godot.ProjectSettings.GlobalizePath("res://");
		var manifestPath = System.IO.Path.Combine(projectPath, "Manifest.asset");

		_manifest = UnityAssetLoader.LoadManifest(manifestPath);

		// Optionally merge experimental brushes
		var experimentalPath = System.IO.Path.Combine(projectPath, "Manifest_Experimental.asset");
		if (System.IO.File.Exists(experimentalPath))
		{
			var experimentalManifest = UnityAssetLoader.LoadManifest(experimentalPath);
			_manifest.AppendFrom(experimentalManifest);
		}

		if (_manifest != null && _manifest.Brushes != null)
		{
			BrushCatalog.Init(_manifest);
			Godot.GD.Print($"Brush system initialized with {_manifest.Brushes.Length} brushes");
		}
		else
		{
			Godot.GD.PushError("Failed to load brush manifest");
		}
	}

	/// <summary>
	/// Gets a brush by its durable name (e.g., "Ink", "Light", etc.)
	/// </summary>
	public BrushDescriptor GetBrushByName(string durableName)
	{
		if (_manifest?.Brushes == null) return null;

		foreach (var brush in _manifest.Brushes)
		{
			if (brush.m_DurableName == durableName)
				return brush;
		}

		return null;
	}

	/// <summary>
	/// Gets the first available brush (useful for testing).
	/// </summary>
	public BrushDescriptor GetDefaultBrush()
	{
		if (_manifest?.Brushes != null && _manifest.Brushes.Length > 0)
		{
			return _manifest.Brushes[0];
		}
		return null;
	}
}
