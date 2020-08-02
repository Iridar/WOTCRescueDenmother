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
	if (LootRecovered != none && class'Denmother'.static.IsMissionFirstRetaliation('UISL'))
	{
		UnitState = class'Denmother'.static.GetDenmotherCrewUnitState();

		if (LootRecovered.VIPPanel == none)
		{
			LootRecovered.VIPPanel = LootRecovered.Spawn(class'UIInventory_VIPRecovered', LootRecovered).InitVIPRecovered();
			LootRecovered.VIPPanel.SetPosition(1300, 772); // position is based on guided out panel in Inventory.fla
		}

		if (UnitState != none && UnitState.IsAlive())
		{
			`LOG("UIScreenListener_Denmother: Denmother is alive, creating actor pawn",, 'IRITEST');
			LootRecovered.VIPPanel.CreateVIPPawn(UnitState);

			StatusLabel = LootRecovered.VIPPanel.m_strVIPStatus[eVIPStatus_Awarded];
			VIPState = eUIState_Good;
			DisplayText = UnitState.GetName(eNameType_FullNick);
		}
		else	// If she was dead by the end of the mission, she gets cleaned up and doesn't exist anymore.
		{
			`LOG("UIScreenListener_Denmother: Denmother is dead or doesn't exist, marking VIP dead",, 'IRITEST');
			StatusLabel = LootRecovered.VIPPanel.m_strVIPStatus[eVIPStatus_Killed];
			VIPState = eUIState_Bad;
			DisplayText = class'Denmother'.default.strDenmotherNickName;
		}

		ResistanceHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();

		LootRecovered.VIPPanel.AS_UpdateData(class'UIUtilities_Text'.static.GetColoredText(StatusLabel, VIPState), 
			class'UIUtilities_Text'.static.GetColoredText(DisplayText, eUIState_Normal),
			"", ResistanceHQ.VIPRewardsString);
	}
}
/*
event OnInit(UIScreen Screen)
{
	local UIInventory_LootRecovered				LootRecovered;
	local XComGameState_Unit					UnitState;
	local XComGameState_HeadquartersResistance	ResistanceHQ;

	LootRecovered = UIInventory_LootRecovered(Screen);
	if (LootRecovered != none && class'Denmother'.static.IsMissionFirstRetaliation('UISL'))
	{
		//	If there's no Denmother Unit State in the crew at this point in time, then it means the player evacuated from the mission, leaving her to die.
		//	Then show the "VIP Lost" text on the reward screen.
		UnitState = class'Denmother'.static.GetDenmotherCrewUnitState();
		if (UnitState == none)
		{
			`LOG("UISL - no Denmother Unit State in crew, she was probably left for dead on the mission",, 'IRITEST');
			ResistanceHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();

			LootRecovered.VIPPanel = LootRecovered.Spawn(class'UIInventory_VIPRecovered', LootRecovered).InitVIPRecovered();
			LootRecovered.VIPPanel.SetPosition(1300, 772); // position is based on guided out panel in Inventory.fla

			LootRecovered.VIPPanel.AS_UpdateData(class'UIUtilities_Text'.static.GetColoredText(LootRecovered.VIPPanel.m_strVIPStatus[eVIPStatus_Killed], eUIState_Bad), 
				class'UIUtilities_Text'.static.GetColoredText(class'Denmother'.default.strDenmotherNickName, eUIState_Normal),
				"", ResistanceHQ.VIPRewardsString);
		}
	}
}*/