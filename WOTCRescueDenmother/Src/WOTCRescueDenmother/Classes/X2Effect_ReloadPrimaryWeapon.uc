class X2Effect_ReloadPrimaryWeapon extends X2Effect;

var localized string strWeaponReloaded;

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_Unit UnitState;
	local XComGameState_Item PrimaryWeapon;

	UnitState = XComGameState_Unit(kNewTargetState);
	
	if (UnitState != none)
	{
		PrimaryWeapon = UnitState.GetPrimaryWeapon();

		PrimaryWeapon.Ammo = PrimaryWeapon.GetClipSize();
	}

	//super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}


simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local X2Action_PlaySoundAndFlyOver	SoundAndFlyOver;
	local X2Action_PlayAnimation		PlayAnimation;
	local X2Action_MoveTurn				MoveTurnAction;
	local XComGameStateContext_Ability  Context;
	local XComGameState_Unit			SourceUnit;
	local XComGameStateVisualizationMgr VisMgr;
	local X2Action						FoundAction;

	
	if (EffectApplyResult == 'AA_Success')
	{	
		//VisMgr = `XCOMVISUALIZATIONMGR;
		//FoundAction = VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_Fire');

		//Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
		//SourceUnit = XComGameState_Unit(VisualizeGameState.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID));

		//MoveTurnAction = X2Action_MoveTurn(class'X2Action_MoveTurn'.static.AddToVisualizationTree(ActionMetadata, Context, false, FoundAction));
		//MoveTurnAction.m_vFacePoint =  `XWORLD.GetPositionFromTileCoordinates(SourceUnit.TileLocation);
		//MoveTurnAction.UpdateAimTarget = true;

		PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
		PlayAnimation.Params.AnimName = 'HL_CatchSupplies';

		PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
		PlayAnimation.Params.AnimName = 'HL_Reload';

		SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, strWeaponReloaded, '', eColor_Good, "img:///UILibrary_PerkIcons.UIPerk_reload");
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
	
}