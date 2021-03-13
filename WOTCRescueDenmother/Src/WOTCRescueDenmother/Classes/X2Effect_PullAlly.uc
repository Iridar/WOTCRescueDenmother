class X2Effect_PullAlly extends X2Effect_GetOverHere;

static function bool HasBindableNeighborTile(XComGameState_Unit SourceUnitState, vector PreferredDirection=vect(1,0,0), optional out TTile TeleportToTile )
{
	//	Pass source unit state so it can be retrieved later by the delegate
	if( SourceUnitState.FindAvailableNeighborTileWeighted(PreferredDirection, TeleportToTile, IsTileValidForBind, SourceUnitState) )
	{
		return true;
	}
	return false;
}

// This delegate is called for all tiles grabbed by FindAvailableNeighborTileWeighted(), one at a time.
// If it can find no valid tile, the effect will skip validation and pull the unit to any standable tile nearby.
static function bool IsTileValidForBind(const out TTile TileOption, const out TTile SourceTile, const out Object PassedObject)
{
	local XComWorldData					World;
	local array<XComUnitPawnNativeBase> UnitViewers;
	local XComUnitPawnNativeBase		UnitViewer;
	local XComGameState_Unit			EnemyUnit;
	local XComGameState_Unit			SourceUnit;
	local XComGameStateHistory			History;
	local vector						TargetLoc;
	local vector						EnemyUnitLocation;
	local float							TargetCoverAngle;
	local ECoverType					Cover;

	World = `XWORLD;
	History = `XCOMHISTORY;
	SourceUnit = XComGameState_Unit(PassedObject);
	TargetLoc = World.GetPositionFromTileCoordinates(TileOption);

	// Get all units who can see the current tile we're cycling through.
	World.GetTileViewingUnits(TileOption, UnitViewers);
	
	foreach UnitViewers(UnitViewer)
	{	
		//	If this tile is visible to an enemy unit
		EnemyUnit = XComGameState_Unit(History.GetGameStateForObjectID(UnitViewer.ObjectID));
		if (SourceUnit.IsEnemyUnit(EnemyUnit))
		{
			// Is this tile in cover relative to enemy unit's position?
			EnemyUnitLocation = World.GetPositionFromTileCoordinates(EnemyUnit.TileLocation);
			Cover = World.GetCoverTypeForTarget(EnemyUnitLocation, TargetLoc, TargetCoverAngle);

			// No cover = bad tile. Hard pass.
			if (Cover == CT_None)
			{
				return false;
			}
		}
	}

	// If we're here, it means this tile is in cover relative to all enemy units who can see it, or no enemies can see it.
	return true;
}