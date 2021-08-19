class X2StrategyElement_DenmotherReward extends X2StrategyElement config(Denmother);

var config int GTS_Training_Unlock_Cost_Supplies;
var config name GTS_Training_Unlock_Grants_Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_DenmotherObjective());
	Templates.AddItem(Create_GTS_Unlock());

	return Templates;
}

static function X2DataTemplate Create_DenmotherObjective()
{
	local X2ObjectiveTemplate Template;

	`CREATE_X2TEMPLATE(class'X2ObjectiveTemplate', Template, 'IRI_Rescue_Denmother_Objective');

	Template.bMainObjective = true;
	Template.TacticalCompletion = true;

	return Template;
}

static function X2SoldierAbilityUnlockTemplate Create_GTS_Unlock()
{
	local X2SoldierAbilityUnlockTemplate Template;
	local ArtifactCost Resources;

	`CREATE_X2TEMPLATE(class'X2SoldierAbilityUnlockTemplate', Template, 'IRI_Keeper_GTS_Unlock');

	Template.AllowedClasses.AddItem('Keeper');

	Template.AbilityName = default.GTS_Training_Unlock_Grants_Ability;
	Template.strImage = "img:///IRIDenmotherUI.GTS_KeeperTraining";

	// Requirements
	Template.Requirements.RequiredHighestSoldierRank = 5;
	Template.Requirements.RequiredSoldierClass = 'Keeper';
	Template.Requirements.RequiredSoldierRankClassCombo = true;
	Template.Requirements.bVisibleIfSoldierRankGatesNotMet = true;

	// Cost
	Resources.ItemTemplateName = 'Supplies';
	Resources.Quantity = default.GTS_Training_Unlock_Cost_Supplies;
	Template.Cost.ResourceCosts.AddItem(Resources);

	return Template;
}