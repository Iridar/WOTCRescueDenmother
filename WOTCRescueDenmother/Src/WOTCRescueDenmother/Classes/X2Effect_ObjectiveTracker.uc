class X2Effect_ObjectiveTracker extends X2Effect_Persistent;

//	This effect remains on Denmother until the mission is over

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager		EventMgr;
	local Object				EffectObj;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;

	//	Using ELD State Submitted for removed from play listener so that it runs after Unit Evacuated.
	//	Unit is removed from play if they are killed too ? Probably the effect is removed when they are killed
	EventMgr.RegisterForEvent(EffectObj, 'UnitRemovedFromPlay', UnitRemovedFromPlay_Listener, ELD_OnStateSubmitted,,,, EffectObj);	
	EventMgr.RegisterForEvent(EffectObj, 'CleanupTacticalMission', TacticalGameEnd_Listener, ELD_Immediate,,,, EffectObj);	
	EventMgr.RegisterForEvent(EffectObj, 'UnitEvacuated', UnitEvacuated_Listener, ELD_Immediate,,,, EffectObj);	
	
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

static function EventListenerReturn UnitEvacuated_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
    local XComGameState_Unit    UnitState;
	local XComGameState_Effect	EffectState;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	EffectState = XComGameState_Effect(CallbackData);

	//`LOG("X2Effect_ObjectiveTracker: UnitEvacuated_Listener running for unit:" @ UnitState.GetFullName() @ "on event:" @ InEventID,, 'IRITEST');

	if (EffectState != none && UnitState != none && UnitState.ObjectID == EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID)
	{
		UnitState.SetUnitFloatValue('IRI_Denmother_Evacuated_Value', 1, eCleanup_BeginTactical);

		`LOG("Denmother is evacuated, removing the objective tracker effect.",, 'IRITEST');
		EffectState.RemoveEffect(NewGameState, NewGameState, true);
	}
	
    return ELR_NoInterrupt;
}

static function bool WasDenmotherEvacuated(XComGameState_Unit UnitState)
{
	local UnitValue UV;

	return UnitState.GetUnitValue('IRI_Denmother_Evacuated_Value', UV);
}

static function EventListenerReturn UnitRemovedFromPlay_Listener(Object EventData, Object EventSource, XComGameState GameState, name InEventID, Object CallbackData)
{
    local XComGameState_Unit		UnitState;
	local XComGameState_Effect		EffectState;
	local XComGameState				NewGameState;

	EffectState = XComGameState_Effect(CallbackData);
	UnitState = XComGameState_Unit(EventData);

	`LOG("X2Effect_ObjectiveTracker: UnitRemovedFromPlay_Listener running for unit:" @ UnitState.GetFullName() @ "on event:" @ InEventID,, 'IRITEST');

	if (EffectState != none && UnitState != none && UnitState.ObjectID == EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating Denmother Objective");

		if (UnitState.IsAlive())
		{
			`LOG("Denmother is alive, marking objective complete.",, 'IRITEST');
			class'Denmother'.static.SucceedDenmotherObjective(NewGameState);		
		}
		else
		{
			`LOG("Denmother is dead, marking objective as failed.",, 'IRITEST');
			class'Denmother'.static.FailDenmotherObjective(NewGameState);	
		}
		`LOG("Denmother is removed from play, removing the objective tracker effect.",, 'IRITEST');
		EffectState.RemoveEffect(NewGameState, NewGameState, true);

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	
    return ELR_NoInterrupt;
}

static function EventListenerReturn TacticalGameEnd_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
	local XComGameState_Effect			EffectState;

	EffectState = XComGameState_Effect(CallbackData);
	
	if (EffectState != none)
	{
		`LOG("TacticalGameEnd_Listener: Removing Objective Tracker effect due to Tactical Game End",, 'IRITEST');
		EffectState.RemoveEffect(NewGameState, NewGameState, true);
	}
    return ELR_NoInterrupt;
}

simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	local XComGameState_Unit		UnitState;
	local XComGameState_BattleData	BattleData;
	local bool bSweepObjectiveComplete, bEvacuated, bAlive;
	
	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	if (UnitState == none)
		return;

	//	if this is false, then the unit was NOT evacuated when the tactical game ended. Then it means if it shows up as true only when the unit WAS evacuated, we can use it to add her to squad when she's evacuated even if she's dead

	//	Denmother is added to the crew if:
	//	1) If XCOM has killed all enemies, then we don't care if she's alive or not, her body is recovered even if she's dead.
	//	2) If she was evacuated. Then we don't care if all enemies were killed or not, and we don't care if she's alive or not, her body is recovered either way.

	bSweepObjectiveComplete = class'Denmother'.static.IsSweepObjectiveComplete();
	bEvacuated = WasDenmotherEvacuated(UnitState);
	`LOG("Removing Objective Tracker effect from:" @ UnitState.GetFullName() @ "unit alive:" @ UnitState.IsAlive() @ "|| bleeding out:" @ UnitState.IsBleedingOut() @ "|| evacuated:" @ bEvacuated @ "|| Sweep objective complete:" @ bSweepObjectiveComplete,, 'IRITEST');
	//	UnitState.IsAlive() cannot be used by itself here, because she will still report as alive even if XCOM evacuated, leaving her bleeding out and surrounded by enemies
	if (bSweepObjectiveComplete || bEvacuated)
	{
		`LOG("Denmother is alive or evacuated, marking objective complete, adding her to squad.",, 'IRITEST');		

		//	Will let Denmother walk off Skyranger and transition from tactical to strategy
		class'Denmother'.static.AddUnitToSquadAndCrew(UnitState, NewGameState);

		// This will display Denmother on the mission end screen
		BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
		BattleData.RewardUnits.AddItem(UnitState.GetReference());		
	}

	//	Is she alive by the time the mission ends?
	bAlive = UnitState.IsAlive();

	//	If so, check if she was bleeding out
	if (bAlive && UnitState.IsBleedingOut())
	{
		//	 If she was, then she will actually survive only if she was evacuated, or XCOM killed all enemies
		bAlive = bEvacuated || bSweepObjectiveComplete;
	}

	if (bAlive)
	{
		class'Denmother'.static.SucceedDenmotherObjective(NewGameState);
	}
	else
	{
		class'Denmother'.static.FailDenmotherObjective(NewGameState);
	}

	super.OnEffectRemoved(ApplyEffectParameters, NewGameState, bCleansed, RemovedEffectState);
}

//	Sweep Objective complete
//		Alive? Add to crew
//		Dead? Add to crew

//	Sweep Objective NOT complete
//		Alive (= evacuated)? Add to crew --handled
//		Dead? Do not add to crew -- handled.
//		Denmother evacced, but rest of the squad is dead? -- expected behavior: you have denmother walk out of skyranger, and she's on the reward screen.
//		Denmother is not evacced, and the squad is dead? --expected behavior: no denmother, end screen mentions her as VIP lost --handled

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

defaultproperties
{
	EffectName = "IRI_Denmother_ObjectiveTracker_Effect"
}