// Simple drawing controller for testing stroke generation
// Controls:
// - MOUSE: Move pointer in 3D space
// - SPACE: Hold to draw
// - M: Toggle automatic circle movement
// - N: Stop automatic movement
// - R: Reset
// - 1-5: Change brush color (Red, Green, Blue, Yellow, White)
// - LEFT/RIGHT ARROW: Cycle through brush types
using System.Collections.Generic;
using System.Linq;
using TiltBrush;
using UnityEngine;

public partial class SimpleDrawingController : MonoBehaviour
{
	[Godot.Export] public Godot.NodePath PointerPath;
	[Godot.Export] public Godot.NodePath CameraPath;
	[Godot.Export] public float CircleRadius = 2.0f;
	[Godot.Export] public float MoveSpeed = 1.0f;
	[Godot.Export] public bool DrawOnStart = false;
	[Godot.Export] public float DrawingPlaneZ = 0f; // Z position of the drawing plane

	private PointerScript Pointer;
	private Godot.Camera3D Camera;

	private bool _isDrawing = false;
	private bool _moveMode = false;
	private float _time = 0;

	// Predefined colors
	private Color[] _colors = new Color[]
	{
		new Color(1, 0, 0, 1),      // Red
		new Color(0, 1, 0, 1),      // Green
		new Color(0.2f, 0.5f, 1, 1), // Blue
		new Color(1, 1, 0, 1),      // Yellow
		new Color(1, 1, 1, 1)       // White
	};
	private int _currentColorIndex = 2; // Start with blue

	// Brush cycling
	private List<BrushDescriptor> _availableBrushes;
	private int _currentBrushIndex = 0;

	// Key press tracking to prevent repeat
	private bool _leftArrowWasPressed = false;
	private bool _rightArrowWasPressed = false;
	private bool _mKeyWasPressed = false;
	private bool _cKeyWasPressed = false;

	public override void Awake()
	{
		base.Awake();
		Godot.GD.Print("SimpleDrawingController: Awake called");

		// Resolve the NodePath to get the actual PointerScript
		if (PointerPath != null && !PointerPath.IsEmpty)
		{
			Godot.GD.Print($"SimpleDrawingController: Resolving PointerPath: {PointerPath}");
			var node = GetNode(PointerPath);
			if (node != null)
			{
				Godot.GD.Print($"SimpleDrawingController: Found node: {node.Name}, Type: {node.GetType().Name}");
				Pointer = node as PointerScript;
				if (Pointer == null)
				{
					Godot.GD.PushError($"SimpleDrawingController: Node at path is not a PointerScript! It's a {node.GetType().Name}");
				}
			}
			else
			{
				Godot.GD.PushError($"SimpleDrawingController: Could not find node at path: {PointerPath}");
			}
		}
		else
		{
			Godot.GD.PushError("SimpleDrawingController: PointerPath is not set!");
		}

		// Resolve camera
		if (CameraPath != null && !CameraPath.IsEmpty)
		{
			var node = GetNode(CameraPath);
			Camera = node as Godot.Camera3D;
			if (Camera == null)
			{
				Godot.GD.PushError($"SimpleDrawingController: CameraPath does not point to a Camera3D!");
			}
		}
		else
		{
			// Try to find camera in scene
			Camera = GetViewport()?.GetCamera3D();
			if (Camera != null)
			{
				Godot.GD.Print("SimpleDrawingController: Auto-detected active camera");
			}
		}
	}

	public override void Start()
	{
		base.Start();
		Godot.GD.Print("SimpleDrawingController: Start called");
		Godot.GD.Print($"SimpleDrawingController: Pointer = {(Pointer != null ? "assigned" : "NULL")}");
		Godot.GD.Print($"SimpleDrawingController: Camera = {(Camera != null ? "assigned" : "NULL")}");
		Godot.GD.Print($"SimpleDrawingController: DrawOnStart = {DrawOnStart}");

		// Get available brushes from catalog
		_availableBrushes = BrushCatalog.AllBrushes?.ToList() ?? new List<BrushDescriptor>();
		if (_availableBrushes.Count > 0)
		{
			Godot.GD.Print($"SimpleDrawingController: Found {_availableBrushes.Count} brushes");
			// Find current brush index
			if (Pointer?.m_CurrentBrush != null)
			{
				_currentBrushIndex = _availableBrushes.IndexOf(Pointer.m_CurrentBrush);
				if (_currentBrushIndex < 0) _currentBrushIndex = 0;
			}
		}
		else
		{
			Godot.GD.PushWarning("SimpleDrawingController: No brushes available in catalog");
		}

		PrintControls();

		if (DrawOnStart && Pointer != null)
		{
			StartDrawing();
		}
	}

	private void PrintControls()
	{
		Godot.GD.Print("========================================");
		Godot.GD.Print("CONTROLS:");
		Godot.GD.Print("  MOUSE - Move pointer");
		Godot.GD.Print("  SPACE - Hold to draw");
		Godot.GD.Print("  1-5 - Change color (Red/Green/Blue/Yellow/White)");
		Godot.GD.Print("  LEFT/RIGHT ARROW - Cycle brushes");
		Godot.GD.Print("  M - Toggle auto-movement (adds torus knot offset to mouse)");
		Godot.GD.Print("  C - Clear canvas (remove all strokes)");
		Godot.GD.Print("  R - Reset");
		Godot.GD.Print("========================================");
	}

	public override void Update()
	{
		base.Update();

		if (Pointer == null)
		{
			return;
		}

		// Get input state
		bool spacePressed = Godot.Input.IsPhysicalKeyPressed(Godot.Key.Space);
		bool mPressed = Godot.Input.IsPhysicalKeyPressed(Godot.Key.M);
		bool cPressed = Godot.Input.IsPhysicalKeyPressed(Godot.Key.C);
		bool rPressed = Godot.Input.IsPhysicalKeyPressed(Godot.Key.R);

		// Handle drawing toggle with SPACE (hold to draw)
		if (spacePressed && !_isDrawing)
		{
			StartDrawing();
		}
		else if (!spacePressed && _isDrawing)
		{
			StopDrawing();
		}

		// Toggle move mode with M
		if (mPressed && !_mKeyWasPressed)
		{
			if (!_moveMode)
			{
				_moveMode = true;
				_time = 0; // Reset time
				Godot.GD.Print("Auto-movement: ON - Torus knot offset applied to mouse position");
			}
			else
			{
				_moveMode = false;
				Godot.GD.Print("Auto-movement: OFF");
			}
		}
		_mKeyWasPressed = mPressed;

		// Update pointer position from mouse
		if (Camera != null)
		{
			Vector3 mousePosition = GetMouseWorldPosition();

			// If auto-movement is enabled, add torus knot offset
			if (_moveMode)
			{
				_time += Time.deltaTime * MoveSpeed * 0.125f; // 12.5% speed

				// Torus knot parameters (p, q) - (3, 2) creates a trefoil knot
				int p = 3;
				int q = 2;
				float R = CircleRadius * 0.5f; // Major radius (50% of CircleRadius)
				float r = CircleRadius * 0.5f * 0.4f; // Minor radius

				float t = _time;

				// Parametric equations for (p, q) torus knot
				float x = (R + r * Mathf.Cos(q * t)) * Mathf.Cos(p * t);
				float y = (R + r * Mathf.Cos(q * t)) * Mathf.Sin(p * t);
				float z = r * Mathf.Sin(q * t);

				Vector3 offset = new Vector3(x, y, z);
				mousePosition += offset;
			}

			// Update pointer position
			var pointerNode = Pointer as UnityEngine.MonoBehaviour;
			if (pointerNode != null)
			{
				pointerNode.GlobalPosition = mousePosition;
			}
		}

		// Handle color change (1-5 keys)
		for (int i = 0; i < 5; i++)
		{
			if (Godot.Input.IsPhysicalKeyPressed((Godot.Key)((int)Godot.Key.Key1 + i)))
			{
				if (i != _currentColorIndex)
				{
					_currentColorIndex = i;
					Pointer.m_CurrentColor = _colors[i];
					string[] colorNames = { "Red", "Green", "Blue", "Yellow", "White" };
					Godot.GD.Print($"Color changed to: {colorNames[i]}");
				}
			}
		}

		// Handle brush cycling (arrow keys)
		bool leftArrowPressed = Godot.Input.IsPhysicalKeyPressed(Godot.Key.Left);
		bool rightArrowPressed = Godot.Input.IsPhysicalKeyPressed(Godot.Key.Right);

		if (leftArrowPressed && !_leftArrowWasPressed && _availableBrushes != null && _availableBrushes.Count > 0)
		{
			_currentBrushIndex = (_currentBrushIndex - 1 + _availableBrushes.Count) % _availableBrushes.Count;
			Pointer.m_CurrentBrush = _availableBrushes[_currentBrushIndex];
			Godot.GD.Print($"Brush changed to: {Pointer.m_CurrentBrush.m_DurableName} ({_currentBrushIndex + 1}/{_availableBrushes.Count})");
		}

		if (rightArrowPressed && !_rightArrowWasPressed && _availableBrushes != null && _availableBrushes.Count > 0)
		{
			_currentBrushIndex = (_currentBrushIndex + 1) % _availableBrushes.Count;
			Pointer.m_CurrentBrush = _availableBrushes[_currentBrushIndex];
			Godot.GD.Print($"Brush changed to: {Pointer.m_CurrentBrush.m_DurableName} ({_currentBrushIndex + 1}/{_availableBrushes.Count})");
		}

		_leftArrowWasPressed = leftArrowPressed;
		_rightArrowWasPressed = rightArrowPressed;

		// Clear canvas with C
		if (cPressed && !_cKeyWasPressed)
		{
			ClearCanvas();
		}
		_cKeyWasPressed = cPressed;

		// Reset with R
		if (rPressed)
		{
			Reset();
		}
	}

	private Vector3 GetMouseWorldPosition()
	{
		var mousePos = GetViewport().GetMousePosition();

		// Project mouse position to 3D space at the drawing plane
		var from = Camera.ProjectRayOrigin(mousePos);
		var direction = Camera.ProjectRayNormal(mousePos);

		// Calculate intersection with plane at Z = DrawingPlaneZ
		// Plane equation: z = DrawingPlaneZ
		// Ray equation: P = from + t * direction
		// Solve for t when z component equals DrawingPlaneZ

		if (Mathf.Abs(direction.Z) > 0.0001f) // Avoid division by zero
		{
			float t = (DrawingPlaneZ - from.Z) / direction.Z;
			var worldPos = from + direction * t;
			return new Vector3(worldPos.X, worldPos.Y, worldPos.Z);
		}

		return Vector3.zero;
	}

	private void StartDrawing()
	{
		if (Pointer != null)
		{
			_isDrawing = true;
			Pointer.DrawingEnabled = true;
			Godot.GD.Print("========================================");
			Godot.GD.Print("Drawing STARTED - Release SPACE to stop");
			Godot.GD.Print($"Pointer.Canvas = {(Pointer.Canvas != null ? "assigned" : "NULL")}");
			Godot.GD.Print($"Pointer.m_CurrentBrush = {(Pointer.m_CurrentBrush != null ? Pointer.m_CurrentBrush.m_DurableName : "NULL")}");
			Godot.GD.Print("========================================");
		}
	}

	private void StopDrawing()
	{
		if (Pointer != null)
		{
			_isDrawing = false;
			Pointer.DrawingEnabled = false;
			Godot.GD.Print("Drawing STOPPED");

			// Check if any geometry was created
			var canvas = Pointer.Canvas;
			if (canvas != null)
			{
				int childCount = (canvas as UnityEngine.MonoBehaviour)?.GetChildCount() ?? 0;
				Godot.GD.Print($"Canvas has {childCount} child nodes after drawing");
			}
		}
	}

	private void ClearCanvas()
	{
		if (Pointer != null && Pointer.Canvas != null)
		{
			Pointer.Canvas.ClearCanvas();
		}
		else
		{
			Godot.GD.PushWarning("Cannot clear canvas: Pointer or Canvas is null");
		}
	}

	private void Reset()
	{
		_isDrawing = false;
		_moveMode = false;
		_time = 0;

		if (Pointer != null)
		{
			Pointer.DrawingEnabled = false;
			var pointerNode = Pointer as UnityEngine.MonoBehaviour;
			if (pointerNode != null)
			{
				pointerNode.GlobalPosition = UnityEngine.Vector3.zero;
			}
		}

		Godot.GD.Print("Demo RESET");
	}

}
