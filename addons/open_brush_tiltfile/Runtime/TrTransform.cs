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
using Godot;
using Newtonsoft.Json;

namespace OpenBrush.TiltFile
{
    /// Similar to Matrix4x4, except only handles translation, rotation,
    /// and uniform scale; omits generalized scale and perspective.
    [JsonConverter(typeof(TrTransformConverter))]
    [Serializable]
    public struct TrTransform : IEquatable<TrTransform>
    {
        public Vector3 translation;
        public Quaternion rotation;
        public float scale;

        public static readonly TrTransform identity = TR(Vector3.zero, Quaternion.identity);

        public static TrTransform T(Vector3 t)
        {
            return new TrTransform { translation = t, rotation = Quaternion.identity, scale = 1f };
        }

        public static TrTransform R(Quaternion r)
        {
            return new TrTransform { translation = Vector3.zero, rotation = r, scale = 1f };
        }

        public static TrTransform R(float angleDegrees, Vector3 axis)
        {
            Quaternion r = Quaternion.AngleAxis(angleDegrees, axis);
            return new TrTransform { translation = Vector3.zero, rotation = r, scale = 1f };
        }

        public static TrTransform S(float s)
        {
            return new TrTransform { translation = Vector3.zero, rotation = Quaternion.identity, scale = s };
        }

        public static TrTransform TR(Vector3 t, Quaternion r)
        {
            return new TrTransform { translation = t, rotation = r, scale = 1f };
        }

        public static TrTransform TRS(Vector3 t, Quaternion r, float s)
        {
            return new TrTransform { translation = t, rotation = r, scale = s };
        }

        public static TrTransform FromTransform3D(Transform3D xf)
        {
            Vector3 t = (Vector3)xf.Origin;
            Quaternion r = (Quaternion)xf.Basis.GetRotationQuaternion();
            Vector3 scaleVec = (Vector3)xf.Basis.Scale;
            float uniformScale = scaleVec.x;
            return TRS(t, r, uniformScale);
        }

        /// Returns a.inverse * b
        public static TrTransform InvMul(TrTransform a, TrTransform b)
        {
            Quaternion aInvRot = a.rotation.TrueInverse();
            return TRS(aInvRot * ((b.translation - a.translation) / a.scale),
                aInvRot * b.rotation,
                b.scale / a.scale);
        }

        /// Linearly interpolate between two TrTransforms.
        /// Translation is linearly interpolated, rotation is spherically interpolated,
        /// log of scale is linearly interpolated (so requires scale > 0).
        public static TrTransform Lerp(TrTransform a, TrTransform b, float t)
        {
            System.Diagnostics.Debug.Assert(a.scale > 0 && b.scale > 0);
            float logA = MathF.Log(a.scale);
            float logB = MathF.Log(b.scale);
            float logS = logA + (logB - logA) * t;
            return TRS(Vector3.Lerp(a.translation, b.translation, t),
                Quaternion.Slerp(a.rotation, b.rotation, t),
                MathF.Exp(logS));
        }

        /// Equivalent to doing a matrix-multiply against the 4-vector (p, 1)
        public static Vector3 operator *(TrTransform a, Vector3 b)
        {
            return a.MultiplyPoint(b);
        }

        public static TrTransform operator *(TrTransform a, TrTransform b)
        {
            return TRS(a.rotation * (a.scale * b.translation) + a.translation,
                a.rotation * b.rotation,
                a.scale * b.scale);
        }

        public static Plane operator *(TrTransform xf, Plane plane)
        {
            Vector3 normal1 = xf.rotation * (Vector3)plane.Normal;
            float d1 = (xf.scale * plane.D) - Vector3.Dot(normal1, xf.translation);
            return new Plane((Godot.Vector3)normal1, d1);
        }

        public static bool operator !=(TrTransform lhs, TrTransform rhs)
        {
            return !(lhs == rhs);
        }

        /// Returns true if the transforms are exactly identical, down to the
        /// quaternion components.
        public static bool operator ==(TrTransform lhs, TrTransform rhs)
        {
            return lhs.translation.x == rhs.translation.x &&
                lhs.translation.y == rhs.translation.y &&
                lhs.translation.z == rhs.translation.z &&
                lhs.rotation.x == rhs.rotation.x &&
                lhs.rotation.y == rhs.rotation.y &&
                lhs.rotation.z == rhs.rotation.z &&
                lhs.rotation.w == rhs.rotation.w &&
                lhs.scale == rhs.scale;
        }

        /// Returns true if the transforms are approximately equal.
        public static bool Approximately(TrTransform lhs, TrTransform rhs)
        {
            return Mathf.IsEqualApprox(lhs.translation.x, rhs.translation.x) &&
                Mathf.IsEqualApprox(lhs.translation.y, rhs.translation.y) &&
                Mathf.IsEqualApprox(lhs.translation.z, rhs.translation.z) &&
                Mathf.IsEqualApprox(lhs.rotation.x, rhs.rotation.x) &&
                Mathf.IsEqualApprox(lhs.rotation.y, rhs.rotation.y) &&
                Mathf.IsEqualApprox(lhs.rotation.z, rhs.rotation.z) &&
                Mathf.IsEqualApprox(lhs.rotation.w, rhs.rotation.w) &&
                Mathf.IsEqualApprox(lhs.scale, rhs.scale);
        }

        public TrTransform inverse
        {
            get
            {
                Quaternion rInv = this.rotation.TrueInverse();
                float invScale = 1f / this.scale;
                return TRS((rInv * this.translation) * -invScale, rInv, invScale);
            }
        }

        public Vector3 forward => this.rotation * Vector3.forward;
        public Vector3 up => this.rotation * Vector3.up;
        public Vector3 right => this.rotation * Vector3.right;

        public bool IsFinite()
        {
            return
                !float.IsNaN(translation.x) && !float.IsInfinity(translation.x) &&
                !float.IsNaN(translation.y) && !float.IsInfinity(translation.y) &&
                !float.IsNaN(translation.z) && !float.IsInfinity(translation.z) &&
                !float.IsNaN(rotation.x) && !float.IsInfinity(rotation.x) &&
                !float.IsNaN(rotation.y) && !float.IsInfinity(rotation.y) &&
                !float.IsNaN(rotation.z) && !float.IsInfinity(rotation.z) &&
                !float.IsNaN(rotation.w) && !float.IsInfinity(rotation.w) &&
                !float.IsNaN(scale) && !float.IsInfinity(scale);
        }

        public override string ToString()
        {
            return string.Format("T: {0:e} {1:e} {2:e}\nR: {3:e} {4:e} {5:e}  {6:e}\n S: {7:e}",
                translation.x, translation.y, translation.z,
                rotation.x, rotation.y, rotation.z, rotation.w,
                scale);
        }

        public override bool Equals(object obj)
        {
            return obj is TrTransform other && this == other;
        }

        public bool Equals(TrTransform other)
        {
            return this == other;
        }

        public override int GetHashCode()
        {
            return HashCode.Combine(translation.x, translation.y, translation.z,
                rotation.x, rotation.y, rotation.z, rotation.w, scale);
        }

        public Transform3D ToTransform3D()
        {
            var basis = new Basis((Godot.Quaternion)rotation).Scaled(new Godot.Vector3(scale, scale, scale));
            return new Transform3D(basis, (Godot.Vector3)translation);
        }

        /// Equivalent to doing a matrix-multiply against the 4-vector (p, 1)
        public Vector3 MultiplyPoint(Vector3 p)
        {
            return translation + (rotation * (scale * p));
        }

        /// Equivalent to doing a matrix-multiply against the 4-vector (p, 0)
        public Vector3 MultiplyVector(Vector3 v)
        {
            return rotation * (scale * v);
        }

        /// Multiply a bivector (the result of a cross-product).
        /// Use this for things with units of distance^2, like angular momentum.
        public Vector3 MultiplyBivector(Vector3 v)
        {
            return rotation * ((scale * scale) * v);
        }

        /// Transforms a normal or a non-distance quantity like angular velocity.
        public Vector3 MultiplyNormal(Vector3 v)
        {
            return rotation * v;
        }

        /// Changes the coordinate system of an active transformation.
        public TrTransform TransformBy(TrTransform rhs)
        {
            Quaternion similar = (rhs.rotation * this.rotation * rhs.rotation.TrueInverse());
            Vector3 retTrans = similar * (-this.scale * rhs.translation)
                + rhs.rotation * (rhs.scale * this.translation)
                + rhs.translation;

            return new TrTransform
            {
                translation = retTrans,
                rotation = similar,
                scale = this.scale
            };
        }
    }
}
