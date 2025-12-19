# audio_manager.gd
# 오디오 관리 오토로드 싱글톤
class_name AudioManager
extends Node

# BGM 플레이어
var bgm_player: AudioStreamPlayer
var bgm_fade_tween: Tween

# SE 플레이어 (여러 효과음 동시 재생용)
var se_players: Array[AudioStreamPlayer] = []
const MAX_SE_PLAYERS: int = 8

# 볼륨 설정
var bgm_volume: float = 0.8
var se_volume: float = 1.0

# BGM 경로
const BGM_PATHS = {
	"battle": "res://assets/audio/bgm/battle.ogg",
	"victory": "res://assets/audio/bgm/victory.ogg",
	"defeat": "res://assets/audio/bgm/defeat.ogg",
	"field": "res://assets/audio/bgm/field.ogg"
}

# SE 경로
const SE_PATHS = {
	"attack": "res://assets/audio/se/attack.wav",
	"hit": "res://assets/audio/se/hit.wav",
	"critical": "res://assets/audio/se/critical.ogg",
	"break": "res://assets/audio/se/break.ogg",
	"heal": "res://assets/audio/se/heal.wav",
	"select": "res://assets/audio/se/select.ogg",
	"cancel": "res://assets/audio/se/cancel.wav"
}


func _ready() -> void:
	# BGM 플레이어 생성
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	add_child(bgm_player)

	# SE 플레이어 풀 생성
	for i in range(MAX_SE_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		se_players.append(player)


#region BGM
func play_bgm(bgm_name: String, fade_in: float = 0.5) -> void:
	var path = BGM_PATHS.get(bgm_name, "")
	if path.is_empty():
		push_warning("BGM not found: " + bgm_name)
		return

	if not ResourceLoader.exists(path):
		push_warning("BGM file not found: " + path)
		return

	var stream = load(path)
	if stream:
		_play_bgm_stream(stream, fade_in)


func _play_bgm_stream(stream: AudioStream, fade_in: float) -> void:
	if bgm_fade_tween:
		bgm_fade_tween.kill()

	bgm_player.stream = stream
	bgm_player.volume_db = linear_to_db(0.0)
	bgm_player.play()

	# 페이드 인
	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(
		bgm_player, "volume_db",
		linear_to_db(bgm_volume),
		fade_in
	)


func stop_bgm(fade_out: float = 0.5) -> void:
	if bgm_fade_tween:
		bgm_fade_tween.kill()

	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(
		bgm_player, "volume_db",
		linear_to_db(0.0),
		fade_out
	)
	bgm_fade_tween.tween_callback(bgm_player.stop)


func change_bgm(bgm_name: String, fade_out: float = 0.5, fade_in: float = 0.5) -> void:
	"""현재 BGM을 페이드 아웃 후 새 BGM 재생"""
	if bgm_fade_tween:
		bgm_fade_tween.kill()

	bgm_fade_tween = create_tween()
	bgm_fade_tween.tween_property(
		bgm_player, "volume_db",
		linear_to_db(0.0),
		fade_out
	)
	bgm_fade_tween.tween_callback(func(): play_bgm(bgm_name, fade_in))
#endregion


#region SE
func play_se(se_name: String, pitch: float = 1.0) -> void:
	var path = SE_PATHS.get(se_name, "")
	if path.is_empty():
		push_warning("SE not found: " + se_name)
		return

	if not ResourceLoader.exists(path):
		# 파일이 없으면 조용히 실패 (개발 중에는 흔함)
		return

	var stream = load(path)
	if stream:
		_play_se_stream(stream, pitch)


func _play_se_stream(stream: AudioStream, pitch: float = 1.0) -> void:
	# 사용 가능한 플레이어 찾기
	for player in se_players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch
			player.volume_db = linear_to_db(se_volume)
			player.play()
			return

	# 모든 플레이어가 사용 중이면 첫 번째 것 재사용
	se_players[0].stream = stream
	se_players[0].pitch_scale = pitch
	se_players[0].play()


func play_se_with_variation(se_name: String, pitch_min: float = 0.9, pitch_max: float = 1.1) -> void:
	"""피치 변화를 주어 같은 효과음도 다양하게"""
	play_se(se_name, randf_range(pitch_min, pitch_max))
#endregion


#region 볼륨 조절
func set_bgm_volume(volume: float) -> void:
	bgm_volume = clamp(volume, 0.0, 1.0)
	bgm_player.volume_db = linear_to_db(bgm_volume)


func set_se_volume(volume: float) -> void:
	se_volume = clamp(volume, 0.0, 1.0)
#endregion
