class X2Condition_UnitSize extends X2Condition;

//	This condition fails if the ability is activated against a unit higher than regular trooper or that takes up more than 1 tile.

event name CallMeetsCondition(XComGameState_BaseObject kTarget) 
{
	local XComGameState_Unit	UnitState;
	
	UnitState = XComGameState_Unit(kTarget);
	
	if (UnitState != none)
	{
		if (UnitState.UnitSize > 1 || UnitState.UnitHeight > 2)
		{
			return 'AA_AbilityUnavailable';
		}
	}
	else return 'AA_NotAUnit';
	
	return 'AA_Success'; 
}
/*
Unit:  Faceless size:  1 height:  4
Unit:  ADVENT Trooper size:  1 height:  2
Unit:  Berserker size:  1 height:  3
*/