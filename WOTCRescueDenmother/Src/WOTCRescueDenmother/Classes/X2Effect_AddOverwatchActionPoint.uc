class X2Effect_AddOverwatchActionPoint extends X2Effect;

// Unused

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_Unit	UnitState;
	local XComGameState_Item	PrimaryWeapon;
	local X2WeaponTemplate		WeaponTemplate;

	UnitState = XComGameState_Unit(kNewTargetState);
	if (UnitState == none)
		return; 

	PrimaryWeapon = UnitState.GetPrimaryWeapon();
	if (PrimaryWeapon == none)
		return;

	if (PrimaryWeapon.Ammo < 1)
		return;

	WeaponTemplate = X2WeaponTemplate(PrimaryWeapon.GetMyTemplate());
	if (WeaponTemplate == none)
		return;

	UnitState.ReserveActionPoints.AddItem(WeaponTemplate.OverwatchActionPoint);
}

simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	if (EffectApplyResult == 'AA_Success')
	{	
		class'X2Ability_DefaultAbilitySet'.static.OverwatchAbility_BuildVisualization(VisualizeGameState);
	}	
}