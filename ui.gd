# ---- scenes/ui.gd ----
extends CanvasLayer

var progress_bar
var percentage_label
var win_screen

func _ready():
	progress_bar = $ProgressBar
	percentage_label = $PercentageLabel
	win_screen = $WinScreen
	
	win_screen.hide()

# 切り取り率の更新
func update_percentage(percentage):
	progress_bar.value = percentage
	percentage_label.text = "切り取り率: %.1f%%" % percentage

# 勝利画面表示
func show_win_screen():
	win_screen.show()
