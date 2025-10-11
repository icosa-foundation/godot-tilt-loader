// MonoBehaviour - Unity to Godot compatibility layer
// This allows Unity MonoBehaviour scripts to work in Godot
using Godot;
using System;

namespace UnityEngine
{
	// Base class that bridges Unity MonoBehaviour to Godot Node3D
	public abstract partial class MonoBehaviour : Node3D
	{
		private GameObject _gameObject;
		private Transform _transform;

		// Explicitly hide Node3D.Quaternion property to prevent shadowing UnityEngine.Quaternion type
		// Use 'new' to hide the inherited member
		private new Godot.Quaternion Quaternion
		{
			get => base.Quaternion;
			set => base.Quaternion = value;
		}

		public GameObject gameObject
		{
			get
			{
				if (_gameObject == null)
				{
					_gameObject = new GameObject(this);
					_gameObject.RegisterComponent(this);
				}
				return _gameObject;
			}
		}

		public Transform transform
		{
			get
			{
				if (_transform == null)
				{
					_transform = new Transform(this);
				}
				return _transform;
			}
		}

		// Unity lifecycle methods that can be overridden
		public virtual void Awake() { }
		public virtual void Start() { }
		public virtual void Update() { }
		public virtual void LateUpdate() { }
		public virtual void FixedUpdate() { }
		public virtual void OnDestroy() { }

		// Godot lifecycle integration
		public override void _Ready()
		{
			base._Ready();
			Awake();
			CallDeferred(nameof(DeferredStart));
		}

		private void DeferredStart()
		{
			Start();
		}

		public override void _Process(double delta)
		{
			base._Process(delta);
			Update();
		}

		public override void _PhysicsProcess(double delta)
		{
			base._PhysicsProcess(delta);
			FixedUpdate();
		}

		public override void _ExitTree()
		{
			OnDestroy();
			base._ExitTree();
		}

		// Component helpers
		protected T GetComponent<T>() where T : class
		{
			// Check if it's a Unity-style component first
			if (typeof(T) == typeof(MeshFilter))
			{
				var meshInstance = GetNodeOrNull<MeshInstance3D>("MeshInstance3D");
				if (meshInstance != null)
					return new MeshFilter(meshInstance) as T;
			}
			else if (typeof(T) == typeof(Renderer))
			{
				var meshInstance = GetNodeOrNull<MeshInstance3D>("MeshInstance3D");
				if (meshInstance != null)
					return new Renderer(meshInstance) as T;
			}

			// Try to find as a Godot node
			if (this is T thisAsT)
				return thisAsT;

			// Search children
			foreach (var child in GetChildren())
			{
				if (child is T childAsT)
					return childAsT;
			}

			return gameObject.GetComponent<T>();
		}

		protected T AddComponent<T>() where T : class, new()
		{
			return gameObject.AddComponent<T>();
		}

		// Static Unity methods available to all MonoBehaviour scripts
		protected static void Destroy(GameObject obj) => Object.Destroy(obj);
		protected static void Destroy(Object obj) => Object.Destroy(obj);
		protected static void Destroy(Mesh mesh) => Object.Destroy(mesh);
		protected static T Instantiate<T>(T original) where T : Object => Object.Instantiate(original);
		protected static GameObject Instantiate(GameObject original) => Object.Instantiate(original);
	}
}
