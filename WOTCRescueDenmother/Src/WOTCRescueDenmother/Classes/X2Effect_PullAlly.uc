class X2Effect_PullAlly extends X2Effect_GetOverHere;

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_Unit	SourceUnit, TargetUnit;
	local XComGameStateHistory	History;
	local TTIle					TeleportToTile;
	local X2EventManager		EventManager;

	History = `XCOMHISTORY;
	
	SourceUnit = XComGameState_Unit(History.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	TargetUnit = XComGameState_Unit(kNewTargetState);
	if (SourceUnit == none || TargetUnit == none)
		return;

	FindValidPullTile(SourceUnit, TargetUnit, TeleportToTile);
	
	EventManager = `XEVENTMGR;

	// Move the target to this space
	TargetUnit.SetVisibilityLocation(TeleportToTile);

	EventManager.TriggerEvent('ObjectMoved', TargetUnit, TargetUnit, NewGameState);
	EventManager.TriggerEvent('UnitMoveFinished', TargetUnit, TargetUnit, NewGameState);
}

static private function FindValidPullTile(const XComGameState_Unit SourceUnit, const XComGameState_Unit TargetUnit, out TTile TeleportToTile)
{
	local TTile			SourceTile;
	local TTile			TargetTile;
	local Vector		SourceLocation;
	local Vector		TargetLocation;
	local Vector		PullDirection;
	local array<TTile>	AvailableTiles;
	local vector		TeleportToLocation;
	local XComWorldData	World;

	World = `XWORLD;

	SourceTile = SourceUnit.TileLocation;
	TargetTile = TargetUnit.TileLocation;
	SourceLocation = World.GetPositionFromTileCoordinates(SourceTile);
	TargetLocation = World.GetPositionFromTileCoordinates(TargetTile);
	PullDirection = Normal(TargetLocation - SourceLocation);

	GetAvailableTiles(SourceTile, AvailableTiles);

	`LOG("FindValidPullTile::AvailableTiles:" @ AvailableTiles.Length @ ", Source Tile:" @ SourceTile.X @ SourceTile.Y @ SourceTile.Z, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	//	Default to nearest valid location if we can't pull the unit to a neighboring tile.
	if (AvailableTiles.Length == 0)
	{
		TeleportToLocation = World.FindClosestValidLocation(SourceLocation, false, true);
		TeleportToTile = World.GetTileCoordinatesFromPosition(TeleportToLocation);

		`LOG("Found no available tiles, defaulting to closest valid location." @ AvailableTiles.Length, class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return;
	}
	//	Stop validation here if there's only one tile. (1)
	if (AvailableTiles.Length == 1)
	{
		TeleportToTile = AvailableTiles[0];

		`LOG("Found only one available tile, skipping further validation.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return;
	}

	//	We have more than one tile to choose from. Let's choose the best one.

	TruncateAvailableTilesByCover(TargetUnit, AvailableTiles);

	`LOG("Available Tiles after cover trunction:" @ AvailableTiles.Length, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	//	Stop validation here if there's only one tile. (2)
	if (AvailableTiles.Length == 1)
	{
		TeleportToTile = AvailableTiles[0];
		return;
	}

	GetBestTileByPullDirection(PullDirection, AvailableTiles, SourceTile, TeleportToTile);
}

//	If any of the AvailableTiles provide High Cover, then all other tiles will be removed.
//	If no tiles offer High Cover, then remove all except Low Cover.
//	If no tiles offer even Low Cover, then prefer tiles that are not visible to enemies, but only if the Moving Unit is low on health and doesn't have action points.
///	If all tiles in the array don't offer any kind of cover and are in enemy LoS, then we don't do anything.
static private function TruncateAvailableTilesByCover(const XComGameState_Unit MovingUnit, out array<TTile> AvailableTiles)
{
	local XComWorldData					World;
	local TTile							TestTile;
	local array<XComUnitPawnNativeBase> UnitViewers;
	local XComUnitPawnNativeBase		UnitViewer;
	local XComGameState_Unit			EnemyUnit;
	local array<XComGameState_Unit>		EnemyUnits;
	local XComGameStateHistory			History;
	local vector						TestLocation;
	local vector						EnemyUnitLocation;
	local float							TargetCoverAngle;
	local ECoverType					Cover;

	local array<TTile>					HighCoverTiles;
	local array<TTile>					LowCoverTiles;
	local array<TTile>					NoEnemyLoSTiles;

	local bool							bTileIsHighCover;
	local bool							bTileIsLowCover;

	World = `XWORLD;
	History = `XCOMHISTORY;

	//	Sort available tiles by cover they provide.
	foreach AvailableTiles(TestTile)
	{	
		`LOG("TruncateAvailableTilesByCover::Looking at tile:" @ TestTile.X @ TestTile.Y @ TestTile.Z, class'Denmother'.default.bLog, 'IRIDENMOTHER');

		TestLocation = World.GetPositionFromTileCoordinates(TestTile);
		//	Build an array of enemy units that can see this tile.
		World.GetTileViewingUnits(TestTile, UnitViewers);
		EnemyUnits.Length = 0;
		foreach UnitViewers(UnitViewer)
		{	
			EnemyUnit = XComGameState_Unit(History.GetGameStateForObjectID(UnitViewer.ObjectID));
			if (MovingUnit.IsEnemyUnit(EnemyUnit))
			{
				EnemyUnits.AddItem(EnemyUnit);
			}
		}
		`LOG("This tile is visible to:" @ EnemyUnits.Length @ "enemy units.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

		//	No units see this tile. But is this tile in cover or not?
		if (EnemyUnits.Length == 0)
		{
			NoEnemyLoSTiles.AddItem(TestTile);
			`LOG("This tile is not visible to enemies.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

			if (World.IsLocationHighCover(TestLocation))
			{
				`LOG("This tile has high cover.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
				bTileIsHighCover = true;
				bTileIsLowCover = false; 
			}
			else if (World.IsLocationLowCover(TestLocation))
			{
				`LOG("This tile has low cover.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
				bTileIsHighCover = false;
				bTileIsLowCover = true;				
			}
			else
			{
				`LOG("This tile has NO cover.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
				bTileIsHighCover = false;
				bTileIsLowCover = false;	
			}
		}
		else
		{
			foreach EnemyUnits(EnemyUnit)
			{
				EnemyUnitLocation = World.GetPositionFromTileCoordinates(EnemyUnit.TileLocation);
				Cover = World.GetCoverTypeForTarget(EnemyUnitLocation, TestLocation, TargetCoverAngle);

				bTileIsHighCover = true;
				bTileIsLowCover = true; 

				switch (Cover)
				{
				case CT_Standing:
					break;
				case CT_MidLevel:
					`LOG("This tile has NO high cover.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
					bTileIsHighCover = false;
					break;
				case CT_None:
					`LOG("This tile has NO low cover.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
					bTileIsHighCover = false;
					bTileIsLowCover = false;
					break;
				default:
					break;
				}
			}
		}
		if (bTileIsLowCover)
		{
			LowCoverTiles.AddItem(TestTile);
		}
		else if (bTileIsHighCover)
		{
			HighCoverTiles.AddItem(TestTile);
		}
	}

	`LOG("Found tiles in total, High:" @ HighCoverTiles.Length @ ", Low:" @ LowCoverTiles.Length @ "No LoS:" @ NoEnemyLoSTiles.Length, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	//	Truncate the AvailableTiles array, leaving only tiles with best cover.
	//	We prefer High Cover > Low Cover > No Enemy LoS tiles.
	if (HighCoverTiles.Length > 0)
	{
		AvailableTiles = HighCoverTiles;
		`LOG("Selecting High Cover array.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	}
	else if (LowCoverTiles.Length > 0)
	{
		AvailableTiles = LowCoverTiles;
		`LOG("Selecting Low Cover array.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	}	//	Prefer tiles outside enemy LoS only if the unit is low on HP and doesn't have any action points.
	else if (NoEnemyLoSTiles.Length > 0 && MovingUnit.ActionPoints.Length == 0 && (MovingUnit.GetCurrentStat(eStat_HP) / MovingUnit.GetMaxStat(eStat_HP) < 0.5f))
	{
		`LOG("Selecting No LoS array.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		AvailableTiles = NoEnemyLoSTiles;
	}
}

//	This function will collect up to 8 tiles around the source unit. Only empty, enterable tiles on the same Z level are collected.
static private function GetAvailableTiles(const out TTile SourceTile, out array<TTile> AvailableTiles)
{
	local TTile			TestTile;
	local XComWorldData World;
	local array<Actor> TileActors;

	World = `XWORLD;

	TestTile = SourceTile;
	for (TestTile.X = SourceTile.X - 1; TestTile.X <= SourceTile.X + 1; TestTile.X++)
	{
		for (TestTile.Y = SourceTile.Y - 1; TestTile.Y <= SourceTile.Y + 1; TestTile.Y++)
		{
			if (TestTile == SourceTile)
				continue;

			TileActors = World.GetActorsOnTile(TestTile);

			// If the tile is empty and is on the same z as this unit's location
			if (TileActors.Length == 0 && World.CanUnitsEnterTile(TestTile) && World.GetFloorTileZ(TestTile, false) == World.GetFloorTileZ(SourceTile, false))
			{
				AvailableTiles.AddItem(TestTile);
			}
		}
	}
}

static private function GetBestTileByPullDirection(Vector PreferredDirection, const out array<TTile> AvailableTiles, const out TTile SourceTile, out TTile OutTileLocation)
{
	local float			DotToPreferred;
	local float			BestDot;
	local int			CardinalScore;
	local int			BestCardinalScore;
	local XComWorldData	World;
	local vector		DirectionToTestTile;
	local TTile			TestTile;

	World = `XWORLD;
	BestDot = -1.0f; // Exact opposite of preferred direction
	BestCardinalScore = -1;

	foreach AvailableTiles(TestTile)
	{
		CardinalScore = (abs(TestTile.X - SourceTile.X) > 0 && abs(TestTile.Y - SourceTile.Y) > 0) ? 0 : 1;
		DirectionToTestTile = Normal(World.GetPositionFromTileCoordinates(TestTile) - World.GetPositionFromTileCoordinates(SourceTile));
		DotToPreferred = NoZDot(PreferredDirection, DirectionToTestTile);

		// Jwats: Cardinal directions have priority over diagonals
		if ((DotToPreferred >= BestDot && CardinalScore >= BestCardinalScore) || (CardinalScore > BestCardinalScore))
		{
			BestCardinalScore = CardinalScore;
			BestDot = DotToPreferred;
			OutTileLocation = TestTile;
		}
	}
}