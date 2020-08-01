class UIScreenListener_Denmother extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local UIInventory_LootRecovered LootRecovered;
	local XComGameState_Unit		UnitState;
	local string					StatusLabel;
	local EUIState					VIPState;

	local XComGameState_HeadquartersResistance ResistanceHQ;

	LootRecovered = UIInventory_LootRecovered(Screen);
	if (LootRecovered != none)
	{
		UnitState = class'Denmother'.static.GetDenmotherTacticalUnitState();
		if (UnitState != none)
		{
			if (UnitState.IsAlive())
			{
				`LOG("UIScreenListener_Denmother: Denmother is alive, creating actor pawn",, 'IRITEST');
				LootRecovered.VIPPanel.CreateVIPPawn(class'Denmother'.static.GetDenmotherTacticalUnitState());

				StatusLabel = LootRecovered.VIPPanel.m_strVIPStatus[eVIPStatus_Awarded];
				VIPState = eUIState_Good;
			}
			else	// If she was dead by the end of the mission, she gets cleaned up and doesn't exist anymore. TODO: check mission, if there's no Denmother unit state, then she was killed.
			{
				StatusLabel = LootRecovered.VIPPanel.m_strVIPStatus[eVIPStatus_Killed];
				VIPState = eUIState_Bad;
			}

			ResistanceHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();

			LootRecovered.VIPPanel.AS_UpdateData(class'UIUtilities_Text'.static.GetColoredText(StatusLabel, VIPState), 
				class'UIUtilities_Text'.static.GetColoredText(UnitState.GetFullName(), eUIState_Normal),
				"", ResistanceHQ.VIPRewardsString);
		}
	}
}

event OnRemoved(UIScreen Screen)
{
	

				//	Add an eyepatch here, after creating the pawn, so she's still without an eyepatch on the rewards screen, but with the eyepatch in the barracks
			UnitState.kAppearance.nmFacePropUpper = 'Eyepatch_F';
			UnitState.StoreAppearance(); 

			`HQPRES.UINewStaffAvailable(RewardState.RewardObjectReference);
}
