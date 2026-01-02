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
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace OpenBrush.TiltFile
{
    public sealed class Vector2Converter : JsonConverter<Vector2>
    {
        public override Vector2 ReadJson(JsonReader reader, Type objectType, Vector2 existingValue,
            bool hasExistingValue, JsonSerializer serializer)
        {
            if (reader.TokenType == JsonToken.Null)
            {
                return default;
            }
            JArray array = JArray.Load(reader);
            if (array.Count < 2)
            {
                throw new JsonSerializationException("Vector2 must have at least 2 elements.");
            }
            return new Vector2(array[0].Value<float>(), array[1].Value<float>());
        }

        public override void WriteJson(JsonWriter writer, Vector2 value, JsonSerializer serializer)
        {
            writer.WriteStartArray();
            writer.WriteValue(value.x);
            writer.WriteValue(value.y);
            writer.WriteEndArray();
        }
    }

    public sealed class Vector3Converter : JsonConverter<Vector3>
    {
        public override Vector3 ReadJson(JsonReader reader, Type objectType, Vector3 existingValue,
            bool hasExistingValue, JsonSerializer serializer)
        {
            if (reader.TokenType == JsonToken.Null)
            {
                return default;
            }
            JArray array = JArray.Load(reader);
            if (array.Count < 3)
            {
                throw new JsonSerializationException("Vector3 must have at least 3 elements.");
            }
            return new Vector3(array[0].Value<float>(), array[1].Value<float>(), array[2].Value<float>());
        }

        public override void WriteJson(JsonWriter writer, Vector3 value, JsonSerializer serializer)
        {
            writer.WriteStartArray();
            writer.WriteValue(value.x);
            writer.WriteValue(value.y);
            writer.WriteValue(value.z);
            writer.WriteEndArray();
        }
    }

    public sealed class Vector4Converter : JsonConverter<Vector4>
    {
        public override Vector4 ReadJson(JsonReader reader, Type objectType, Vector4 existingValue,
            bool hasExistingValue, JsonSerializer serializer)
        {
            if (reader.TokenType == JsonToken.Null)
            {
                return default;
            }
            JArray array = JArray.Load(reader);
            if (array.Count < 4)
            {
                throw new JsonSerializationException("Vector4 must have 4 elements.");
            }
            return new Vector4(array[0].Value<float>(), array[1].Value<float>(), array[2].Value<float>(),
                array[3].Value<float>());
        }

        public override void WriteJson(JsonWriter writer, Vector4 value, JsonSerializer serializer)
        {
            writer.WriteStartArray();
            writer.WriteValue(value.x);
            writer.WriteValue(value.y);
            writer.WriteValue(value.z);
            writer.WriteValue(value.w);
            writer.WriteEndArray();
        }
    }

    public sealed class QuaternionConverter : JsonConverter<Quaternion>
    {
        public override Quaternion ReadJson(JsonReader reader, Type objectType, Quaternion existingValue,
            bool hasExistingValue, JsonSerializer serializer)
        {
            if (reader.TokenType == JsonToken.Null)
            {
                return default;
            }
            JArray array = JArray.Load(reader);
            if (array.Count < 4)
            {
                throw new JsonSerializationException("Quaternion must have 4 elements.");
            }
            return new Quaternion(array[0].Value<float>(), array[1].Value<float>(), array[2].Value<float>(),
                array[3].Value<float>());
        }

        public override void WriteJson(JsonWriter writer, Quaternion value, JsonSerializer serializer)
        {
            writer.WriteStartArray();
            writer.WriteValue(value.x);
            writer.WriteValue(value.y);
            writer.WriteValue(value.z);
            writer.WriteValue(value.w);
            writer.WriteEndArray();
        }
    }

    public sealed class ColorConverter : JsonConverter<Color>
    {
        public override Color ReadJson(JsonReader reader, Type objectType, Color existingValue,
            bool hasExistingValue, JsonSerializer serializer)
        {
            if (reader.TokenType == JsonToken.Null)
            {
                return default;
            }
            JArray array = JArray.Load(reader);
            if (array.Count < 3)
            {
                throw new JsonSerializationException("Color must have at least 3 elements.");
            }
            float a = (array.Count > 3) ? array[3].Value<float>() : 1.0f;
            return new Color(array[0].Value<float>(), array[1].Value<float>(), array[2].Value<float>(), a);
        }

        public override void WriteJson(JsonWriter writer, Color value, JsonSerializer serializer)
        {
            writer.WriteStartArray();
            writer.WriteValue(value.r);
            writer.WriteValue(value.g);
            writer.WriteValue(value.b);
            writer.WriteValue(value.a);
            writer.WriteEndArray();
        }
    }

    public sealed class Color32Converter : JsonConverter<Color32>
    {
        public override Color32 ReadJson(JsonReader reader, Type objectType, Color32 existingValue,
            bool hasExistingValue, JsonSerializer serializer)
        {
            if (reader.TokenType == JsonToken.Null)
            {
                return default;
            }
            JArray array = JArray.Load(reader);
            if (array.Count < 3)
            {
                throw new JsonSerializationException("Color32 must have at least 3 elements.");
            }
            byte a = (array.Count > 3) ? array[3].Value<byte>() : (byte)255;
            return new Color32(array[0].Value<byte>(), array[1].Value<byte>(), array[2].Value<byte>(), a);
        }

        public override void WriteJson(JsonWriter writer, Color32 value, JsonSerializer serializer)
        {
            writer.WriteStartArray();
            writer.WriteValue(value.r);
            writer.WriteValue(value.g);
            writer.WriteValue(value.b);
            writer.WriteValue(value.a);
            writer.WriteEndArray();
        }
    }

    public sealed class TrTransformConverter : JsonConverter<TrTransform>
    {
        public override TrTransform ReadJson(JsonReader reader, Type objectType, TrTransform existingValue,
            bool hasExistingValue, JsonSerializer serializer)
        {
            if (reader.TokenType == JsonToken.Null)
            {
                return default;
            }
            JArray array = JArray.Load(reader);
            if (array.Count < 3)
            {
                throw new JsonSerializationException("TrTransform must have 3 elements.");
            }
            Vector3 position = array[0].ToObject<Vector3>(serializer);
            Quaternion rotation = array[1].ToObject<Quaternion>(serializer);
            float scale = array[2].Value<float>();
            return TrTransform.TRS(position, rotation, scale);
        }

        public override void WriteJson(JsonWriter writer, TrTransform value, JsonSerializer serializer)
        {
            writer.WriteStartArray();
            serializer.Serialize(writer, value.translation);
            serializer.Serialize(writer, value.rotation);
            writer.WriteValue(value.scale);
            writer.WriteEndArray();
        }
    }
}
