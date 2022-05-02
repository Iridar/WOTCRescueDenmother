class X2Effect_ReloadPrimaryWeapon extends X2Effect_Persistent;

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager EventMgr;
	local Object EffectObj;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;
	EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', AbilityActivated_Listener, ELD_OnStateSubmitted,, /*`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID)*/,, EffectObj);
}

// This listener removes the Effect if the activated ability has restored any ammo for the weapon with which this effect is associated with.
static function EventListenerReturn AbilityActivated_Listener(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
    local XComGameStateContext_Ability		AbilityContext;
	local XComGameState_Item				WeaponState;
	local XComGameState_Item				OldWeaponState;
	local XComGameState_Effect_TransferAmmo	EffectState;
	local XComGameState						NewGameState;
	local XComGameStateHistory				History;
	local int ClipSize;
	local int NewClipSize;
	local bool bWeaponWasFullyLoaded;

    AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
    if (AbilityContext == none || AbilityContext.InterruptionStatus == eInterruptionStatus_Interrupt || 
		AbilityContext.InputContext.AbilityTemplateName == 'IRI_ResupplyAmmo') // Don't run the listener for other Resupply Ammo itself, it handles removing existing effects of this type automatically.
        return ELR_NoInterrupt;

	EffectState = XComGameState_Effect_TransferAmmo(CallbackData);
	if (EffectState == none || EffectState.bRemoved)
		return ELR_NoInterrupt;

	// Continue only if the weapon used for the activated ability is the one whose ammo we have fiddled with.
	//	Edit: check disabled so that we don't filter out abilities activated by others.
	//if (AbilityContext.InputContext.ItemObject != EffectState.WeaponRef)
	//	return ELR_NoInterrupt;

	History = `XCOMHISTORY;
	WeaponState = XComGameState_Item(GameState.GetGameStateForObjectID(EffectState.WeaponRef.ObjectID));
	OldWeaponState = XComGameState_Item(History.GetGameStateForObjectID(EffectState.WeaponRef.ObjectID,, GameState.HistoryIndex - 1));
	
	if (WeaponState == none || OldWeaponState == none || OldWeaponState.Ammo >= WeaponState.Ammo)
		return ELR_NoInterrupt;

	// If we're still here, it means the weapon has gained ammo from one source or another. Remove the effect.

	// Removing the effect may change weapon's clip size, so record the clipsize and whether the weapon was at full capacity.
	ClipSize = WeaponState.GetClipSize();
	bWeaponWasFullyLoaded = WeaponState.Ammo == ClipSize;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing Transfer Ammo Effect");
	EffectState.RemoveEffect(NewGameState, NewGameState, true);
	`GAMERULES.SubmitGameState(NewGameState);

	WeaponState = XComGameState_Item(History.GetGameStateForObjectID(EffectState.WeaponRef.ObjectID));
	NewClipSize = WeaponState.GetClipSize();

	// If after removing the effect the weapon has less or more ammo than it's supposed to, address it.
	if (WeaponState.Ammo > NewClipSize || bWeaponWasFullyLoaded && WeaponState.Ammo != NewClipSize)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing Transfer Ammo Effect");
		WeaponState = XComGameState_Item(NewGameState.ModifyStateObject(WeaponState.Class, WeaponState.ObjectID));
		WeaponState.Ammo = NewClipSize;
		`GAMERULES.SubmitGameState(NewGameState);
	}
	
    return ELR_NoInterrupt;
}

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_Unit SourceUnit;
	local XComGameState_Unit TargetUnit;
	local XComGameState_Item PrimaryWeapon;
	local XComGameState_Item NewPrimaryWeapon;
	local XComGameState_Effect_TransferAmmo TransferAmmo;
	local bool bAmmoApplied;

	TargetUnit = XComGameState_Unit(kNewTargetState);
	SourceUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));

	`LOG("X2Effect_ReloadPrimaryWeapon applied to:" @ TargetUnit.GetFullName() @ TargetUnit.GetSoldierClassTemplateName(), class'Denmother'.default.bLog, 'IRIDENMOTHER');
	
	if (SourceUnit != none && TargetUnit != none)
	{	
		PrimaryWeapon = TargetUnit.GetItemInSlot(eInvSlot_PrimaryWeapon, NewGameState);
		if (PrimaryWeapon != none)
		{
			NewPrimaryWeapon = XComGameState_Item(NewGameState.GetGameStateForObjectID(PrimaryWeapon.ObjectID));
			if (NewPrimaryWeapon == none)
			{
				NewPrimaryWeapon = XComGameState_Item(NewGameState.ModifyStateObject(PrimaryWeapon.Class, PrimaryWeapon.ObjectID));
			}
			if (NewPrimaryWeapon != none)
			{
				`LOG("X2Effect_ReloadPrimaryWeapon attempting to transfer special ammo to:" @ PrimaryWeapon.GetMyTemplateName(), class'Denmother'.default.bLog, 'IRIDENMOTHER');

				TransferAmmo = XComGameState_Effect_TransferAmmo(NewEffectState);
				bAmmoApplied = TransferAmmo.ApplyNewAmmo(SourceUnit, TargetUnit, NewPrimaryWeapon, NewGameState);

				NewPrimaryWeapon.Ammo = NewPrimaryWeapon.GetClipSize();
			}
		}
	}

	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);

	// If there was no special ammo to transfer, then there's no reason to keep the effect on the unit.
	if (!bAmmoApplied)
	{
		NewEffectState.RemoveEffect(NewGameState, NewGameState, true);
	}
}
/*
private function XComGameState_Object GetAndPrepStateObject(int ObjectID, XComGameState NewGameState)
{
	local XComGameState_Object StateObject;

	StateObject = NewGameState.GetGameStateForObjectID(ObjectID);
	if (StateObject != none)
	{
		return StateObject;
	}

	StateObject = `XCOMHISTORY.GetGameStateForObjectID(ObjectID);
	if (StateObject != none)
	{
		StateObject = NewGameState.ModifyStateObject(StateObject.Class, StateObject.ObjectID);
	}

	if (StateObject == none)
	{
		`LOG("WARNING :: Failed to get state object with ObjectID:" @ ObjectID, class'Denmother'.default.bLog, 'IRIDENMOTHER');
		`LOG(GetScriptTrace(), class'Denmother'.default.bLog, 'IRIDENMOTHER');
	}

	return StateObject;
}
*/
simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	local XComGameState_Effect_TransferAmmo TransferAmmo;

	`LOG("X2Effect_ReloadPrimaryWeapon removing effect.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

	TransferAmmo = XComGameState_Effect_TransferAmmo(RemovedEffectState);

	TransferAmmo.ApplyOldAmmo(NewGameState);

	super.OnEffectRemoved(ApplyEffectParameters, NewGameState, bCleansed, RemovedEffectState);
}

simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local X2Action_PlaySoundAndFlyOver		SoundAndFlyOver;
	local X2Action_PlayAnimation			PlayAnimation;
	local XComGameState_Effect_TransferAmmo TransferAmmo;
	local XComGameState_Unit				SourceUnit;
	local XComGameState_Unit				TargetUnit;
	local XComGameStateContext_Ability		Context;
	local X2AbilityTemplate					AbilityTemplate;
	local VisualizationActionMetadata		ShooterMetadata;
	local XComGameStateHistory				History;
	local string							FlyoverString;

	if (EffectApplyResult == 'AA_Success')
	{	
		Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
		History = `XCOMHISTORY;

		TargetUnit = XComGameState_Unit(ActionMetadata.StateObject_NewState);
		if (TargetUnit == none)
		{
			`LOG("X2Effect_ReloadPrimaryWeapon no target unit state.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			return;
		}
		TransferAmmo = XComGameState_Effect_TransferAmmo(TargetUnit.GetUnitAffectedByEffectState(EffectName));
		if (TransferAmmo == none)
		{
			`LOG("X2Effect_ReloadPrimaryWeapon no effect state.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			FlyoverString = class'XComGameState_Effect_TransferAmmo'.default.strWeaponReloaded;
		}
		else
		{
			FlyoverString = TransferAmmo.GetFlyoverString();
		}

		PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		PlayAnimation.Params.AnimName = 'HL_CatchSupplies';

		PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		PlayAnimation.Params.AnimName = 'HL_Reload';

		SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, FlyoverString, 'Reloading', eColor_Good, "img:///UILibrary_PerkIcons.UIPerk_reload");

		// Handle Supply Run flyover.
		SourceUnit = XComGameState_Unit(History.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID));
		if (SourceUnit.HasSoldierAbility('IRI_SupplyRun', true))
		{
			AbilityTemplate = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('IRI_SupplyRun');
			if (AbilityTemplate != none)
			{
				ShooterMetadata.StateObject_OldState = History.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
				ShooterMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID);
				ShooterMetadata.VisualizeActor = History.GetVisualizer(Context.InputContext.SourceObject.ObjectID);

				SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ShooterMetadata, Context, false, SoundAndFlyOver));
				SoundAndFlyOver.SetSoundAndFlyOverParameters(None, AbilityTemplate.LocFlyOverText, '', eColor_Good, AbilityTemplate.IconImage);
			}
		}
	}	
}
/*
simulated function AddX2ActionsForVisualization_Removed(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult, XComGameState_Effect RemovedEffect)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(ActionMetadata.StateObject_NewState);
	if (UnitState != none)
	{
		
	}
	super.AddX2ActionsForVisualization_Removed(VisualizeGameState, ActionMetadata, EffectApplyResult, RemovedEffect);
}
*/
defaultproperties
{
	EffectName = "IRI_ResupplyAmmo_Effect"
	GameStateEffectClass = class'XComGameState_Effect_TransferAmmo'
}