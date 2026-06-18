#include "native_convex_hull_util.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <QuickHull.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

using namespace godot;

namespace {

constexpr double QUICKHULL_MI_TOLERANCE_ADAPTER = 1.2;

Vector3 to_godot_vector(const quickhull::Vector3<double> &point) {
	return Vector3(static_cast<real_t>(point.x), static_cast<real_t>(point.y), static_cast<real_t>(point.z));
}

Vector3 triangle_normal(const Vector3 &a, const Vector3 &b, const Vector3 &c) {
	const Vector3 normal = (b - a).cross(c - a);
	const real_t length = normal.length();
	if (length <= static_cast<real_t>(1e-12)) {
		return Vector3();
	}
	return normal / length;
}

double dot(const quickhull::Vector3<double> &a, const quickhull::Vector3<double> &b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

quickhull::Vector3<double> subtract(const quickhull::Vector3<double> &a, const quickhull::Vector3<double> &b) {
	return quickhull::Vector3<double>(a.x - b.x, a.y - b.y, a.z - b.z);
}

quickhull::Vector3<double> cross(const quickhull::Vector3<double> &a, const quickhull::Vector3<double> &b) {
	return quickhull::Vector3<double>(
			a.y * b.z - a.z * b.y,
			a.z * b.x - a.x * b.z,
			a.x * b.y - a.y * b.x);
}

double length_squared(const quickhull::Vector3<double> &v) {
	return dot(v, v);
}

double max_abs_scale(const std::vector<quickhull::Vector3<double>> &points) {
	double scale = 0.0;
	for (const quickhull::Vector3<double> &point : points) {
		scale = std::max(scale, std::abs(point.x));
		scale = std::max(scale, std::abs(point.y));
		scale = std::max(scale, std::abs(point.z));
	}
	return scale;
}

bool has_3d_extent(const std::vector<quickhull::Vector3<double>> &points, double tolerance) {
	const double tolerance_squared = tolerance * tolerance;

	size_t first = 0;
	size_t second = 0;
	double best_line_span = 0.0;
	for (size_t i = 0; i < points.size(); ++i) {
		for (size_t j = i + 1; j < points.size(); ++j) {
			const double distance_squared = length_squared(subtract(points[j], points[i]));
			if (distance_squared > best_line_span) {
				best_line_span = distance_squared;
				first = i;
				second = j;
			}
		}
	}
	if (best_line_span <= tolerance_squared) {
		return false;
	}

	const quickhull::Vector3<double> line = subtract(points[second], points[first]);
	size_t third = 0;
	double best_line_distance_squared = 0.0;
	for (size_t i = 0; i < points.size(); ++i) {
		const quickhull::Vector3<double> area = cross(line, subtract(points[i], points[first]));
		const double distance_squared = length_squared(area) / best_line_span;
		if (distance_squared > best_line_distance_squared) {
			best_line_distance_squared = distance_squared;
			third = i;
		}
	}
	if (best_line_distance_squared <= tolerance_squared) {
		return false;
	}

	const quickhull::Vector3<double> normal = cross(subtract(points[second], points[first]), subtract(points[third], points[first]));
	const double normal_length_squared = length_squared(normal);
	if (normal_length_squared <= tolerance_squared) {
		return false;
	}

	double best_plane_distance_squared = 0.0;
	for (size_t i = 0; i < points.size(); ++i) {
		const double signed_distance_times_normal_length = dot(normal, subtract(points[i], points[first]));
		const double distance_squared = (signed_distance_times_normal_length * signed_distance_times_normal_length) / normal_length_squared;
		if (distance_squared > best_plane_distance_squared) {
			best_plane_distance_squared = distance_squared;
		}
	}
	return best_plane_distance_squared > tolerance_squared;
}

Dictionary empty_result() {
	Dictionary result;
	result["ok"] = false;
	result["points"] = Array();
	result["faces"] = Array();
	return result;
}

} // namespace

void NativeConvexHullUtil::_bind_methods() {
	ClassDB::bind_method(D_METHOD("create", "points", "tolerance"), &NativeConvexHullUtil::create);
}

Dictionary NativeConvexHullUtil::create(const PackedVector3Array &points, double tolerance) const {
	if (points.size() < 4) {
		return empty_result();
	}

	std::vector<quickhull::Vector3<double>> input;
	input.reserve(static_cast<size_t>(points.size()));
	for (int64_t i = 0; i < points.size(); ++i) {
		const Vector3 point = points[i];
		input.emplace_back(static_cast<double>(point.x), static_cast<double>(point.y), static_cast<double>(point.z));
	}
	const double absolute_tolerance = std::max(std::abs(tolerance), 1e-12);
	if (!has_3d_extent(input, absolute_tolerance)) {
		return empty_result();
	}

	quickhull::QuickHull<double> quick_hull;
	const double scale = std::max(max_abs_scale(input), 1e-12);
	// QuickHull and Unity's MIConvexHull use different tolerance semantics. The adapter was
	// calibrated against imported Open Brush hull strokes so QuickHull keeps the same boundary
	// vertices as MIConvexHull at Unity's brush tolerance.
	const double quick_hull_epsilon = (absolute_tolerance * QUICKHULL_MI_TOLERANCE_ADAPTER) / scale;
	const quickhull::ConvexHull<double> hull = quick_hull.getConvexHull(input, true, false, quick_hull_epsilon);
	const auto &vertices = hull.getVertexBuffer();
	const auto &indices = hull.getIndexBuffer();
	if (vertices.size() < 4 || indices.size() < 12) {
		return empty_result();
	}

	Array hull_points;
	hull_points.resize(static_cast<int64_t>(vertices.size()));
	for (int64_t i = 0; i < static_cast<int64_t>(vertices.size()); ++i) {
		hull_points[i] = to_godot_vector(vertices[static_cast<size_t>(i)]);
	}

	Array faces;
	const size_t triangle_count = indices.size() / 3;
	faces.resize(static_cast<int64_t>(triangle_count));
	for (size_t triangle = 0; triangle < triangle_count; ++triangle) {
		const int32_t i0 = static_cast<int32_t>(indices[triangle * 3 + 0]);
		const int32_t i1 = static_cast<int32_t>(indices[triangle * 3 + 1]);
		const int32_t i2 = static_cast<int32_t>(indices[triangle * 3 + 2]);
		const Vector3 p0 = hull_points[i0];
		const Vector3 p1 = hull_points[i1];
		const Vector3 p2 = hull_points[i2];

		PackedInt32Array face_indices;
		face_indices.push_back(i0);
		face_indices.push_back(i1);
		face_indices.push_back(i2);

		Dictionary face;
		face["indices"] = face_indices;
		face["normal"] = triangle_normal(p0, p1, p2);
		faces[static_cast<int64_t>(triangle)] = face;
	}

	Dictionary result;
	result["ok"] = true;
	result["points"] = hull_points;
	result["faces"] = faces;
	return result;
}
