class_name NetConfig
## Shared constants for the booth leaderboard network (server/station/display).

const PORT := 4433
const MAX_PEERS := 8
const MAX_NAME_LEN := 16

## Zero-config discovery: server broadcasts a beacon on this UDP port;
## stations/display listen for it and learn the server's LAN IP.
const DISCOVERY_PORT := 4434
const DISCOVERY_SERVICE := "accessible-archery-leaderboard"
const DISCOVERY_INTERVAL_SECONDS := 1.0
## How long a station/display waits to hear a beacon before falling back to
## the manual/default IP (booth WiFi/switch hiccup, or broadcast blocked).
const DISCOVERY_TIMEOUT_SECONDS := 5.0

## Single arrows cap at 10 (see target.gd); a banked run is many arrows, so
## this is a generous sanity ceiling, not a real max score.
const MAX_PLAUSIBLE_SCORE := 5000

## How often a disconnected station/display retries connecting, forever,
## with no staff intervention needed.
const RECONNECT_INTERVAL_SECONDS := 3.0

## Placeholder list — extend as needed. Public-screen safety net, not a
## real moderation system (booth is supervised, so validation stays light).
const PROFANITY_BLOCKLIST: PackedStringArray = [
	"fuck", "shit", "bitch", "cunt", "nigger", "faggot",
]
