class X2Effect_DeployDenmother extends X2Effect_PersistentStatChange;

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager		EventMgr;
	local Object				EffectObj;
	local XComGameState_Unit	UnitState;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	
	EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', AbilityActivated_Listener, ELD_OnStateSubmitted,,,, EffectObj);	
	EventMgr.RegisterForEvent(EffectObj, 'UnitRemovedFromPlay', UnitRemovedFromPlay_Listener, ELD_Immediate,, UnitState,, EffectObj);	
	
	
	//EventMgr.RegisterForEvent(EffectObj, 'UnitSeesUnit', AbilityActivated_Listener, ELD_OnStateSubmitted,,,, EffectObj);	
	
	super.RegisterForEvents(EffectGameState);
}

static function EventListenerReturn UnitRemovedFromPlay_Listener(Object EventData, Object EventSource, XComGameState NewGameState, name InEventID, Object CallbackData)
{
    local XComGameState_Unit            UnitState;
	local XComGameState_Effect			EffectState;

	EffectState = XComGameState_Effect(CallbackData);
	UnitState = XComGameState_Unit(EventData);

	`LOG("UnitRemovedFromPlay_Listener running for unit:" @ UnitState.GetFullName(),, 'IRITEST');

	if (EffectState != none)
	{
		`LOG("UnitRemovedFromPlay_Listener: Removing the effect",, 'IRITEST');
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

	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	AbilityState = XComGameState_Ability(EventData);
	EffectState = XComGameState_Effect(CallbackData);

	if (AbilityContext != none && EffectState != none && AbilityState != none && AbilityState.IsAbilityInputTriggered())
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
		//	Do it here so that Denmother doesn't appear in the skyranger cinematic

		//	tell the game that the new unit is part of your squad so the mission wont just end if others retreat -LEB
		UnitState.bSpawnedFromAvenger = true;	
	}
	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}

defaultproperties
{
	EffectName = "IRI_DeployDenmother_Effect"
}