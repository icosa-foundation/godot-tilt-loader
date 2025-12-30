using TiltBrush;
using UnityEngine;
using Godot;

public partial class MinimalXrExample : MonoBehaviour
{
		[Export] public NodePath BrushSystemPath;
		[Export] public NodePath PointerPath;
		[Export] public NodePath LeftControllerPath;
		[Export] public NodePath RightControllerPath;
		public UnityEngine.Color PointerColor = new UnityEngine.Color(0.2f, 0.5f, 1.0f, 1f);
		[Export] public float PointerSize01 = 0.05f;  // Default brush size for VR (now using 1:1 meter scale)
		[Export] public StringName DrawAction = new StringName("trigger_click");
		[Export] public StringName LeftThumbstickAction = new StringName("primary");
		[Export] public StringName RightThumbstickAction = new StringName("primary");
		[Export] public StringName ClearAllAction = new StringName("by_button");  // Y/B button typically
		[Export] public float BrushSizeChangeSpeed = 0.3f;  // Rate of change in normalized space (0.3 = 30% per second at full thumbstick)
		[Export] public float DefaultBrushSize = 0.05f;  // Default size when switching brushes

		private BrushSystemSetup BrushSystem;
		private PointerScript m_Pointer;
		private CanvasScript m_Canvas;
		private BrushDescriptor _runtimeBrush;
		private XRController3D _leftController;
		private XRController3D _rightController;
		private FileAccess _logFile;
		private int _currentBrushIndex = 0;
		private float _lastLeftThumbstickX = 0f;
		private bool _leftThumbstickTriggered = false;  // Prevents continuous triggering while held
		private const float ThumbstickDeadzone = 0.5f;

		private void LogDebug(string message)
		{
				GD.Print(message);
				if (_logFile == null)
				{
						_logFile = FileAccess.Open("user://xr_debug.log", FileAccess.ModeFlags.Write);
				}
				if (_logFile != null)
				{
						_logFile.StoreLine($"[{UnityEngine.Time.timeSinceLevelLoad:F2}] {message}");
						_logFile.Flush();
				}
		}

		public override void Start()
		{
				base.Start();
				GD.Print("MinimalXrExample: Start called");
				GD.Print($"Debug log file: {ProjectSettings.GlobalizePath("user://xr_debug.log")}");

				// Debug XR setup
				LogDebug($"XRDEBUG: XRServer active: {XRServer.GetPrimaryInterface()?.IsInitialized()}");
				LogDebug($"XRDEBUG: Viewport UseXR: {GetViewport().UseXR}");
				LogDebug($"XRDEBUG: App.METERS_TO_UNITS = {App.METERS_TO_UNITS}");

				BrushSystem = GetNode(BrushSystemPath) as BrushSystemSetup;
				if (BrushSystem == null)
				{
						GD.PushError("MinimalXrExample: BrushSystemPath does not point to a BrushSystemSetup!");
				}

				m_Pointer = GetNode(PointerPath) as PointerScript;
				if (m_Pointer == null)
				{
						GD.PushError("MinimalXrExample: PointerPath does not point to a PointerScript!");
				}

				_leftController = GetNode(LeftControllerPath) as XRController3D;
				if (_leftController == null)
				{
						GD.PushWarning("MinimalXrExample: LeftControllerPath is not set or not an XRController3D");
				}

				_rightController = GetNode(RightControllerPath) as XRController3D;
				if (_rightController == null)
				{
						GD.PushError("MinimalXrExample: RightControllerPath does not point to an XRController3D!");
				}

				if (BrushSystem != null)
				{
						_runtimeBrush = BrushSystem.GetBrushByName("Ink") ?? BrushSystem.GetDefaultBrush();
						// Find the index of the current brush
						if (BrushSystem.Manifest?.Brushes != null)
						{
								_currentBrushIndex = System.Array.IndexOf(BrushSystem.Manifest.Brushes, _runtimeBrush);
								if (_currentBrushIndex < 0) _currentBrushIndex = 0;
						}
						GD.Print($"Using brush: {_runtimeBrush?.m_DurableName ?? "none"} (index {_currentBrushIndex})");
						GD.Print($"Brush size range: {m_Pointer.BrushSizeAbsolute} (will be scaled by 0.1 for VR)");
				}

				// Get XROrigin3D to parent the canvas to it
				var xrOrigin = GetNode<XROrigin3D>("../XROrigin3D");
				if (xrOrigin == null)
				{
						GD.PushError("MinimalXrExample: Could not find XROrigin3D!");
						return;
				}

				LogDebug($"XRDEBUG: XROrigin3D scale: {xrOrigin.Scale}");

				m_Canvas = new CanvasScript
				{
						Name = "CanvasScript"
				};
				xrOrigin.AddChild(m_Canvas);
				LogDebug($"XRDEBUG: Canvas created, scale: {m_Canvas.Scale}, IsInsideTree={m_Canvas.IsInsideTree()}");

				if (m_Pointer != null)
				{
						m_Pointer.Canvas = m_Canvas;
						m_Pointer.m_CurrentBrush = _runtimeBrush ?? m_Pointer.m_CurrentBrush;
						m_Pointer.m_CurrentColor = PointerColor;
						m_Pointer.BrushSize01 = PointerSize01;
						m_Pointer.m_CurrentPressure = 1.0f;

						LogDebug($"XRDEBUG: Pointer configured - BrushSize01={PointerSize01}, BrushSizeAbsolute={m_Pointer.BrushSizeAbsolute}");
						LogDebug($"XRDEBUG: Pointer m_CurrentBrushSize={m_Pointer.m_CurrentBrushSize}");
				}
		}

		private int _debugFrameCounter = 0;
		private bool _clearButtonWasPressed = false;

		private void ClearCanvas()
		{
				if (m_Canvas != null)
				{
						m_Canvas.ClearCanvas();
						GD.Print("Canvas cleared!");
				}
		}

		public override void Update()
		{
				base.Update();

				// Debug: Log controller tracking every 60 frames
				_debugFrameCounter++;
				if (_debugFrameCounter % 60 == 0)
				{
						if (_rightController != null)
						{
								LogDebug($"XRDEBUG: Right controller tracked: {_rightController.GetIsActive()}, pos: {_rightController.GlobalPosition}");
						}
						if (_leftController != null)
						{
								LogDebug($"XRDEBUG: Left controller tracked: {_leftController.GetIsActive()}, pos: {_leftController.GlobalPosition}");
						}
				}

				if (m_Pointer == null || _rightController == null)
				{
						return;
				}

				// Sync pointer position to controller (Pointer is child of XROrigin3D, not controller)
				// This makes pointer.localPosition = room-space position for PointerScript compatibility
				m_Pointer.GlobalPosition = _rightController.GlobalPosition;
				m_Pointer.GlobalRotation = _rightController.GlobalRotation;

				bool triggerPressed = _rightController.IsButtonPressed(DrawAction);

				// Debug: Log when trigger state changes
				if (triggerPressed != m_Pointer.DrawingEnabled)
				{
						LogDebug($"XRDEBUG: Trigger {(triggerPressed ? "PRESSED" : "RELEASED")} - Drawing {(triggerPressed ? "ENABLED" : "DISABLED")}");
						LogDebug($"XRDEBUG: Checking action '{DrawAction}'");
						LogDebug($"XRDEBUG: Right controller position: {_rightController.GlobalPosition}");
						LogDebug($"XRDEBUG: Pointer position: {m_Pointer.GlobalPosition}");
				}

				m_Pointer.DrawingEnabled = triggerPressed;

				// Handle "clear all" button (with debouncing)
				if (_leftController != null)
				{
						bool clearButtonPressed = _leftController.IsButtonPressed(ClearAllAction);
						if (clearButtonPressed && !_clearButtonWasPressed)
						{
								ClearCanvas();
						}
						_clearButtonWasPressed = clearButtonPressed;
				}

				// Handle left thumbstick (horizontal) for brush selection - single flick only
				if (_leftController != null && BrushSystem != null && BrushSystem.Manifest?.Brushes != null)
				{
						var leftThumbstick = _leftController.GetVector2(LeftThumbstickAction);
						float thumbstickX = leftThumbstick.X;
						float absThumbstick = Godot.Mathf.Abs(thumbstickX);

						// Detect single flick: trigger when crossing deadzone, then wait for return to neutral
						if (absThumbstick >= ThumbstickDeadzone && !_leftThumbstickTriggered)
						{
								_leftThumbstickTriggered = true;
								int brushCount = BrushSystem.Manifest.Brushes.Length;
								if (thumbstickX > 0)
								{
										// Right: Next brush
										_currentBrushIndex = (_currentBrushIndex + 1) % brushCount;
										_runtimeBrush = BrushSystem.Manifest.Brushes[_currentBrushIndex];
										m_Pointer.m_CurrentBrush = _runtimeBrush;
										m_Pointer.BrushSize01 = DefaultBrushSize;
										GD.Print($"Switched to brush: {_runtimeBrush.m_DurableName}, size: {m_Pointer.m_CurrentBrushSize}");
								}
								else
								{
										// Left: Previous brush
										_currentBrushIndex = (_currentBrushIndex - 1 + brushCount) % brushCount;
										_runtimeBrush = BrushSystem.Manifest.Brushes[_currentBrushIndex];
										m_Pointer.m_CurrentBrush = _runtimeBrush;
										m_Pointer.BrushSize01 = DefaultBrushSize;
										GD.Print($"Switched to brush: {_runtimeBrush.m_DurableName}, size: {m_Pointer.m_CurrentBrushSize}");
								}
						}
						// Reset trigger flag when thumbstick returns to neutral
						else if (absThumbstick < ThumbstickDeadzone)
						{
								_leftThumbstickTriggered = false;
						}
						_lastLeftThumbstickX = thumbstickX;
				}

				// Handle right thumbstick (horizontal) for brush size
				if (_rightController != null && m_Pointer != null)
				{
						var rightThumbstick = _rightController.GetVector2(RightThumbstickAction);
						float thumbstickX = rightThumbstick.X;

						// Continuous brush size adjustment using normalized BrushSize01 [0,1]
						if (Godot.Mathf.Abs(thumbstickX) > ThumbstickDeadzone)
						{
								// Additive adjustment in normalized space
								float sizeChange = thumbstickX * BrushSizeChangeSpeed * UnityEngine.Time.deltaTime;
								m_Pointer.BrushSize01 = Godot.Mathf.Clamp(m_Pointer.BrushSize01 + sizeChange, 0.0f, 1.0f);
						}
				}
		}
}
