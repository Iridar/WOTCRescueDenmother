class X2StrategyElement_DenmotherReward extends X2StrategyElement;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_DenmotherObjective());

	//Templates.AddItem(Create_DenmotherReward());

	return Templates;
}

static function X2DataTemplate Create_DenmotherObjective()
{
	local X2ObjectiveTemplate Template;

	`CREATE_X2TEMPLATE(class'X2ObjectiveTemplate', Template, 'IRI_Rescue_Denmother_Objective');

	Template.bMainObjective = true;
	Template.TacticalCompletion = true;
	Template.CompleteObjectiveFn = DenmotherObjectiveComplete;

	//Template.CompletionEvent = 'IRI_RescuedDenmother_Event';	

	//Template.ObjectiveRequirementsMetFn = RescueDenmother_ObjectiveRequirementsMet;

	return Template;
}

static function DenmotherObjectiveComplete(XComGameState NewGameState, XComGameState_Objective ObjectiveState)
{
		//local XComGameStateHistory			History;
		//local XComGameState_ObjectivesList	ObjectiveList;
		//local XComGameState_BattleData		BattleData;
		//local int i;

		//	Will let Denmother walk off Skyranger and actually transition from tactical to strategy
		//AddUnitToSquadAndCrew(UnitState, NewGameState);
		`LOG("Denmother objective is complete",, 'IRITEST');
}
/*
static function bool RescueDenmother_ObjectiveRequirementsMet(XComGameState NewGameState, XComGameState_Objective ObjectiveState)
{
	local XComGameState_Unit UnitState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if (UnitState.TacticalTag == 'IRI_DenmotherReward_Tag')
		{
			if (UnitState.IsAlive())
			{
				`LOG(GetFuncName() @ "Found unit with Denmother tactical tag, she's alive, objective can complete",, 'IRITEST');
				return true;
			}
			`LOG(GetFuncName() @ "Found unit with Denmother tactical tag, she's dead, objective cannot complete",, 'IRITEST');
			return false;
		}
	}
	`LOG(GetFuncName() @ "Did not find unit with Denmother tactical tag, objective cannot complete",, 'IRITEST');
	return false;
}*/
/*
static function X2DataTemplate Create_DenmotherReward()
{
	local X2RewardTemplate Template;

	`CREATE_X2Reward_TEMPLATE(Template, 'IRI_Reward_DenmotherSoldier');

	Template.rewardObjectTemplateName = 'Soldier';

	//Template.IsRewardAvailableFn = HasDenmotherBeenRescued;
	Template.GenerateRewardFn = Generate_DenmotherReward;
	Template.SetRewardFn = class'X2StrategyElement_DefaultRewards'.static.SetPersonnelReward;
	Template.GiveRewardFn = class'X2StrategyElement_DefaultRewards'.static.GivePersonnelReward;
	Template.GetRewardStringFn = class'X2StrategyElement_DefaultRewards'.static.GetPersonnelRewardString;
	Template.GetRewardImageFn = class'X2StrategyElement_DefaultRewards'.static.GetPersonnelRewardImage;
	Template.GetBlackMarketStringFn = class'X2StrategyElement_DefaultRewards'.static.GetSoldierBlackMarketString;
	Template.GetRewardIconFn = class'X2StrategyElement_DefaultRewards'.static.GetGenericRewardIcon;
	Template.RewardPopupFn = class'X2StrategyElement_DefaultRewards'.static.PersonnelRewardPopup;

	return Template;
}*/
/*
static function bool HasDenmotherBeenRescued(optional XComGameState NewGameState, optional StateObjectReference AuxRef)
{
	return false;
}*/
/*
static function Generate_DenmotherReward(XComGameState_Reward RewardState, XComGameState NewGameState, optional float RewardScalar = 1.0, optional StateObjectReference RegionRef)
{
	local XComGameState_Unit UnitState;

	`LOG("Generate_DenmotherReward",, 'IRITEST');

	UnitState = class'Denmother'.static.CreateDenmotherUnit(NewGameState, true);

	UnitState.SetCurrentStat(eStat_HP, 1);
	UnitState.LowestHP = 1;

	RewardState.RewardObjectReference = UnitState.GetReference();

	// Set an appropriate fame score for the unit
	UnitState.StartingFame = `XCOMHQ.AverageSoldierFame;
	UnitState.bIsFamous = true;
	`XEVENTMGR.TriggerEvent('RewardUnitGenerated', UnitState, UnitState); //issue #185 - fires off event with unit after they've been promoted to their reward rank
}
*/