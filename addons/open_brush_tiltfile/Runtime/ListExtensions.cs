// Copyright 2020 The Tilt Brush Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Collections.Generic;
using System.Reflection;

namespace OpenBrush.TiltFile
{
    public static class ListExtensions
    {
        public static void SetCount<T>(this List<T> list, int count)
        {
            if (list == null)
            {
                throw new ArgumentNullException(nameof(list));
            }
            if (count < 0)
            {
                throw new ArgumentOutOfRangeException(nameof(count));
            }

            if (list.Count < count)
            {
                list.Capacity = Math.Max(list.Capacity, count);
                int toAdd = count - list.Count;
                for (int i = 0; i < toAdd; i++)
                {
                    list.Add(default);
                }
            }
            else if (list.Count > count)
            {
                list.RemoveRange(count, list.Count - count);
            }
        }

        public static T[] GetBackingArray<T>(this List<T> list)
        {
            if (list == null)
            {
                throw new ArgumentNullException(nameof(list));
            }
            return ListBackingArray<T>.Get(list);
        }

        private static class ListBackingArray<T>
        {
            private static readonly FieldInfo ItemsField =
                typeof(List<T>).GetField("_items", BindingFlags.NonPublic | BindingFlags.Instance);

            public static T[] Get(List<T> list)
            {
                if (ItemsField == null)
                {
                    return list.ToArray();
                }
                return (T[])ItemsField.GetValue(list);
            }
        }
    }
}
