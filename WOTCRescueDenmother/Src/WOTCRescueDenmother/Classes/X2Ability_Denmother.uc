class X2Ability_Denmother extends X2Ability config(Denmother);

var config int DenmotherBleedoutTurns;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_KnockoutAndBleedoutSelf());
	Templates.AddItem(Create_OneGoodEye_Passive());

	return Templates;
}

static function X2AbilityTemplate Create_KnockoutAndBleedoutSelf()
{
	local X2AbilityTemplate	Template;
	local X2Effect_DeployDenmother	Effect;
	//local X2Effect_Persistent		BleedingOut;
	local X2Effect_ObjectiveTracker	ObjectiveTrackerEffect;
	local X2Effect_ApplyWeaponDamage	DamageEffect;
	local X2Effect_Persistent		GuaranteeBleedout;
	
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

	//Template.AddTargetEffect(class'X2StatusEffects'.static.CreateUnconsciousStatusEffect());

	//BleedingOut = class'X2StatusEffects'.static.CreateBleedingOutStatusEffect();
	//BleedingOut.iNumTurns = default.DenmotherBleedoutTurns;
	//Template.AddTargetEffect(BleedingOut);
	GuaranteeBleedout = new class'X2Effect_Persistent';
	GuaranteeBleedout.BuildPersistentEffect(1, false, true, false, eGameRule_PlayerTurnEnd);
	GuaranteeBleedout.bEffectForcesBleedout = true;
	Template.AddTargetEffect(GuaranteeBleedout);

	DamageEffect = new class'X2Effect_ApplyWeaponDamage';
	DamageEffect.bIgnoreBaseDamage = true;
	DamageEffect.EffectDamageValue.Damage = 100;
	Template.AddTargetEffect(DamageEffect);

	Effect = new class'X2Effect_DeployDenmother';
	Effect.BuildPersistentEffect(1, true);
	//Effect.DeathActionClass = class'X2Action_Death';
	//Effect.AddPersistentStatChange(eStat_SightRadius, -0.99f, MODOP_Multiplication);
	Template.AddTargetEffect(Effect);

	ObjectiveTrackerEffect = new class'X2Effect_ObjectiveTracker';
	ObjectiveTrackerEffect.BuildPersistentEffect(1, true, false);
	//ObjectiveTrackerEffect.VisualizationFn = class'X2StatusEffects'.static.BleedingOutVisualizationTicked;
	ObjectiveTrackerEffect.bRemoveWhenSourceDies = false;
	ObjectiveTrackerEffect.bRemoveWhenTargetDies = false;
	Template.AddTargetEffect(ObjectiveTrackerEffect);

	Template.FrameAbilityCameraType = eCameraFraming_Never;
	Template.bFrameEvenWhenUnitIsHidden = false;
	Template.bShowActivation = false;
	Template.bUsesFiringCamera = false;
	Template.bSkipFireAction = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState; 
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization; // class'X2Ability_DefaultAbilitySet'.static.Knockout_BuildVisualization;

	return Template;
}

/*
imulated function Knockout_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory History;
	local XComGameStateContext_Ability  Context;
	local StateObjectReference          InteractingUnitRef;
	local StateObjectReference			TargetUnitRef;
	local XComGameState_Ability         Ability;

	local VisualizationActionMetadata        EmptyTrack;
	local VisualizationActionMetadata        ActionMetadata;
	local VisualizationActionMetadata		 TargetActionMetadata;

	local X2Action_PlaySoundAndFlyOver SoundAndFlyOver;
	local int EffectIndex;
	local X2AbilityTemplate AbilityTemplate;
	local name EffectApplyResult, UnconsciousEffectApplyResult;
	local X2Effect_Persistent TestEffect;

	History = `XCOMHISTORY;

	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	InteractingUnitRef = Context.InputContext.SourceObject;
	TargetUnitRef = Context.InputContext.PrimaryTarget;
	AbilityTemplate = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(Context.InputContext.AbilityTemplateName);

	//Configure the visualization track for the shooter

	ActionMetadata = EmptyTrack;
	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(InteractingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(InteractingUnitRef.ObjectID);
	ActionMetadata.VisualizeActor = History.GetVisualizer(InteractingUnitRef.ObjectID);
					
	Ability = XComGameState_Ability(History.GetGameStateForObjectID(Context.InputContext.AbilityRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1));
	SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
	SoundAndFlyOver.SetSoundAndFlyOverParameters(None, Ability.GetMyTemplate().LocFlyOverText, '', eColor_Good);

	for( EffectIndex = 0; EffectIndex < AbilityTemplate.AbilityShooterEffects.Length; ++EffectIndex )
	{
		AbilityTemplate.AbilityShooterEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, Context.FindShooterEffectApplyResult(AbilityTemplate.AbilityShooterEffects[EffectIndex]));
	}

	//Configure the visualization track for the target

	TargetActionMetadata = EmptyTrack;
	TargetActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(TargetUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	TargetActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(TargetUnitRef.ObjectID);
	TargetActionMetadata.VisualizeActor = History.GetVisualizer(TargetUnitRef.ObjectID);

	for( EffectIndex = 0; EffectIndex < AbilityTemplate.AbilityTargetEffects.Length; ++EffectIndex )
	{
		EffectApplyResult = Context.FindTargetEffectApplyResult(AbilityTemplate.AbilityTargetEffects[EffectIndex]);
		AbilityTemplate.AbilityTargetEffects[EffectIndex].AddX2ActionsForVisualization(VisualizeGameState, TargetActionMetadata, EffectApplyResult);
		
		TestEffect = X2Effect_Persistent(AbilityTemplate.AbilityTargetEffects[EffectIndex]);
		if( (TestEffect != none) &&
			(TestEffect.EffectName == class'X2StatusEffects'.default.UnconsciousName) &&
			(UnconsciousEffectApplyResult != 'AA_Success') )
		{
			UnconsciousEffectApplyResult = EffectApplyResult;
		}
	}

	if( UnconsciousEffectApplyResult == 'AA_Success' )
	{
		class'X2Action_ExitCover'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
		class'X2Action_Knockout'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
		class'X2Action_EnterCover'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded);
	}
}
*/
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