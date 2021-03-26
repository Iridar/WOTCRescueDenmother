class UIScreenListener_Denmother extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local UIInventory_LootRecovered				LootRecovered;
	local XComGameState_Unit					UnitState;
	local string								StatusLabel;
	local EUIState								VIPState;
	local XComGameState_HeadquartersResistance	ResistanceHQ;
	local string								DisplayText;

	LootRecovered = UIInventory_LootRecovered(Screen);
	if (LootRecovered != none && class'X2Denmother'.static.IsMissionFirstRetaliation('UISL'))
	{
		UnitState = class'X2Denmother'.static.GetDenmotherHistoryUnitState();

		if (LootRecovered.VIPPanel == none)
		{
			LootRecovered.VIPPanel = LootRecovered.Spawn(class'UIInventory_VIPRecovered', LootRecovered).InitVIPRecovered();
			LootRecovered.VIPPanel.SetPosition(1300, 772); // position is based on guided out panel in Inventory.fla
		}

		if (UnitState != none && UnitState.IsAlive())
		{
			`LOG("UIScreenListener_Denmother: Denmother is alive, creating actor pawn", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			LootRecovered.VIPPanel.CreateVIPPawn(UnitState);

			StatusLabel = LootRecovered.VIPPanel.m_strVIPStatus[eVIPStatus_Awarded];
			VIPState = eUIState_Good;
			DisplayText = class'X2Denmother'.default.strDenmotherFirstName @ "\"" $ class'X2Denmother'.default.strDenmotherNickName $ "\"" @ class'X2Denmother'.default.strDenmotherLastName;
		}
		else	// If she was dead by the end of the mission, she gets cleaned up and doesn't exist anymore.
		{
			`LOG("UIScreenListener_Denmother: Denmother is dead or doesn't exist, marking VIP dead", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			StatusLabel = LootRecovered.VIPPanel.m_strVIPStatus[eVIPStatus_Killed];
			VIPState = eUIState_Bad;
			DisplayText = class'X2Denmother'.default.strDenmotherFirstName @ "\"" $ class'X2Denmother'.default.strDenmotherNickName $ "\"" @ class'X2Denmother'.default.strDenmotherLastName;
		}

		ResistanceHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();

		LootRecovered.VIPPanel.AS_UpdateData(class'UIUtilities_Text'.static.GetColoredText(StatusLabel, VIPState), 
			class'UIUtilities_Text'.static.GetColoredText(DisplayText, eUIState_Normal),
			"", ResistanceHQ.VIPRewardsString);
	}

	if (IsInStrategy() && IsKeeperInCrew())
	{
		AddSoldierUnlockTemplate('OfficerTrainingSchool', 'IRI_Keeper_GTS_Unlock');
	}
}

static private function AddSoldierUnlockTemplate(name FacilityName, name UnlockGTSName)
{
	local X2FacilityTemplate FacilityTemplate;

	// Find the GTS facility template
	FacilityTemplate = X2FacilityTemplate(class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate(FacilityName));
	if (FacilityTemplate == none)
		return;

	if (FacilityTemplate.SoldierUnlockTemplates.Find(UnlockGTSName) != INDEX_NONE)
		return;

	// Update the GTS template with the specified soldier unlock
	FacilityTemplate.SoldierUnlockTemplates.AddItem(UnlockGTSName);
}

static private function bool IsKeeperInCrew()
{
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;

	History = `XCOMHISTORY;
	XComHQ = `XCOMHQ;

	foreach XComHQ.Crew(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (UnitState.GetSoldierClassTemplateName() == 'Keeper')
		{
			return true;
		}
	}
	return false;
}

static private function bool IsInStrategy()
{
	return `HQGAME  != none && `HQPC != None && `HQPRES != none;
}