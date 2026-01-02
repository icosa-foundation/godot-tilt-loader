using Godot;
using OpenBrush.TiltFile;
using System.IO;
using Newtonsoft.Json;

public partial class TestTiltLoader : Node
{
	public override void _Ready()
	{
		TiltFile.Logger = GodotLogger.Instance;

		string path = "res://env-scale-test.tilt"; // or user://
		var tilt = new TiltFile(path);

		GD.Print($"Header valid: {tilt.IsHeaderValid()}");

		using var meta = tilt.GetReadStream(TiltFile.FN_METADATA);
		if (meta == null)
		{
			GD.PrintErr("metadata.json missing");
			return;
		}

		SketchMetadata metadata;
		using (var sr = new StreamReader(meta))
		{
			metadata = JsonConvert.DeserializeObject<SketchMetadata>(sr.ReadToEnd());
		}

		using var sketch = tilt.GetReadStream(TiltFile.FN_SKETCH);
		if (sketch == null)
		{
			GD.PrintErr("data.sketch missing");
			return;
		}

		GD.Print($"BrushIndex count: {metadata.BrushIndex?.Length ?? 0}");
		var strokes = SketchReader.ReadStrokes(sketch, metadata.BrushIndex);
		GD.Print($"Strokes: {strokes?.Count ?? 0}");
		if (strokes != null && strokes.Count > 0)
		{
			var stroke = strokes[0];
			GD.Print($"First stroke brush: {stroke.BrushGuid}");
			GD.Print($"First stroke color: {stroke.Color.r}, {stroke.Color.g}, {stroke.Color.b}, {stroke.Color.a}");
			GD.Print($"First stroke size: {stroke.BrushSize}");
			GD.Print($"First stroke scale: {stroke.BrushScale}");
			GD.Print($"First stroke seed: {stroke.Seed}");
			GD.Print($"First stroke flags: {stroke.Flags}");
			GD.Print($"First stroke group id: {stroke.GroupId}");
			GD.Print($"First stroke layer: {stroke.LayerIndex}");
			GD.Print($"First stroke points: {stroke.ControlPoints.Count}");

			for (int i = 0; i < stroke.ControlPoints.Count; i++)
			{
				var cp = stroke.ControlPoints[i];
				GD.Print($"CP {i}: pos=({cp.Position.x}, {cp.Position.y}, {cp.Position.z}) " +
						 $"rot=({cp.Orientation.x}, {cp.Orientation.y}, {cp.Orientation.z}, {cp.Orientation.w}) " +
						 $"pressure={cp.Pressure} time={cp.TimestampMs}");
			}
		}
	}
}
