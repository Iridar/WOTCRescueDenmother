class XComGameState_Effect_TransferAmmo extends XComGameState_Effect;

var localized string strWeaponReloaded;

var StateObjectReference		WeaponRef;

var StateObjectReference		NewAmmoRef;
var array<StateObjectReference>	NewAmmoAbilities;
var EInventorySlot				NewAmmoSlot;

var StateObjectReference		OldAmmoRef;
//var array<StateObjectReference>	OldAmmoAbilities;
var EInventorySlot				OldAmmoSlot;

var bool bAmmoApplied;

final function bool ApplyNewAmmo(XComGameState_Unit SourceUnit, XComGameState_Unit TargetUnit, XComGameState_Item ItemState, XComGameState NewGameState)
{
	local X2AmmoTemplate			AmmoTemplate;
	local X2WeaponTemplate			WeaponTemplate;
	
	local XComGameState_Item		NewAmmoState;

	local bool						bOriginalIgnoreRestrictions;

	local XComGameState_Player		PlayerState;
	local StateObjectReference		AbilityRef;
	local array<AbilitySetupData>	AbilityData;
	local X2TacticalGameRuleset		TacticalRules;
	local int i;

	`LOG("ApplyNewAmmo begin.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

	AmmoTemplate = FindNewAmmo(SourceUnit);
	if (AmmoTemplate == none)
	{
		`LOG("Did not find any ammo on the source unit.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
	}

	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());
	if (WeaponTemplate == none || !AmmoTemplate.IsWeaponValidForAmmo(WeaponTemplate) || WeaponTemplate.Abilities.Find('HotLoadAmmo') == INDEX_NONE)
	{
		`LOG(WeaponTemplate.DataName @ "Does not support ammo:" @ AmmoTemplate.DataName, class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
	}

	WeaponRef = ItemState.GetReference();
	OldAmmoRef = ItemState.LoadedAmmo;
	if (!MaybeUnequipOldAmmo(TargetUnit, NewGameState))
	{
		`LOG("Failed to resolve already equipped ammo, aborting ammo transfer.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	}

	NewAmmoState = AmmoTemplate.CreateInstanceFromTemplate(NewGameState);

	if (OldAmmoSlot != eInvSlot_Unknown)
	{
		NewAmmoSlot = OldAmmoSlot;
	}
	else
	{
		NewAmmoSlot = AmmoTemplate.InventorySlot;
	}

	bOriginalIgnoreRestrictions = TargetUnit.bIgnoreItemEquipRestrictions;
	TargetUnit.bIgnoreItemEquipRestrictions = true;

	if (TargetUnit.AddItemToInventory(NewAmmoState, NewAmmoSlot, NewGameState))
	{
		`LOG("Successfully equipped new ammo into slot:" @ NewAmmoSlot, class'Denmother'.default.bLog, 'IRIDENMOTHER');
		NewAmmoRef = NewAmmoState.GetReference();
		ItemState.LoadedAmmo = NewAmmoRef;
		bAmmoApplied = true;
	}
	else
	{
		`LOG("Failed to equip new ammo into slot:" @ NewAmmoSlot, class'Denmother'.default.bLog, 'IRIDENMOTHER');
		MaybeEquipOldAmmo(TargetUnit, NewGameState);
	}
	TargetUnit.bIgnoreItemEquipRestrictions = bOriginalIgnoreRestrictions;
	
	
	PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(TargetUnit.ControllingPlayer.ObjectID));			
	AbilityData = TargetUnit.GatherUnitAbilitiesForInit(/*NewGameState*/, PlayerState); // Passing StartState to it causes a bug in LWOTC where it restores ammo for some weapons.
	TacticalRules = `TACTICALRULES;

	for (i = 0; i < AbilityData.Length; i++)
	{
		if (AbilityData[i].SourceWeaponRef == NewAmmoRef)
		{	
			`LOG("Initializing ability:" @ AbilityData[i].Template.DataName @ "for target unit:" @ TargetUnit.GetFullName(),, 'WOTCMoreSparkWeapons');
					
			AbilityRef = TacticalRules.InitAbilityForUnit(AbilityData[i].Template, TargetUnit, NewGameState, NewAmmoRef);
			NewAmmoAbilities.AddItem(AbilityRef);
			//AbilityState = XComGameState_Ability(NewGameState.GetGameStateForObjectID(AbilityRef.ObjectID));
			//RestoreAbilityChargeCooldownData(AbilityState);
		}
	}
		
	return true;
}

private function bool MaybeUnequipOldAmmo(XComGameState_Unit TargetUnit, XComGameState NewGameState)
{
	//local XComGameState_Ability		AbilityState;	
	local XComGameState_Item		OldAmmoState;
	local XComGameStateHistory		History;
	//local int i;

	if (OldAmmoRef.ObjectID == 0)
		return true;

	History = `XCOMHISTORY;
	OldAmmoState = XComGameState_Item(History.GetGameStateForObjectID(OldAmmoRef.ObjectID));
	if (OldAmmoState == none)
		return true;

	OldAmmoSlot = OldAmmoState.InventorySlot;
	`LOG("Target unit already has ammo equipped:" @ OldAmmoState.GetMyTemplateName() @ "in slot:" @ OldAmmoSlot, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	OldAmmoState = XComGameState_Item(NewGameState.ModifyStateObject(OldAmmoState.Class, OldAmmoState.ObjectID));
	if (!TargetUnit.RemoveItemFromInventory(OldAmmoState, NewGameState))
	{
		`LOG("Failed to unequip existing ammo:" @ OldAmmoState.GetMyTemplateName(), class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
	}
	
	`LOG("Successfully unequipped existing ammo:" @ OldAmmoState.GetMyTemplateName(), class'Denmother'.default.bLog, 'IRIDENMOTHER');
	
	/*
	for (i = TargetUnit.Abilities.Length - 1; i >= 0; i--)
	{
		AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(TargetUnit.Abilities[i].ObjectID));
		if (AbilityState == none)
			continue;

		if (AbilityState.SourceWeapon == OldAmmoRef)
		{
			`LOG("Found ability attached to ammo:" @ AbilityState.GetMyTemplateName() @ ", removing", class'Denmother'.default.bLog, 'IRIDENMOTHER'); 
			OldAmmoAbilities.AddItem(TargetUnit.Abilities[i]);
			TargetUnit.Abilities.Remove(i, 1);
		}
	}
	*/	
	return true;
}

private function bool MaybeEquipOldAmmo(XComGameState_Unit TargetUnit, XComGameState NewGameState)
{
//	local XComGameState_Ability		AbilityState;	
	local XComGameState_Item		OldAmmoState;
	local XComGameStateHistory		History;
	local bool						bOriginalIgnoreRestrictions;

	if (OldAmmoRef.ObjectID == 0)
		return true;

	History = `XCOMHISTORY;
	OldAmmoState = XComGameState_Item(History.GetGameStateForObjectID(OldAmmoRef.ObjectID));
	if (OldAmmoState == none)
		return true;

	OldAmmoState = XComGameState_Item(NewGameState.ModifyStateObject(OldAmmoState.Class, OldAmmoState.ObjectID));
	bOriginalIgnoreRestrictions = TargetUnit.bIgnoreItemEquipRestrictions;
	TargetUnit.bIgnoreItemEquipRestrictions = true;
	if (TargetUnit.AddItemToInventory(OldAmmoState, OldAmmoSlot, NewGameState))
	{
		`LOG("Successfully equipped old ammo:" @ OldAmmoState.GetMyTemplateName() @ "into slot:" @ OldAmmoSlot, class'Denmother'.default.bLog, 'IRIDENMOTHER');
		TargetUnit.bIgnoreItemEquipRestrictions = bOriginalIgnoreRestrictions;
		return true;
	}
	TargetUnit.bIgnoreItemEquipRestrictions = bOriginalIgnoreRestrictions;
	
	`LOG("Failed to equip old ammo:" @ OldAmmoState.GetMyTemplateName() @ "into slot:" @ OldAmmoSlot, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	return false;
}

final function ApplyOldAmmo(XComGameState NewGameState)
{
	local XComGameState_Item ItemState;
	local XComGameState_Unit TargetUnit;
	local XComGameState_Item NewAmmoState;

	if (!bAmmoApplied)
		return;
		
	NewAmmoState = XComGameState_Item(GetGameStateForObjectID(NewGameState, NewAmmoRef.ObjectID));
	TargetUnit = XComGameState_Unit(GetGameStateForObjectID(NewGameState, ApplyEffectParameters.TargetStateObjectRef.ObjectID));
	if (TargetUnit != none)
	{
		if (TargetUnit.RemoveItemFromInventory(NewAmmoState, NewGameState))
		{
			NewGameState.RemoveStateObject(NewAmmoRef.ObjectID);
		}
		MaybeEquipOldAmmo(TargetUnit, NewGameState);
		RemoveNewAmmoEffectsAndAbilities(TargetUnit, NewGameState);
	}

	ItemState = XComGameState_Item(GetGameStateForObjectID(NewGameState, WeaponRef.ObjectID));
	//ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', WeaponRef.ObjectID));
	if (ItemState != none)
	{	
		ItemState.LoadedAmmo = OldAmmoRef;
	}
}

private function RemoveNewAmmoEffectsAndAbilities(XComGameState_Unit TargetUnit, XComGameState NewGameState)
{
	local XComGameState_Ability		AbilityState;	
	local XComGameState_Effect		EffectState;
	local StateObjectReference		Ref;
	local XComGameStateHistory		History;
//	local int i;
	
	History = `XCOMHISTORY;
	
	foreach TargetUnit.AffectedByEffects(Ref)
	{
		EffectState = XComGameState_Effect(History.GetGameStateForObjectID(Ref.ObjectID));
		if (EffectState == none)
			continue;

		if (EffectState.ApplyEffectParameters.ItemStateObjectRef == NewAmmoRef &&
			NewAmmoAbilities.Find('ObjectID', EffectState.ApplyEffectParameters.AbilityStateObjectRef.ObjectID) != INDEX_NONE)
		{
			EffectState.RemoveEffect(NewGameState, NewGameState, true);
		}
	}

	foreach NewAmmoAbilities(Ref)
	{
		AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(Ref.ObjectID));
		if (AbilityState == none)
			continue;

		AbilityState = XComGameState_Ability(NewGameState.ModifyStateObject(AbilityState.Class, AbilityState.ObjectID));
		TargetUnit.Abilities.RemoveItem(Ref);
		NewGameState.RemoveStateObject(AbilityState.ObjectID);
	}
}

/*
function GatherAffectedWeapons(XComGameState_Unit TargetUnit, XComGameState NewGameState, out array<XComGameState_Item> AffectedWeapons)
{
	local array<XComGameState_Item> InventoryItems;
	local XComGameState_Item		ItemState;
	local XComGameState_Item		NewItemState;
	local X2WeaponTemplate			WeaponTemplate;

	InventoryItems = TargetUnit.GetAllInventoryItems(, true);
	foreach InventoryItems(ItemState)
	{	
		WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());
		if (WeaponTemplate.Abilities.Find('HotLoadAmmo') != INDEX_NONE)
		{
			NewItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ItemState.ObjectID));
			AffectedWeapons.AddItem(NewItemState);
		}
	}
}*/

function string GetFlyoverString()
{	
	local XComGameState_Item ItemState;

	if (bAmmoApplied)
	{
		ItemState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(NewAmmoRef.ObjectID));
		if (ItemState != none)
		{
			return strWeaponReloaded @ "-" @ ItemState.GetMyTemplate().FriendlyName;
		}
	}
	return strWeaponReloaded;
}
static private function XComGameState_BaseObject GetGameStateForObjectID(XComGameState NewGameState, const int StateObjectID)
{
	local XComGameState_BaseObject BaseObject;

	BaseObject = NewGameState.GetGameStateForObjectID(StateObjectID);
	if (BaseObject == none)
	{
		BaseObject = `XCOMHISTORY.GetGameStateForObjectID(StateObjectID);
		if (BaseObject != none)
		{
			BaseObject = NewGameState.ModifyStateObject(BaseObject.Class, StateObjectID);
		}	
	}
	return BaseObject;
}

final function X2AmmoTemplate FindNewAmmo(XComGameState_Unit UnitState)
{
	local XComGameState_Item		AmmoState;
	local array<XComGameState_Item> InventoryItems;
	local X2AmmoTemplate			AmmoTemplate;

	InventoryItems = UnitState.GetAllInventoryItems(, true);
	foreach InventoryItems(AmmoState)
	{
		AmmoTemplate = X2AmmoTemplate(AmmoState.GetMyTemplate());
		if (AmmoTemplate != none && AmmoState.InventorySlot != eInvSlot_Backpack && AmmoState.InventorySlot != eInvSlot_Loot)
		{
			NewAmmoRef = AmmoState.GetReference();
			return AmmoTemplate;
		}
	}
	return none;
}