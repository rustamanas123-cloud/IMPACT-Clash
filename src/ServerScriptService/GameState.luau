local GameState = {}

GameState.States = {
	LOBBY = "LOBBY",
	INTERMISSION = "INTERMISSION",
	ROUND = "ROUND",
	ENDED = "ENDED"
}

GameState.Current = GameState.States.ROUND

GameState.Participants = {}
GameState.Alive = {}
GameState.ChargeStarted = {}
GameState.StunnedUntil = {}
GameState.IsBlocking = {}
GameState.ComboCount = {}
GameState.LastAttackTime = {}
GameState.ComboExpiresAt = {}

return GameState
