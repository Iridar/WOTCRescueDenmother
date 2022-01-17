class XComGameState_Effect_TransferAmmo extends XComGameState_Effect;

var localized string strWeaponReloaded;

var StateObjectReference NewAmmoRef;
var StateObjectReference WeaponRef;
var StateObjectReference OldAmmoRef;
var bool bAmmoApplied;

final function bool ApplyNewAmmo(XComGameState_Unit SourceUnit, XComGameState_Item ItemState, XComGameState NewGameState)
{
	local X2AmmoTemplate AmmoTemplate;
	local X2WeaponTemplate WeaponTemplate;

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
		return true;
	}
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