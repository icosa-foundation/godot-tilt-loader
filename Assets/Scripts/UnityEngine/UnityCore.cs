// Unity-to-Godot compatibility layer for core Unity classes
// Note: Global type aliases are defined in Scripts/GlobalUsings.cs
using Godot;
using System;
using System.Collections.Generic;

namespace UnityEngine
{
	// Debug logging wrapper
	public static class Debug
	{
		public static void Log(object message) => GD.Print(message);
		public static void LogWarning(object message) => GD.PushWarning(message?.ToString() ?? "null");
		public static void LogError(object message) => GD.PushError(message?.ToString() ?? "null");
		public static void LogException(Exception exception) => GD.PushError($"Exception: {exception}");

		public static void LogFormat(string format, params object[] args) => GD.Print(string.Format(format, args));
		public static void LogWarningFormat(string format, params object[] args) => GD.PushWarning(string.Format(format, args));
		public static void LogErrorFormat(string format, params object[] args) => GD.PushError(string.Format(format, args));

		public static void Assert(bool condition)
		{
			if (!condition) LogError("Assertion failed");
		}

		public static void Assert(bool condition, string message)
		{
			if (!condition) LogError($"Assertion failed: {message}");
		}

		public static void AssertFormat(bool condition, string format, params object[] args)
		{
			if (!condition) LogError($"Assertion failed: {string.Format(format, args)}");
		}
	}

	// Time wrapper
	public static class Time
	{
		private static ulong _startTicks = Godot.Time.GetTicksUsec();

		public static float time => (float)((Godot.Time.GetTicksUsec() - _startTicks) / 1_000_000.0);
		public static float timeSinceLevelLoad => time;
		public static float deltaTime => (float)Engine.GetPhysicsInterpolationFraction();
		public static int frameCount => (int)Engine.GetProcessFrames();
	}

	// Transform wrapper - wraps Godot Node3D
	public class Transform : IDisposable
	{
		private Node3D _node;

		public Transform(Node3D node)
		{
			_node = node;
		}

		internal Node3D Node => _node;

		public Vector3 position
		{
			get => _node?.GlobalPosition ?? Vector3.zero;
			set { if (_node != null) _node.GlobalPosition = value; }
		}

		public Quaternion rotation
		{
			get => _node?.GlobalBasis.GetRotationQuaternion() ?? Quaternion.identity;
			set { if (_node != null) _node.GlobalBasis = Godot.Basis.FromEuler(value.eulerAngles * (Mathf.PI / 180f)); }
		}

		public Vector3 localPosition
		{
			get => _node?.Position ?? Vector3.zero;
			set { if (_node != null) _node.Position = value; }
		}

		public Quaternion localRotation
		{
			get => _node?.Basis.GetRotationQuaternion() ?? Quaternion.identity;
			set { if (_node != null) _node.Basis = Godot.Basis.FromEuler(value.eulerAngles * (Mathf.PI / 180f)); }
		}

		public Vector3 localScale
		{
			get => _node?.Scale ?? Vector3.one;
			set { if (_node != null) _node.Scale = value; }
		}

		public Transform parent
		{
			get
			{
				var parentNode = _node?.GetParent() as Node3D;
				return parentNode != null ? new Transform(parentNode) : null;
			}
			set
			{
				if (_node != null && value?._node != null)
				{
					_node.Reparent(value._node);
				}
			}
		}

		public void SetParent(Transform parent, bool worldPositionStays = true)
		{
			if (_node == null || parent?._node == null) return;

			if (worldPositionStays)
			{
				var globalPos = _node.GlobalPosition;
				var globalRot = _node.GlobalBasis;
				_node.Reparent(parent._node);
				_node.GlobalPosition = globalPos;
				_node.GlobalBasis = globalRot;
			}
			else
			{
				_node.Reparent(parent._node);
			}
		}

		public T GetComponent<T>() where T : class
		{
			// Try to get component from the GameObject wrapper
			var gameObject = new GameObject(_node);
			return gameObject.GetComponent<T>();
		}

		public void Dispose()
		{
			_node = null;
		}

		public static implicit operator Transform(Node3D node) => new Transform(node);
		public static implicit operator Node3D(Transform transform) => transform?._node;
	}

	// GameObject wrapper - wraps Godot Node3D
	public class GameObject : IDisposable
	{
		private Node3D _node;
		private Dictionary<Type, object> _components = new Dictionary<Type, object>();

		public GameObject()
		{
			_node = new Node3D();
		}

		public GameObject(string name) : this()
		{
			_node.Name = name;
		}

		internal GameObject(Node3D node)
		{
			_node = node;
		}

		internal Node3D Node => _node;

		public string name
		{
			get => _node?.Name ?? "";
			set { if (_node != null) _node.Name = value; }
		}

		public Transform transform => _node != null ? new Transform(_node) : null;

		public bool activeSelf => _node?.Visible ?? false;

		public void SetActive(bool value)
		{
			if (_node != null) _node.Visible = value;
		}

		public T GetComponent<T>() where T : class
		{
			if (_components.TryGetValue(typeof(T), out var component))
				return component as T;

			// Try to find in node's children
			if (_node != null)
			{
				foreach (var child in _node.GetChildren())
				{
					if (child is T typedChild)
					{
						_components[typeof(T)] = typedChild;
						return typedChild;
					}
				}
			}

			return null;
		}

		public T AddComponent<T>() where T : class, new()
		{
			var component = new T();
			_components[typeof(T)] = component;
			return component;
		}

		internal void RegisterComponent<T>(T component) where T : class
		{
			_components[typeof(T)] = component;
		}

		public void Dispose()
		{
			_components.Clear();
			_node = null;
		}

		public static implicit operator GameObject(Node3D node) => new GameObject(node);
		public static implicit operator Node3D(GameObject gameObject) => gameObject?._node;
	}

	// Object base class wrapper
	public class Object
	{
		public static void Destroy(GameObject obj)
		{
			obj?.Node?.QueueFree();
		}

		public static void Destroy(UnityEngine.Object obj)
		{
			// Stub for destroying Unity objects
		}

		public static void Destroy(Mesh mesh)
		{
			mesh?.Dispose();
		}

		public static T Instantiate<T>(T original) where T : UnityEngine.Object
		{
			// Handle ScriptableObject cloning
			if (original is ScriptableObject scriptableObject)
			{
				return scriptableObject.ShallowClone() as T;
			}

			// Stub - needs proper implementation for other object types
			return default(T);
		}

		public static GameObject Instantiate(GameObject original)
		{
			if (original?.Node != null)
			{
				var duplicated = original.Node.Duplicate() as Node3D;
				return new GameObject(duplicated);
			}
			return null;
		}
	}

	// Static methods for Instantiate and Destroy (Unity allows calling these without Object. prefix)
	public static class UnityEngineHelpers
	{
		public static void Destroy(GameObject obj) => Object.Destroy(obj);
		public static void Destroy(Object obj) => Object.Destroy(obj);
		public static T Instantiate<T>(T original) where T : Object => Object.Instantiate(original);
		public static GameObject Instantiate(GameObject original) => Object.Instantiate(original);
	}
}

// Make Instantiate and Destroy available globally
namespace TiltBrush
{
	using UnityEngine;
	using static UnityEngine.UnityEngineHelpers;
}
