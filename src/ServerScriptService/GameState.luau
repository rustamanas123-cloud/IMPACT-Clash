local GameState = {}

GameState.States = {
	LOBBY = "LOBBY",
	INTERMISSION = "INTERMISSION",
	ROUND = "ROUND",
	ENDED = "ENDED",
}

GameState.Current = GameState.States.LOBBY
GameState.RoundNumber = 0
GameState.RoundEndsAt = 0
GameState.Winner = nil

GameState.Participants = {}
GameState.Alive = {}
GameState.ChargeStarted = {}
GameState.StunnedUntil = {}
GameState.IsBlocking = {}
GameState.ComboCount = {}
GameState.LastAttackTime = {}
GameState.ComboExpiresAt = {}
GameState.DashReadyAt = {}

return GameState
