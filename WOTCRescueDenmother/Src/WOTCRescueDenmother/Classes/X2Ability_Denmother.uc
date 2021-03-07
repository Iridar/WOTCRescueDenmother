class X2Ability_Denmother extends X2Ability config(Denmother);

var config int DenmotherBleedoutTurns;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ResupplyAmmo());

	Templates.AddItem(Create_KnockoutAndBleedoutSelf());
	Templates.AddItem(Create_OneGoodEye_Passive());

	return Templates;
}

static function X2AbilityTemplate Create_ResupplyAmmo()
{
	local X2AbilityTemplate				Template;
	local X2Effect_ReloadPrimaryWeapon	ReloadEffect;
	local X2Condition_UnitProperty      TargetCondition;
	local X2Effect_RemoveEffects		RemoveEffects;

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
	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.TargetingMethod = class'X2TargetingMethod_ResupplyAmmo';
	Template.SkipRenderOfAOETargetingTiles = true;
	Template.SkipRenderOfTargetingTemplate = true;	

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	TargetCondition = new class'X2Condition_UnitProperty';
	TargetCondition.ExcludeHostileToSource = true;
	TargetCondition.ExcludeFriendlyToSource = false;
	TargetCondition.RequireSquadmates = false;
	TargetCondition.FailOnNonUnits = true;
	TargetCondition.ExcludeDead = true;
	TargetCondition.ExcludeRobotic = false;
	TargetCondition.ExcludeUnableToAct = true;
	Template.AbilityTargetConditions.AddItem(TargetCondition);
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	//	Remove any existing instances of this effect on the target unit so that we don't get into stupid games 
	//	between multiple keepers trying to apply their ammo effects to the same target.
	RemoveEffects = new class'X2Effect_RemoveEffects';
	RemoveEffects.EffectNamesToRemove.AddItem(class'X2Effect_ReloadPrimaryWeapon'.default.EffectName);
	Template.AddShooterEffect(RemoveEffects);	

	ReloadEffect = new class'X2Effect_ReloadPrimaryWeapon';
	ReloadEffect.BuildPersistentEffect(1, true, false);
	ReloadEffect.SetDisplayInfo(ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage, true);
	Template.AddTargetEffect(ReloadEffect);

	//Template.CinescriptCameraType = "StandardGrenadeFiring";
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState; 
	//Template.BuildVisualizationFn = GiveRocket_BuildVisualization;
	//Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
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
	local X2Action_MarkerNamed			ExitReplace;

	local XComGameStateHistory			History;
	local XComGameState_Unit			SourceUnit;
	local XComGameStateContext_Ability  Context;
	local X2Action_MoveTurn				MoveTurnAction;
	//local X2Action_TimedWait			TimedWait;

	TypicalAbility_BuildVisualization(VisualizeGameState);

	VisMgr = `XCOMVISUALIZATIONMGR;
	ExitCoverAction = VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_ExitCover');
	FireAction = VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_Fire');

	if (ExitCoverAction != none && FireAction != none)
	{
		Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());

		//	Replace original Exit Cover Action with a custom one that doesn't make the primary target crouch due to "friendly fire".
		ActionMetadata = ExitCoverAction.Metadata;
		NewExitCoverAction = class'X2Action_ExitCoverSupplyThrow'.static.AddToVisualizationTree(ActionMetadata, Context, true,, ExitCoverAction.ParentActions);
		
		VisMgr.ConnectAction(FireAction, VisMgr.BuildVisTree, false, NewExitCoverAction);

		ExitReplace = X2Action_MarkerNamed(class'X2Action'.static.CreateVisualizationActionClass(class'X2Action_MarkerNamed', Context));
		ExitReplace.SetName("ExitActionStub");
		VisMgr.ReplaceNode(ExitReplace, ExitCoverAction);

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