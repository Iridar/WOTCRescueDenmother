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
	local X2AbilityTemplate				Template;
	local X2Effect_Persistent			BleedingOut;
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

	Template.AddTargetEffect(class'X2StatusEffects'.static.CreateUnconsciousStatusEffect());

	BleedingOut = class'X2StatusEffects'.static.CreateBleedingOutStatusEffect();
	BleedingOut.iNumTurns = default.DenmotherBleedoutTurns;
	Template.AddTargetEffect(BleedingOut);

	// Give Denmother 0 tile detection range and keep her in concealment until targeted by an xcom ability.
	BreakConcealmentListener = new class'X2Effect_BreakConcealmentListener';
	BreakConcealmentListener.BuildPersistentEffect(1, true, false, false);
	BreakConcealmentListener.AddPersistentStatChange(eStat_DetectionModifier, 1);
	BreakConcealmentListener.bRemoveWhenTargetConcealmentBroken = true;
	BreakConcealmentListener.SetDisplayInfo( ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyHelpText( ), Template.IconImage, true ); // TODO: Remove this after debugging
	Template.AddTargetEffect(BreakConcealmentListener);

	ObjectiveTrackerEffect = new class'X2Effect_ObjectiveTracker';
	ObjectiveTrackerEffect.BuildPersistentEffect(1, true, false);
	ObjectiveTrackerEffect.VisualizationFn = class'X2StatusEffects'.static.BleedingOutVisualizationTicked;
	ObjectiveTrackerEffect.bRemoveWhenSourceDies = false;
	ObjectiveTrackerEffect.bRemoveWhenTargetDies = false;
	Template.AddTargetEffect(ObjectiveTrackerEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState; 
	Template.BuildVisualizationFn = class'X2Ability_DefaultAbilitySet'.static.Knockout_BuildVisualization;

	return Template;
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