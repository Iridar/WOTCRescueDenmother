class X2Effect_DeployDenmother extends X2Effect_Persistent;

//	Denmother is first spawned on the neutral team to prevent activating enemy pods. When this effect is removed, she'll be moved to the XCOM team.
//	The effect is removed when any XCOM units activates any ability on her.

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager		EventMgr;
	local Object				EffectObj;
	local XComGameState_Unit	UnitState;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', AbilityActivated_Listener, ELD_OnStateSubmitted,,,, EffectObj);	
	EventMgr.RegisterForEvent(EffectObj, 'CivilianRescued', CivilianRescued_Listener, ELD_Immediate,, UnitState,, EffectObj);	
	
	super.RegisterForEvents(EffectGameState);
}

static function EventListenerReturn CivilianRescued_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
	local XComGameState_Effect EffectState;
	local XComGameState_Unit   UnitState;

	EffectState = XComGameState_Effect(CallbackData);

	if (EffectState != none && !EffectState.bRemoved)
	{
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
		if (UnitState != none)
		{
			class'Denmother'.static.SetGroupAndPlayer(UnitState, eTeam_XCom, NewGameState);		
		}
		else `LOG("ERROR, CivilianRescued_Listener failed to get Denmother unit state from NewGameState.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

		EffectState.RemoveEffect(NewGameState, NewGameState, true);
	}
	
    return ELR_NoInterrupt;
}

static function EventListenerReturn AbilityActivated_Listener(Object EventData, Object EventSource, XComGameState GameState, name InEventID, Object CallbackData)
{
    local XComGameState_Unit            UnitState;
    local XComGameState_Ability         AbilityState;
	local XComGameStateContext_Ability  AbilityContext;
	local XComGameState_Effect			EffectState;
	local XComGameState					NewGameState;

	if (GameState.GetContext().InterruptionStatus == eInterruptionStatus_Interrupt)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState.GetTeam() != eTeam_XCom)
		return ELR_NoInterrupt;

	//	Remove the effect if any XCOM soldier uses an ability on Denmother
	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	AbilityState = XComGameState_Ability(EventData);
	EffectState = XComGameState_Effect(CallbackData);

	if (AbilityContext != none && EffectState != none && !EffectState.bRemoved && AbilityState != none && AbilityState.IsAbilityInputTriggered())
	{
		if (AbilityContext.InputContext.PrimaryTarget == EffectState.ApplyEffectParameters.TargetStateObjectRef)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Setting XCOM team for Denmother");

			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
			class'Denmother'.static.SetGroupAndPlayer(UnitState, eTeam_XCom, NewGameState);		

			EffectState.RemoveEffect(NewGameState, NewGameState, true);
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
	}
	
    return ELR_NoInterrupt;
}

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_Unit				UnitState;
	
	UnitState = XComGameState_Unit(kNewTargetState);
	
	if (UnitState != none)
	{
		UnitState.ActionPoints.Length = 0;

		//	tell the game that the new unit is part of your squad so the mission wont just end if others retreat -LEB
		//	(in case Denmother is revived, and is last to evac, or the squad dies)
		UnitState.bSpawnedFromAvenger = true;	

		//	Damage and bleedout the unit.
		//UnitState.TakeEffectDamage(self, UnitState.GetCurrentStat(eStat_HP) + UnitState.GetCurrentStat(eStat_ShieldHP), 0, 0, ApplyEffectParameters, NewGameState, true, true);

		//UnitState.SetCurrentStat(eStat_SightRadius, 3);
	}
	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}

simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	`LOG("Removing Deploy Denmother effect.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

	super.OnEffectRemoved(ApplyEffectParameters, NewGameState, bCleansed, RemovedEffectState);
}

defaultproperties
{
	EffectName = "IRI_DeployDenmother_Effect"
}