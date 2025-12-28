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
		/// Gets the default brushes path relative to the project root.
		/// </summary>
		public static string GetDefaultBrushesPath()
		{
			// Get the project root (where the .csproj file is)
			var projectPath = Godot.ProjectSettings.GlobalizePath("res://");
			return Path.Combine(projectPath, "Resources", "Brushes", "Basic");
		}
	}
}
