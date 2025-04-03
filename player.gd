# ---- scenes/player.gd ----
extends CharacterBody2D

# 移動状態の定義
enum MoveState {
	AUTO_CLOCKWISE,  # 時計回りの自動移動
	MANUAL,          # マニュアル移動
	RETURNING        # 壁に戻る移動
}

# 設定
var speed: float = 150.0
var auto_speed: float = 120.0
var current_state = MoveState.AUTO_CLOCKWISE
var game_area_rect: Rect2
var wall_margin: float = 10.0
var last_wall_position: Vector2
var return_target: Vector2
var return_time: float = 0.5
var return_timer: float = 0.0
var path_points = []
var min_distance_between_points: float = 10.0

# シグナル
signal path_point_added(point)
signal path_completed(points)

func _ready():
	# ゲームエリアの初期化
	var parent = get_parent()
	var top_layer = parent.get_node("Layers/TopLayer")
	game_area_rect = Rect2(
		Vector2.ZERO,
		Vector2(top_layer.texture.get_width(), top_layer.texture.get_height())
	)
	
	# 初期化
	last_wall_position = position

func set_speed(new_speed):
	speed = new_speed
	
func set_auto_speed(new_auto_speed):
	auto_speed = new_auto_speed

func _physics_process(delta):
	match current_state:
		MoveState.AUTO_CLOCKWISE:
			_handle_auto_movement(delta)
		
		MoveState.MANUAL:
			_handle_manual_movement(delta)
			
		MoveState.RETURNING:
			_handle_return_movement(delta)
	
	# 軌跡のポイントを記録（一定間隔ごと）
	if current_state == MoveState.MANUAL:
		_record_path_point()

# 自動移動の処理
func _handle_auto_movement(delta):
	var direction = Vector2.ZERO
	
	# 壁沿いの移動を計算
	if position.x >= game_area_rect.size.x - wall_margin and position.y <= wall_margin:
		# 右上
		direction = Vector2(0, 1)
	elif position.x >= game_area_rect.size.x - wall_margin and position.y >= game_area_rect.size.y - wall_margin:
		# 右下
		direction = Vector2(-1, 0)
	elif position.x <= wall_margin and position.y >= game_area_rect.size.y - wall_margin:
		# 左下
		direction = Vector2(0, -1)
	elif position.x <= wall_margin and position.y <= wall_margin:
		# 左上
		direction = Vector2(1, 0)
	elif position.x >= game_area_rect.size.x - wall_margin:
		# 右壁
		direction = Vector2(0, 1)
	elif position.y >= game_area_rect.size.y - wall_margin:
		# 下壁
		direction = Vector2(-1, 0)
	elif position.x <= wall_margin:
		# 左壁
		direction = Vector2(0, -1)
	elif position.y <= wall_margin:
		# 上壁
		direction = Vector2(1, 0)
	
	# 移動適用
	velocity = direction * auto_speed
	move_and_slide()
	
	# 壁沿いにいる場合は位置を記録
	if _is_on_wall():
		last_wall_position = position

# マニュアル移動の処理
func _handle_manual_movement(delta):
	var direction = Vector2.ZERO
	
	# 入力の取得
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	
	# 入力がなくなったら四角形を閉じて自動移動に戻る
	if direction == Vector2.ZERO and path_points.size() > 2:
		# 閉じた四角形を作成する処理
		var closed_path = path_points.duplicate()
		closed_path.append(last_wall_position)  # 最後の点として壁の位置を追加
		emit_signal("path_completed", closed_path)
		path_points.clear()
		current_state = MoveState.RETURNING
		return_target = last_wall_position
		return_timer = 0.0
		return
	
	# 移動適用
	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

# 壁に戻る動作の処理
func _handle_return_movement(delta):
	return_timer += delta
	var progress = min(return_timer / return_time, 1.0)
	
	# 線形補間で戻る
	position = position.lerp(return_target, progress)
	
	# 戻り完了
	if progress >= 1.0:
		position = return_target
		current_state = MoveState.AUTO_CLOCKWISE
		velocity = Vector2.ZERO

# 壁上にいるかどうか
func _is_on_wall():
	var margin = wall_margin * 1.5  # 少し余裕を持たせる
	return (
		position.x <= margin or
		position.x >= game_area_rect.size.x - margin or
		position.y <= margin or
		position.y >= game_area_rect.size.y - margin
	)

# 入力イベント処理
func _input(event):
	# 自動移動中に方向キーが押されたらマニュアルモードに
	if current_state == MoveState.AUTO_CLOCKWISE:
		if (
			event.is_action_pressed("ui_left") or
			event.is_action_pressed("ui_right") or
			event.is_action_pressed("ui_up") or
			event.is_action_pressed("ui_down")
		):
			path_points.clear()
			path_points.append(position)  # 最初のポイントとして現在位置を追加
			emit_signal("path_point_added", position)
			current_state = MoveState.MANUAL

# パスポイントを記録
func _record_path_point():
	# 前のポイントとの距離が最小距離を超えたら記録
	if path_points.size() > 0:
		var last_point = path_points[path_points.size() - 1]
		if position.distance_to(last_point) > min_distance_between_points:
			path_points.append(position)
			emit_signal("path_point_added", position)
	else:
		path_points.append(position)
		emit_signal("path_point_added", position)

# 壁に戻る指示
func return_to_wall():
	current_state = MoveState.RETURNING
	return_target = last_wall_position
	return_timer = 0.0
