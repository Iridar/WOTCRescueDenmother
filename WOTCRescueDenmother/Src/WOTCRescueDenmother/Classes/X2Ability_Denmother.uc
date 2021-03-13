class X2Ability_Denmother extends X2Ability config(Denmother);

var config int DenmotherBleedoutTurns;

//var config(Keeper) float ResupplyAmmoDistanceTiles;
var config(Keeper) int PullAllyCooldown;
var config(Keeper) int ResupplyAmmoCooldown;
var config(Keeper) int BandageThrowCooldown;
var config(Keeper) int BandageThrowHeal;
var config(Keeper) int BandageThrowDuration;
var config(Keeper) int BandageThrowCharges;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_GrappleGun());
	Templates.AddItem(Create_ResupplyAmmo());
	Templates.AddItem(Create_BandageThrow());
	Templates.AddItem(PurePassive('IRI_SupplyRun', "img:///IRIKeeperBackpack.UI.UIPerk_SupplyRun", false, 'eAbilitySource_Perk', true));

	Templates.AddItem(PullAlly());
	Templates.AddItem(PullLoot());

	Templates.AddItem(Create_KnockoutAndBleedoutSelf());
	Templates.AddItem(Create_OneGoodEye_Passive());

	return Templates;
}

static function X2AbilityTemplate Create_GrappleGun()
{
	local X2AbilityTemplate	Template;

	Template = class'X2Ability_DefaultAbilitySet'.static.AddGrapple('IRI_GrappleGun');

	Template.AdditionalAbilities.AddItem('IRI_PullLoot');

	return Template;
}

static function X2AbilityTemplate Create_BandageThrow()
{
	local X2AbilityTemplate						Template;
	local X2Condition_UnitProperty				UnitProperty;
	
	local X2Effect_BandageThrow					BandageThrow;	
	local X2Effect_GrantActionPoints			GrantActionPoints;
	local X2Condition_AbilityProperty			AbilityProperty;

	local X2AbilityTarget_Single				SingleTarget;
	local X2AbilityMultiTarget_Radius			Radius;
	local X2Effect_RemoveEffectsByDamageType	RemoveEffects;
	local X2Effect_ApplyMedikitHeal				HealEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_BandageThrow');

	AddCooldown(Template, default.BandageThrowCooldown);
	AddCharges(Template, default.BandageThrowCharges);
	AddActionCost(Template);

	//	Icon Setup
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_helpinghand";
	Template.bDontDisplayInAbilitySummary = false;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.Hostility = eHostility_Defensive;

	//	Targeting and Triggering
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.AbilityToHitCalc = default.DeadEye;

	SingleTarget = new class'X2AbilityTarget_Single';
	SingleTarget.OnlyIncludeTargetsInsideWeaponRange = true;
	SingleTarget.bIncludeSelf = true;
	SingleTarget.bShowAOE = true;
	Template.AbilityTargetStyle = SingleTarget;
	Template.bLimitTargetIcons = false;

	Radius = new class'X2AbilityMultiTarget_Radius';
	Radius.bUseWeaponRadius = true;
	Radius.bUseWeaponBlockingCoverFlag = true;
	Radius.bExcludeSelfAsTargetIfWithinRadius = true;
	Radius.fTargetRadius = 0.25f;
	Template.AbilityMultiTargetStyle = Radius;

	Template.TargetingMethod = class'X2TargetingMethod_ResupplyAmmo';
	Template.SkipRenderOfAOETargetingTiles = false;
	Template.SkipRenderOfTargetingTemplate = true;	

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	UnitProperty = new class'X2Condition_UnitProperty';
	UnitProperty.ExcludeHostileToSource = true;
	UnitProperty.ExcludeFriendlyToSource = false;
	UnitProperty.RequireSquadmates = false;
	UnitProperty.FailOnNonUnits = true;
	UnitProperty.ExcludeDead = true;
	UnitProperty.ExcludeRobotic = true;
	UnitProperty.ExcludeUnableToAct = true;
	UnitProperty.TreatMindControlledSquadmateAsHostile = true;
	//UnitProperty.RequireWithinRange = true;
	//UnitProperty.WithinRange = `TILESTOUNITS(default.ResupplyAmmoDistanceTiles);
	Template.AbilityTargetConditions.AddItem(UnitProperty);
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	Template.AbilityTargetConditions.AddItem(new class'X2Condition_BandageThrow');

	//	Remove bleeding.
	RemoveEffects = new class'X2Effect_RemoveEffectsByDamageType';
	RemoveEffects.DamageTypesToRemove.AddItem('Bleeding');
	Template.AddTargetEffect(RemoveEffects);	

	BandageThrow = new class'X2Effect_BandageThrow';
	BandageThrow.BuildPersistentEffect(default.BandageThrowDuration, false, false, false, eGameRule_PlayerTurnBegin);
	BandageThrow.DuplicateResponse = eDupe_Allow;
	BandageThrow.SetDisplayInfo(ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage, true);
	
	HealEffect = new class'X2Effect_ApplyMedikitHeal';
	HealEffect.PerUseHP = default.BandageThrowHeal;
	BandageThrow.ApplyOnTick.AddItem(HealEffect);

	Template.AddTargetEffect(BandageThrow);	
	Template.AddTargetEffect(HealEffect);

	AbilityProperty = new class'X2Condition_AbilityProperty';
	AbilityProperty.OwnerHasSoldierAbilities.AddItem('IRI_SupplyRun');

	GrantActionPoints = new class'X2Effect_GrantActionPoints';
	GrantActionPoints.NumActionPoints = 1;
	GrantActionPoints.PointType = class'X2CharacterTemplateManager'.default.MoveActionPoint;
	GrantActionPoints.TargetConditions.AddItem(AbilityProperty);
	GrantActionPoints.TargetConditions.AddItem(new class'X2Condition_ExcludeSelfTarget');
	Template.AddShooterEffect(GrantActionPoints);

	//Template.CinescriptCameraType = "StandardGrenadeFiring";
	Template.bLimitTargetIcons = true;
	Template.ActivationSpeech = 'HealingAlly';
	Template.CustomFireAnim = 'FF_BandageThrow';
	Template.CustomSelfFireAnim = 'NO_ApplyBandages';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState; 
	Template.BuildVisualizationFn = ResupplyAmmo_BuildVisualization;

	return Template;
}

static function X2AbilityTemplate Create_ResupplyAmmo()
{
	local X2AbilityTemplate					Template;
	local X2Effect_ReloadPrimaryWeapon		ReloadEffect;
	local X2Condition_UnitProperty			UnitProperty;
	local X2Effect_RemoveEffects			RemoveEffects;
	local X2Condition_ResupplyAmmo			ResupplyCondition;
	local X2Effect_GrantActionPoints		GrantActionPoints;
	local X2Condition_AbilityProperty		AbilityProperty;

	local X2AbilityTarget_Single            SingleTarget;
	local X2AbilityMultiTarget_Radius		Radius;
	//local X2AbilityPassiveAOE_SelfRadius	PassiveAOEStyle;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_ResupplyAmmo');

	//	Icon Setup
	Template.IconImage = "img:///IRIKeeperBackpack.UI.UIPerk_ResupplyAmmo";
	Template.bDontDisplayInAbilitySummary = false;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.Hostility = eHostility_Neutral;

	AddCooldown(Template, default.ResupplyAmmoCooldown);
	AddActionCost(Template);

	//	Targeting and Triggering
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.AbilityToHitCalc = default.DeadEye;

	SingleTarget = new class'X2AbilityTarget_Single';
	SingleTarget.OnlyIncludeTargetsInsideWeaponRange = true;
	SingleTarget.bIncludeSelf = false;
	SingleTarget.bShowAOE = true;
	Template.AbilityTargetStyle = SingleTarget;
	Template.bLimitTargetIcons = false;

	//PassiveAOEStyle = new class'X2AbilityPassiveAOE_SelfRadius';
	//PassiveAOEStyle.OnlyIncludeTargetsInsideWeaponRange = true;
	//Template.AbilityPassiveAOEStyle = PassiveAOEStyle;
	
	Radius = new class'X2AbilityMultiTarget_Radius';
	Radius.bUseWeaponRadius = true;
	Radius.bUseWeaponBlockingCoverFlag = true;
	Radius.bExcludeSelfAsTargetIfWithinRadius = true;
	Radius.fTargetRadius = 0.25f;
	Template.AbilityMultiTargetStyle = Radius;

	Template.TargetingMethod = class'X2TargetingMethod_ResupplyAmmo';
	Template.SkipRenderOfAOETargetingTiles = false;
	Template.SkipRenderOfTargetingTemplate = true;	

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	UnitProperty = new class'X2Condition_UnitProperty';
	UnitProperty.ExcludeHostileToSource = true;
	UnitProperty.ExcludeFriendlyToSource = false;
	UnitProperty.RequireSquadmates = false;
	UnitProperty.FailOnNonUnits = true;
	UnitProperty.ExcludeDead = true;
	UnitProperty.ExcludeRobotic = false;
	UnitProperty.ExcludeUnableToAct = true;
	UnitProperty.TreatMindControlledSquadmateAsHostile = true;
	//UnitProperty.RequireWithinRange = true;
	//UnitProperty.WithinRange = `TILESTOUNITS(default.ResupplyAmmoDistanceTiles);
	Template.AbilityTargetConditions.AddItem(UnitProperty);
	ResupplyCondition = new class'X2Condition_ResupplyAmmo';
	Template.AbilityTargetConditions.AddItem(ResupplyCondition);
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	//	Remove any existing instances of this effect on the target unit so that we don't get into stupid games 
	//	between multiple keepers trying to apply their ammo effects to the same target.
	RemoveEffects = new class'X2Effect_RemoveEffects';
	RemoveEffects.EffectNamesToRemove.AddItem(class'X2Effect_ReloadPrimaryWeapon'.default.EffectName);
	Template.AddTargetEffect(RemoveEffects);	

	ReloadEffect = new class'X2Effect_ReloadPrimaryWeapon';
	ReloadEffect.BuildPersistentEffect(1, true, false);
	ReloadEffect.SetDisplayInfo(ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage, true);
	Template.AddTargetEffect(ReloadEffect);

	AbilityProperty = new class'X2Condition_AbilityProperty';
	AbilityProperty.OwnerHasSoldierAbilities.AddItem('IRI_SupplyRun');

	GrantActionPoints = new class'X2Effect_GrantActionPoints';
	GrantActionPoints.NumActionPoints = 1;
	GrantActionPoints.PointType = class'X2CharacterTemplateManager'.default.MoveActionPoint;
	GrantActionPoints.TargetConditions.AddItem(AbilityProperty);
	Template.AddShooterEffect(GrantActionPoints);

	//Template.CinescriptCameraType = "StandardGrenadeFiring";
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState; 
	Template.BuildVisualizationFn = ResupplyAmmo_BuildVisualization;

	return Template;
}

simulated function ResupplyAmmo_BuildVisualization(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata   ActionMetadata;
	local XComGameStateVisualizationMgr VisMgr;
	local X2Action						FireAction;
	local X2Action_EnterCover			EnterCoverAction;
	local X2Action_ExitCover			ExitCoverAction;
	local X2Action_ExitCover			TargetExitCover;
	local X2Action						NewExitCoverAction;

	local XComGameStateHistory			History;
	local XComGameState_Unit			SourceUnit;
	local XComGameStateContext_Ability  Context;
	local X2Action_MoveTurn				MoveTurnAction;

	TypicalAbility_BuildVisualization(VisualizeGameState);

	VisMgr = `XCOMVISUALIZATIONMGR;
	
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	ExitCoverAction = X2Action_ExitCover(VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_ExitCover',, Context.InputContext.SourceObject.ObjectID));
	FireAction = VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_Fire');

	if (ExitCoverAction != none && FireAction != none)
	{
		// If ability was self-targeted
		if (Context.InputContext.PrimaryTarget == Context.InputContext.SourceObject)
		{
			//	Kill exit and enter cover viz
			EnterCoverAction = X2Action_EnterCover(VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_EnterCover',, Context.InputContext.SourceObject.ObjectID));
			EnterCoverAction.bSkipEnterCover = true;
			ExitCoverAction.bSkipExitCoverVisualization = true;
			return;
		}

		//	Replace original Exit Cover Action with a custom one that doesn't make the primary target crouch due to "friendly fire".
		NewExitCoverAction = class'X2Action'.static.CreateVisualizationActionClass(class'X2Action_ExitCoverSupplyThrow', Context);
		VisMgr.ReplaceNode(NewExitCoverAction, ExitCoverAction);

		// Make primary target face the shooter.
		History = `XCOMHISTORY;
		SourceUnit = XComGameState_Unit(VisualizeGameState.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID));

		ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(Context.InputContext.PrimaryTarget.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
		ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(Context.InputContext.PrimaryTarget.ObjectID);
		ActionMetadata.VisualizeActor = History.GetVisualizer(Context.InputContext.PrimaryTarget.ObjectID);

		TargetExitCover = X2Action_ExitCover(class'X2Action_ExitCover'.static.AddToVisualizationTree(ActionMetadata, Context, false, NewExitCoverAction));
		TargetExitCover.bSkipExitCoverVisualization = true;

		MoveTurnAction = X2Action_MoveTurn(class'X2Action_MoveTurn'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		MoveTurnAction.m_vFacePoint =  `XWORLD.GetPositionFromTileCoordinates(SourceUnit.TileLocation);
		MoveTurnAction.UpdateAimTarget = true;

		// Play idle animation while the projectile travels.
		class'X2Action_PlayIdleAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
	}
}


static function X2AbilityTemplate PullAlly()
{
	local X2AbilityTemplate                 Template;
	local X2Condition_UnitProperty          UnitPropertyCondition;
	local X2Condition_UnblockedNeighborTile UnblockedNeighborTileCondition;
	local X2Effect_GetOverHere              GetOverHereEffect;
	local X2Effect_ApplyWeaponDamage		EnvironmentDamageForProjectile;
	local X2Effect_RemoveEffects			RemoveEffects;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_PullAlly');
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_holdtheline";

	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;

	AddActionCost(Template);
	AddCooldown(Template, default.PullAllyCooldown);

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	// There must be a free tile around the source unit
	UnblockedNeighborTileCondition = new class'X2Condition_UnblockedNeighborTile';
	UnblockedNeighborTileCondition.RequireVisible = true;
	Template.AbilityShooterConditions.AddItem(UnblockedNeighborTileCondition);

	// The Target must be alive and a humanoid
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeRobotic = true;
	UnitPropertyCondition.FailOnNonUnits = true;
	UnitPropertyCondition.ExcludeCivilian = true;
	UnitPropertyCondition.ExcludeTurret = true;
	UnitPropertyCondition.TreatMindControlledSquadmateAsHostile = true;
	UnitPropertyCondition.ExcludeHostileToSource = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = false;
	UnitPropertyCondition.RequireWithinMinRange = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);

	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	//	prevent various stationary units from being pulled inappropriately
	Template.AbilityTargetConditions.AddItem(class'X2Ability_TemplarAbilitySet'.static.InvertAndExchangeEffectsCondition());

	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.AbilityToHitCalc = default.DeadEye;

	GetOverHereEffect = new class'X2Effect_GetOverHere';
 	GetOverHereEffect.OverrideStartAnimName = 'NO_KeeperGetPulled';
 	GetOverHereEffect.OverrideStopAnimName = 'NO_GrappleStop';
	GetOverHereEffect.RequireVisibleTile = true;
	Template.AddTargetEffect(GetOverHereEffect);

	EnvironmentDamageForProjectile = new class'X2Effect_ApplyWeaponDamage';
	EnvironmentDamageForProjectile.bIgnoreBaseDamage = true;
	EnvironmentDamageForProjectile.EnvironmentalDamageAmount = 30;
	Template.AddTargetEffect(EnvironmentDamageForProjectile);

	RemoveEffects = new class'X2Effect_RemoveEffects';
	RemoveEffects.EffectNamesToRemove.AddItem(class'X2Effect_Suppression'.default.EffectName);
	Template.AddTargetEffect(RemoveEffects);

	Template.bForceProjectileTouchEvents = true;

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = PullAlly_BuildVisualization;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
	Template.Hostility = eHostility_Defensive;
	Template.bFrameEvenWhenUnitIsHidden = true;

	// Custom fire action that doesn't use idle state machine to turn the target towards the shooter.
	Template.ActionFireClass = class'X2Action_GrappleGetOverHere';
	//Template.ActivationSpeech = 'Justice';
		
	return Template;
}

simulated function PullAlly_BuildVisualization(XComGameState VisualizeGameState)
{
	local VisualizationActionMetadata   ActionMetadata;
	local XComGameStateVisualizationMgr VisMgr;
	local X2Action_ExitCover			ExitCoverAction;
	local X2Action_ExitCoverSupplyThrow NewExitCoverAction;
	local X2Action_ExitCover			TargetExitCover;

	local XComGameState_Unit			SourceUnit;
	local XComGameStateContext_Ability  Context;
	local X2Action_MoveTurn				MoveTurnAction;
	local X2Action_ViperGetOverHere		GetOverHereAction;
	local X2Action						TargetGetPulledAction;
	local X2Action_PlayIdleAnimation	PlayIdleAnimation;
	local X2Action_PlayAnimation		PlayAnimation;
	local X2Action_WaitForAnotherAction WaitAction;

	TypicalAbility_BuildVisualization(VisualizeGameState);

	VisMgr = `XCOMVISUALIZATIONMGR;
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	ExitCoverAction = X2Action_ExitCover(VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_ExitCover'));
	TargetGetPulledAction = VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_ViperGetOverHereTarget');
	// This is the fire action for this ability.
	GetOverHereAction = X2Action_ViperGetOverHere(VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_ViperGetOverHere'));

	if (ExitCoverAction != none && GetOverHereAction != none && TargetGetPulledAction != none && Context != none)
	{
		// From the Grapple Pull BuildViz
		GetOverHereAction.StartAnimName = 'NO_StranglePullStart';
		GetOverHereAction.StopAnimName = 'NO_StranglePullStop';		
		
		// Replace the Exit Cover Action with a custom one that doesn't make the target duck.
		NewExitCoverAction = X2Action_ExitCoverSupplyThrow(class'X2Action'.static.CreateVisualizationActionClass(class'X2Action_ExitCoverSupplyThrow', Context));
		NewExitCoverAction.bUsePreviousGameState = true; // From the Grapple Pull BuildViz
		VisMgr.ReplaceNode(NewExitCoverAction, ExitCoverAction);

		// Make primary target face the shooter.
		SourceUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID));

		ActionMetadata = TargetGetPulledAction.Metadata;

		TargetExitCover = X2Action_ExitCover(class'X2Action_ExitCover'.static.AddToVisualizationTree(ActionMetadata, Context, false, NewExitCoverAction.TreeRoot));
		TargetExitCover.bSkipExitCoverVisualization = true;

		MoveTurnAction = X2Action_MoveTurn(class'X2Action_MoveTurn'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		MoveTurnAction.m_vFacePoint =  `XWORLD.GetPositionFromTileCoordinates(SourceUnit.TileLocation);
		MoveTurnAction.UpdateAimTarget = true;

		// Play generic idle animation so that the soldier doesn't auto-turn to nearest enemy via IdleStateMachine
		PlayIdleAnimation = X2Action_PlayIdleAnimation(class'X2Action_PlayIdleAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		PlayIdleAnimation.bFinishAnimationWait = false; // Set up this action to instacomplete the moment the next action is ready

		// And the next action is ready when the shooter finishes Exit Cover.
		WaitAction = X2Action_WaitForAnotherAction(class'X2Action_WaitForAnotherAction'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		WaitAction.ActionToWaitFor = NewExitCoverAction;

		// Play "raise left hand" animation while the projectile travels.
		PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		PlayAnimation.Params.AnimName = 'HL_SignalHaltA';		
	}
}

static function X2AbilityTemplate PullLoot()
{
	local X2AbilityTemplate                 Template;		
	local X2Condition_Lootable              LootableCondition;
	local X2Condition_Visibility			VisibilityCondition;
	local X2AbilityMultiTarget_Radius       MultiTarget;
	local X2AbilityTarget_Single            SingleTarget;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_PullLoot');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_targetpaint"; 
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.LOOT_PRIORITY;
	Template.bDisplayInUITooltip = false;
	Template.bDontDisplayInAbilitySummary = true;

	AddActionCost(Template);

	// Targeting and Triggering
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	SingleTarget = new class'X2AbilityTarget_Single';
	SingleTarget.bAllowInteractiveObjects = true;
	Template.AbilityTargetStyle = SingleTarget;	

	MultiTarget = new class'X2AbilityMultiTarget_Loot';
	MultiTarget.bUseWeaponRadius = false;
	MultiTarget.fTargetRadius = class'X2Ability_DefaultAbilitySet'.default.EXPANDED_LOOT_RANGE;
	MultiTarget.bIgnoreBlockingCover = true; // UI doesn't/cant conform to cover so don't block the collection either
	Template.AbilityMultiTargetStyle = MultiTarget;
	Template.SkipRenderOfAOETargetingTiles = true;

	//	Shooter Conditions
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	// Target Conditions
	LootableCondition = new class'X2Condition_Lootable';
	LootableCondition.bRestrictRange = false;
	Template.AbilityTargetConditions.AddItem(LootableCondition);

	VisibilityCondition = new class'X2Condition_Visibility';
	VisibilityCondition.bRequireLOS = true;
	Template.AbilityTargetConditions.AddItem(VisibilityCondition);

	LootableCondition = new class'X2Condition_Lootable';
	//  Note: the multi target handles restricting the range on these based on the primary target's location
	Template.AbilityMultiTargetConditions.AddItem(LootableCondition);

	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_ShowIfAvailable;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
		
	Template.CustomFireAnim = 'NO_Pull_Loot';
	Template.BuildNewGameStateFn = class'X2Ability_DefaultAbilitySet'.static.LootAbility_BuildGameState;
	Template.BuildVisualizationFn = PullLoot_BuildVisualization;
	Template.ModifyNewContextFn = ModifyContext_PullLoot;
	Template.Hostility = eHostility_Neutral;

	Template.CinescriptCameraType = "Loot";

	return Template;
}

static function PullLoot_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory				History;
	local XComGameStateContext_Ability		Context;
	local StateObjectReference				InteractingUnitRef;	
	local Lootable							LootTarget;
	local VisualizationActionMetadata       ActionMetadata;

	History = `XCOMHISTORY;
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	InteractingUnitRef = Context.InputContext.SourceObject;
	LootTarget = Lootable(History.GetGameStateForObjectID(Context.InputContext.PrimaryTarget.ObjectID));

	//Configure the visualization track for the shooter
	//****************************************************************************************
	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
	ActionMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

	class'X2Action_ExitCoverLoot'.static.AddToVisualizationTree(ActionMetadata, Context);
	class'X2Action_Fire'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
	class'X2Action_EnterCover'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
	class'X2Action_Loot'.static.AddToVisualizationTreeIfLooted(LootTarget, Context, ActionMetadata);	
	//****************************************************************************************
}

static function ModifyContext_PullLoot(XComGameStateContext Context)
{
	local XComGameStateContext_Ability	AbilityContext;
	local Lootable						LootTarget;
	local TTile							LootTileLocation;
	local vector						LootLocation;

	AbilityContext = XComGameStateContext_Ability(Context);
	LootTarget = Lootable(`XCOMHISTORY.GetGameStateForObjectID(AbilityContext.InputContext.PrimaryTarget.ObjectID));

	if (LootTarget != none)
	{
		LootTileLocation = LootTarget.GetLootLocation();
		LootLocation = `XWORLD.GetPositionFromTileCoordinates(LootTileLocation);

		AbilityContext.InputContext.TargetLocations.Length = 0;
		AbilityContext.InputContext.TargetLocations.AddItem(LootLocation);

		AbilityContext.ResultContext.ProjectileHitLocations.Length = 0;
		AbilityContext.ResultContext.ProjectileHitLocations.AddItem(LootLocation);

		// Probably unnecessary
		AbilityContext.ResultContext.HitResult = eHit_Success;
	}
} 


static function X2AbilityTemplate Create_KnockoutAndBleedoutSelf()
{
	local X2AbilityTemplate				Template;
	local X2Effect_Persistent			BleedingOut;
	local X2Effect_Persistent			UnconsciousEffect;
	local X2Effect_ObjectiveTracker		ObjectiveTrackerEffect;
	local X2Effect_BreakConcealmentListener	BreakConcealmentListener;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_KnockoutAndBleedoutSelf');

	//	Icon Setup
	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_none";
	Template.bDontDisplayInAbilitySummary = true;
	Template.AbilitySourceName = 'eAbilitySource_Standard';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;

	//	Targeting and Triggering
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	//	Change effect set up a little to reduce the amount of camera panning towards Denmother.
	UnconsciousEffect = class'X2StatusEffects'.static.CreateUnconsciousStatusEffect();
	UnconsciousEffect.VisualizationFn = none;
	Template.AddTargetEffect(UnconsciousEffect);

	BleedingOut = class'X2StatusEffects'.static.CreateBleedingOutStatusEffect();
	BleedingOut.iNumTurns = default.DenmotherBleedoutTurns;
	BleedingOut.EffectTickedVisualizationFn = Denmother_BleedingOutVisualizationTicked;
	BleedingOut.EffectTickedFn = Denmother_Bleedout_EffectTicked;
	Template.AddTargetEffect(BleedingOut);

	// Give Denmother 0 tile detection range and keep her in concealment until targeted by an xcom ability.
	BreakConcealmentListener = new class'X2Effect_BreakConcealmentListener';
	BreakConcealmentListener.BuildPersistentEffect(1, true, false, false);
	BreakConcealmentListener.AddPersistentStatChange(eStat_DetectionRadius, 0.0f, MODOP_Multiplication);
	BreakConcealmentListener.bRemoveWhenTargetConcealmentBroken = true;
	//BreakConcealmentListener.SetDisplayInfo( ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyHelpText( ), Template.IconImage, true );
	Template.AddTargetEffect(BreakConcealmentListener);

	ObjectiveTrackerEffect = new class'X2Effect_ObjectiveTracker';
	ObjectiveTrackerEffect.BuildPersistentEffect(1, true, false);
	ObjectiveTrackerEffect.bRemoveWhenSourceDies = false;
	ObjectiveTrackerEffect.bRemoveWhenTargetDies = false;
	Template.AddTargetEffect(ObjectiveTrackerEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState; 
	Template.BuildVisualizationFn = class'X2Ability_DefaultAbilitySet'.static.Knockout_BuildVisualization;

	return Template;
}

// The Bleedout effect is applied to Denmother technically before the player's furst turn, so when they see her bleeding out on the mission start, she will have X turns remaining,
// But once the player actually gets control of the soldiers it will be X-1. To fix this, make the effect autoextend itself by one turn the first time it ticks.
static function bool Denmother_Bleedout_EffectTicked(X2Effect_Persistent PersistentEffect, const out EffectAppliedData ApplyEffectParameters, XComGameState_Effect kNewEffectState, XComGameState NewGameState, bool FirstApplication)
{
	if (kNewEffectState.FullTurnsTicked == 0)
	{
		`LOG("Denmother Bleedout ticking for the first time, increasing turns remaining.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		kNewEffectState.iTurnsRemaining++;
	}
	// The effect will continue.
	return false;
}

// Do not visualize ticking the first time effect is applied.
// Otherwise use regular bleedout tick visualization. This removes excessive camera panning on the mission start.
static function Denmother_BleedingOutVisualizationTicked(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local XComGameState_Effect	EffectState;
	local XComGameState_Unit	UnitState;

	UnitState = XComGameState_Unit(ActionMetadata.StateObject_NewState);
	if (UnitState == none)
	{
		UnitState = XComGameState_Unit(ActionMetadata.StateObject_OldState);
	}
	if (UnitState != none)
	{
		EffectState = UnitState.GetUnitAffectedByEffectState(class'X2StatusEffects'.default.BleedingOutName);
		if (EffectState != none)
		{
			if (EffectState.FullTurnsTicked == 0)
			{
				`LOG("Skipping bleedout visualization tick for the first turn", class'Denmother'.default.bLog, 'IRIDENMOTHER');
				return;
			}
		}
	}
	
	class'X2StatusEffects'.static.BleedingOutVisualizationTicked(VisualizeGameState, ActionMetadata, EffectApplyResult);
}

static function X2AbilityTemplate Create_OneGoodEye_Passive()
{
	local X2AbilityTemplate		Template;
	local X2Effect_OneGoodEye	Effect;
	
	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_OneGoodEye_Passive');

	SetPassive(Template);
	Template.IconImage = "img:///IRIDenmotherUI.UIPerk_OneGoodEye";
	Template.AbilitySourceName = 'eAbilitySource_Perk';

	Effect = new class'X2Effect_OneGoodEye';
	Effect.BuildPersistentEffect(1, true);
	Effect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.LocLongDescription, Template.IconImage, true,, Template.AbilitySourceName);
	Template.AddTargetEffect(Effect);

	return Template;
}

//	========================================
//				COMMON CODE
//	========================================

static function SetPassive(out X2AbilityTemplate Template)
{
	Template.bIsPassive = true;

	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;

	//	These are actually default for X2AbilityTemplate
	Template.bDisplayInUITacticalText = true;
	Template.bDisplayInUITooltip = true;
	Template.bDontDisplayInAbilitySummary = false;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	Template.Hostility = eHostility_Neutral;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
}

static function AddCooldown(out X2AbilityTemplate Template, int Cooldown)
{
	local X2AbilityCooldown AbilityCooldown;

	if (Cooldown > 0)
	{
		AbilityCooldown = new class'X2AbilityCooldown';
		AbilityCooldown.iNumTurns = Cooldown;
		Template.AbilityCooldown = AbilityCooldown;
	}
}

static function AddCharges(out X2AbilityTemplate Template, int InitialCharges)
{
	local X2AbilityCharges		Charges;
	local X2AbilityCost_Charges	ChargeCost;

	if (InitialCharges > 0)
	{
		Charges = new class'X2AbilityCharges';
		Charges.InitialCharges = InitialCharges;
		Template.AbilityCharges = Charges;

		ChargeCost = new class'X2AbilityCost_Charges';
		ChargeCost.NumCharges = 1;
		Template.AbilityCosts.AddItem(ChargeCost);
	}
}

static function AddFreeCost(out X2AbilityTemplate Template)
{
	local X2AbilityCost_ActionPoints ActionPointCost;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bFreeCost = true;
	Template.AbilityCosts.AddItem(ActionPointCost);
}

static function AddActionCost(out X2AbilityTemplate Template, optional bool bEndsTurn = false)
{
	local X2AbilityCost_ActionPoints ActionPointCost;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bFreeCost = false;
	ActionPointCost.bConsumeAllPoints = bEndsTurn;
	Template.AbilityCosts.AddItem(ActionPointCost);
}