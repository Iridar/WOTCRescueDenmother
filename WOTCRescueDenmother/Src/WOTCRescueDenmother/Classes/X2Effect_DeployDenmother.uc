class X2Effect_DeployDenmother extends X2Effect_Persistent;

//	This effect will remain on Denmother until the mission is over or an XCOM unit activates an ability on her.
//	Removing the effect will move her to the XCOM Team, meaning the player will be able to control her, if she's revived,
//	and she will activate enemy pods if they see her, even unconscious.

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager		EventMgr;
	local Object				EffectObj;
	//local XComGameState_Unit	UnitState;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;
	//UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	
	EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', AbilityActivated_Listener, ELD_OnStateSubmitted,,,, EffectObj);	
	//EventMgr.RegisterForEvent(EffectObj, 'UnitRemovedFromPlay', UnitRemovedFromPlay_Listener, ELD_Immediate,, UnitState,, EffectObj);	

	super.RegisterForEvents(EffectGameState);
}

//	Probably not necessary
static function EventListenerReturn UnitRemovedFromPlay_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
	local XComGameState_Effect			EffectState;

	EffectState = XComGameState_Effect(CallbackData);
	if (EffectState != none)
	{
		`LOG("X2Effect_DeployDenmother: UnitRemovedFromPlay_Listener: Removing the effect.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
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

	if (AbilityContext != none && EffectState != none && AbilityState != none && AbilityState.IsAbilityInputTriggered())
	{
		if (AbilityContext.InputContext.PrimaryTarget == EffectState.ApplyEffectParameters.TargetStateObjectRef)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Setting XCOM team for Denmother");
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
		UnitState.TakeEffectDamage(self, UnitState.GetCurrentStat(eStat_HP) + UnitState.GetCurrentStat(eStat_ShieldHP), 0, 0, ApplyEffectParameters, NewGameState, true, true);

		//UnitState.SetCurrentStat(eStat_SightRadius, 3);
	}
	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}

simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	local XComGameState_Unit UnitState;
	
	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	if (UnitState != none)
	{
		`LOG("Removing Deploy Denmother effect from:" @ UnitState.GetFullName(), class'Denmother'.default.bLog, 'IRIDENMOTHER');

		class'Denmother'.static.SetGroupAndPlayer(UnitState, eTeam_XCom, NewGameState);

		//UnitState.SetCurrentStat(eStat_SightRadius, UnitState.GetBaseStat(eStat_SightRadius));	
	}
	super.OnEffectRemoved(ApplyEffectParameters,NewGameState, bCleansed, RemovedEffectState);
}

defaultproperties
{
	EffectName = "IRI_DeployDenmother_Effect"
}