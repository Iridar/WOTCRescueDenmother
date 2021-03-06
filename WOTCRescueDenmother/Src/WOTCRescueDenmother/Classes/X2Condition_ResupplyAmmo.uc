class X2Condition_ResupplyAmmo extends X2Condition config(Denmother);

/*
return 'AA_TileIsBlocked';
return 'AA_UnitIsWrongType';
return 'AA_WeaponIncompatible';
return 'AA_AbilityUnavailable';
return 'AA_CannotAfford_ActionPoints';
return 'AA_CannotAfford_Charges';
return 'AA_CannotAfford_AmmoCost';
return 'AA_CannotAfford_ReserveActionPoints';
return 'AA_CannotAfford_Focus';
return 'AA_UnitIsFlanked';
return 'AA_UnitIsConcealed';
return 'AA_UnitIsDead';
return 'AA_UnitIsInStasis';
return 'AA_UnitIsImmune';
return 'AA_UnitIsFriendly';
return 'AA_UnitIsHostile';
return 'AA_UnitIsPanicked';
return 'AA_UnitIsNotImpaired';
return 'AA_WrongBiome';
return 'AA_NotInRange';
return 'AA_NoTargets';
return 'AA_NotVisible';
*/

static final function X2AmmoTemplate GetExperimentalAmmoTemplate(const XComGameState_Unit SourceUnit, const XComGameState_Item ItemState)
{
	local XComGameState_Item				AmmoState;
	local array<XComGameState_Item>			InventoryItems;
	local X2AmmoTemplate					AmmoTemplate;
	local X2WeaponTemplate					WeaponTemplate;
	local XComGameState_Effect_TransferAmmo TransferAmmo;
	
	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());
	if (WeaponTemplate == none || WeaponTemplate.Abilities.Find('HotLoadAmmo') == INDEX_NONE)
		return none;

	// Prevent the following:
		//several keepers can multiply some experimental ammo by resupply each other with it.
		//I.e. Keeper A has Explosive Ammo, and gives it to Keeper B who had Bluescreen Rounds, and now Keeper B will both shoot and give out Explosive Ammo, at least until they reload themselves.
	// If this source unit Keeper has been given different Experimental Ammo by another Keeper, then this Keeper will still give out the Experimental Ammo they had equipped previously.
	// While they have the resupply effect on them, the ammo is not actually in their inventory, so we have to get it manually.
	TransferAmmo = XComGameState_Effect_TransferAmmo(SourceUnit.GetUnitAffectedByEffectState('IRI_ResupplyAmmo_Effect'));
	if (TransferAmmo != none)
	{
		AmmoState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(TransferAmmo.OldAmmoRef.ObjectID));
		if (AmmoState != none)
		{
			AmmoTemplate = X2AmmoTemplate(AmmoState.GetMyTemplate());
			if (AmmoTemplate != none && AmmoTemplate.IsWeaponValidForAmmo(WeaponTemplate))
			{
				return AmmoTemplate;
			}
		}
	}


	InventoryItems = SourceUnit.GetAllInventoryItems(, true);
	foreach InventoryItems(AmmoState)
	{
		AmmoTemplate = X2AmmoTemplate(AmmoState.GetMyTemplate());
		if (AmmoTemplate != none && AmmoState.InventorySlot != eInvSlot_Backpack && AmmoState.InventorySlot != eInvSlot_Loot && AmmoTemplate.IsWeaponValidForAmmo(WeaponTemplate))
		{
			return AmmoTemplate;
		}
	}
	return none;
}


event name CallMeetsConditionWithSource(XComGameState_BaseObject kTarget, XComGameState_BaseObject kSource) 
{ 
	local XComGameState_Unit	SourceUnit;
	local XComGameState_Unit	TargetUnit;
	local XComGameState_Item	PrimaryWeapon;
	local X2AmmoTemplate		AmmoTemplate;
	local X2AmmoTemplate		TargetAmmoTemplate;

	TargetUnit = XComGameState_Unit(kTarget);
	if (TargetUnit != none)
	{
		PrimaryWeapon = TargetUnit.GetPrimaryWeapon();
		if (PrimaryWeapon == none)
			return 'AA_WeaponIncompatible';	
		
		if (PrimaryWeapon.Ammo < PrimaryWeapon.GetClipSize())
		{
			// Always allow resupply ammo if the target's weapon wants reload.
			return 'AA_Success';
		}
		else
		{
			SourceUnit = XComGameState_Unit(kSource);
			if (SourceUnit != none)
			{
				AmmoTemplate = GetExperimentalAmmoTemplate(SourceUnit, PrimaryWeapon);
				if (AmmoTemplate == none)
					return 'AA_AmmoAlreadyFull';

				TargetAmmoTemplate = X2AmmoTemplate(PrimaryWeapon.GetLoadedAmmoTemplate(none));
				if (TargetAmmoTemplate != none && TargetAmmoTemplate.DataName == AmmoTemplate.DataName)
					return 'AA_AmmoAlreadyFull';

				// If we're still here, shooter has experimental ammo, and the target has no experimental ammo, or at least it is different from our experimental ammo.
				return 'AA_Success';
			}
		}
	}
	
	return 'AA_AbilityUnavailable'; 
}
/*
event name CallAbilityMeetsCondition(XComGameState_Ability kAbility, XComGameState_BaseObject kTarget) 
{
	local XComGameState_Unit	TargetUnit;
	
	TargetUnit = XComGameState_Unit(kTarget);
	
	if (TargetUnit != none)
	{
	}
	else return 'AA_NotAUnit';
	
	return 'AA_Success'; 
}

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return true;
}
*/
