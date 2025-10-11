// Unity Localization stub - minimal pass-through implementation
using System;
using System.Threading.Tasks;

namespace UnityEngine.Localization
{
    /// <summary>
    /// Stub implementation of Unity's LocalizedString.
    /// Just stores a plain string without actual localization support.
    /// </summary>
    [Serializable]
    public class LocalizedString
    {
        private string _value;

        public LocalizedString()
        {
            _value = string.Empty;
        }

        public LocalizedString(string value)
        {
            _value = value;
        }

        /// <summary>
        /// Returns the string value wrapped in a completed Task.
        /// </summary>
        public Task<string> GetLocalizedStringAsync()
        {
            return Task.FromResult(_value ?? string.Empty);
        }

        /// <summary>
        /// Synchronous access to the string value.
        /// </summary>
        public string GetLocalizedString()
        {
            return _value ?? string.Empty;
        }

        // Implicit conversion from string for convenience
        public static implicit operator LocalizedString(string value)
        {
            return new LocalizedString(value);
        }

        public static implicit operator string(LocalizedString localizedString)
        {
            return localizedString?._value ?? string.Empty;
        }

        public override string ToString()
        {
            return _value ?? string.Empty;
        }
    }
}
