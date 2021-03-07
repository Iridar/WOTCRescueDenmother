class X2Action_ExitCoverSupplyThrow extends X2Action_ExitCover;

// This custom Exit Cover Actions does not make the primary target of the ability crouch due to "friendly fire".

function LineOfFireFriendlyUnitCrouch()
{
	local XComGameState_Unit MyUnitState;
	local XComGameState_Unit TestUnitState;
	local XGUnit TestUnitVisualizer;
	local XComGameStateHistory History;
	local array<TTile> TilesToTest;
	local int scan;
	local XComWorldData WorldData;
	local array<StateObjectReference> UnitRefs;
	local StateObjectReference UnitRef;

	History = `XCOMHISTORY;
	WorldData = `XWORLD;

	MyUnitState = XComGameState_Unit(History.GetGameStateForObjectID(Unit.ObjectID));

	TilesToTest = GetTilesInLineOfFire();
	for( scan = 0; scan < TilesToTest.Length; ++scan )
	{
		UnitRefs = WorldData.GetUnitsOnTile(TilesToTest[scan]);
		foreach UnitRefs( UnitRef )
		{
			//	ADDED
			if (UnitRef == AbilityContext.InputContext.PrimaryTarget)
				continue;
			//	END OF ADDED

			TestUnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
			if( TestUnitState.IsAlive() && !TestUnitState.bRemovedFromPlay && TestUnitState.IsFriendlyUnit(MyUnitState) )
			{
				TestUnitVisualizer = XGUnit(TestUnitState.GetVisualizer());
				//If the unit isn't doing anything, play a crouch
				if( TestUnitVisualizer != Unit && TestUnitVisualizer.GetNumVisualizerTracks() == 0 )
				{
					TestUnitVisualizer.IdleStateMachine.PerformCrouch();
				}
			}
		}
	}
}