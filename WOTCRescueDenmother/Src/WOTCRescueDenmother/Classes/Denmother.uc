class Denmother extends Object;

var localized string strDenmotherFirstName;
var localized string strDenmotherLastName;
var localized string strDenmotherNickName;

var localized string strDenmotherGoodBackground;
var localized string strDenmotherBadBackground;

static function FailDenmotherObjective(XComGameState NewGameState)
{
	local XComGameStateHistory			History;
	local XComGameState_ObjectivesList	ObjectiveList;
	local int i;

	//	Denmother is dead, mark objective as failed
	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_ObjectivesList', ObjectiveList)
	{
		break;
	}

	ObjectiveList = XComGameState_ObjectivesList(NewGameState.ModifyStateObject(class'XComGameState_ObjectivesList', ObjectiveList != none ? ObjectiveList.ObjectID : -1));
	for (i = 0; i < ObjectiveList.ObjectiveDisplayInfos.Length; i++)
	{
		if (ObjectiveList.ObjectiveDisplayInfos[i].ObjectiveTemplateName == 'IRI_Rescue_Denmother_Objective')
		{
			ObjectiveList.ObjectiveDisplayInfos[i].ShowFailed = true;
			break;
		}
	}
}

static function SucceedDenmotherObjective(XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local XComGameStateHistory			History;
	local XComGameState_ObjectivesList	ObjectiveList;
	local XComGameState_BattleData		BattleData;
	local int i;

	//	Denmother is rescued, mark objective in the list as green
	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_ObjectivesList', ObjectiveList)
	{
		break;
	}

	ObjectiveList = XComGameState_ObjectivesList(NewGameState.ModifyStateObject(class'XComGameState_ObjectivesList', ObjectiveList != none ? ObjectiveList.ObjectID : -1));
	for (i = 0; i < ObjectiveList.ObjectiveDisplayInfos.Length; i++)
	{
		if (ObjectiveList.ObjectiveDisplayInfos[i].ObjectiveTemplateName == 'IRI_Rescue_Denmother_Objective')
		{
			ObjectiveList.ObjectiveDisplayInfos[i].ShowCompleted = true;
			break;
		}
	}

	//	Will let Denmother walk off Skyranger and actually transition from tactical to strategy
	AddUnitToSquad(UnitState, NewGameState);

	// This will display Denmother on the mission end screen
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.ModifyStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
	BattleData.RewardUnits.AddItem(UnitState.GetReference());
}

static function XComGameState_Objective GetDenmotherObjective()
{
	local XComGameStateHistory		History;
	local XComGameState_Objective	ObjectiveState;

	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_Objective', ObjectiveState)
	{
		if (ObjectiveState.GetMyTemplateName() == 'IRI_Rescue_Denmother_Objective')
		{
			return ObjectiveState;
		}
	}
	return none;
}

static function AddUnitToSquad(XComGameState_Unit UnitState, XComGameState NewGameState)
{	
	local XComGameState_HeadquartersXCom XComHQ;

	foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}
	if (XComHQ == none)
	{
		XComHQ = `XCOMHQ;
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	}
	XComHQ.Squad.AddItem(UnitState.GetReference());
}

static function bool WereCiviliansRescued(const XComGameState_BattleData BattleData)
{
	local int idx;

	for(idx = 0; idx < BattleData.MapData.ActiveMission.MissionObjectives.Length; idx++)
	{
		if (BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'Rescue_T1')
		{
			return BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted;
		}
	}
	return false;
}
static function bool IsSweepObjectiveComplete(const XComGameState_BattleData BattleData)
{
	local int idx;

	for(idx = 0; idx < BattleData.MapData.ActiveMission.MissionObjectives.Length; idx++)
	{
		`LOG("IsSweepObjectiveComplete:" @ BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName @ BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted,, 'IRITEST');
		if (BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'Sweep')
		{
			return BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted;
		}
	}
	return false;
}
/*
[0110.21] IRITEST: Found objective: 0 name: Sweep
[0110.21] IRITEST: Found objective: 1 name: Rescue_T1
[0110.21] IRITEST: Found objective: 2 name: Rescue_T2
[0110.21] IRITEST: Found objective: 3 name: Rescue_T3
*/

static function bool WasDenmotherRescued(const XComGameState_BattleData BattleData)
{
	local XComGameState_Unit UnitState;

	UnitState = GetDenmotherTacticalUnitState();

	//	 TODO: Check if the sweep objective was completed if she's still alive even if XCOM loses?
	
	return UnitState != none && UnitState.IsAlive();
}

static function EquipMarksmanCarbine(XComGameState_Unit UnitState, XComGameState NewGameState)
{
}

static function XComGameState_Item CreateMarksmanCarbine(XComGameState NewGameState)
{
}

static function GiveOneGoodEyeAbility(XComGameState_Unit UnitState)
{	
	local SoldierClassAbilityType AbilityStruct;

	AbilityStruct.AbilityName = 'IRI_OneGoodEye_Passive';
	UnitState.AbilityTree[0].Abilities.AddItem(AbilityStruct);
}

	/*
	var array<SoldierRankAbilities> AbilityTree; // All Soldier Classes now build and store their ability tree upon rank up to Squaddie (could be at creation time)

	struct native SoldierRankAbilities
	{
		var array<SoldierClassAbilityType> Abilities;
	};
	struct native SoldierClassAbilityType
	{
		var name AbilityName;
		var EInventorySlot ApplyToWeaponSlot;
		var name UtilityCat;
	};*/

static function XComGameState_Unit GetDenmotherTacticalUnitState()
{	
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if (UnitState.TacticalTag == 'IRI_DenmotherReward_Tag')
		{
			`LOG("GetDenmotherTacticalUnitState: Found Denmother Unit State, she's alive:" @ UnitState.IsAlive(),, 'IRITEST');
			return UnitState;
		}
	}
	`LOG("GetDenmotherTacticalUnitState: did not find Denmother Unit State",, 'IRITEST');
	return none;
}

static function XComGameState_Unit GetDenmotherCrewUnitState()
{	
	local XComGameStateHistory				History;
	local XComGameState_Unit				UnitState;
	local XComGameState_HeadquartersXCom	XComHQ;
	local StateObjectReference				UnitRef;
	local UnitValue							UV;

	History = `XCOMHISTORY;
	XComHQ = `XCOMHQ;

	foreach XComHQ.Crew(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (UnitState != none && UnitState.GetUnitValue('IRI_ThisUnitIsDenmother_Value', UV))
		{
			`LOG("GetDenmotherCrewUnitState: found Denmother Unit State in Avenger Crew",, 'IRITEST');
			return UnitState;
		}
	}	

	`LOG("GetDenmotherCrewUnitState: did not find Denmother Unit State in Avenger Crew",, 'IRITEST');
	return none;
}

static function SetUpDenmother(XComGameState_Unit UnitState, optional bool bAsSoldier)
{
	UnitState.kAppearance.nmPawn = 'XCom_Soldier_F';
	UnitState.kAppearance.iGender = eGender_Female; //2;
	UnitState.kAppearance.iRace = 0; 
	UnitState.kAppearance.iSkinColor = 0;
	UnitState.kAppearance.iEyeColor = 3;	//	blue
	UnitState.kAppearance.iHairColor = 7; // blonde
	UnitState.kAppearance.iAttitude = 4;	//	happy go lucky
	UnitState.kAppearance.nmBeard = '';
	UnitState.kAppearance.nmArms_Underlay = 'CnvUnderlay_Std_Arms_A_M';
	UnitState.kAppearance.nmLeftArmDeco = '';
	UnitState.kAppearance.nmRightArmDeco = '';
	UnitState.kAppearance.nmTorsoDeco = '';
	UnitState.kAppearance.nmEye = 'DefaultEyes';
	UnitState.kAppearance.nmFacePropUpper = 'Earring_F';
	UnitState.kAppearance.nmFacePropLower = '';
	UnitState.kAppearance.nmPatterns = 'Pat_Nothing';
	UnitState.kAppearance.nmHelmet = '';
	UnitState.kAppearance.nmLeftForearm = '';
	UnitState.kAppearance.nmRightForearm = '';
	UnitState.kAppearance.nmThighs = '';
	UnitState.kAppearance.nmShins = '';
	UnitState.kAppearance.nmTattoo_LeftArm = 'Tattoo_Arms_BLANK';
	UnitState.kAppearance.nmTattoo_RightArm = 'Tattoo_Arms_BLANK';
	UnitState.kAppearance.nmTeeth = 'DefaultTeeth';
	UnitState.kAppearance.iWeaponTint = 5;
	UnitState.kAppearance.nmWeaponPattern = 'Pat_Nothing';
	UnitState.kAppearance.nmVoice = 'FemaleVoice10_English_US';

	UnitState.kAppearance.nmArms = 'CnvMed_Std_E_F';
	UnitState.kAppearance.nmLeftArm = '';
	UnitState.kAppearance.nmRightArm = '';
	UnitState.kAppearance.nmTorso = 'CnvMed_Std_A_F';	//	Torso 0 (just xcom kevlar)
	UnitState.kAppearance.nmTorso_Underlay = 'CnvUnderlay_Std_A_F';
	UnitState.kAppearance.nmLegs = 'CnvMed_Std_D_F';	//	xcom kevlar pants
	UnitState.kAppearance.nmLegs_Underlay = 'CnvUnderlay_Std_A_F';
	UnitState.kAppearance.nmHaircut = 'FemHair_M'; // Bob haircut
	UnitState.kAppearance.nmHead = 'CaucFem_E';

	UnitState.SetCountry('Country_USA');
	if (bAsSoldier)
	{
		UnitState.SetCharacterName(default.strDenmotherFirstName, default.strDenmotherLastName, default.strDenmotherNickName);
		UnitState.SetUnitFloatValue('IRI_ThisUnitIsDenmother_Value', 1, eCleanup_Never);

		//	TODO: add scars here
	}
	else
	{
		UnitState.SetCharacterName("", default.strDenmotherNickName, "");
	}
	

	UnitState.kAppearance.iArmorTint = 69;	//	white
	UnitState.kAppearance.iArmorTintSecondary = 49;	//	blue-grey		
}


static function SetGroupAndPlayer(XComGameState_Unit UnitState, ETeam SetTeam, XComGameState NewGameState)
{
	local XComGameStateHistory			History;
	local XComGameState_Player			PlayerState;
	local XComGameState_AIGroup			Group, PreviousGroupState;

	History = `XCOMHISTORY;

	// assign the new unit to the human team -LEB
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if(PlayerState.GetTeam() == SetTeam)
		{
			`LOG("Assigned player" @ SetTeam,, 'IRITEST');
			UnitState.SetControllingPlayer(PlayerState.GetReference());
			break;
		}
	}
	//	set AI Group for the new unit so it can be controlled by the player properly
	foreach History.IterateByClassType(class'XComGameState_AIGroup', Group)
	{
		if (Group.TeamName == SetTeam)
		{
			`LOG("Found group",, 'IRITEST');
			break;
		}
	}

	if( UnitState != none && Group != none )
	{
		PreviousGroupState = UnitState.GetGroupMembership(NewGameState);

		if( PreviousGroupState != none ) PreviousGroupState.RemoveUnitFromGroup(UnitState.ObjectID, NewGameState);

		`LOG("Assigned group" @ SetTeam,, 'IRITEST');
		Group = XComGameState_AIGroup(NewGameState.ModifyStateObject(class'XComGameState_AIGroup', Group.ObjectID));
		Group.AddUnitToGroup(UnitState.ObjectID, NewGameState);
	}
}