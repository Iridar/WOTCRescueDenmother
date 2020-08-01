class X2DownloadableContentInfo_WOTCRescueDenmother extends X2DownloadableContentInfo;

//	TODO: better denmother positioning in mission
//	TODO: make her cosmetics not appear for randomly generated soldiers
//	straighten out her torso cosmetics, check that optionals are added properly and then comment them out
//	give her scar and eyepatch when she's added as a soldier
//	 TODO: Check if the sweep objective was completed if she's still alive even if XCOM loses?
//	align left hand socket better. firing animation, projectiles, sounds
//	TODO: add a mission check into UISL
//	visual weapon upgrades
//	figure out how to get rid of the duplicate marksman carbine
//	todo: recover denmother's weapon if she's killed on the mission, but the mission is success
//		same, but if she's killed, and XCOM evacuates her body


// GTS unlock allows to train other soldiers like that in GTS? IRIDenmotherUI.GTS_KeeperTraining

//	Denmother rescued or not
//	XCOM killed all enemies or not
//	Enough civs were saved or not

/// <summary>
/// Called just before the player launches into a tactical a mission while this DLC / Mod is installed.
/// Allows dlcs/mods to modify the start state before launching into the mission
/// </summary>
/*
static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{
	//local XComGameState_Unit				UnitState; 
	//local X2CharacterTemplateManager		CharMgr;
	//local X2CharacterTemplate				CharTemplate;
	//local XComGameState_BattleData			BattleData;
	local X2StrategyElementTemplateManager	StratMgr;
//	local X2RewardTemplate					RewardTemplate;
//	local XComGameState_Reward				MissionRewardState;
	local XComGameState_MissionCalendar		CalendarState;
	//local MissionObjectiveDefinition		NewObjective;
	local X2ObjectiveTemplate				NewObjectiveTemplate;
	local XComGameState_Objective			NewObjectiveState;

	CalendarState = XComGameState_MissionCalendar(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_MissionCalendar'));

	`LOG("Pre mission for:" @ MissionState.Source @ MissionState.GeneratedMission.Mission.MissionName @ "this is first retaliation:" @ !CalendarState.HasCreatedMultipleMissionsOfSource('MissionSource_Retaliation'),, 'IRITEST');	

	if (MissionState.Source == 'MissionSource_Retaliation' && !CalendarState.HasCreatedMultipleMissionsOfSource('MissionSource_Retaliation'))
	{
		//	Generate a new Denmother unit. Its only purpose is to show up on the post-mission screen.
		//CharMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
		//CharTemplate = CharMgr.FindCharacterTemplate('Soldier');
		//UnitState = CharTemplate.CreateInstanceFromTemplate(StartGameState);

		//class'Denmother'.static.SetUpDenmother(UnitState);

		//	Apply rookie loadout so she doesn't stand there with empty hands
		//UnitState.ApplyInventoryLoadout(StartGameState);

		//BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		//BattleData = XComGameState_BattleData(StartGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

		// This will display Denmother on the mission end screen if the mission succeeds, and show "vip lost" if it fails
		//BattleData.RewardUnits.AddItem(UnitState.GetReference());

		// ----------------------

		//	Inject a new soldier reward into the mission. This is necessary to actually add the Denmother soldier to the barracks.
		StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

		//RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('IRI_Reward_DenmotherSoldier'));
		//MissionRewardState = RewardTemplate.CreateInstanceFromTemplate(StartGameState);
		//MissionRewardState.GenerateReward(StartGameState, 1, MissionState.Region);
		//MissionState.Rewards.AddItem(MissionRewardState.GetReference());

		//	-----------------------
		`LOG("Injecting objective",, 'IRITEST');	

		//	Inject a new objective into the objective list
		NewObjectiveTemplate = X2ObjectiveTemplate(StratMgr.FindStrategyElementTemplate('IRI_Rescue_Denmother_Objective'));
		NewObjectiveState = NewObjectiveTemplate.CreateInstanceFromTemplate(StartGameState);
		NewObjectiveState.StartObjective(StartGameState, true);
	}
}
*/
static event OnPostMission()
{
	//local XComGameState_MissionSite MissionState;
	local XComGameState_BattleData	BattleData;
	local XComGameStateHistory		History;
	local XComGameState				NewGameState;
	local XComGameState_Objective	ObjectiveState;
	local XComGameState_Unit		UnitState;

	//local X2StrategyElementTemplateManager	StratMgr;
	//local X2RewardTemplate					RewardTemplate;
	//local XComGameState_Reward				MissionRewardState;
	//local int i;

	`LOG("On Post Mission",, 'IRITEST');

	ObjectiveState = class'Denmother'.static.GetDenmotherObjective();

	if (ObjectiveState != none /*&& ObjectiveState.ObjState != eObjectiveState_Completed*/)
	{
		`LOG("On Post Mission: Hiding denmother objective.",, 'IRITEST');
		History = `XCOMHISTORY;

		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

		//MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Generate Denmother Reward");

		//	Complete the objective so it doesn't appear on the Geoscape, regardless if Denmother was rescued or not
		ObjectiveState.CompleteObjective(NewGameState);
		/*
		if (class'Denmother'.static.WasDenmotherRescued(XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'))))
		{
			StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
			RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('IRI_Reward_DenmotherSoldier'));
			MissionRewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
			MissionRewardState.GenerateReward(NewGameState);
			MissionRewardState.GiveReward(NewGameState);
			//MissionRewardState.DisplayRewardPopup();
			MissionRewardState.CleanUpReward(NewGameState);
		}*/

		UnitState = class'Denmother'.static.GetDenmotherCrewUnitState();
		if (UnitState != none)
		{
			UnitState.ClearUnitValue('IRI_ThisUnitIsDenmother_Value');
			`LOG("On Post Mission: found Denmother in avenger crew.",, 'IRITEST');

			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			if (class'Denmother'.static.WereCiviliansRescued(BattleData))
			{
				`LOG("On Post Mission: Civilians were rescued, setting good backstory",, 'IRITEST');
				UnitState.SetBackground(class'Denmother'.default.strDenmotherGoodBackground);
			}
			else
			{	
				`LOG("On Post Mission: Civilians were NOT rescued, setting bad backstory",, 'IRITEST');
				UnitState.SetBackground(class'Denmother'.default.strDenmotherBadBackground);
			}

			class'Denmother'.static.GiveOneGoodEyeAbility(UnitState);

			//	Fix the name
			UnitState.SetCharacterName(class'Denmother'.default.strDenmotherFirstName, class'Denmother'.default.strDenmotherLastName, class'Denmother'.default.strDenmotherNickName);
		}
		else `LOG("On Post Mission: no denmother in avenger crew.",, 'IRITEST');

		if (NewGameState.GetNumGameStateObjects() > 0)
		{
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}
	else
	{
		`LOG("Objective is complete or doesn't exist, doing nothing",, 'IRITEST');
	}
}