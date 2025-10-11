// Unity attribute stubs for compatibility
// These attributes are mainly for Unity's inspector and don't have direct Godot equivalents
// In Godot, use [Export] instead of [SerializeField]
using System;

// JetBrains.Annotations namespace for code analysis attributes
namespace JetBrains.Annotations
{
    /// <summary>
    /// Indicates that a method does not make any observable state changes.
    /// Used by code analysis tools (ReSharper, Rider, etc.)
    /// </summary>
    [AttributeUsage(AttributeTargets.Method)]
    public sealed class PureAttribute : Attribute
    {
    }

    /// <summary>
    /// Indicates that the marked symbol is used implicitly (by reflection, serialization, etc.)
    /// </summary>
    [AttributeUsage(AttributeTargets.All)]
    public sealed class UsedImplicitlyAttribute : Attribute
    {
    }

    /// <summary>
    /// Indicates that a method can return null.
    /// </summary>
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Parameter | AttributeTargets.Property | AttributeTargets.Delegate | AttributeTargets.Field)]
    public sealed class CanBeNullAttribute : Attribute
    {
    }

    /// <summary>
    /// Indicates that a method cannot return null.
    /// </summary>
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Parameter | AttributeTargets.Property | AttributeTargets.Delegate | AttributeTargets.Field)]
    public sealed class NotNullAttribute : Attribute
    {
    }
}

namespace UnityEngine
{
    /// <summary>
    /// Base class for Unity property attributes.
    /// Used to create custom property drawers in Unity's inspector.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field, Inherited = true)]
    public abstract class PropertyAttribute : Attribute
    {
        public int order { get; set; }
    }

    /// <summary>
    /// Unity ScriptableObject base class.
    /// In Godot, consider using Resource instead.
    /// </summary>
    public class ScriptableObject : Object
    {
        public string name { get; set; }

        // Stub implementation
        public ScriptableObject()
        {
            name = "";
        }

        /// <summary>
        /// Creates a shallow copy of the ScriptableObject.
        /// Arrays and reference types will need to be manually copied if deep cloning is needed.
        /// </summary>
        public object ShallowClone()
        {
            return MemberwiseClone();
        }
    }

    /// <summary>
    /// Unity attribute to make private fields visible in the inspector.
    /// In Godot, use [Export] instead.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field)]
    public class SerializeField : Attribute
    {
    }

    /// <summary>
    /// Unity attribute to specify a numeric range for inspector sliders.
    /// In Godot, use [Export(PropertyHint.Range, "min,max")] instead.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field)]
    public class RangeAttribute : Attribute
    {
        public float min;
        public float max;

        public RangeAttribute(float min, float max)
        {
            this.min = min;
            this.max = max;
        }
    }

    /// <summary>
    /// Unity attribute to add a tooltip in the inspector.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Property | AttributeTargets.Class)]
    public class TooltipAttribute : Attribute
    {
        public string tooltip;

        public TooltipAttribute(string tooltip)
        {
            this.tooltip = tooltip;
        }
    }

    /// <summary>
    /// Unity attribute to add a header in the inspector.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field)]
    public class HeaderAttribute : Attribute
    {
        public string header;

        public HeaderAttribute(string header)
        {
            this.header = header;
        }
    }

    /// <summary>
    /// Unity attribute to hide a field from the inspector.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field)]
    public class HideInInspector : Attribute
    {
    }

    /// <summary>
    /// Unity attribute to add space in the inspector.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field)]
    public class SpaceAttribute : Attribute
    {
        public float height;

        public SpaceAttribute()
        {
            this.height = 8f;
        }

        public SpaceAttribute(float height)
        {
            this.height = height;
        }
    }

    /// <summary>
    /// Unity attribute to create menu items for ScriptableObject creation.
    /// In Unity Editor, this adds items to Assets > Create menu.
    /// </summary>
    [AttributeUsage(AttributeTargets.Class)]
    public class CreateAssetMenuAttribute : Attribute
    {
        public string fileName { get; set; }
        public string menuName { get; set; }
        public int order { get; set; }

        public CreateAssetMenuAttribute()
        {
            fileName = "New ScriptableObject";
            menuName = "";
            order = 0;
        }
    }

    /// <summary>
    /// Unity attribute for text areas in the inspector.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field)]
    public class TextAreaAttribute : Attribute
    {
        public int minLines;
        public int maxLines;

        public TextAreaAttribute()
        {
            this.minLines = 3;
            this.maxLines = 3;
        }

        public TextAreaAttribute(int minLines, int maxLines)
        {
            this.minLines = minLines;
            this.maxLines = maxLines;
        }
    }

    /// <summary>
    /// Unity attribute to force a field to be serialized.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Property)]
    public class SerializeReference : Attribute
    {
    }

    /// <summary>
    /// Unity attribute for multiline text fields.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field)]
    public class MultilineAttribute : Attribute
    {
        public int lines;

        public MultilineAttribute()
        {
            this.lines = 3;
        }

        public MultilineAttribute(int lines)
        {
            this.lines = lines;
        }
    }

    /// <summary>
    /// Unity attribute to add a context menu item.
    /// </summary>
    [AttributeUsage(AttributeTargets.Method)]
    public class ContextMenu : Attribute
    {
        public string menuName;

        public ContextMenu(string menuName)
        {
            this.menuName = menuName;
        }
    }

    /// <summary>
    /// Unity attribute to add a context menu item for a field.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field)]
    public class ContextMenuItemAttribute : Attribute
    {
        public string name;
        public string function;

        public ContextMenuItemAttribute(string name, string function)
        {
            this.name = name;
            this.function = function;
        }
    }
}
