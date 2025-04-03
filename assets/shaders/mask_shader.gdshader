
shader_type canvas_item;

// 固定サイズの配列（最大20ポリゴン、各ポリゴンは最大20頂点）
uniform vec2 polygon_points[400]; // 20ポリゴン × 20頂点 = 400頂点
uniform int polygon_sizes[20]; // 各ポリゴンの頂点数
uniform int polygon_count; // 現在使用中のポリゴン数

// ポイントがポリゴン内にあるかどうかを判定
bool point_in_polygon(vec2 point, int poly_start_idx, int poly_size) {
	bool inside = false;
	
	for (int i = 0; i < poly_size; i++) {
		int j = (i > 0) ? i - 1 : poly_size - 1;
		
		vec2 vi = polygon_points[poly_start_idx + i];
		vec2 vj = polygon_points[poly_start_idx + j];
		
		if (((vi.y > point.y) != (vj.y > point.y)) &&
			(point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x)) {
			inside = !inside;
		}
	}
	
	return inside;
}

void fragment() {
	// UVを使用してピクセル座標に変換
	vec2 pixel_pos = UV * vec2(textureSize(TEXTURE, 0));
	bool in_any_polygon = false;
	
	// 全ポリゴンをチェック
	int point_index = 0;
	
	for (int p = 0; p < polygon_count; p++) {
		int poly_size = polygon_sizes[p];
		
		if (point_in_polygon(pixel_pos, point_index, poly_size)) {
			in_any_polygon = true;
			break;
		}
		
		point_index += poly_size;
	}
	
	// マスク処理
	if (in_any_polygon) {
		// 切り取られた部分は透明に
		COLOR.a = 0.0;
	} else {
		// 通常表示
		COLOR = texture(TEXTURE, UV);
	}
}