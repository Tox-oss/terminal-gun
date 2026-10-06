extends CanvasLayer
## L'HUD: vite, punteggio, livello, nemici vivi, stato dell'arma.
##
## Un `CanvasLayer` e sette `Control`: otto nodi, sempre gli stessi. L'HUD non
## cresce con la partita e non legge nessun nodo: chi lo alimenta gli passa dei
## numeri con `set_state()`, e chi lo alimenta e' `src/render/arena.gd`, che li
## prende dal contratto. Un HUD che si va a cercare il giocatore con
## `get_node("../../Player")` diventerebbe una quarta foglia che conosce le altre.
##
## Le stringhe a schermo sono ASCII: l'HUD viene letto anche nei log di
## `--headless`, e la console di Windows mangia gli accenti.

const DEFAULT_MAX_HEALTH := 100.0
## Sotto questa vita la barra diventa rossa: e' l'unico colore che cambia.
const LOW_HEALTH_RATIO := 0.3

var health: float = DEFAULT_MAX_HEALTH
var health_max: float = DEFAULT_MAX_HEALTH
var score: int = 0
var level: int = 1
var weapon_text: String = "-"
var enemies: int = 0

var _health: ProgressBar = null
var _health_text: Label = null
var _score: Label = null
var _level: Label = null
var _weapon: Label = null
var _enemies: Label = null

func _ready() -> void:
	# Percorsi espliciti invece di `%Nome`: se una Label si cancella, l'HUD
	# deve mostrare un HUD incompleto, non spegnersi con un errore.
	_health = get_node_or_null("Root/Health") as ProgressBar
	_health_text = get_node_or_null("Root/HealthText") as Label
	_score = get_node_or_null("Root/Score") as Label
	_level = get_node_or_null("Root/Level") as Label
	_weapon = get_node_or_null("Root/Weapon") as Label
	_enemies = get_node_or_null("Root/Enemies") as Label
	redraw()

## Il punto d'ingresso di arena. Numeri, non nodi.
func set_state(p_health: float, p_health_max: float, p_score: int,
		p_weapon_text: String, p_enemies: int, p_level: int) -> void:
	health = p_health
	# Una `max_hp` a zero o negativo viene dal chiamante sbagliato: senza il
	# tetto qui sotto, `health / health_max` darebbe un infinito e la barra
	# mostrerebbe numeri a caso.
	health_max = maxf(p_health_max, 0.0001)
	score = p_score
	weapon_text = p_weapon_text
	enemies = p_enemies
	level = p_level
	redraw()

## 0.0 a 1.0, sempre. Anche con vite a zero o negative.
func health_ratio() -> float:
	return clampf(health / maxf(health_max, 0.0001), 0.0, 1.0)

## Cosa c'è scritto, per il test: leggo le Label invece di ricostruire qui la
## stringa che metterei dentro.
func score_text() -> String:
	return _score.text if _score != null else ""

func enemy_text() -> String:
	return _enemies.text if _enemies != null else ""

func weapon_state_text() -> String:
	return _weapon.text if _weapon != null else ""

func redraw() -> void:
	var ratio := health_ratio()
	if _health != null:
		_health.max_value = health_max
		_health.value = clampf(health, 0.0, health_max)
	if _health_text != null:
		_health_text.text = "HP %d / %d" % [roundi(health), roundi(health_max)]
		_health_text.modulate = Color(1.0, 0.45, 0.4) if ratio <= LOW_HEALTH_RATIO else Color.WHITE
	if _score != null:
		_score.text = "SCORE %d" % score
	if _level != null:
		_level.text = "LV %d" % level
	if _weapon != null:
		_weapon.text = "WEAPON %s" % weapon_text
	if _enemies != null:
		_enemies.text = "ENEMIES %d" % enemies