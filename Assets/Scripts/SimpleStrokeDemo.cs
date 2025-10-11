// Simple demo script showing how to use the stroke generation system in Godot
using TiltBrush;
using UnityEngine;

/// <summary>
/// Basic example of using the TiltBrush stroke generation in Godot.
/// Attach this to a Node3D in your scene.
/// </summary>
public partial class SimpleStrokeDemo : MonoBehaviour
{
	[Godot.Export] public CanvasScript Canvas;
	[Godot.Export] public PointerScript Pointer;
	[Godot.Export] public bool DrawOnStart = false;
	[Godot.Export] public float MoveSpeed = 1.0f;

	private float _time;
	private bool _isDrawing;

	public void Awake()
	{

		Godot.GD.Print("SimpleStrokeDemo: Awake called");

		// If not set via inspector, try to find in scene
		if (Canvas == null)
		{
			Canvas = GetNodeOrNull<CanvasScript>("Canvas");
		}

		if (Pointer == null)
		{
			Pointer = GetNodeOrNull<PointerScript>("Pointer");
		}

		// Validate setup
		if (Canvas == null)
		{
			Godot.GD.PushError("SimpleStrokeDemo: No Canvas found! Please assign a CanvasScript in the inspector.");
		}

		if (Pointer == null)
		{
			Godot.GD.PushError("SimpleStrokeDemo: No Pointer found! Please assign a PointerScript in the inspector.");
		}
	}

	public void Start()
	{

		if (Pointer != null && Canvas != null)
		{
			// Configure pointer
			Pointer.Canvas = Canvas;
			Pointer.m_CurrentColor = new Color(1, 0, 0, 1); // Red
			Pointer.BrushSize01 = 0.5f;
			Pointer.m_CurrentPressure = 1.0f;

			// TODO: Set brush descriptor when brush system is initialized
			// Pointer.m_CurrentBrush = BrushCatalog.GetBrush(...);

			if (DrawOnStart)
			{
				_isDrawing = true;
				Pointer.DrawingEnabled = true;
			}

			Godot.GD.Print("SimpleStrokeDemo: Pointer configured successfully");
		}
	}

	public void Update()
	{

		if (Pointer == null) return;

		// Toggle drawing with spacebar
		if (Godot.Input.IsKeyPressed(Godot.Key.Space) && !_isDrawing)
		{
			_isDrawing = true;
			Pointer.DrawingEnabled = true;
			Godot.GD.Print("Drawing started");
		}
		else if (Input.IsKeyJustReleased(Godot.Key.Space) && _isDrawing)
		{
			_isDrawing = false;
			Pointer.DrawingEnabled = false;
			Godot.GD.Print("Drawing stopped");
		}

		// Move pointer in a circle pattern while drawing
		if (_isDrawing)
		{
			_time += Time.deltaTime * MoveSpeed;

			float radius = 2.0f;
			float x = Mathf.Cos(_time) * radius;
			float z = Mathf.Sin(_time) * radius;
			float y = Mathf.Sin(_time * 2) * 0.5f; // Add some vertical movement

			// Update pointer position
			if (Pointer.transform != null)
			{
				Pointer.transform.position = new Vector3(x, y, z);
			}
		}

		// Press R to reset
		if (Input.IsKeyJustPressed(Godot.Key.R))
		{
			ResetDemo();
		}
	}

	private void ResetDemo()
	{
		_isDrawing = false;
		_time = 0;

		if (Pointer != null)
		{
			Pointer.DrawingEnabled = false;
			Pointer.transform.position = Vector3.zero;
		}

		// TODO: Clear existing strokes
		Godot.GD.Print("Demo reset");
	}

}
