class X2Ability_Denmother extends X2Ability config(Denmother);

var config int DenmotherBleedoutTurns;

var config(Keeper) float ResupplyAmmoDistanceTiles;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ResupplyAmmo());
	Templates.AddItem(PurePassive('IRI_SupplyRun', "img:///IRIKeeperBackpack.UI.UIPerk_SupplyRun", false, 'eAbilitySource_Perk', true));

	Templates.AddItem(PullAlly());
	Templates.AddItem(PullLoot());

	Templates.AddItem(Create_KnockoutAndBleedoutSelf());
	Templates.AddItem(Create_OneGoodEye_Passive());

	return Templates;
}

static function X2AbilityTemplate Create_ResupplyAmmo()
{
	local X2AbilityTemplate				Template;
	local X2Effect_ReloadPrimaryWeapon	ReloadEffect;
	local X2Condition_UnitProperty      UnitProperty;
	local X2Effect_RemoveEffects		RemoveEffects;
	local X2Condition_ResupplyAmmo		ResupplyCondition;
	local X2Effect_GrantActionPoints	GrantActionPoints;
	local X2Condition_AbilityProperty	AbilityProperty;

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
	local X2Action						ExitCoverAction;
	local X2Action_ExitCover			TargetExitCover;
	local X2Action						NewExitCoverAction;

	local X2Action_PlaySoundAndFlyOver	SoundAndFlyOver;
	local X2AbilityTemplate				AbilityTemplate;
	local array<X2Action>				FindActions;
	local X2Action						FindAction;
	local X2Action_MarkerNamed			MarkerAction;

	local XComGameStateHistory			History;
	local XComGameState_Unit			SourceUnit;
	local XComGameStateContext_Ability  Context;
	local X2Action_MoveTurn				MoveTurnAction;

	CustomTypicalAbility_BuildVisualization(VisualizeGameState);

	VisMgr = `XCOMVISUALIZATIONMGR;
	ExitCoverAction = VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_ExitCover');
	FireAction = VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_Fire');
	VisMgr.GetNodesOfType(VisMgr.BuildVisTree, class'X2Action_MarkerNamed', FindActions);

	if (ExitCoverAction != none && FireAction != none)
	{
		Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());

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

		// Handle Supply Run flyover.
		if (SourceUnit.HasSoldierAbility('IRI_SupplyRun', true))
		{
			foreach FindActions(FindAction)
			{
				MarkerAction = X2Action_MarkerNamed(FindAction);
				if (MarkerAction.MarkerName == 'IRI_FlyoverMarker')
				{
					break;
				}
			}

			AbilityTemplate = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('IRI_SupplyRun');
			if (AbilityTemplate != none && MarkerAction != none)
			{
				ActionMetadata = FireAction.Metadata;
				SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, Context, false, MarkerAction));
				SoundAndFlyOver.SetSoundAndFlyOverParameters(None, AbilityTemplate.LocFlyOverText, '', eColor_Good, AbilityTemplate.IconImage);
			}
		}
	}
}



static function X2AbilityTemplate PullAlly()
{
	local X2AbilityTemplate                 Template;
	//local X2AbilityCost_ActionPoints        ActionPointCost;
	//local X2AbilityCooldown                 Cooldown;
	local X2Condition_UnitProperty          UnitPropertyCondition;
	local X2Condition_UnblockedNeighborTile UnblockedNeighborTileCondition;
	local X2Effect_GetOverHere              GetOverHereEffect;
	local X2Effect_ApplyWeaponDamage		EnvironmentDamageForProjectile;
	local X2Effect_RemoveEffects			RemoveEffects;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_PullAlly');
	Template.IconImage = "img:///UILibrary_XPACK_Common.PerkIcons.UIPerk_Justice";

	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;

	//ActionPointCost = new class'X2AbilityCost_ActionPoints';
	//ActionPointCost.iNumPoints = 1;
	//ActionPointCost.bConsumeAllPoints = false;
	//Template.AbilityCosts.AddItem(ActionPointCost);

   // Cooldown = New class'X2AbilityCooldown';
	//Cooldown.iNumTurns = 5;
	//Template.AbilityCooldown = Cooldown;

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

	Template.AdditionalAbilities.AddItem('IRI_PullLoot');
		
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
	//local X2Condition_UnitProperty          UnitPropertyCondition;	
	local X2Condition_Lootable              LootableCondition;
	local X2Condition_Visibility			VisibilityCondition;
	local X2AbilityTrigger_PlayerInput      InputTrigger;
	local X2AbilityMultiTarget_Radius       MultiTarget;
	local X2AbilityTarget_Single            SingleTarget;
	//local X2Condition_UnitEffects			UnitEffects;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_PullLoot');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_loot"; 
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.LOOT_PRIORITY;
	Template.bDisplayInUITooltip = false;
	Template.bDontDisplayInAbilitySummary = true;
		/*
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeImpaired = true;
	UnitPropertyCondition.ImpairedIgnoresStuns = true;
	UnitPropertyCondition.ExcludePanicked = true;
	Template.AbilityShooterConditions.AddItem(UnitPropertyCondition);

	UnitEffects = new class'X2Condition_UnitEffects';
	UnitEffects.AddExcludeEffect(class'X2Ability_CarryUnit'.default.CarryUnitEffectName, 'AA_CarryingUnit');
	Template.AbilityShooterConditions.AddItem(UnitEffects);
	*/
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	LootableCondition = new class'X2Condition_Lootable';
	//LootableCondition.LootableRange = `TILESTOUNITS(17);
	LootableCondition.bRestrictRange = false;
	Template.AbilityTargetConditions.AddItem(LootableCondition);

	VisibilityCondition = new class'X2Condition_Visibility';
	VisibilityCondition.bRequireLOS = true;
	Template.AbilityTargetConditions.AddItem(VisibilityCondition);

	InputTrigger = new class'X2AbilityTrigger_PlayerInput';
	Template.AbilityTriggers.AddItem(InputTrigger);

	SingleTarget = new class'X2AbilityTarget_Single';
	SingleTarget.bAllowInteractiveObjects = true;
	Template.AbilityTargetStyle = SingleTarget;	

	MultiTarget = new class'X2AbilityMultiTarget_Loot';
	MultiTarget.bUseWeaponRadius = false;
	MultiTarget.fTargetRadius = class'X2Ability_DefaultAbilitySet'.default.EXPANDED_LOOT_RANGE;
	MultiTarget.bIgnoreBlockingCover = true; // UI doesn't/cant conform to cover so don't block the collection either
	Template.AbilityMultiTargetStyle = MultiTarget;
	Template.SkipRenderOfAOETargetingTiles = true;

	LootableCondition = new class'X2Condition_Lootable';
	//  Note: the multi target handles restricting the range on these based on the primary target's location
	Template.AbilityMultiTargetConditions.AddItem(LootableCondition);

	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_ShowIfAvailable;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
		
	Template.CustomFireAnim = 'NO_Pull_Loot';
	Template.BuildNewGameStateFn = class'X2Ability_DefaultAbilitySet'.static.LootAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.Hostility = eHostility_Neutral;

	Template.CinescriptCameraType = "Loot";

	return Template;
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



//--------------------------------------------------------

static function CustomTypicalAbility_BuildVisualization(XComGameState VisualizeGameState)
{	
	//general
	local XComGameStateHistory	History;
	local XComGameStateVisualizationMgr VisualizationMgr;

	//visualizers
	local Actor	TargetVisualizer, ShooterVisualizer;

	//actions
	local X2Action							AddedAction;
	local X2Action							FireAction;
	local X2Action_MoveTurn					MoveTurnAction;
	local X2Action_PlaySoundAndFlyOver		SoundAndFlyover;
	local X2Action_ExitCoverSupplyThrow		ExitCoverAction;
	local X2Action_MoveTeleport				TeleportMoveAction;
	local X2Action_Delay					MoveDelay;
	local X2Action_MoveEnd					MoveEnd;
	local X2Action_MarkerNamed				JoinActions;
	local array<X2Action>					LeafNodes;
	local X2Action_WaitForAnotherAction		WaitForFireAction;

	//state objects
	local XComGameState_Ability				AbilityState;
	local XComGameState_EnvironmentDamage	EnvironmentDamageEvent;
	local XComGameState_WorldEffectTileData WorldDataUpdate;
	local XComGameState_InteractiveObject	InteractiveObject;
	local XComGameState_BaseObject			TargetStateObject;
	local XComGameState_Item				SourceWeapon;
	local StateObjectReference				ShootingUnitRef;

	//interfaces
	local X2VisualizerInterface			TargetVisualizerInterface, ShooterVisualizerInterface;

	//contexts
	local XComGameStateContext_Ability	Context;
	local AbilityInputContext			AbilityContext;

	//templates
	local X2AbilityTemplate	AbilityTemplate;
	local X2AmmoTemplate	AmmoTemplate;
	local X2WeaponTemplate	WeaponTemplate;
	local array<X2Effect>	MultiTargetEffects;

	//Tree metadata
	local VisualizationActionMetadata   InitData;
	local VisualizationActionMetadata   BuildData;
	local VisualizationActionMetadata   SourceData, InterruptTrack;

	local XComGameState_Unit TargetUnitState;	
	local name         ApplyResult;

	//indices
	local int	EffectIndex, TargetIndex;
	local int	TrackIndex;
	local int	WindowBreakTouchIndex;

	//flags
	local bool	bSourceIsAlsoTarget;
	local bool	bMultiSourceIsAlsoTarget;
	local bool  bPlayedAttackResultNarrative;
			
	// good/bad determination
	local bool bGoodAbility;

	History = `XCOMHISTORY;
	VisualizationMgr = `XCOMVISUALIZATIONMGR;
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	AbilityContext = Context.InputContext;
	AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(AbilityContext.AbilityRef.ObjectID));
	AbilityTemplate = class'XComGameState_Ability'.static.GetMyTemplateManager().FindAbilityTemplate(AbilityContext.AbilityTemplateName);
	ShootingUnitRef = Context.InputContext.SourceObject;

	//Configure the visualization track for the shooter, part I. We split this into two parts since
	//in some situations the shooter can also be a target
	//****************************************************************************************
	ShooterVisualizer = History.GetVisualizer(ShootingUnitRef.ObjectID);
	ShooterVisualizerInterface = X2VisualizerInterface(ShooterVisualizer);

	SourceData = InitData;
	SourceData.StateObject_OldState = History.GetGameStateForObjectID(ShootingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	SourceData.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(ShootingUnitRef.ObjectID);
	if (SourceData.StateObject_NewState == none)
		SourceData.StateObject_NewState = SourceData.StateObject_OldState;
	SourceData.VisualizeActor = ShooterVisualizer;	

	SourceWeapon = XComGameState_Item(History.GetGameStateForObjectID(AbilityContext.ItemObject.ObjectID));
	if (SourceWeapon != None)
	{
		WeaponTemplate = X2WeaponTemplate(SourceWeapon.GetMyTemplate());
		AmmoTemplate = X2AmmoTemplate(SourceWeapon.GetLoadedAmmoTemplate(AbilityState));
	}

	bGoodAbility = XComGameState_Unit(SourceData.StateObject_NewState).IsFriendlyToLocalPlayer();

	if( Context.IsResultContextMiss() && AbilityTemplate.SourceMissSpeech != '' )
	{
		SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(BuildData, Context));
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", AbilityTemplate.SourceMissSpeech, bGoodAbility ? eColor_Bad : eColor_Good);
	}
	else if( Context.IsResultContextHit() && AbilityTemplate.SourceHitSpeech != '' )
	{
		SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(BuildData, Context));
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, "", AbilityTemplate.SourceHitSpeech, bGoodAbility ? eColor_Good : eColor_Bad);
	}

	if( !AbilityTemplate.bSkipFireAction || Context.InputContext.MovementPaths.Length > 0 )
	{
		ExitCoverAction = X2Action_ExitCoverSupplyThrow(class'X2Action_ExitCoverSupplyThrow'.static.AddToVisualizationTree(SourceData, Context));
		ExitCoverAction.bSkipExitCoverVisualization = AbilityTemplate.bSkipExitCoverWhenFiring;

		// if this ability has a built in move, do it right before we do the fire action
		if(Context.InputContext.MovementPaths.Length > 0)
		{			
			// note that we skip the stop animation since we'll be doing our own stop with the end of move attack
			class'X2VisualizerHelpers'.static.ParsePath(Context, SourceData, AbilityTemplate.bSkipMoveStop);

			//  add paths for other units moving with us (e.g. gremlins moving with a move+attack ability)
			if (Context.InputContext.MovementPaths.Length > 1)
			{
				for (TrackIndex = 1; TrackIndex < Context.InputContext.MovementPaths.Length; ++TrackIndex)
				{
					BuildData = InitData;
					BuildData.StateObject_OldState = History.GetGameStateForObjectID(Context.InputContext.MovementPaths[TrackIndex].MovingUnitRef.ObjectID);
					BuildData.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(Context.InputContext.MovementPaths[TrackIndex].MovingUnitRef.ObjectID);
					MoveDelay = X2Action_Delay(class'X2Action_Delay'.static.AddToVisualizationTree(BuildData, Context));
					MoveDelay.Duration = class'X2Ability_DefaultAbilitySet'.default.TypicalMoveDelay;
					class'X2VisualizerHelpers'.static.ParsePath(Context, BuildData, AbilityTemplate.bSkipMoveStop);	
				}
			}

			if( !AbilityTemplate.bSkipFireAction )
			{
				MoveEnd = X2Action_MoveEnd(VisualizationMgr.GetNodeOfType(VisualizationMgr.BuildVisTree, class'X2Action_MoveEnd', SourceData.VisualizeActor));				

				if (MoveEnd != none)
				{
					// add the fire action as a child of the node immediately prior to the move end
					AddedAction = AbilityTemplate.ActionFireClass.static.AddToVisualizationTree(SourceData, Context, false, none, MoveEnd.ParentActions);

					// reconnect the move end action as a child of the fire action, as a special end of move animation will be performed for this move + attack ability
					VisualizationMgr.DisconnectAction(MoveEnd);
					VisualizationMgr.ConnectAction(MoveEnd, VisualizationMgr.BuildVisTree, false, AddedAction);
				}
				else
				{
					//See if this is a teleport. If so, don't perform exit cover visuals
					TeleportMoveAction = X2Action_MoveTeleport(VisualizationMgr.GetNodeOfType(VisualizationMgr.BuildVisTree, class'X2Action_MoveTeleport', SourceData.VisualizeActor));
					if (TeleportMoveAction != none)
					{
						//Skip the FOW Reveal ( at the start of the path ). Let the fire take care of it ( end of the path )
						ExitCoverAction.bSkipFOWReveal = true;
					}

					AddedAction = AbilityTemplate.ActionFireClass.static.AddToVisualizationTree(SourceData, Context, false, SourceData.LastActionAdded);
				}
			}
		}
		else
		{
			//If we were interrupted, insert a marker node for the interrupting visualization code to use. In the move path version above, it is expected for interrupts to be 
			//done during the move.
			if (Context.InterruptionStatus != eInterruptionStatus_None)
			{
				//Insert markers for the subsequent interrupt to insert into
				class'X2Action'.static.AddInterruptMarkerPair(SourceData, Context, ExitCoverAction);
			}

			if (!AbilityTemplate.bSkipFireAction)
			{
				// no move, just add the fire action. Parent is exit cover action if we have one
				AddedAction = AbilityTemplate.ActionFireClass.static.AddToVisualizationTree(SourceData, Context, false, SourceData.LastActionAdded);
			}			
		}

		if( !AbilityTemplate.bSkipFireAction )
		{
			FireAction = AddedAction;

			class'XComGameState_NarrativeManager'.static.BuildVisualizationForDynamicNarrative(VisualizeGameState, false, 'AttackBegin', FireAction.ParentActions[0]);

			if( AbilityTemplate.AbilityToHitCalc != None )
			{
				X2Action_Fire(AddedAction).SetFireParameters(Context.IsResultContextHit());
			}
		}
	}

	//If there are effects added to the shooter, add the visualizer actions for them
	for (EffectIndex = 0; EffectIndex < AbilityTemplate.AbilityShooterEffects.Length; ++EffectIndex)
	{
		AbilityTemplate.AbilityShooterEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, SourceData, Context.FindShooterEffectApplyResult(AbilityTemplate.AbilityShooterEffects[EffectIndex]));		
	}
	//****************************************************************************************

	//Configure the visualization track for the target(s). This functionality uses the context primarily
	//since the game state may not include state objects for misses.
	//****************************************************************************************	
	bSourceIsAlsoTarget = AbilityContext.PrimaryTarget.ObjectID == AbilityContext.SourceObject.ObjectID; //The shooter is the primary target
	if (AbilityTemplate.AbilityTargetEffects.Length > 0 &&			//There are effects to apply
		AbilityContext.PrimaryTarget.ObjectID > 0)				//There is a primary target
	{
		TargetVisualizer = History.GetVisualizer(AbilityContext.PrimaryTarget.ObjectID);
		TargetVisualizerInterface = X2VisualizerInterface(TargetVisualizer);

		if( bSourceIsAlsoTarget )
		{
			BuildData = SourceData;
		}
		else
		{
			BuildData = InterruptTrack;        //  interrupt track will either be empty or filled out correctly
		}

		BuildData.VisualizeActor = TargetVisualizer;

		TargetStateObject = VisualizeGameState.GetGameStateForObjectID(AbilityContext.PrimaryTarget.ObjectID);
		if( TargetStateObject != none )
		{
			History.GetCurrentAndPreviousGameStatesForObjectID(AbilityContext.PrimaryTarget.ObjectID, 
															   BuildData.StateObject_OldState, BuildData.StateObject_NewState,
															   eReturnType_Reference,
															   VisualizeGameState.HistoryIndex);
			`assert(BuildData.StateObject_NewState == TargetStateObject);
		}
		else
		{
			//If TargetStateObject is none, it means that the visualize game state does not contain an entry for the primary target. Use the history version
			//and show no change.
			BuildData.StateObject_OldState = History.GetGameStateForObjectID(AbilityContext.PrimaryTarget.ObjectID);
			BuildData.StateObject_NewState = BuildData.StateObject_OldState;
		}

		// if this is a melee attack, make sure the target is facing the location he will be melee'd from
		if(!AbilityTemplate.bSkipFireAction 
			&& !bSourceIsAlsoTarget 
			&& AbilityContext.MovementPaths.Length > 0
			&& AbilityContext.MovementPaths[0].MovementData.Length > 0
			&& XGUnit(TargetVisualizer) != none)
		{
			MoveTurnAction = X2Action_MoveTurn(class'X2Action_MoveTurn'.static.AddToVisualizationTree(BuildData, Context, false, ExitCoverAction));
			MoveTurnAction.m_vFacePoint = AbilityContext.MovementPaths[0].MovementData[AbilityContext.MovementPaths[0].MovementData.Length - 1].Position;
			MoveTurnAction.m_vFacePoint.Z = TargetVisualizerInterface.GetTargetingFocusLocation().Z;
			MoveTurnAction.UpdateAimTarget = true;

			// Jwats: Add a wait for ability effect so the idle state machine doesn't process!
			WaitForFireAction = X2Action_WaitForAnotherAction(class'X2Action_WaitForAnotherAction'.static.AddToVisualizationTree(BuildData, Context, false, MoveTurnAction));
			WaitForFireAction.ActionToWaitFor = FireAction;
		}

		//Pass in AddedAction (Fire Action) as the LastActionAdded if we have one. Important! As this is automatically used as the parent in the effect application sub functions below.
		if (AddedAction != none && AddedAction.IsA('X2Action_Fire'))
		{
			BuildData.LastActionAdded = AddedAction;
		}
		
		//Add any X2Actions that are specific to this effect being applied. These actions would typically be instantaneous, showing UI world messages
		//playing any effect specific audio, starting effect specific effects, etc. However, they can also potentially perform animations on the 
		//track actor, so the design of effect actions must consider how they will look/play in sequence with other effects.
		for (EffectIndex = 0; EffectIndex < AbilityTemplate.AbilityTargetEffects.Length; ++EffectIndex)
		{
			ApplyResult = Context.FindTargetEffectApplyResult(AbilityTemplate.AbilityTargetEffects[EffectIndex]);

			// Target effect visualization
			if( !Context.bSkipAdditionalVisualizationSteps )
			{
				AbilityTemplate.AbilityTargetEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, ApplyResult);
			}

			// Source effect visualization
			AbilityTemplate.AbilityTargetEffects[EffectIndex].AddX2ActionsForVisualizationSource(VisualizeGameState, SourceData, ApplyResult);
		}

		//the following is used to handle Rupture flyover text
		TargetUnitState = XComGameState_Unit(BuildData.StateObject_OldState);
		if (TargetUnitState != none &&
			XComGameState_Unit(BuildData.StateObject_OldState).GetRupturedValue() == 0 &&
			XComGameState_Unit(BuildData.StateObject_NewState).GetRupturedValue() > 0)
		{
			//this is the frame that we realized we've been ruptured!
			class 'X2StatusEffects'.static.RuptureVisualization(VisualizeGameState, BuildData);
		}

		if (AbilityTemplate.bAllowAmmoEffects && AmmoTemplate != None)
		{
			for (EffectIndex = 0; EffectIndex < AmmoTemplate.TargetEffects.Length; ++EffectIndex)
			{
				ApplyResult = Context.FindTargetEffectApplyResult(AmmoTemplate.TargetEffects[EffectIndex]);
				AmmoTemplate.TargetEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, ApplyResult);
				AmmoTemplate.TargetEffects[EffectIndex].AddX2ActionsForVisualizationSource(VisualizeGameState, SourceData, ApplyResult);
			}
		}
		if (AbilityTemplate.bAllowBonusWeaponEffects && WeaponTemplate != none)
		{
			for (EffectIndex = 0; EffectIndex < WeaponTemplate.BonusWeaponEffects.Length; ++EffectIndex)
			{
				ApplyResult = Context.FindTargetEffectApplyResult(WeaponTemplate.BonusWeaponEffects[EffectIndex]);
				WeaponTemplate.BonusWeaponEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, ApplyResult);
				WeaponTemplate.BonusWeaponEffects[EffectIndex].AddX2ActionsForVisualizationSource(VisualizeGameState, SourceData, ApplyResult);
			}
		}

		if (Context.IsResultContextMiss() && (AbilityTemplate.LocMissMessage != "" || AbilityTemplate.TargetMissSpeech != ''))
		{
			SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(BuildData, Context, false, BuildData.LastActionAdded));
			SoundAndFlyOver.SetSoundAndFlyOverParameters(None, AbilityTemplate.LocMissMessage, AbilityTemplate.TargetMissSpeech, bGoodAbility ? eColor_Bad : eColor_Good);
		}
		else if( Context.IsResultContextHit() && (AbilityTemplate.LocHitMessage != "" || AbilityTemplate.TargetHitSpeech != '') )
		{
			SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(BuildData, Context, false, BuildData.LastActionAdded));
			SoundAndFlyOver.SetSoundAndFlyOverParameters(None, AbilityTemplate.LocHitMessage, AbilityTemplate.TargetHitSpeech, bGoodAbility ? eColor_Good : eColor_Bad);
		}

		if (!bPlayedAttackResultNarrative)
		{
			class'XComGameState_NarrativeManager'.static.BuildVisualizationForDynamicNarrative(VisualizeGameState, false, 'AttackResult');
			bPlayedAttackResultNarrative = true;
		}

		if( TargetVisualizerInterface != none )
		{
			//Allow the visualizer to do any custom processing based on the new game state. For example, units will create a death action when they reach 0 HP.
			TargetVisualizerInterface.BuildAbilityEffectsVisualization(VisualizeGameState, BuildData);
		}

		if( bSourceIsAlsoTarget )
		{
			SourceData = BuildData;
		}
	}

	if (AbilityTemplate.bUseLaunchedGrenadeEffects)
	{
		MultiTargetEffects = X2GrenadeTemplate(SourceWeapon.GetLoadedAmmoTemplate(AbilityState)).LaunchedGrenadeEffects;
	}
	else if (AbilityTemplate.bUseThrownGrenadeEffects)
	{
		MultiTargetEffects = X2GrenadeTemplate(SourceWeapon.GetMyTemplate()).ThrownGrenadeEffects;
	}
	else
	{
		MultiTargetEffects = AbilityTemplate.AbilityMultiTargetEffects;
	}

	//  Apply effects to multi targets - don't show multi effects for burst fire as we just want the first time to visualize
	if( MultiTargetEffects.Length > 0 && AbilityContext.MultiTargets.Length > 0 && X2AbilityMultiTarget_BurstFire(AbilityTemplate.AbilityMultiTargetStyle) == none)
	{
		for( TargetIndex = 0; TargetIndex < AbilityContext.MultiTargets.Length; ++TargetIndex )
		{	
			bMultiSourceIsAlsoTarget = false;
			if( AbilityContext.MultiTargets[TargetIndex].ObjectID == AbilityContext.SourceObject.ObjectID )
			{
				bMultiSourceIsAlsoTarget = true;
				bSourceIsAlsoTarget = bMultiSourceIsAlsoTarget;				
			}

			TargetVisualizer = History.GetVisualizer(AbilityContext.MultiTargets[TargetIndex].ObjectID);
			TargetVisualizerInterface = X2VisualizerInterface(TargetVisualizer);

			if( bMultiSourceIsAlsoTarget )
			{
				BuildData = SourceData;
			}
			else
			{
				BuildData = InitData;
			}
			BuildData.VisualizeActor = TargetVisualizer;

			// if the ability involved a fire action and we don't have already have a potential parent,
			// all the target visualizations should probably be parented to the fire action and not rely on the auto placement.
			if( (BuildData.LastActionAdded == none) && (FireAction != none) )
				BuildData.LastActionAdded = FireAction;

			TargetStateObject = VisualizeGameState.GetGameStateForObjectID(AbilityContext.MultiTargets[TargetIndex].ObjectID);
			if( TargetStateObject != none )
			{
				History.GetCurrentAndPreviousGameStatesForObjectID(AbilityContext.MultiTargets[TargetIndex].ObjectID, 
																	BuildData.StateObject_OldState, BuildData.StateObject_NewState,
																	eReturnType_Reference,
																	VisualizeGameState.HistoryIndex);
				`assert(BuildData.StateObject_NewState == TargetStateObject);
			}			
			else
			{
				//If TargetStateObject is none, it means that the visualize game state does not contain an entry for the primary target. Use the history version
				//and show no change.
				BuildData.StateObject_OldState = History.GetGameStateForObjectID(AbilityContext.MultiTargets[TargetIndex].ObjectID);
				BuildData.StateObject_NewState = BuildData.StateObject_OldState;
			}
		
			//Add any X2Actions that are specific to this effect being applied. These actions would typically be instantaneous, showing UI world messages
			//playing any effect specific audio, starting effect specific effects, etc. However, they can also potentially perform animations on the 
			//track actor, so the design of effect actions must consider how they will look/play in sequence with other effects.
			for (EffectIndex = 0; EffectIndex < MultiTargetEffects.Length; ++EffectIndex)
			{
				ApplyResult = Context.FindMultiTargetEffectApplyResult(MultiTargetEffects[EffectIndex], TargetIndex);

				// Target effect visualization
				MultiTargetEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, ApplyResult);

				// Source effect visualization
				MultiTargetEffects[EffectIndex].AddX2ActionsForVisualizationSource(VisualizeGameState, SourceData, ApplyResult);
			}			

			//the following is used to handle Rupture flyover text
			TargetUnitState = XComGameState_Unit(BuildData.StateObject_OldState);
			if (TargetUnitState != none && 
				XComGameState_Unit(BuildData.StateObject_OldState).GetRupturedValue() == 0 &&
				XComGameState_Unit(BuildData.StateObject_NewState).GetRupturedValue() > 0)
			{
				//this is the frame that we realized we've been ruptured!
				class 'X2StatusEffects'.static.RuptureVisualization(VisualizeGameState, BuildData);
			}
			
			if (!bPlayedAttackResultNarrative)
			{
				class'XComGameState_NarrativeManager'.static.BuildVisualizationForDynamicNarrative(VisualizeGameState, false, 'AttackResult');
				bPlayedAttackResultNarrative = true;
			}

			if( TargetVisualizerInterface != none )
			{
				//Allow the visualizer to do any custom processing based on the new game state. For example, units will create a death action when they reach 0 HP.
				TargetVisualizerInterface.BuildAbilityEffectsVisualization(VisualizeGameState, BuildData);
			}

			if( bMultiSourceIsAlsoTarget )
			{
				SourceData = BuildData;
			}			
		}
	}
	//****************************************************************************************

	//Finish adding the shooter's track
	//****************************************************************************************
	if( !bSourceIsAlsoTarget && ShooterVisualizerInterface != none)
	{
		ShooterVisualizerInterface.BuildAbilityEffectsVisualization(VisualizeGameState, SourceData);				
	}	

	//  Handle redirect visualization
	TypicalAbility_AddEffectRedirects(VisualizeGameState, SourceData);

	//****************************************************************************************

	//Configure the visualization tracks for the environment
	//****************************************************************************************

	if (ExitCoverAction != none)
	{
		ExitCoverAction.ShouldBreakWindowBeforeFiring( Context, WindowBreakTouchIndex );
	}

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_EnvironmentDamage', EnvironmentDamageEvent)
	{
		BuildData = InitData;
		BuildData.VisualizeActor = none;
		BuildData.StateObject_NewState = EnvironmentDamageEvent;
		BuildData.StateObject_OldState = EnvironmentDamageEvent;

		// if this is the damage associated with the exit cover action, we need to force the parenting within the tree
		// otherwise LastActionAdded with be 'none' and actions will auto-parent.
		if ((ExitCoverAction != none) && (WindowBreakTouchIndex > -1))
		{
			if (EnvironmentDamageEvent.HitLocation == AbilityContext.ProjectileEvents[WindowBreakTouchIndex].HitLocation)
			{
				BuildData.LastActionAdded = ExitCoverAction;
			}
		}

		for (EffectIndex = 0; EffectIndex < AbilityTemplate.AbilityShooterEffects.Length; ++EffectIndex)
		{
			AbilityTemplate.AbilityShooterEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, 'AA_Success');		
		}

		for (EffectIndex = 0; EffectIndex < AbilityTemplate.AbilityTargetEffects.Length; ++EffectIndex)
		{
			AbilityTemplate.AbilityTargetEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, 'AA_Success');
		}

		for (EffectIndex = 0; EffectIndex < MultiTargetEffects.Length; ++EffectIndex)
		{
			MultiTargetEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, 'AA_Success');	
		}
	}

	foreach VisualizeGameState.IterateByClassType(class'XComGameState_WorldEffectTileData', WorldDataUpdate)
	{
		BuildData = InitData;
		BuildData.VisualizeActor = none;
		BuildData.StateObject_NewState = WorldDataUpdate;
		BuildData.StateObject_OldState = WorldDataUpdate;

		for (EffectIndex = 0; EffectIndex < AbilityTemplate.AbilityShooterEffects.Length; ++EffectIndex)
		{
			AbilityTemplate.AbilityShooterEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, 'AA_Success');		
		}

		for (EffectIndex = 0; EffectIndex < AbilityTemplate.AbilityTargetEffects.Length; ++EffectIndex)
		{
			AbilityTemplate.AbilityTargetEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, 'AA_Success');
		}

		for (EffectIndex = 0; EffectIndex < MultiTargetEffects.Length; ++EffectIndex)
		{
			MultiTargetEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, BuildData, 'AA_Success');	
		}
	}
	//****************************************************************************************

	//Process any interactions with interactive objects
	foreach VisualizeGameState.IterateByClassType(class'XComGameState_InteractiveObject', InteractiveObject)
	{
		// Add any doors that need to listen for notification. 
		// Move logic is taken from MoveAbility_BuildVisualization, which only has special case handling for AI patrol movement ( which wouldn't happen here )
		if ( Context.InputContext.MovementPaths.Length > 0 || (InteractiveObject.IsDoor() && InteractiveObject.HasDestroyAnim()) ) //Is this a closed door?
		{
			BuildData = InitData;
			//Don't necessarily have a previous state, so just use the one we know about
			BuildData.StateObject_OldState = InteractiveObject;
			BuildData.StateObject_NewState = InteractiveObject;
			BuildData.VisualizeActor = History.GetVisualizer(InteractiveObject.ObjectID);

			class'X2Action_BreakInteractActor'.static.AddToVisualizationTree(BuildData, Context);
		}
	}
	
	//Add a join so that all hit reactions and other actions will complete before the visualization sequence moves on. In the case
	// of fire but no enter cover then we need to make sure to wait for the fire since it isn't a leaf node
	VisualizationMgr.GetAllLeafNodes(VisualizationMgr.BuildVisTree, LeafNodes);

	if (!AbilityTemplate.bSkipFireAction)
	{
		if (!AbilityTemplate.bSkipExitCoverWhenFiring)
		{			
			LeafNodes.AddItem(class'X2Action_EnterCover'.static.AddToVisualizationTree(SourceData, Context, false, FireAction));
		}
		else
		{
			LeafNodes.AddItem(FireAction);
		}
	}
	
	if (VisualizationMgr.BuildVisTree.ChildActions.Length > 0)
	{
		JoinActions = X2Action_MarkerNamed(class'X2Action_MarkerNamed'.static.AddToVisualizationTree(SourceData, Context, false, none, LeafNodes));
		JoinActions.SetName("Join");
	}
}