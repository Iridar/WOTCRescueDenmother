class UIScreenListener_Denmother extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local UIInventory_LootRecovered LootRecovered;
	local XComGameState_Unit		UnitState;
	local string					StatusLabel;

	local XComGameState_HeadquartersResistance ResistanceHQ;

	LootRecovered = UIInventory_LootRecovered(Screen);
	if (LootRecovered != none)
	{
		UnitState = class'Denmother'.static.GetDenmotherTacticalUnitState();
		if (UnitState == none)
		{
			`LOG("UIScreenListener_Denmother: No Denmother tactical unit state",, 'IRITEST');
			UnitState = class'Denmother'.static.GetDenmotherCrewUnitState();
		}
		if (UnitState != none)
		{
			`LOG("UIScreenListener_Denmother: creating Denmother actor pawn",, 'IRITEST');
			LootRecovered.VIPPanel.CreateVIPPawn(UnitState);

			StatusLabel = LootRecovered.VIPPanel.m_strVIPStatus[eVIPStatus_Awarded];
			ResistanceHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();

			LootRecovered.VIPPanel.AS_UpdateData(class'UIUtilities_Text'.static.GetColoredText(StatusLabel, eUIState_Good), 
				class'UIUtilities_Text'.static.GetColoredText(UnitState.GetFullName(), eUIState_Normal),
				"", ResistanceHQ.VIPRewardsString);
		}
		else `LOG("UIScreenListener_Denmother: No Denmother crew unit state",, 'IRITEST');
	}
}
