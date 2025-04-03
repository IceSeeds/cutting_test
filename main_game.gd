# ---- scenes/main_game.gd ----
extends Node2D

# 設定可能なゲームパラメータ
@export var win_percentage: float = 90.0  # 勝利条件の切り取り率
@export var player_speed: float = 150.0   # プレイヤーの移動速度
@export var auto_move_speed: float = 120.0  # 自動移動時の速度

# シェーダーの制限
const MAX_POLYGONS = 20
const MAX_POINTS_PER_POLYGON = 20

# ゲーム状態
var current_cut_percentage: float = 0.0
var total_area: float = 0.0
var cut_area: float = 0.0
var game_won: bool = false
var cutting_in_progress: bool = false

# 参照
var player
var top_layer
var bottom_layer
var mask
var ui
var cut_path = []
var current_polygon = []

# シェーダーデータ
var polygon_points = []
var polygon_sizes = []
var polygon_count = 0

func _ready():
	# ノードの参照を取得
	player = $Player
	top_layer = $Layers/TopLayer
	bottom_layer = $Layers/BottomLayer
	mask = $Layers/Mask
	ui = $UI
	
	# 初期設定
	total_area = top_layer.texture.get_width() * top_layer.texture.get_height()
	player.position = Vector2(top_layer.texture.get_width() - 30, 30)
	player.set_speed(player_speed)
	player.set_auto_speed(auto_move_speed)
	
	# シグナル接続
	player.connect("path_point_added", _on_path_point_added)
	player.connect("path_completed", _on_path_completed)
	
	# 切り取りマスクを初期化
	_initialize_mask()
	
	# UIを初期化
	ui.update_percentage(current_cut_percentage)

# マスクの初期化
func _initialize_mask():
	# シェーダーマテリアルを作成
	var material = ShaderMaterial.new()
	var shader = load("res://assets/shaders/mask_shader.gdshader")
	material.shader = shader
	
	# シェーダーパラメータの初期化
	var empty_points = PackedVector2Array()
	empty_points.resize(400) # 最大400ポイント
	
	var empty_sizes = PackedInt32Array()
	empty_sizes.resize(20) # 最大20ポリゴン
	
	material.set_shader_parameter("polygon_points", empty_points)
	material.set_shader_parameter("polygon_sizes", empty_sizes)
	material.set_shader_parameter("polygon_count", 0)
	
	mask.material = material
	mask.texture = top_layer.texture

# パスポイントが追加されたときの処理
func _on_path_point_added(point):
	cut_path.append(point)
	if cut_path.size() > 1:
		cutting_in_progress = true
	
# パスが完成したときの処理（四角形が閉じた）
func _on_path_completed(final_points):
	if cutting_in_progress:
		# 切り取り処理を実行
		_process_cutting(final_points)
		
		# 状態をリセット
		cut_path = []
		cutting_in_progress = false
		
		# プレイヤーを壁に戻す
		player.return_to_wall()

# 切り取り処理
func _process_cutting(points):
	# ポリゴン数チェック
	if polygon_count >= MAX_POLYGONS:
		print("警告: 最大ポリゴン数に達しました")
		return
		
	# ポイント数チェック
	if points.size() > MAX_POINTS_PER_POLYGON:
		print("警告: ポリゴンの頂点数が多すぎます")
		points = points.slice(0, MAX_POINTS_PER_POLYGON)
	
	# 現在のポリゴンデータを取得
	var current_points = mask.material.get_shader_parameter("polygon_points")
	var current_sizes = mask.material.get_shader_parameter("polygon_sizes")
	
	# 新しいポリゴンの頂点を追加
	var point_index = 0
	for p in range(polygon_count):
		point_index += current_sizes[p]
	
	for i in range(points.size()):
		current_points[point_index + i] = points[i]
	
	# ポリゴンサイズを記録
	current_sizes[polygon_count] = points.size()
	polygon_count += 1
	
	# シェーダーパラメータを更新
	mask.material.set_shader_parameter("polygon_points", current_points)
	mask.material.set_shader_parameter("polygon_sizes", current_sizes)
	mask.material.set_shader_parameter("polygon_count", polygon_count)
	
	# 切り取り面積計算
	var poly_area = _calculate_polygon_area(points)
	cut_area += poly_area
	
	# 切り取り率を更新
	current_cut_percentage = (cut_area / total_area) * 100.0
	ui.update_percentage(current_cut_percentage)
	
	# クリア判定
	if current_cut_percentage >= win_percentage and !game_won:
		game_won = true
		ui.show_win_screen()

# ポリゴンの面積を計算
func _calculate_polygon_area(poly_points):
	var area = 0.0
	var j = poly_points.size() - 1
	
	for i in range(poly_points.size()):
		area += (poly_points[j].x + poly_points[i].x) * (poly_points[j].y - poly_points[i].y)
		j = i
	
	return abs(area) * 0.5
