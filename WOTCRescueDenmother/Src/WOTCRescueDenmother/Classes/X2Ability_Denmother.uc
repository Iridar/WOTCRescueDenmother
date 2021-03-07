class X2Ability_Denmother extends X2Ability config(Denmother);

var config int DenmotherBleedoutTurns;

var localized string strWeaponReloaded;

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

	ReloadEffect = new class'X2Effect_ReloadPrimaryWeapon';
	Template.AddTargetEffect(ReloadEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState; 
	//Template.BuildVisualizationFn = GiveRocket_BuildVisualization;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

simulated function GiveRocket_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory			History;
	local XComGameStateContext_Ability  Context;
	local StateObjectReference          InteractingUnitRef;
	local VisualizationActionMetadata   EmptyTrack;
	local VisualizationActionMetadata   ActionMetadata;
	local X2Action_PlayAnimation		PlayAnimation;
	local X2Action_MoveTurn				MoveTurnAction;
	local X2Action_TimedWait			TimedWait;
	local XComGameStateVisualizationMgr VisMgr;
	local XComGameState_Unit			SourceUnit;
	local X2Action						FoundAction;
	local X2Action_PlaySoundAndFlyOver	SoundAndFlyOver;

	//	Run the Typical Build Viz first. It should set up the Exit Cover -> Fire -> Enter Cover actions for the shooter.
	TypicalAbility_BuildVisualization(VisualizeGameState);

	VisMgr = `XCOMVISUALIZATIONMGR;
	History = `XCOMHISTORY;
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	SourceUnit = XComGameState_Unit(VisualizeGameState.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID));

	//	Find the Fire Action created by Typical Build Viz.
	//	Fire Action in this context is just used to play the Give Rocket animation.
	FoundAction = VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_ExitCover');

	if (FoundAction != none && SourceUnit != none)
	{
		InteractingUnitRef = Context.InputContext.SourceObject;
		ActionMetadata = EmptyTrack;
		ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
		ActionMetadata.StateObject_NewState = SourceUnit;
		ActionMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

		//	Attach a Timed Wait Action to the beginning of the visualization tree. It will be used to synchronize the Give Rocket animation in the Fire Action and Take Rocket animation on the target.
		//  This timer will start ticking the moment the visualization for the shooter begins (visually, at the same time as the Exit Cover action).
		//TimedWait = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(ActionMetadata, Context, false, FoundAction.TreeRoot));
		//TimedWait.DelayTimeSec = 2.25f;

		//	Make the Timed Wait Action a parent of the Fire Action. This means there will be AT LEAST 1 second delay between the start of the ability visualization and the Fire Action,
		//	even if the Exit Cover action completes nearly instantly, which happens when there's no cover to exit from, and the "Shooter" is already facing the Target.
		//VisMgr.ConnectAction(FoundAction, VisMgr.BuildVisTree,, TimedWait);

		//Configure the visualization track for the target
		//****************************************************************************************

		InteractingUnitRef = Context.InputContext.PrimaryTarget;
		ActionMetadata = EmptyTrack;
		ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
		ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
		ActionMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);

		//	The soldier will not actually exit cover, but this is necessary for Move Turn action to work properly. Note that we parent this action to Vis Tree Root, 
		//	so it will start the moment ability visualization starts, practically at the same time as Exit Cover for the Shooter.
		class'X2Action_ExitCover'.static.AddToVisualizationTree(ActionMetadata, Context, false, FoundAction.TreeRoot);

		//	make the target face the location of the Souce Unit
		MoveTurnAction = X2Action_MoveTurn(class'X2Action_MoveTurn'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		MoveTurnAction.m_vFacePoint =  `XWORLD.GetPositionFromTileCoordinates(SourceUnit.TileLocation);
		MoveTurnAction.UpdateAimTarget = true;

		PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
		PlayAnimation.Params.AnimName = 'HL_CatchSupplies';

		TimedWait = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(ActionMetadata, Context, false, PlayAnimation));
		TimedWait.DelayTimeSec = 1.24f;

		PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
		PlayAnimation.Params.AnimName = 'HL_Reload';

		SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext(), false, ActionMetadata.LastActionAdded));
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, strWeaponReloaded, '', eColor_Good, "img:///UILibrary_PerkIcons.UIPerk_reload");

		class'X2Action_EnterCover'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);

		//	hold the camera on the target soldier for a bit
		//TimedWait = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
		//TimedWait.DelayTimeSec = 0.5f;

		//	Important! this is where the syncing magic happens. This sets the Timed Wait action as an additional parent to the Play Animation action. 
		//  So both Play Animation on the Target and Fire Animation on the shooter will be child actions for Timed Wait. As long as Exit Cover for the Shooter, and Exit Cover and Move Turn for the Target
		//	take less than 1.5 seconds, the Play Animation and Fire Action should start at exactly the same time, syncing 
		//VisMgr.ConnectAction(PlayAnimation, VisMgr.BuildVisTree,, FoundAction);
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