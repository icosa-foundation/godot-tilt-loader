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

namespace OpenBrush.TiltFile
{
    public enum StencilType
    {
        Plane = 0,
        Cube = 1,
        Sphere = 2,
        Capsule = 3,
        Cone = 4,
        Cylinder = 5,
        InteriorDome = 6,
        Pyramid = 7,
        Ellipsoid = 8,
        Custom = 9
    }

    public enum TextWidgetMode
    {
        TextMeshPro = 0,
        Geometry = 1
    }

    public enum LightType
    {
        Spot = 0,
        Directional = 1,
        Point = 2,
        Area = 3,
        Rectangle = 4,
        Disc = 5
    }
}
