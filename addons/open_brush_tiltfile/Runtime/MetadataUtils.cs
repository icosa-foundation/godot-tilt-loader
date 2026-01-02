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

using System.Linq;

namespace OpenBrush.TiltFile
{
    public static class MetadataUtils
    {
        public static TrTransform[] Sanitize(TrTransform[] transforms)
        {
            if (transforms != null)
            {
                for (int i = 0; i < transforms.Length; ++i)
                {
                    if (!transforms[i].IsFinite())
                    {
                        TiltFile.Logger.LogWarningFormat("Found non-finite TrTransform: {0}", transforms[i]);
                        return System.Linq.Enumerable.Where(transforms, xf => xf.IsFinite()).ToArray();
                    }
                }
            }

            return transforms;
        }
    }
}
