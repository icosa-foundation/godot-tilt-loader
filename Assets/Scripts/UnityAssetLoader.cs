// Unity Asset Loader - Loads Unity .asset files (YAML format) at runtime
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using TiltBrush;
using UnityEngine;

namespace TiltBrush
{
	/// <summary>
	/// Helper to load Unity .asset files from the Resources folder at runtime.
	/// This allows us to use the original Unity brush descriptors without manual conversion.
	/// </summary>
	public static class UnityAssetLoader
	{
		/// <summary>
		/// Creates a manifest by loading all BrushDescriptor .asset files from a directory.
		/// </summary>
		public static TiltBrushManifest CreateManifestFromDirectory(string directoryPath, bool includeSubdirectories = true)
		{
			var manifest = new TiltBrushManifest();
			var brushDescriptors = new List<BrushDescriptor>();

			if (!Directory.Exists(directoryPath))
			{
				Debug.LogError($"Directory not found: {directoryPath}");
				return manifest;
			}

			var searchOption = includeSubdirectories ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
			var assetFiles = Directory.GetFiles(directoryPath, "*.asset", searchOption);

			Debug.Log($"Found {assetFiles.Length} .asset files in {directoryPath}");

			foreach (var assetFile in assetFiles)
			{
				try
				{
					var descriptor = LoadBrushDescriptor(assetFile);
					if (descriptor != null)
					{
						brushDescriptors.Add(descriptor);
					}
				}
				catch (Exception ex)
				{
					Debug.LogWarning($"Failed to load brush from {assetFile}: {ex.Message}");
				}
			}

			manifest.Brushes = brushDescriptors.ToArray();
			manifest.CompatibilityBrushes = new BrushDescriptor[0]; // Empty for now

			Debug.Log($"Loaded {brushDescriptors.Count} brush descriptors");
			return manifest;
		}

		/// <summary>
		/// Loads a BrushDescriptor from a Unity .asset file (YAML format).
		/// Extracts the essential properties needed for brush generation.
		/// </summary>
		private static BrushDescriptor LoadBrushDescriptor(string assetFilePath)
		{
			var lines = File.ReadAllLines(assetFilePath);
			var descriptor = new BrushDescriptor();

			string currentKey = null;
			bool inGuidBlock = false;

			foreach (var line in lines)
			{
				var trimmed = line.TrimStart();

				// Parse m_Guid block
				if (trimmed.StartsWith("m_Guid:"))
				{
					inGuidBlock = true;
					continue;
				}
				if (inGuidBlock && trimmed.StartsWith("m_storage:"))
				{
					var guidStr = trimmed.Substring(trimmed.IndexOf(':') + 1).Trim();
					if (Guid.TryParse(guidStr, out var guid))
					{
						descriptor.m_Guid = guid;
					}
					inGuidBlock = false;
					continue;
				}

				// Parse other properties
				if (trimmed.StartsWith("m_DurableName:"))
				{
					descriptor.m_DurableName = ParseStringValue(trimmed);
				}
				else if (trimmed.StartsWith("m_BrushSizeRange:"))
				{
					descriptor.m_BrushSizeRange = ParseVector2(trimmed);
				}
				else if (trimmed.StartsWith("m_RenderBackfaces:"))
				{
					descriptor.m_RenderBackfaces = ParseBoolValue(trimmed);
				}
				else if (trimmed.StartsWith("m_Opacity:"))
				{
					descriptor.m_Opacity = ParseFloatValue(trimmed);
				}
				else if (trimmed.StartsWith("m_PressureOpacityRange:"))
				{
					descriptor.m_PressureOpacityRange = ParseVector2(trimmed);
				}
				else if (trimmed.StartsWith("m_TextureAtlasV:"))
				{
					descriptor.m_TextureAtlasV = (int)ParseFloatValue(trimmed);
				}
				else if (trimmed.StartsWith("m_TileRate:"))
				{
					descriptor.m_TileRate = ParseFloatValue(trimmed);
				}
				else if (trimmed.StartsWith("m_PressureSizeRange:"))
				{
					var vec = ParseVector2(trimmed);
					descriptor.GetType().GetField("m_PressureSizeRange",
						System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
						?.SetValue(descriptor, vec);
				}
				else if (trimmed.StartsWith("m_ColorLuminanceMin:"))
				{
					descriptor.m_ColorLuminanceMin = ParseFloatValue(trimmed);
				}
				else if (trimmed.StartsWith("m_ColorSaturationMax:"))
				{
					descriptor.m_ColorSaturationMax = ParseFloatValue(trimmed);
				}
				else if (trimmed.StartsWith("m_SizeVariance:"))
				{
					descriptor.m_SizeVariance = ParseFloatValue(trimmed);
				}
				else if (trimmed.StartsWith("m_SizeRatio:"))
				{
					descriptor.m_SizeRatio = ParseVector2(trimmed);
				}
				else if (trimmed.StartsWith("m_RotationVariance:"))
				{
					descriptor.m_RotationVariance = ParseFloatValue(trimmed);
				}
				else if (trimmed.StartsWith("m_PositionVariance:"))
				{
					descriptor.m_PositionVariance = ParseFloatValue(trimmed);
				}
				else if (trimmed.StartsWith("m_SprayRateMultiplier:"))
				{
					descriptor.m_SprayRateMultiplier = ParseFloatValue(trimmed);
				}
			}

			// Only return if we successfully parsed a GUID and name
			if (descriptor.m_Guid != Guid.Empty && !string.IsNullOrEmpty(descriptor.m_DurableName))
			{
				Debug.Log($"Loaded brush: {descriptor.m_DurableName} ({descriptor.m_Guid})");

			// Load prefab fields if the prefab file exists
			LoadPrefabFields(descriptor, assetFilePath);
				return descriptor;
			}

			return null;
		}

		private static string ParseStringValue(string line)
		{
			var colonIndex = line.IndexOf(':');
			if (colonIndex >= 0 && colonIndex < line.Length - 1)
			{
				return line.Substring(colonIndex + 1).Trim();
			}
			return "";
		}

		private static bool ParseBoolValue(string line)
		{
			var value = ParseStringValue(line);
			return value == "1" || value.ToLower() == "true";
		}

		private static float ParseFloatValue(string line)
		{
			var value = ParseStringValue(line);
			float.TryParse(value, out var result);
			return result;
		}

		private static Vector2 ParseVector2(string line)
		{
			try
			{
				// Format: "m_BrushSizeRange: {x: 0.075, y: 0.15}"
				var vectorStr = line.Substring(line.IndexOf('{') + 1);
				vectorStr = vectorStr.Substring(0, vectorStr.IndexOf('}'));
				var parts = vectorStr.Split(',');

				float x = 0, y = 0;
				foreach (var part in parts)
				{
					if (part.Contains("x:"))
						float.TryParse(part.Substring(part.IndexOf(':') + 1).Trim(), out x);
					else if (part.Contains("y:"))
						float.TryParse(part.Substring(part.IndexOf(':') + 1).Trim(), out y);
				}
				return new Vector2(x, y);
			}
			catch
			{
				return Vector2.zero;
			}
		}

		/// <summary>
		/// Finds a prefab file by its Unity GUID.
		/// </summary>
		private static string FindPrefabByGuid(string guid, string searchPath)
		{
			var metaFiles = Directory.GetFiles(searchPath, "*.prefab.meta", SearchOption.AllDirectories);
			foreach (var metaFile in metaFiles)
			{
				try
				{
					var lines = File.ReadAllLines(metaFile);
					foreach (var line in lines)
					{
						if (line.StartsWith("guid:") && line.Contains(guid))
						{
							return metaFile.Substring(0, metaFile.Length - 5); // Remove ".meta"
						}
					}
				}
				catch { }
			}
			return null;
		}

		/// <summary>
		/// Loads prefab serialized field values from the Unity prefab file.
		/// </summary>
		private static void LoadPrefabFields(BrushDescriptor descriptor, string assetFilePath)
		{
			string prefabPath = null;

			// First, try to find prefab via m_BrushPrefab GUID reference in the .asset file
			var assetLines = File.ReadAllLines(assetFilePath);
			foreach (var line in assetLines)
			{
				if (line.Contains("m_BrushPrefab:") && line.Contains("guid:"))
				{
					// Extract GUID: "m_BrushPrefab: {fileID: 100000, guid: 02c4483733486ec489655bc38e0aa393, type: 3}"
					var guidStart = line.IndexOf("guid:") + 5;
					var guidEnd = line.IndexOf(",", guidStart);
					if (guidEnd == -1) guidEnd = line.IndexOf("}", guidStart);
					if (guidStart > 0 && guidEnd > guidStart)
					{
						var guid = line.Substring(guidStart, guidEnd - guidStart).Trim();
						// Search for .prefab.meta file with this GUID
						var resourcesPath = Path.GetDirectoryName(Path.GetDirectoryName(assetFilePath));
						while (resourcesPath != null && !resourcesPath.EndsWith("Resources"))
						{
							resourcesPath = Path.GetDirectoryName(resourcesPath);
						}
						if (resourcesPath != null)
						{
							prefabPath = FindPrefabByGuid(guid, resourcesPath);
						}
						break;
					}
				}
			}

			// Fall back to looking for .prefab file in same directory as .asset file
			if (prefabPath == null)
			{
				var assetDir = Path.GetDirectoryName(assetFilePath);
				var prefabFiles = Directory.GetFiles(assetDir, "*.prefab", SearchOption.TopDirectoryOnly);
				if (prefabFiles.Length > 0)
				{
					prefabPath = prefabFiles[0];
				}
			}

			if (prefabPath == null)
			{
				return; // No prefab file found
			}

			try
			{
				var lines = File.ReadAllLines(prefabPath);
				bool inBrushComponent = false;

				foreach (var line in lines)
				{
					var trimmed = line.TrimStart();

					// Look for MonoBehaviour component (brush script)
					if (trimmed.StartsWith("MonoBehaviour:"))
					{
						inBrushComponent = true;
						continue;
					}

					// Stop when we hit another component
					if (inBrushComponent && trimmed.StartsWith("---"))
					{
						break;
					}

					if (inBrushComponent)
					{
						// Parse serialized fields
						if (trimmed.StartsWith("m_ShapeModifier:"))
						{
							descriptor.PrefabFields["m_ShapeModifier"] = (int)ParseFloatValue(trimmed);
						}
						else if (trimmed.StartsWith("m_TaperScalar:"))
						{
							descriptor.PrefabFields["m_TaperScalar"] = ParseFloatValue(trimmed);
						}
						else if (trimmed.StartsWith("m_PetalDisplacementAmt:"))
						{
							descriptor.PrefabFields["m_PetalDisplacementAmt"] = ParseFloatValue(trimmed);
						}
						else if (trimmed.StartsWith("m_PetalDisplacementExp:"))
						{
							descriptor.PrefabFields["m_PetalDisplacementExp"] = ParseFloatValue(trimmed);
						}
						else if (trimmed.StartsWith("m_PointsInClosedCircle:"))
						{
							descriptor.PrefabFields["m_PointsInClosedCircle"] = (ushort)(int)ParseFloatValue(trimmed);
						}
						else if (trimmed.StartsWith("m_CapAspect:"))
						{
							descriptor.PrefabFields["m_CapAspect"] = ParseFloatValue(trimmed);
						}
						else if (trimmed.StartsWith("m_EndCaps:"))
						{
							descriptor.PrefabFields["m_EndCaps"] = ParseBoolValue(trimmed);
						}
						else if (trimmed.StartsWith("m_HardEdges:"))
						{
							descriptor.PrefabFields["m_HardEdges"] = ParseBoolValue(trimmed);
						}
						else if (trimmed.StartsWith("m_uvStyle:"))
						{
							descriptor.PrefabFields["m_uvStyle"] = (int)ParseFloatValue(trimmed);
						}
						else if (trimmed.StartsWith("m_BreakAngleMultiplier:"))
						{
							descriptor.PrefabFields["m_BreakAngleMultiplier"] = ParseFloatValue(trimmed);
						}
					}
				}
			}
			catch (Exception ex)
			{
				Debug.LogWarning($"Failed to load prefab fields from {prefabPath}: {ex.Message}");
			}
		}

		/// <summary>
		/// Gets the default brushes path relative to the project root.
		/// </summary>
		public static string GetDefaultBrushesPath()
		{
			// Get the project root (where the .csproj file is)
			var projectPath = Godot.ProjectSettings.GlobalizePath("res://");
			return Path.Combine(projectPath, "Resources", "Brushes", "Basic");
		}

		/// <summary>
		/// Loads a TiltBrushManifest from a Unity .asset file and resolves all brush references.
		/// </summary>
		public static TiltBrushManifest LoadManifest(string manifestPath)
		{
			var manifest = new TiltBrushManifest();
			var brushDescriptors = new List<BrushDescriptor>();

			if (!File.Exists(manifestPath))
			{
				Debug.LogError($"Manifest file not found: {manifestPath}");
				return manifest;
			}

			var lines = File.ReadAllLines(manifestPath);
			var brushGuids = new List<string>();

			// Parse the manifest to extract brush GUIDs
			bool inBrushesArray = false;
			foreach (var line in lines)
			{
				var trimmed = line.Trim();

				if (trimmed.StartsWith("Brushes:"))
				{
					inBrushesArray = true;
					continue;
				}

				if (inBrushesArray)
				{
					// Check if we've left the Brushes array
					if (trimmed.StartsWith("CompatibilityBrushes:") ||
						(trimmed.Length > 0 && !trimmed.StartsWith("-") && !trimmed.StartsWith("{")))
					{
						break;
					}

					// Extract GUID from line like: "- {fileID: 11400000, guid: c80c2ea05a3d85e48858a322a18cf5bb, type: 2}"
					if (trimmed.StartsWith("-") && trimmed.Contains("guid:"))
					{
						var guidStart = trimmed.IndexOf("guid:") + 5;
						var guidEnd = trimmed.IndexOf(",", guidStart);
						if (guidEnd == -1) guidEnd = trimmed.IndexOf("}", guidStart);
						if (guidStart > 0 && guidEnd > guidStart)
						{
							var guid = trimmed.Substring(guidStart, guidEnd - guidStart).Trim();
							brushGuids.Add(guid);
						}
					}
				}
			}


		// Find and load each brush descriptor by GUID
		var brushesPath = Path.GetDirectoryName(manifestPath);
		var resourcesPaths = new[]
		{
			Path.Combine(brushesPath, "Resources", "Brushes"),
			Path.Combine(brushesPath, "Resources", "X", "Brushes")
		};

		foreach (var guid in brushGuids)
		{
			string brushPath = null;
			foreach (var searchPath in resourcesPaths)
			{
				brushPath = FindBrushByGuid(guid, searchPath, null);
				if (brushPath != null) break;
			}

			if (brushPath != null)
				{
					try
					{
						var descriptor = LoadBrushDescriptor(brushPath);
						if (descriptor != null)
						{
							brushDescriptors.Add(descriptor);
						}
					}
					catch (Exception ex)
					{
						Debug.LogWarning($"Failed to load brush {guid}: {ex.Message}");
					}
				}
				else
				{
					Debug.LogWarning($"Could not find brush with GUID {guid}");
				}
			}

			manifest.Brushes = brushDescriptors.ToArray();
			manifest.CompatibilityBrushes = new BrushDescriptor[0];

			return manifest;
		}

	/// <summary>
	/// Finds a brush descriptor .asset file by its Unity GUID.
	/// </summary>
	private static string FindBrushByGuid(string guid, string searchPath, string logPath = null)
	{
		if (!Directory.Exists(searchPath))
		{
			var msg = $"FindBrushByGuid: searchPath does not exist: {searchPath}";
			Debug.LogWarning(msg);
			if (logPath != null) File.AppendAllText(logPath, msg + "\n");
			return null;
		}

		// Manifest GUIDs match Unity .meta file GUIDs (32 chars, no hyphens)
		// Search .asset.meta files for "guid: {guid}"
		var metaFiles = Directory.GetFiles(searchPath, "*.asset.meta", SearchOption.AllDirectories);
		int filesChecked = 0;
		foreach (var metaFile in metaFiles)
		{
			try
			{
				filesChecked++;
				var lines = File.ReadAllLines(metaFile);
				foreach (var line in lines)
				{
					// Look for "guid: c80c2ea05a3d85e48858a322a18cf5bb"
					if (line.StartsWith("guid:") && line.Contains(guid))
					{
						// Return the .asset file path (remove .meta extension)
						var assetFile = metaFile.Substring(0, metaFile.Length - 5); // Remove ".meta"
						return assetFile;
					}
				}
			}
			catch
			{
			}
		}

		return null;
	}
}
} // namespace TiltBrush
