// Simple drawing controller for testing stroke generation
// Press SPACE to draw a circle pattern
// Press M to move the pointer in a circle continuously while drawing
using TiltBrush;
using UnityEngine;

public partial class SimpleDrawingController : MonoBehaviour
{
	[Godot.Export] public Godot.NodePath PointerPath;
	[Godot.Export] public float CircleRadius = 2.0f;
	[Godot.Export] public float MoveSpeed = 1.0f;
	[Godot.Export] public bool DrawOnStart = false;

	private PointerScript Pointer;

	private bool _isDrawing = false;
	private bool _moveMode = false;
	private float _time = 0;

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
	}

	public override void Start()
	{
		base.Start();
		Godot.GD.Print("SimpleDrawingController: Start called");
		Godot.GD.Print($"SimpleDrawingController: Pointer = {(Pointer != null ? "assigned" : "NULL")}");
		Godot.GD.Print($"SimpleDrawingController: DrawOnStart = {DrawOnStart}");

		if (DrawOnStart && Pointer != null)
		{
			StartDrawing();
		}
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
		bool nPressed = Godot.Input.IsPhysicalKeyPressed(Godot.Key.N);
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

		// Toggle move mode with M (one-time press)
		if (mPressed && !_moveMode)
		{
			_moveMode = true;
			Godot.GD.Print("Move mode: ON - Pointer will move in a circle");
		}

		// Turn off move mode with N
		if (nPressed && _moveMode)
		{
			_moveMode = false;
			Godot.GD.Print("Move mode: OFF");
		}

		// Move pointer in circle if move mode is on
		if (_moveMode)
		{
			_time += Time.deltaTime * MoveSpeed;

			float x = Mathf.Cos(_time) * CircleRadius;
			float z = Mathf.Sin(_time) * CircleRadius;
			float y = Mathf.Sin(_time * 2) * 0.5f; // Add vertical movement

			// Update the Node3D position directly
			var pointerNode = Pointer as UnityEngine.MonoBehaviour;
			if (pointerNode != null)
			{
				pointerNode.GlobalPosition = new UnityEngine.Vector3(x, y, z);

				// Debug print every 3 seconds
				if ((int)(_time / 3.0f) != (int)((_time - Time.deltaTime * MoveSpeed) / 3.0f))
				{
					Godot.GD.Print($"Pointer at: ({x:F2}, {y:F2}, {z:F2})");
				}
			}
		}

		// Reset with R
		if (rPressed)
		{
			Reset();
		}
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
