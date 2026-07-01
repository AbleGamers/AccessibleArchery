extends Node
## Autoload `Role`. Parses process role from CLI args, once, on boot.
##
## `--station` / `--server` / `--display` select a role; no flag (a plain
## double-click, or pressing Play in the editor) defaults to station so dev
## iteration never needs a flag.
##
## `--ip=<addr>` overrides the server address stations/display connect to —
## skips UDP auto-discovery entirely, a manual fallback for when broadcast
## traffic is blocked (locked-down venue WiFi, VPN, etc).
##
## `--kiosk` / `--windowed` control fullscreen + close-lockdown, independent
## of role: real booth shortcuts pass `--kiosk` (display is kiosk by default
## regardless — see display_kiosk.gd); dev testing can force `--windowed` to
## avoid a display grabbing the whole screen while iterating.

enum Mode { STATION, SERVER, DISPLAY }

var mode: Mode = Mode.STATION
var server_ip: String = "127.0.0.1"
var ip_overridden: bool = false
var kiosk: bool = false
var windowed: bool = false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		mode = Mode.SERVER
	elif "--display" in args:
		mode = Mode.DISPLAY
	else:
		mode = Mode.STATION  # covers both no flag and explicit --station
	kiosk = "--kiosk" in args
	windowed = "--windowed" in args
	for a in args:
		if a.begins_with("--ip="):
			server_ip = a.substr(5)
			ip_overridden = true
