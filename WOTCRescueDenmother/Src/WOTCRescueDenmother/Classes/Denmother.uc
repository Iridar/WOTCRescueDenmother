class Denmother extends Object config (ClassData);

var localized string strDenmotherFirstName;
var localized string strDenmotherLastName;
var localized string strDenmotherNickName;

var localized string strDenmotherGoodBackground;
var localized string strDenmotherBadBackground;

var config name DenmotherSoldierClass;
var config int	DenmotherStartingRank;

static function bool IsMissionFirstRetaliation(name LogName)
{
	local XComGameState_MissionCalendar		CalendarState;
	local XComGameStateHistory				History;
	local XComGameState_MissionSite			MissionState;
	local XComGameState_BattleData			BattleData;

	`LOG("IsMissionFirstRetaliation check by:" @ LogName,, 'IRITEST');

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleData == none)
	{
		`LOG("IsMissionFirstRetaliation WARNING, no Battle Data",, 'IRITEST');
		return false;
	}

	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));
	if (MissionState == none)
	{
		`LOG("IsMissionFirstRetaliation WARNING, no Mission State",, 'IRITEST');
		return false;
	}
	//`LOG("Mission name:" @ MissionState.Source,, 'IRITEST');

	if (MissionState.Source == 'MissionSource_Retaliation')
	{
		//`LOG("Mission name check passed, this is retaliation",, 'IRITEST');

		CalendarState = XComGameState_MissionCalendar(History.GetSingleGameStateObjectForClass(class'XComGameState_MissionCalendar'));
		if (CalendarState == none)
		{
			`LOG("IsMissionFirstRetaliation WARNING, no Calendar State",, 'IRITEST');
			return false;
		}
		//	I.e. return "true" if calendar DID NOT create multiple retaliation missions yet
		if (!CalendarState.HasCreatedMultipleMissionsOfSource('MissionSource_Retaliation'))
		{
			`LOG("IsMissionFirstRetaliation check succeeds, this is first retaliation.",, 'IRITEST');
			return true;
		}
		`LOG("IsMissionFirstRetaliation check succeeds, this retaliation is not first.",, 'IRITEST');
		return false;
		
	}

	`LOG("IsMissionFirstRetaliation check fail, different mission source.",, 'IRITEST');
	return false;
}

//	Updates the objective list in the upper left corner during tactical mission
static function FailDenmotherObjective(XComGameState NewGameState)
{
	local XComGameStateHistory			History;
	local XComGameState_ObjectivesList	ObjectiveList;
	local int i;

	foreach NewGameState.IterateByClassType(class'XComGameState_ObjectivesList', ObjectiveList)
	{
		break;
	}
	if (ObjectiveList == none)
	{
		History = `XCOMHISTORY;
		foreach History.IterateByClassType(class'XComGameState_ObjectivesList', ObjectiveList)
		{
			break;
		}
		ObjectiveList = XComGameState_ObjectivesList(NewGameState.ModifyStateObject(class'XComGameState_ObjectivesList', ObjectiveList != none ? ObjectiveList.ObjectID : -1));
	}

	//	Denmother is dead, mark objective as red
	for (i = 0; i < ObjectiveList.ObjectiveDisplayInfos.Length; i++)
	{
		if (ObjectiveList.ObjectiveDisplayInfos[i].ObjectiveTemplateName == 'IRI_Rescue_Denmother_Objective')
		{
			ObjectiveList.ObjectiveDisplayInfos[i].ShowFailed = true;
			break;
		}
	}

	AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_1', NewGameState);
}

static function SucceedDenmotherObjective(XComGameState NewGameState)
{
	local XComGameStateHistory			History;
	local XComGameState_ObjectivesList	ObjectiveList;
	local int i;

	foreach NewGameState.IterateByClassType(class'XComGameState_ObjectivesList', ObjectiveList)
	{
		break;
	}
	if (ObjectiveList == none)
	{
		History = `XCOMHISTORY;
		foreach History.IterateByClassType(class'XComGameState_ObjectivesList', ObjectiveList)
		{
			break;
		}
		ObjectiveList = XComGameState_ObjectivesList(NewGameState.ModifyStateObject(class'XComGameState_ObjectivesList', ObjectiveList != none ? ObjectiveList.ObjectID : -1));
	}

	//	Denmother is rescued, mark objective in the list as green
	for (i = 0; i < ObjectiveList.ObjectiveDisplayInfos.Length; i++)
	{
		if (ObjectiveList.ObjectiveDisplayInfos[i].ObjectiveTemplateName == 'IRI_Rescue_Denmother_Objective')
		{
			ObjectiveList.ObjectiveDisplayInfos[i].ShowCompleted = true;
			break;
		}
	}
}

static function HideDenmotherObjective(XComGameState NewGameState)
{
	local XComGameStateHistory			History;
	local XComGameState_ObjectivesList	ObjectiveList;
	local int i;

	foreach NewGameState.IterateByClassType(class'XComGameState_ObjectivesList', ObjectiveList)
	{
		break;
	}
	if (ObjectiveList == none)
	{
		History = `XCOMHISTORY;
		foreach History.IterateByClassType(class'XComGameState_ObjectivesList', ObjectiveList)
		{
			break;
		}
		ObjectiveList = XComGameState_ObjectivesList(NewGameState.ModifyStateObject(class'XComGameState_ObjectivesList', ObjectiveList != none ? ObjectiveList.ObjectID : -1));
	}

	for (i = 0; i < ObjectiveList.ObjectiveDisplayInfos.Length; i++)
	{
		if (ObjectiveList.ObjectiveDisplayInfos[i].ObjectiveTemplateName == 'IRI_Rescue_Denmother_Objective')
		{
			ObjectiveList.ObjectiveDisplayInfos.Remove(i, 1);
			break;
		}
	}
}

static function AddItemToHQInventory(name TemplateName, XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local X2ItemTemplate					ItemTemplate;
	local XComGameState_Item				ItemState;
	local X2ItemTemplateManager				ItemTemplateMgr;

	ItemTemplateMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}
	if (XComHQ == none)
	{
		XComHQ = `XCOMHQ;
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	}

	ItemTemplate = ItemTemplateMgr.FindItemTemplate(TemplateName);
	if (ItemTemplate != none)
	{
		ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
		if (XComHQ.PutItemInInventory(NewGameState, ItemState))
		{
			`LOG("Adding" @ TemplateName @ "to HQ ivnentory",, 'IRITEST');
		}
	}
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

static function AddUnitToSquadAndCrew(XComGameState_Unit UnitState, XComGameState NewGameState)
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
	XComHQ.AddToCrew(NewGameState, UnitState);

	//	This will help find the Denmother unit in avenger crew
	UnitState.SetUnitFloatValue('IRI_ThisUnitIsDenmother_Value', 1, eCleanup_BeginTactical);
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
static function bool IsSweepObjectiveComplete()
{
	local XComGameState_BattleData BattleData;
	local int idx;

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	if (BattleData != none)
	{
		for(idx = 0; idx < BattleData.MapData.ActiveMission.MissionObjectives.Length; idx++)
		{
			`LOG("IsSweepObjectiveComplete:" @ BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName @ BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted,, 'IRITEST');
			if (BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'Sweep')
			{
				return BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted;
			}
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

static function GiveOneGoodEyeAbility(XComGameState_Unit UnitState, XComGameState NewGameState)
{	
	local SoldierClassAbilityType AbilityStruct;

	AbilityStruct.AbilityName = 'IRI_OneGoodEye_Passive';
	UnitState.AbilityTree[0].Abilities.AddItem(AbilityStruct);

	UnitState.BuySoldierProgressionAbility(NewGameState, 0, 2);
}

static function FinalizeDenmotherUnitForCrew()
{
	local XComGameState_Unit	UnitState;
	local XComGameState			NewGameState;

	UnitState = GetDenmotherCrewUnitState();
	if (UnitState != none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Finalizing Denmother Unit");

		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
		UnitState.ClearUnitValue('IRI_ThisUnitIsDenmother_Value');

		class'Denmother'.static.GiveOneGoodEyeAbility(UnitState, NewGameState);

		UnitState.SetCharacterName(class'Denmother'.default.strDenmotherFirstName, class'Denmother'.default.strDenmotherLastName, class'Denmother'.default.strDenmotherNickName);
		UnitState.kAppearance.nmFacePropUpper = 'Eyepatch_F';
		UnitState.StoreAppearance(); 

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		`HQPRES.UINewStaffAvailable(UnitState.GetReference());
	}
}

static function XComGameState_Unit GetDenmotherTacticalUnitState()
{	
	local XComGameStateHistory		History;
	local XComGameState_Unit		UnitState;
	local XComGameState_Objective	ObjectiveState;
	
	ObjectiveState = GetDenmotherObjective();
	if (ObjectiveState != none)
	{
		History = `XCOMHISTORY;
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ObjectiveState.MainObjective.ObjectID));

		if (UnitState != none)
		{
			`LOG("GetDenmotherTacticalUnitState: Found Denmother Tactical Unit State, she's alive:" @ UnitState.IsAlive(),, 'IRITEST');
			return UnitState;
		}
		`LOG("GetDenmotherTacticalUnitState: did not find Denmother Unit State",, 'IRITEST');
		return none;
	}
	`LOG("GetDenmotherTacticalUnitState: did not find Denmother Objective State",, 'IRITEST');	
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

//	====================================================================
//			CREATE DENMOTHER UNIT STATE AND CUSTOMIZE APPEARANCE
//	====================================================================
//	bAsSoldier = true when generating her as a soldier reward you get for completing the mission.
//	= false when generating a unit state that will be bleeding out on the mission itself.
static function XComGameState_Unit CreateDenmotherUnit(XComGameState NewGameState, optional bool bAsSoldier)
{
	local XComGameState_Unit NewUnitState;
	local int idx, StartingIdx;

	NewUnitState = CreateSoldier(NewGameState);
	NewUnitState.RandomizeStats();

	SetDenmotherAppearance(NewUnitState, bAsSoldier);

	NewUnitState.SetXPForRank(default.DenmotherStartingRank);
	NewUnitState.StartingRank = default.DenmotherStartingRank;
	StartingIdx = 0;

	for (idx = StartingIdx; idx < default.DenmotherStartingRank; idx++)
	{
		// Rank up to squaddie
		if (idx == 0)
		{
			NewUnitState.RankUpSoldier(NewGameState, default.DenmotherSoldierClass);
			NewUnitState.ApplyInventoryLoadout(NewGameState, 'DenmotherLoadout');
			NewUnitState.bNeedsNewClassPopup = false;
		}
		else
		{
			NewUnitState.RankUpSoldier(NewGameState, default.DenmotherSoldierClass);
		}
	}
	return NewUnitState;
}

static private function XComGameState_Unit CreateSoldier(XComGameState NewGameState)
{
	local X2CharacterTemplateManager	CharTemplateMgr;	
	local X2CharacterTemplate			CharacterTemplate;
	local XGCharacterGenerator			CharacterGenerator;
	local TSoldier						CharacterGeneratorResult;
	local XComGameState_Unit			SoldierState;
	
	CharTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	CharacterTemplate = CharTemplateMgr.FindCharacterTemplate('Soldier');
	SoldierState = CharacterTemplate.CreateInstanceFromTemplate(NewGameState);
	
	//	Probably not gonna end up using any part of the generated appearance, but let's go through the motions just in case
	CharacterGenerator = `XCOMGRI.Spawn(CharacterTemplate.CharacterGeneratorClass);
	CharacterGeneratorResult = CharacterGenerator.CreateTSoldier('Soldier');
	SoldierState.SetTAppearance(CharacterGeneratorResult.kAppearance);

	return SoldierState;
}

static private function SetDenmotherAppearance(XComGameState_Unit UnitState, optional bool bAsSoldier)
{
	UnitState.kAppearance.nmPawn = 'XCom_Soldier_F';
	UnitState.kAppearance.iGender = eGender_Female; //2;
	UnitState.kAppearance.iRace = 0; 
	UnitState.kAppearance.iSkinColor = 0;
	UnitState.kAppearance.iEyeColor = 21;	//	black
	UnitState.kAppearance.iHairColor = 0; // dark brown
	UnitState.kAppearance.iAttitude = 2;	//	normal
	UnitState.kAppearance.nmBeard = '';
	UnitState.kAppearance.nmArms_Underlay = 'CnvUnderlay_Std_Arms_A_M';
	UnitState.kAppearance.nmLeftArmDeco = '';
	UnitState.kAppearance.nmRightArmDeco = '';
	UnitState.kAppearance.nmEye = 'DefaultEyes';
	UnitState.kAppearance.nmFacePropUpper = '';
	UnitState.kAppearance.nmFacePropLower = '';
	UnitState.kAppearance.nmPatterns = 'Pat_Nothing';
	UnitState.kAppearance.nmLeftForearm = '';
	UnitState.kAppearance.nmRightForearm = '';
	UnitState.kAppearance.nmThighs = '';
	UnitState.kAppearance.nmShins = '';
	UnitState.kAppearance.nmTattoo_LeftArm = 'Tattoo_Arms_BLANK';
	UnitState.kAppearance.nmTattoo_RightArm = 'Tattoo_Arms_BLANK';
	UnitState.kAppearance.nmTeeth = 'DefaultTeeth';
	UnitState.kAppearance.iWeaponTint = 5;
	UnitState.kAppearance.nmWeaponPattern = 'Pat_Nothing';
	UnitState.kAppearance.nmVoice = 'FemaleVoice1_English_US';

	UnitState.kAppearance.nmHelmet = 'WOTCRescueDenmother_Helmets_F';	//	custom hat
	UnitState.kAppearance.nmArms = 'WOTCRescueDenmother_Arms_KV_F';	//	custom arms
	UnitState.kAppearance.nmLeftArm = '';
	UnitState.kAppearance.nmRightArm = '';
	UnitState.kAppearance.nmTorso = 'WOTCRescueDenmother_TorsoWithGear_KV_F';	//	custom torso
	UnitState.kAppearance.nmTorsoDeco = 'WOTCRescueDenmother_TorsoDeco_Backpack_KV_F';	//	custom torso deco
	UnitState.kAppearance.nmTorso_Underlay = 'CnvUnderlay_Std_A_F';
	UnitState.kAppearance.nmLegs = 'WOTCRescueDenmother_Legs_KV_F';	//	custom legs
	UnitState.kAppearance.nmLegs_Underlay = 'CnvUnderlay_Std_A_F';
	UnitState.kAppearance.nmHaircut = 'FemHair_M'; // Bob haircut
	UnitState.kAppearance.nmHead = 'CaucFem_A';

	if (DLCLoaded('DLC_2'))
	{
		UnitState.kAppearance.nmScars = 'DLC_60_Scar_D';
	}
	else
	{
		UnitState.kAppearance.nmScars = 'Scars_01_Burn';
	}

	UnitState.SetCountry('Country_Argentina');
	if (bAsSoldier)
	{
		UnitState.SetCharacterName(default.strDenmotherFirstName, default.strDenmotherLastName, default.strDenmotherNickName);
		UnitState.kAppearance.nmFacePropUpper = 'Eyepatch_F';
	}
	else
	{
		//	"Blood McBloodyface is still bleeding out" popups don't mention unit's nickname, so using it as last name so the soldier understand who the hell the popup is talking about
		UnitState.SetCharacterName("", default.strDenmotherNickName, "");
	}
	
	UnitState.kAppearance.iArmorTint = 0;	//	drab green
	UnitState.kAppearance.iArmorTintSecondary = 29;	//	dark drab green

	UnitState.StoreAppearance(); 
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

static private function bool DLCLoaded(name DLCName)
{
	local XComOnlineEventMgr	EventManager;
	local int					Index;

	EventManager = `ONLINEEVENTMGR;

	for(Index = EventManager.GetNumDLC() - 1; Index >= 0; Index--)	
	{
		if(EventManager.GetDLCNames(Index) == DLCName)	
		{
			return true;
		}
	}
	return false;
}