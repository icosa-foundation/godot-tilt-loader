#include "native_convex_hull_util.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <QuickHull.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

using namespace godot;

namespace {

constexpr double QUICKHULL_MI_TOLERANCE_ADAPTER = 1.2;
constexpr double POLYGON_FACE_NORMAL_DOT = 1.0 - 1e-10;

struct TriangleFace {
	std::array<int32_t, 3> indices;
	Vector3 normal;
	double plane_offset = 0.0;
};

struct PolygonFaceGroup {
	Vector3 normal_sum;
	Vector3 normal;
	double plane_offset = 0.0;
	std::vector<int32_t> indices;
	std::vector<TriangleFace> triangles;
};

struct EdgeRecord {
	int32_t a = 0;
	int32_t b = 0;
	int32_t count = 0;
};

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

double dot_godot(const Vector3 &a, const Vector3 &b) {
	return static_cast<double>(a.x) * static_cast<double>(b.x) +
			static_cast<double>(a.y) * static_cast<double>(b.y) +
			static_cast<double>(a.z) * static_cast<double>(b.z);
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

void append_unique_index(std::vector<int32_t> &indices, int32_t index) {
	if (std::find(indices.begin(), indices.end(), index) == indices.end()) {
		indices.push_back(index);
	}
}

Vector3 normalized_or_zero(const Vector3 &value) {
	const real_t length = value.length();
	if (length <= static_cast<real_t>(1e-12)) {
		return Vector3();
	}
	return value / length;
}

void append_group_triangle(PolygonFaceGroup &group, const TriangleFace &triangle) {
	group.triangles.push_back(triangle);
	for (const int32_t index : triangle.indices) {
		append_unique_index(group.indices, index);
	}
}

void add_edge_record(std::vector<EdgeRecord> &edges, int32_t a, int32_t b) {
	const int32_t low = std::min(a, b);
	const int32_t high = std::max(a, b);
	for (EdgeRecord &edge : edges) {
		if (std::min(edge.a, edge.b) == low && std::max(edge.a, edge.b) == high) {
			edge.count += 1;
			return;
		}
	}
	edges.push_back({ a, b, 1 });
}

std::vector<int32_t> ordered_boundary_edges(const std::vector<TriangleFace> &triangles) {
	std::vector<EdgeRecord> edges;
	for (const TriangleFace &triangle : triangles) {
		add_edge_record(edges, triangle.indices[0], triangle.indices[1]);
		add_edge_record(edges, triangle.indices[1], triangle.indices[2]);
		add_edge_record(edges, triangle.indices[2], triangle.indices[0]);
	}

	std::vector<EdgeRecord> boundary_edges;
	for (const EdgeRecord &edge : edges) {
		if (edge.count == 1) {
			boundary_edges.push_back(edge);
		}
	}
	if (boundary_edges.size() < 3) {
		return {};
	}

	std::vector<int32_t> ordered;
	std::vector<bool> used(boundary_edges.size(), false);
	ordered.reserve(boundary_edges.size());
	ordered.push_back(boundary_edges[0].a);
	int32_t current = boundary_edges[0].b;
	used[0] = true;

	for (size_t step = 1; step < boundary_edges.size(); ++step) {
		ordered.push_back(current);
		bool found_next = false;
		for (size_t edge_index = 0; edge_index < boundary_edges.size(); ++edge_index) {
			if (used[edge_index]) {
				continue;
			}
			const EdgeRecord &edge = boundary_edges[edge_index];
			if (edge.a == current) {
				current = edge.b;
				used[edge_index] = true;
				found_next = true;
				break;
			}
			if (edge.b == current) {
				current = edge.a;
				used[edge_index] = true;
				found_next = true;
				break;
			}
		}
		if (!found_next) {
			return {};
		}
	}
	if (current != ordered[0]) {
		return {};
	}
	return ordered;
}

std::vector<int32_t> projected_polygon_boundary(const Array &hull_points, const std::vector<int32_t> &indices, const Vector3 &normal) {
	if (indices.size() <= 3) {
		return indices;
	}

	Vector3 center;
	for (const int32_t index : indices) {
		center += static_cast<Vector3>(hull_points[index]);
	}
	center /= static_cast<real_t>(indices.size());

	Vector3 axis_u = normal.cross(Vector3(0.0, 1.0, 0.0));
	if (axis_u.length_squared() <= static_cast<real_t>(1e-12)) {
		axis_u = normal.cross(Vector3(1.0, 0.0, 0.0));
	}
	axis_u = normalized_or_zero(axis_u);
	const Vector3 axis_v = normalized_or_zero(normal.cross(axis_u));

	struct ProjectedIndex {
		int32_t index = 0;
		double u = 0.0;
		double v = 0.0;
	};
	std::vector<ProjectedIndex> projected;
	projected.reserve(indices.size());
	for (const int32_t index : indices) {
		const Vector3 offset = static_cast<Vector3>(hull_points[index]) - center;
		projected.push_back({
				index,
				dot_godot(offset, axis_u),
				dot_godot(offset, axis_v),
		});
	}
	std::sort(projected.begin(), projected.end(), [](const ProjectedIndex &a, const ProjectedIndex &b) {
		if (a.u != b.u) {
			return a.u < b.u;
		}
		return a.v < b.v;
	});

	const auto cross_2d = [](const ProjectedIndex &a, const ProjectedIndex &b, const ProjectedIndex &c) {
		return (b.u - a.u) * (c.v - a.v) - (b.v - a.v) * (c.u - a.u);
	};

	std::vector<ProjectedIndex> lower;
	for (const ProjectedIndex &item : projected) {
		while (lower.size() >= 2 && cross_2d(lower[lower.size() - 2], lower[lower.size() - 1], item) <= 1e-12) {
			lower.pop_back();
		}
		lower.push_back(item);
	}

	std::vector<ProjectedIndex> upper;
	for (auto item = projected.rbegin(); item != projected.rend(); ++item) {
		while (upper.size() >= 2 && cross_2d(upper[upper.size() - 2], upper[upper.size() - 1], *item) <= 1e-12) {
			upper.pop_back();
		}
		upper.push_back(*item);
	}

	std::vector<int32_t> ordered;
	if (!lower.empty()) {
		lower.pop_back();
	}
	if (!upper.empty()) {
		upper.pop_back();
	}
	ordered.reserve(lower.size() + upper.size());
	for (const ProjectedIndex &item : lower) {
		ordered.push_back(item.index);
	}
	for (const ProjectedIndex &item : upper) {
		ordered.push_back(item.index);
	}

	if (ordered.size() >= 3) {
		const Vector3 p0 = static_cast<Vector3>(hull_points[ordered[0]]);
		const Vector3 p1 = static_cast<Vector3>(hull_points[ordered[1]]);
		const Vector3 p2 = static_cast<Vector3>(hull_points[ordered[2]]);
		if (dot_godot((p1 - p0).cross(p2 - p0), normal) < 0.0) {
			std::reverse(ordered.begin(), ordered.end());
		}
	}
	return ordered;
}

Array build_polygon_faces(const Array &hull_points, const std::vector<TriangleFace> &triangles, double plane_tolerance) {
	std::vector<PolygonFaceGroup> groups;
	for (const TriangleFace &triangle : triangles) {
		bool grouped = false;
		for (PolygonFaceGroup &group : groups) {
			if (dot_godot(group.normal, triangle.normal) < POLYGON_FACE_NORMAL_DOT) {
				continue;
			}
			if (std::abs(triangle.plane_offset - group.plane_offset) > plane_tolerance) {
				continue;
			}
			group.normal_sum += triangle.normal;
			group.normal = normalized_or_zero(group.normal_sum);
			group.plane_offset = (group.plane_offset + triangle.plane_offset) * 0.5;
			append_group_triangle(group, triangle);
			grouped = true;
			break;
		}
		if (!grouped) {
			PolygonFaceGroup group;
			group.normal_sum = triangle.normal;
			group.normal = triangle.normal;
			group.plane_offset = triangle.plane_offset;
			append_group_triangle(group, triangle);
			groups.push_back(group);
		}
	}

	Array faces;
	for (const PolygonFaceGroup &group : groups) {
		if (group.indices.size() < 3) {
			continue;
		}
		std::vector<int32_t> ordered_indices = ordered_boundary_edges(group.triangles);
		if (ordered_indices.empty()) {
			ordered_indices = projected_polygon_boundary(hull_points, group.indices, group.normal);
		}
		if (ordered_indices.size() < 3) {
			continue;
		}
		const Vector3 p0 = static_cast<Vector3>(hull_points[ordered_indices[0]]);
		const Vector3 p1 = static_cast<Vector3>(hull_points[ordered_indices[1]]);
		const Vector3 p2 = static_cast<Vector3>(hull_points[ordered_indices[2]]);
		if (dot_godot((p1 - p0).cross(p2 - p0), group.normal) < 0.0) {
			std::reverse(ordered_indices.begin(), ordered_indices.end());
		}

		PackedInt32Array face_indices;
		for (const int32_t index : ordered_indices) {
			face_indices.push_back(index);
		}

		Dictionary face;
		face["indices"] = face_indices;
		face["normal"] = group.normal;
		faces.push_back(face);
	}
	return faces;
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
	Vector3 hull_center;
	for (int64_t i = 0; i < static_cast<int64_t>(vertices.size()); ++i) {
		hull_center += static_cast<Vector3>(hull_points[i]);
	}
	hull_center /= static_cast<real_t>(vertices.size());

	const size_t triangle_count = indices.size() / 3;
	std::vector<TriangleFace> triangles;
	triangles.reserve(triangle_count);
	for (size_t triangle = 0; triangle < triangle_count; ++triangle) {
		const int32_t i0 = static_cast<int32_t>(indices[triangle * 3 + 0]);
		const int32_t i1 = static_cast<int32_t>(indices[triangle * 3 + 1]);
		const int32_t i2 = static_cast<int32_t>(indices[triangle * 3 + 2]);
		const Vector3 p0 = static_cast<Vector3>(hull_points[i0]);
		const Vector3 p1 = static_cast<Vector3>(hull_points[i1]);
		const Vector3 p2 = static_cast<Vector3>(hull_points[i2]);
		Vector3 normal = triangle_normal(p0, p1, p2);
		if (normal.length_squared() <= static_cast<real_t>(1e-12)) {
			continue;
		}
		TriangleFace face;
		face.indices = { i0, i1, i2 };
		if (dot_godot(normal, hull_center - p0) > 0.0) {
			normal = -normal;
			face.indices = { i0, i2, i1 };
		}
		face.normal = normal;
		face.plane_offset = dot_godot(normal, p0);
		triangles.push_back(face);
	}
	if (triangles.empty()) {
		return empty_result();
	}
	const double polygon_plane_tolerance = scale * 1e-10;
	Array faces = build_polygon_faces(hull_points, triangles, polygon_plane_tolerance);
	if (faces.is_empty()) {
		return empty_result();
	}

	Dictionary result;
	result["ok"] = true;
	result["points"] = hull_points;
	result["faces"] = faces;
	return result;
}
