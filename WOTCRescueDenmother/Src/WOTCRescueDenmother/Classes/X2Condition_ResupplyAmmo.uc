class X2Condition_ResupplyAmmo extends X2Condition config(Denmother);

var protected X2Condition_UnitProperty UnitProperty;


var config int ResupplyAmmoDistanceTiles;


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

event name CallMeetsCondition(XComGameState_BaseObject kTarget) 
{
	return UnitProperty.MeetsCondition(kTarget); 
}

static private function int GetBondLevel(const XComGameState_Unit SourceUnit, const XComGameState_Unit TargetUnit)
{
	local SoldierBond BondInfo;

	if (SourceUnit.GetBondData(SourceUnit.GetReference(), BondInfo))
	{
		if (BondInfo.Bondmate.ObjectID == TargetUnit.ObjectID)
		{
			return BondInfo.BondLevel;
		}
	}
	return 0;
}

static private function bool UnitHasValidExperimentalAmmo(const XComGameState_Unit UnitState, const XComGameState_Item ItemState)
{
	local XComGameState_Item		AmmoState;
	local array<XComGameState_Item> InventoryItems;
	local X2AmmoTemplate			AmmoTemplate;
	local X2WeaponTemplate			WeaponTemplate;

	WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());
	if (WeaponTemplate == none || WeaponTemplate.Abilities.Find('HotLoadAmmo') == INDEX_NONE)
		return false;

	InventoryItems = UnitState.GetAllInventoryItems(, true);
	foreach InventoryItems(AmmoState)
	{
		AmmoTemplate = X2AmmoTemplate(AmmoState.GetMyTemplate());
		if (AmmoTemplate != none && AmmoState.InventorySlot != eInvSlot_Backpack && AmmoState.InventorySlot != eInvSlot_Loot && AmmoTemplate.IsWeaponValidForAmmo(WeaponTemplate))
		{
			return true;
		}
	}
	return false;
}

event name CallMeetsConditionWithSource(XComGameState_BaseObject kTarget, XComGameState_BaseObject kSource) 
{ 
	local XComGameState_Unit	SourceUnit;
	local XComGameState_Unit	TargetUnit;
	local XComGameState_Item	PrimaryWeapon;
	
	SourceUnit = XComGameState_Unit(kSource);
	TargetUnit = XComGameState_Unit(kTarget);
	
	if (SourceUnit != none && TargetUnit != none)
	{
		UnitProperty.WithinRange = `TILESTOUNITS(ResupplyAmmoDistanceTiles + GetBondLevel(SourceUnit, TargetUnit));
		if (UnitProperty.MeetsConditionWithSource(kTarget, kSource) == 'AA_Success')
		{
			PrimaryWeapon = TargetUnit.GetPrimaryWeapon();
			if (PrimaryWeapon == none)
				return 'AA_WeaponIncompatible';	

			if (UnitHasValidExperimentalAmmo(SourceUnit, PrimaryWeapon) || PrimaryWeapon.Ammo < PrimaryWeapon.GetClipSize())
			{
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
defaultproperties
{
	Begin Object Class=X2Condition_UnitProperty Name=DefaultUnitProperty
		ExcludeHostileToSource = true
		ExcludeFriendlyToSource = false
		RequireSquadmates = false
		FailOnNonUnits = true
		ExcludeDead = true
		ExcludeRobotic = false
		ExcludeUnableToAct = true
		TreatMindControlledSquadmateAsHostile = true
		RequireWithinRange = true
	End Object
	UnitProperty = DefaultUnitProperty
}