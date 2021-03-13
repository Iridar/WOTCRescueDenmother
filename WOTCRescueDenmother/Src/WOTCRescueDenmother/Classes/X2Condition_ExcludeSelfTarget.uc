class X2Condition_ExcludeSelfTarget extends X2Condition;

event name CallMeetsConditionWithSource(XComGameState_BaseObject kTarget, XComGameState_BaseObject kSource) 
{ 
	if (kTarget == kSource)
	{	
		return 'AA_AbilityUnavailable';
	}
	
	return 'AA_Success'; 
}