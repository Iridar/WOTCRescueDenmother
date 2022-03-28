class X2Effect_BreakConcealmentListener extends X2Effect_PersistentStatChange;

// Denmother is put into concealment when she's spawned for the first time, this effect will break the concealment when she's targeted by any XCOM ability.

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local Object EffectObj;

	EffectObj = EffectGameState;
	`XEVENTMGR.RegisterForEvent(EffectObj, 'AbilityActivated', AbilityActivated_Listener, ELD_OnStateSubmitted,, ,, EffectObj);	
	
	super.RegisterForEvents(EffectGameState);
}

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_Unit UnitState;

	// Apply the effect normally first, so that she gets reduced detection radius.
	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);

	// Put Denmother into concealment. She should already be in concealment when her Unit State is created, but she gets teleported afterwards, and I'm worried
	// there's a possibility of her concealment being broken when she gets onto her new tile. So just in case, put her into concealment again.
	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	if (UnitState != none)
	{
		`LOG("X2Effect_BreakConcealmentListener:OnEffectAdded: activating Denmother's concealment.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		UnitState.SetIndividualConcealment(true, NewGameState);
	}
	else
	{
		`LOG("X2Effect_BreakConcealmentListener:OnEffectAdded: Error, could not find Denmother's unit state in New Game State.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	}
}

static function EventListenerReturn AbilityActivated_Listener(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
    local XComGameStateContext_Ability	AbilityContext;
    local XComGameState_Unit            SourceUnit;
	local XComGameState_Unit            UnitState;
	local XComGameState_Effect			EffectState;
	local XComGameState					NewGameState;
	local StateObjectReference			TargetRef;
	local bool							bDenmotherMultiTarget;

    AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
    if (AbilityContext == none || AbilityContext.InterruptionStatus == eInterruptionStatus_Interrupt)
        return ELR_NoInterrupt;

    SourceUnit = XComGameState_Unit(EventSource);
    if (SourceUnit == none || SourceUnit.GetTeam() != eTeam_XCOM)
        return ELR_NoInterrupt;

	EffectState = XComGameState_Effect(CallbackData);
	if (EffectState == none || EffectState.bRemoved)
		return ELR_NoInterrupt;

	// Don't trigger for "abilities" Denmother activates herself.
	if (AbilityContext.InputContext.SourceObject == EffectState.ApplyEffectParameters.TargetStateObjectRef)
		return ELR_NoInterrupt;

	foreach AbilityContext.InputContext.MultiTargets(TargetRef)
	{
		if (TargetRef == EffectState.ApplyEffectParameters.TargetStateObjectRef)
		{
			bDenmotherMultiTarget = true;
			break;
		}
	}

	// Break Denmother's concealment the moment she's targeted by an XCOM Ability.
	if (bDenmotherMultiTarget || AbilityContext.InputContext.PrimaryTarget == EffectState.ApplyEffectParameters.TargetStateObjectRef)
	{
		`LOG("X2Effect_BreakConcealmentListener:AbilityActivated_Listener: breking Denmother's concealment by ability:" @ AbilityContext.InputContext.AbilityTemplateName, class'Denmother'.default.bLog, 'IRIDENMOTHER');
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Breaking Denmother Concealment");

		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID));
		EffectState.RemoveEffect(NewGameState, NewGameState, true);
		UnitState.SetIndividualConcealment(false, NewGameState);
		UnitState.bRequiresVisibilityUpdate = true;

		`GAMERULES.SubmitGameState(NewGameState);
	}
    return ELR_NoInterrupt;
}