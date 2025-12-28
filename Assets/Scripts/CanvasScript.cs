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

using UnityEngine;

namespace TiltBrush
{

    public partial class CanvasScript : MonoBehaviour
    {
        public TrTransform Pose => Coords.AsGlobal[transform];

        /// <summary>
        /// Clears all strokes from the canvas by removing all child nodes
        /// </summary>
        public void ClearCanvas()
        {
            var node = this as UnityEngine.MonoBehaviour;
            if (node != null)
            {
                int childCount = node.GetChildCount();
                Godot.GD.Print($"Clearing canvas: removing {childCount} strokes");

                // Remove all children (strokes)
                for (int i = childCount - 1; i >= 0; i--)
                {
                    var child = node.GetChild(i);
                    child.QueueFree();
                }
            }
        }
    }

} // namespace TiltBrush
