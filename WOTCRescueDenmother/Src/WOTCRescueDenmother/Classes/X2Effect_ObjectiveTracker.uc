class X2Effect_ObjectiveTracker extends X2Effect_Persistent;

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager		EventMgr;
	local Object				EffectObj;
	//local XComGameState_Unit	UnitState;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;
	//UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	
	EventMgr.RegisterForEvent(EffectObj, 'UnitRemovedFromPlay', UnitRemovedFromPlay_Listener, ELD_Immediate,,,, EffectObj);	

	//	'TacticalGameEnd' -> too late, apparently unit is already "dead" at that time (I assume if it's not on the XCOM team)
	//	'OverrideVictoriousPlayer' -> still dead
	//	'CleanupTacticalMission' -> still dead
	EventMgr.RegisterForEvent(EffectObj, 'PreCompleteStrategyFromTacticalTransfer', TacticalGameEnd_Listener, ELD_Immediate,,,, EffectObj);	
	

	/*
	the 'OnMissionObjectiveComplete' event is so worthless.
	If you get BattleData from history, then the objective is not complete yet, so you don't know which objective was completed.
	If you get BattlaData from pending Game State given to you by the event, then all objectives in it will have been already marked complete and removed,
	so again you can't check which objective was complete if the mission is over now.
	'PreCompleteStrategyFromTacticalTransfer' doesn't get picked up by event listeners in persistent effects, which is understandable
	'ObjectiveCompleted' doesn't trigger for regular mission objectives
	*/
	//EventMgr.RegisterForEvent(EffectObj, 'ObjectiveCompleted', ObjectiveComplete_Listener, ELD_Immediate,,,, EffectObj);	
	
	super.RegisterForEvents(EffectGameState);
}
/*
static function EventListenerReturn ObjectiveComplete_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
    //local XComGameState_Unit            UnitState;
	local XComGameState_Effect			EffectState;
	local XComGameState_Objective		ObjectiveState;

	EffectState = XComGameState_Effect(CallbackData);
	ObjectiveState = XComGameState_Objective(EventData);
	ObjectiveState = XComGameState_Objective(NewGameState.GetGameStateForObjectID(ObjectiveState.ObjectID));

	`LOG("Running ObjectiveComplete_Listener for objective:" @ ObjectiveState.GetMyTemplateName(),, 'IRITEST');

	//if (ObjectiveState.)
	//{
	//	`LOG("ObjectiveComplete_Listener:: sweep objective complete, removing effect Objective Tracker effect from Denmother",, 'IRITEST');
	//	EffectState.RemoveEffect(NewGameState, NewGameState, true);
	//}
	
    return ELR_NoInterrupt;
}*/

static function EventListenerReturn UnitRemovedFromPlay_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
    local XComGameState_Unit            UnitState;
	local XComGameState_Effect			EffectState;

	EffectState = XComGameState_Effect(CallbackData);
	UnitState = XComGameState_Unit(EventData);

	`LOG("UnitRemovedFromPlay_Listener running for unit:" @ UnitState.GetFullName() @ "on event:" @ InEventID,, 'IRITEST');

	if (EffectState != none && UnitState != none && UnitState.TacticalTag == 'IRI_DenmotherReward_Tag')
	{
		`LOG("UnitRemovedFromPlay_Listener:: Removing effect Objective Tracker effect from Denmother",, 'IRITEST');
		EffectState.RemoveEffect(NewGameState, NewGameState, true);
	}
	
    return ELR_NoInterrupt;
}

static function EventListenerReturn TacticalGameEnd_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
    local XComGameState_Unit			UnitState;
	local XComGameState_Effect			EffectState;

	EffectState = XComGameState_Effect(CallbackData);
	
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));

	`LOG("TacticalGameEnd_Listener: Removing Objective Tracker effect from:" @ UnitState.GetFullName(),, 'IRITEST');

	//	Add Denmother to squad if she's alive when she exists tactical play so that she can walk off the Skyranger
	if (UnitState.IsAlive())
	{
		`LOG("Denmother is alive, marking objective complete, adding her to squad.",, 'IRITEST');

		class'Denmother'.static.SucceedDenmotherObjective(UnitState, NewGameState);		
	}
	else
	{
		`LOG("Denmother is dead, marking objective as failed.",, 'IRITEST');
		class'Denmother'.static.FailDenmotherObjective(NewGameState);		
	}	
	
    return ELR_NoInterrupt;
}

simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	local XComGameState_Unit			UnitState;
	
	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.TargetStateObjectRef.ObjectID));

	`LOG("Removing Objective Tracker effect from:" @ UnitState.GetFullName(),, 'IRITEST');

	//	Add Denmother to squad if she's alive when she exists tactical play so that she can walk off the Skyranger
	if (UnitState.IsAlive())
	{
		`LOG("Denmother is alive, marking objective complete, adding her to squad.",, 'IRITEST');

		class'Denmother'.static.SucceedDenmotherObjective(UnitState, NewGameState);		
	}
	else
	{
		`LOG("Denmother is dead, marking objective as failed.",, 'IRITEST');
		class'Denmother'.static.FailDenmotherObjective(NewGameState);		
	}	

	super.OnEffectRemoved(ApplyEffectParameters,NewGameState, bCleansed, RemovedEffectState);
}

defaultproperties
{
	EffectName = "IRI_Denmother_ObjectiveTracker_Effect"
}