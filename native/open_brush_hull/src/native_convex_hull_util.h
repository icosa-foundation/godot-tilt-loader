#ifndef NATIVE_CONVEX_HULL_UTIL_H
#define NATIVE_CONVEX_HULL_UTIL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

class NativeConvexHullUtil : public RefCounted {
	GDCLASS(NativeConvexHullUtil, RefCounted)

protected:
	static void _bind_methods();

public:
	Dictionary create(const PackedVector3Array &points, double tolerance) const;
};

} // namespace godot

#endif // NATIVE_CONVEX_HULL_UTIL_H
