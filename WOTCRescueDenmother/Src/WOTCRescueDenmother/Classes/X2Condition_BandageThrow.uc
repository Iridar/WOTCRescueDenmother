class X2Condition_BandageThrow extends X2Condition;

event name CallMeetsCondition(XComGameState_BaseObject kTarget) 
{
	local XComGameState_Unit	UnitState;
	
	UnitState = XComGameState_Unit(kTarget);
	
	if (UnitState != none)
	{
		if (UnitState.GetCurrentStat(eStat_HP) < UnitState.GetMaxStat(eStat_HP) || UnitState.IsUnitAffectedByEffectName('Bleeding'))
		{
			return 'AA_Success'; 
		}
	}
	else return 'AA_NotAUnit';
	
	return 'AA_AbilityUnavailable';
}