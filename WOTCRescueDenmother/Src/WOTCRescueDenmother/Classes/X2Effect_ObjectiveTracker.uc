class X2Effect_ObjectiveTracker extends X2Effect_Persistent;

//	This effect is responsible for tracking Denmother throughout the mission and adjusting the displayed objective status in the UI.
//	The effect also handles handling Denmother herself, and adding her to squad.

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Unit				UnitState;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	if (UnitState != none)
	{
		`LOG("X2Effect_ObjectiveTracker:OnEffectAdded: adding Denmother to squad.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

		// Add her to squad so she doesn't get cleaned up by the game if she's evacuated as a corpse.
		// Can't do it after she's created, cuz then she gets to deploy in Skyranger matinee :joy:
		XComHQ = class'Denmother'.static.GetAndPrepXComHQ(NewGameState);
		XComHQ.Squad.AddItem(UnitState.GetReference());
	}
	else
	{
		`LOG("X2Effect_ObjectiveTracker:OnEffectAdded: Error, could not find Denmother's unit state in New Game State.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	}

	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager		EventMgr;
	local Object				EffectObj;
	local XComGameState_Unit	UnitState;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));

	//EventMgr.UnRegisterFromEvent(EffectObj, 'UnitDied');
	EventMgr.RegisterForEvent(EffectObj, 'UnitDied', UnitDied_Listener, ELD_Immediate,, UnitState,, EffectObj);	

	//	Using ELD State Submitted for removed from play listener so that it runs *after* Unit Evacuated listener.
	EventMgr.RegisterForEvent(EffectObj, 'UnitRemovedFromPlay', UnitRemovedFromPlay_Listener, ELD_OnStateSubmitted,, UnitState,, EffectObj);	
	EventMgr.RegisterForEvent(EffectObj, 'UnitEvacuated', UnitEvacuated_Listener, ELD_Immediate,, UnitState,, EffectObj);	

	EventMgr.RegisterForEvent(EffectObj, 'CleanupTacticalMission', TacticalGameEnd_Listener, ELD_Immediate,,,, EffectObj);	

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

static function EventListenerReturn UnitDied_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
    local XComGameState_Unit    UnitState;
	local XComGameState_Effect	EffectState;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	EffectState = XComGameState_Effect(CallbackData);

	if (EffectState != none && UnitState != none)
	{
		`LOG("X2Effect_ObjectiveTracker: UnitDied_Listener: Denmother is dead, marking objective as failed.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		class'Denmother'.static.FailDenmotherObjective(NewGameState);	
	}
	
    return ELR_NoInterrupt;
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

	//`LOG("X2Effect_ObjectiveTracker: UnitEvacuated_Listener running for unit:" @ UnitState.GetFullName() @ "on event:" @ InEventID, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	if (EffectState != none && !EffectState.bRemoved && UnitState != none)
	{
		UnitState.SetUnitFloatValue('IRI_Denmother_Evacuated_Value', 1, eCleanup_BeginTactical);

		`LOG("X2Effect_ObjectiveTracker: UnitEvacuated_Listener: Denmother is evacuated, removing the objective tracker effect.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		EffectState.RemoveEffect(NewGameState, NewGameState, true);
	}
	
    return ELR_NoInterrupt;
}

static private function bool WasDenmotherEvacuated(XComGameState_Unit UnitState)
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

	`LOG("X2Effect_ObjectiveTracker: UnitRemovedFromPlay_Listener running for unit:" @ UnitState.GetFullName() @ "on event:" @ InEventID, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	if (EffectState != none && !EffectState.bRemoved && UnitState != none && UnitState.ObjectID == EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating Denmother Objective");

		if (UnitState.IsAlive())
		{
			`LOG("X2Effect_ObjectiveTracker: UnitRemovedFromPlay_Listener: Denmother is alive, marking objective complete.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			class'Denmother'.static.SucceedDenmotherObjective(NewGameState);		
		}
		else
		{
			`LOG("X2Effect_ObjectiveTracker: UnitRemovedFromPlay_Listener: Denmother is dead, marking objective as failed.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			class'Denmother'.static.FailDenmotherObjective(NewGameState);	
		}
		`LOG("X2Effect_ObjectiveTracker: UnitRemovedFromPlay_Listener: Denmother is removed from play, removing the objective tracker effect.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		EffectState.RemoveEffect(NewGameState, NewGameState, true);

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	
    return ELR_NoInterrupt;
}

static function EventListenerReturn TacticalGameEnd_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
	local XComGameState_Effect EffectState;

	EffectState = XComGameState_Effect(CallbackData);
	
	if (EffectState != none && !EffectState.bRemoved)
	{
		`LOG("TacticalGameEnd_Listener: Removing Objective Tracker effect due to Tactical Game End", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		EffectState.RemoveEffect(NewGameState, NewGameState, true);
	}
    return ELR_NoInterrupt;
}

simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	local XComGameState_Unit				UnitState;
	local XComGameState_BattleData			BattleData;
	local bool								bSweepObjectiveComplete, bEvacuated, bAlive;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Item				ItemState;
	
	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	if (UnitState == none)
		return;

	//	if this is false, then the unit was NOT evacuated when the tactical game ended. Then it means if it shows up as true only when the unit WAS evacuated, we can use it to add her to squad when she's evacuated even if she's dead

	//	Denmother is added to the crew if:
	//	1) If XCOM has killed all enemies, then we don't care if she's alive or not, her body is recovered even if she's dead.
	//	2) If she was evacuated. Then we don't care if all enemies were killed or not, and we don't care if she's alive or not, her body is recovered either way.

	bSweepObjectiveComplete = class'Denmother'.static.IsSweepObjectiveComplete();
	bEvacuated = WasDenmotherEvacuated(UnitState);
	`LOG("Removing Objective Tracker effect from:" @ UnitState.GetFullName() @ "unit alive:" @ UnitState.IsAlive() @ "|| bleeding out:" @ UnitState.IsBleedingOut() @ "|| evacuated:" @ bEvacuated @ "|| Sweep objective complete:" @ bSweepObjectiveComplete, class'Denmother'.default.bLog, 'IRIDENMOTHER');

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


	//	UnitState.IsAlive() cannot be used by itself here, because she will still report as alive even if XCOM evacuated, leaving her bleeding out and surrounded by enemies
	if (bSweepObjectiveComplete || bEvacuated)
	{
		`LOG("Denmother is alive or body recovered, adding her to Reward Units.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

		// This will display Denmother on the mission end screen
		BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
		BattleData.RewardUnits.AddItem(UnitState.GetReference());	
		
		if (!bAlive)
		{
			//	If Denmother is dead, but her body was recovered, add her rifle into mission loot.
			ItemState = UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon);
			if (ItemState != none)
			{
				//	This is enough to add the rifle into HQ inventory
				BattleData.CarriedOutLootBucket.AddItem(ItemState.GetMyTemplateName());

				//	This is required to make it show up on the post mission screen
				`LOG("Adding Denmother's rifle to XCOM HQ Loot Recovered:" @ ItemState.GetMyTemplateName(), class'Denmother'.default.bLog, 'IRIDENMOTHER');		
				XComHQ = class'Denmother'.static.GetAndPrepXComHQ(NewGameState);
				XComHQ.LootRecovered.AddItem(ItemState.GetReference());
			}
		}
		else
		{
			//	If Denmother is dead and her body wasn't recovered then move her to resistance team.
			//-- Pointless, she still counts as XCOM soldier killed on the mission end screen.
			//`LOG("Denmother is dead and her body was not recovered, moving her to the neutral team.", class'Denmother'.default.bLog, 'IRIDENMOTHER');		
			//class'Denmother'.static.SetGroupAndPlayer(UnitState, eTeam_Resistance, NewGameState);
		}
	}

	super.OnEffectRemoved(ApplyEffectParameters, NewGameState, bCleansed, RemovedEffectState);
}

//	Sweep Objective complete
//		Alive? Add to crew
//		Dead? Add to crew - handled

//	Sweep Objective NOT complete
//		Alive (= evacuated)? Add to crew --handled
//		Dead? Do not add to crew -- handled.
//		Denmother evacced, but rest of the squad is dead? -- expected behavior: you have denmother walk out of skyranger, and she's on the reward screen. --handled
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

	`LOG("Running ObjectiveComplete_Listener for objective:" @ ObjectiveState.GetMyTemplateName(), class'Denmother'.default.bLog, 'IRIDENMOTHER');

	//if (ObjectiveState.)
	//{
	//	`LOG("ObjectiveComplete_Listener:: sweep objective complete, removing effect Objective Tracker effect from Denmother", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	//	EffectState.RemoveEffect(NewGameState, NewGameState, true);
	//}
	
    return ELR_NoInterrupt;
}*/

defaultproperties
{
	EffectName = "IRI_Denmother_ObjectiveTracker_Effect"
}