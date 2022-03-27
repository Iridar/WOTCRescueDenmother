class XComGameState_Effect_TransferAmmo extends XComGameState_Effect;

var localized string strWeaponReloaded;

var StateObjectReference NewAmmoRef;
var StateObjectReference WeaponRef;
var StateObjectReference OldAmmoRef;
var StateObjectReference AbilityRef;
var bool bAmmoApplied;

var private array<EffectAppliedData> AppliedDatas;

final function bool ApplyNewAmmo(XComGameState_Unit SourceUnit, XComGameState_Unit TargetUnit, XComGameState_Item ItemState, XComGameState NewGameState)
{
	local X2AmmoTemplate	AmmoTemplate;
	local X2WeaponTemplate	WeaponTemplate;
	local name				AbilityName;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager Mgr;
	local X2Effect			Effect;

	`LOG("ApplyNewAmmo begin.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

	AmmoTemplate = FindNewAmmo(SourceUnit);
	if (AmmoTemplate == none)
	{
		`LOG("Did not find any ammo on the source unit.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
	}
	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

	if (WeaponTemplate != none && AmmoTemplate.IsWeaponValidForAmmo(WeaponTemplate) && WeaponTemplate.Abilities.Find('HotLoadAmmo') != INDEX_NONE)
	{
		WeaponRef = ItemState.GetReference();
		OldAmmoRef = ItemState.LoadedAmmo;
		ItemState.LoadedAmmo = NewAmmoRef;
		bAmmoApplied = true;

		Mgr = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
		foreach AmmoTemplate.Abilities(AbilityName)
		{
			`LOG("Looking at ammo ability:" @ AbilityName, class'Denmother'.default.bLog, 'IRIDENMOTHER');
			AbilityTemplate = Mgr.FindAbilityTemplate(AbilityName);
			if (AbilityTemplate == none)
				continue;

			foreach AbilityTemplate.AbilityShooterEffects(Effect)
			{
				
				if (!Effect.IsA('X2Effect_Persistent'))
					continue;

				`LOG("Looking at ability shooter effect:" @ Effect.Class.Name @ X2Effect_Persistent(Effect).EffectName, class'Denmother'.default.bLog, 'IRIDENMOTHER');

				ApplyExtraEffect(AbilityName, X2Effect_Persistent(Effect), SourceUnit, TargetUnit, NewGameState);
			}

			if (X2AbilityTarget_Self(AbilityTemplate.AbilityTargetStyle) != none)
			{
				foreach AbilityTemplate.AbilityTargetEffects(Effect)
				{
					if (!Effect.IsA('X2Effect_Persistent'))
						continue;

					`LOG("Looking at ability target effect:" @ Effect.Class.Name @ X2Effect_Persistent(Effect).EffectName, class'Denmother'.default.bLog, 'IRIDENMOTHER');

					ApplyExtraEffect(AbilityName, X2Effect_Persistent(Effect), SourceUnit, TargetUnit, NewGameState);
				}
			}
		}


		`LOG("Successfully applied new ammo.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return true;
	}
	`LOG("Failed to apply new ammo." @ WeaponTemplate != none @ AmmoTemplate.IsWeaponValidForAmmo(WeaponTemplate) @ WeaponTemplate.Abilities.Find('HotLoadAmmo') != INDEX_NONE, class'Denmother'.default.bLog, 'IRIDENMOTHER');
	return false;
}

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

final function ApplyOldAmmo(XComGameState NewGameState)
{
	local XComGameState_Item ItemState;

	if (bAmmoApplied)
	{
		ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', WeaponRef.ObjectID));
		if (ItemState != none)
		{	
			ItemState.LoadedAmmo = OldAmmoRef;
		}
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

private function ApplyExtraEffect(name TemplateName, X2Effect_Persistent PersistentEffect, XComGameState_Unit SourceUnit, XComGameState_Unit TargetUnit, XComGameState NewGameState)
{
	local EffectAppliedData AppliedData;
	local XComGameState_Player PlayerState;

	AppliedData = ApplyEffectParameters; 
	
	//AppliedData.PlayerStateObjectRef = SourceUnit.ControllingPlayer;
	//AppliedData.SourceStateObjectRef = SourceUnit.GetReference();
	//AppliedData.TargetStateObjectRef = TargetUnit.GetReference();
	AppliedData.ItemStateObjectRef = NewAmmoRef;
	AppliedData.AbilityStateObjectRef = SourceUnit.FindAbility('AbilityName', NewAmmoRef);
	AppliedData.AbilityInputContext.AbilityTemplateName = TemplateName;
	AppliedData.AbilityInputContext.AbilityRef = AppliedData.AbilityStateObjectRef;
	//AppliedData.AbilityInputContext.PrimaryTarget = AppliedData.TargetStateObjectRef;
	AppliedData.AbilityInputContext.ItemObject = NewAmmoRef;

	AppliedData.EffectRef.LookupType = TELT_AbilityTargetEffects;
	AppliedData.EffectRef.SourceTemplateName = PersistentEffect.Class.Name;

	if (PersistentEffect.ApplyEffect(AppliedData, TargetUnit, NewGameState) == 'AA_Success')
	{
		//AppliedDatas.AddItem(AppliedData);
		`LOG("Applied effect successfully.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	}
	else `LOG("Failed to apply effect", class'Denmother'.default.bLog, 'IRIDENMOTHER');
}

/*
struct native EffectAppliedData
{
	var() StateObjectReference PlayerStateObjectRef;       // Player's turn when this effect was created
	var() StateObjectReference SourceStateObjectRef;       // The state object responsible for applying this effect
	var() StateObjectReference TargetStateObjectRef;       // A state object representing the Target that will be affected by this effect	
	var() StateObjectReference ItemStateObjectRef;         // Item associated with creating this effect, if any	

	var() StateObjectReference AbilityStateObjectRef;      // Ability associated with creating this effect, if any
	var() AbilityInputContext  AbilityInputContext;        // Copy of the input context used to create this effect		
	var() AbilityResultContext AbilityResultContext;       // Copy of the result context for the ability
	var() X2EffectTemplateRef  EffectRef;				   // The info necessary to lookup this X2Effect as a Template, given the source template
	
};*/