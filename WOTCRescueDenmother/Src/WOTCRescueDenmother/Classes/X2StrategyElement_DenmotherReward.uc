class X2StrategyElement_DenmotherReward extends X2StrategyElement;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_DenmotherObjective());

	return Templates;
}

static function X2DataTemplate Create_DenmotherObjective()
{
	local X2ObjectiveTemplate Template;

	`CREATE_X2TEMPLATE(class'X2ObjectiveTemplate', Template, 'IRI_Rescue_Denmother_Objective');

	Template.bMainObjective = true;
	Template.TacticalCompletion = true;
	//Template.CompleteObjectiveFn = DenmotherObjectiveComplete;

	//Template.CompletionEvent = 'IRI_RescuedDenmother_Event';	

	//Template.ObjectiveRequirementsMetFn = RescueDenmother_ObjectiveRequirementsMet;

	return Template;
}
/*
static function DenmotherObjectiveComplete(XComGameState NewGameState, XComGameState_Objective ObjectiveState)
{
		//local XComGameStateHistory			History;
		//local XComGameState_ObjectivesList	ObjectiveList;
		//local XComGameState_BattleData		BattleData;
		//local int i;

		//	Will let Denmother walk off Skyranger and actually transition from tactical to strategy
		//AddUnitToSquadAndCrew(UnitState, NewGameState);
		`LOG("Denmother objective is complete",, 'IRITEST');
}*/