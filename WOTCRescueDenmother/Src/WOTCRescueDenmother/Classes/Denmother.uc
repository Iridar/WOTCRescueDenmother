class Denmother extends Object config (Denmother);

var localized string strDenmotherFirstName;
var localized string strDenmotherLastName;
var localized string strDenmotherNickName;

var localized string strDenmother_Background_Good;
var localized string strDenmother_Background_Bad;
var localized string strDenmother_Background_Dead;

var config name DenmotherSoldierClass;
var config int	DenmotherStartingRank;
var config bool bLog;

var config TAppearance MissionAppearance;
var config TAppearance AvengerAppearance;
var config name AlienHuntersScar;
var config name VanillaScar;
var config name Country;
var config int DenmotherRecoveryDays;

var config bool NoDenmotherCosmeticsOnRandomlyGeneratedSoldiers;

//	====================================================================
//			INTERFACE FUNCTIONS FOR THE OBJECTIVE SYSTEM
//	====================================================================

static function bool IsMissionFirstRetaliation(name LogName)
{
	local XComGameState_MissionCalendar		CalendarState;
	local XComGameStateHistory				History;
	local XComGameState_MissionSite			MissionState;
	local XComGameState_BattleData			BattleData;

	`LOG("IsMissionFirstRetaliation check by:" @ LogName, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleData == none)
	{
		`LOG("IsMissionFirstRetaliation WARNING, no Battle Data, check fails.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
	}

	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));
	if (MissionState == none)
	{
		`LOG("IsMissionFirstRetaliation WARNING, no Mission State, check fails.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
	}

	if (MissionState.Source == 'MissionSource_Retaliation')
	{
		CalendarState = XComGameState_MissionCalendar(History.GetSingleGameStateObjectForClass(class'XComGameState_MissionCalendar'));
		if (CalendarState == none)
		{
			`LOG("IsMissionFirstRetaliation WARNING, no Calendar State, check fails.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			return false;
		}
		//	I.e. return "true" if calendar DID NOT create multiple retaliation missions yet
		if (!CalendarState.HasCreatedMultipleMissionsOfSource('MissionSource_Retaliation'))
		{
			`LOG("IsMissionFirstRetaliation check succeeds, this is first retaliation.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			return true;
		}
		`LOG("IsMissionFirstRetaliation check fails, this retaliation is not first.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
		
	}

	`LOG("IsMissionFirstRetaliation check fails, different mission source:" @ MissionState.Source, class'Denmother'.default.bLog, 'IRIDENMOTHER');
	return false;
}


//	Firaxis likes to separate the unit state on mission with the unit state you get as a reward.
//	That system has 9000 lines of incomprehensible noodle code, so I set up a simpler system.
//	The Denmother unit spawned on the tactical mission is *the* unit you get as a "reward" if you save her.
//	I have my own "grant reward" kind of code in place.
//	The GetDenmotherTacticalUnitState and GetDenmotherCrewUnitState both technically look for the same Unit State, but they do it via different methods.

static function XComGameState_Unit GetDenmotherTacticalUnitState()
{	
	local XComGameStateHistory		History;
	local XComGameState_Unit		UnitState;
	local XComGameState_Objective	ObjectiveState;
	
	ObjectiveState = GetDenmotherObjectiveState();
	if (ObjectiveState != none)
	{
		History = `XCOMHISTORY;
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ObjectiveState.MainObjective.ObjectID));

		if (UnitState != none)
		{
			`LOG("GetDenmotherTacticalUnitState: Found Denmother Tactical Unit State, she's alive:" @ UnitState.IsAlive(), class'Denmother'.default.bLog, 'IRIDENMOTHER');
			return UnitState;
		}
		`LOG("GetDenmotherTacticalUnitState: did not find Denmother Unit State", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		return none;
	}
	`LOG("GetDenmotherTacticalUnitState: did not find Denmother Objective State", class'Denmother'.default.bLog, 'IRIDENMOTHER');	
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
			`LOG("GetDenmotherCrewUnitState: found Denmother Unit State in Avenger Crew.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			return UnitState;
		}
	}	

	foreach XComHQ.DeadCrew(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (UnitState != none && UnitState.GetUnitValue('IRI_ThisUnitIsDenmother_Value', UV))
		{
			`LOG("GetDenmotherCrewUnitState: found Denmother Unit State in Dead Crew.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			return UnitState;
		}
	}

	`LOG("GetDenmotherCrewUnitState: did not find Denmother Unit State in Avenger Crew.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	return none;
}

static function XComGameState_Objective GetDenmotherObjectiveState()
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

//	Updates the objective list in the upper left corner during tactical mission.
//	I don't fully understand how it works, so I treat it as a cosmetic change.
static function FailDenmotherObjective(XComGameState NewGameState)
{
	local XComGameState_ObjectivesList	ObjectiveList;
	local int i;

	ObjectiveList = GetAndPrepObjectivesList(NewGameState);

	//	Denmother is dead, mark objective as red
	for (i = 0; i < ObjectiveList.ObjectiveDisplayInfos.Length; i++)
	{
		if (ObjectiveList.ObjectiveDisplayInfos[i].ObjectiveTemplateName == 'IRI_Rescue_Denmother_Objective')
		{
			ObjectiveList.ObjectiveDisplayInfos[i].ShowFailed = true;
			break;
		}
	}
}

static function SucceedDenmotherObjective(XComGameState NewGameState)
{
	local XComGameState_ObjectivesList	ObjectiveList;
	local int i;

	ObjectiveList = GetAndPrepObjectivesList(NewGameState);

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
	local XComGameState_ObjectivesList	ObjectiveList;
	local int i;

	ObjectiveList = GetAndPrepObjectivesList(NewGameState);

	for (i = 0; i < ObjectiveList.ObjectiveDisplayInfos.Length; i++)
	{
		if (ObjectiveList.ObjectiveDisplayInfos[i].ObjectiveTemplateName == 'IRI_Rescue_Denmother_Objective')
		{
			ObjectiveList.ObjectiveDisplayInfos.Remove(i, 1);
			break;
		}
	}
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
			`LOG("IsSweepObjectiveComplete:" @ BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName @ BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted, class'Denmother'.default.bLog, 'IRIDENMOTHER');
			if (BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'Sweep')
			{
				return BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted;
			}
		}
	}
	return false;
}

static function AddUnitToSquadAndCrew(XComGameState_Unit UnitState, XComGameState NewGameState)
{	
	local XComGameState_HeadquartersXCom	XComHQ;

	XComHQ = GetAndPrepXComHQ(NewGameState);

	XComHQ.Squad.AddItem(UnitState.GetReference());

	//	Need to gate behind Alive check or the unit would end up in Dead Crew twice
	if (UnitState.IsAlive())
	{
		`LOG("Added Denmother to Avenger crew", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		XComHQ.AddToCrew(NewGameState, UnitState);
	}

	//	Unnecessary, handled automatically when transitioning from tactical to strategy by moving dead units from squad to dead crew
	//else
	//{
	//	XComHQ.DeadCrew.AddItem(UnitState.GetReference());
	//}

	//	This will help find the Denmother unit in avenger crew
	UnitState.SetUnitFloatValue('IRI_ThisUnitIsDenmother_Value', 1, eCleanup_BeginTactical);
}

static function CreateDenmotherHealingProject(XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom				XComHQ;
	local XComGameState_HeadquartersProjectHealSoldier	HealingProject;

	if (UnitState != none && UnitState.IsAlive())
	{
		`LOG("Creating a healing project for Denmother", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		XComHQ = class'Denmother'.static.GetAndPrepXComHQ(NewGameState);
		HealingProject = XComGameState_HeadquartersProjectHealSoldier(NewGameState.CreateNewStateObject(class'XComGameState_HeadquartersProjectHealSoldier'));
		HealingProject.SetProjectFocus(UnitState.GetReference(), NewGameState);
		HealingProject.BlockPointsRemaining = 0;
		HealingProject.ProjectPointsRemaining = 0;
		HealingProject.AddRecoveryDays(default.DenmotherRecoveryDays);
		XComHQ.Projects.AddItem(HealingProject.GetReference());
	}
}

static private function GiveOneGoodEyeAbility(XComGameState_Unit UnitState, XComGameState NewGameState)
{	
	local SoldierClassAbilityType AbilityStruct;

	AbilityStruct.AbilityName = 'IRI_OneGoodEye_Passive';
	UnitState.AbilityTree[0].Abilities.AddItem(AbilityStruct);

	UnitState.BuySoldierProgressionAbility(NewGameState, 0, 2);
}

static function FinalizeDenmotherUnitForCrew()
{
	local XComGameState_Unit		UnitState;
	local XComGameState				NewGameState;
	local XComGameState_BattleData	BattleData;	

	UnitState = GetDenmotherCrewUnitState();
	if (UnitState != none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Finalizing Denmother Unit");

		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));

		UnitState.ClearUnitValue('IRI_ThisUnitIsDenmother_Value');		

		GiveOneGoodEyeAbility(UnitState, NewGameState);

		UnitState.SetCharacterName(class'Denmother'.default.strDenmotherFirstName, class'Denmother'.default.strDenmotherLastName, class'Denmother'.default.strDenmotherNickName);

		UnitState.kAppearance = default.AvengerAppearance;
		if (DLCLoaded('DLC_2'))
		{
			UnitState.kAppearance.nmScars = default.AlienHuntersScar;
		}
		else
		{
			UnitState.kAppearance.nmScars = default.VanillaScar;
		}
		UnitState.StoreAppearance(); 

		BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		if (UnitState.IsDead())
		{
			`LOG("FinalizeDenmotherUnitForCrew: Denmother is dead, setting dead backstory.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			UnitState.SetBackground(class'Denmother'.default.strDenmother_Background_Dead);
			//	This will unlock "Denmother died" dossier.
			AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_Dead', NewGameState);
		}
		else if (class'Denmother'.static.WereCiviliansRescued(BattleData))
		{
			`LOG("FinalizeDenmotherUnitForCrew: Civilians were rescued, setting good backstory.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			UnitState.SetBackground(class'Denmother'.default.strDenmother_Background_Good);
			AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_Good', NewGameState);
			
		}
		else
		{	
			`LOG("FinalizeDenmotherUnitForCrew: Civilians were NOT rescued, setting bad backstory.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			UnitState.SetBackground(class'Denmother'.default.strDenmother_Background_Bad);
			AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_Bad', NewGameState);
		}

		CreateDenmotherHealingProject(UnitState, NewGameState);

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		`HQPRES.UINewStaffAvailable(UnitState.GetReference());
	}
}

//	====================================================================
//			CREATE DENMOTHER UNIT STATE AND CUSTOMIZE APPEARANCE
//	====================================================================
//	bAsSoldier = true when generating her as a soldier reward you get for completing the mission.
//	= false when generating a unit state that will be bleeding out on the mission itself.
static function XComGameState_Unit CreateDenmotherUnit(XComGameState NewGameState)
{
	local XComGameState_Unit		NewUnitState;
	local XComGameState_Analytics	Analytics;
	local int						idx, StartingIdx;

	NewUnitState = CreateSoldier(NewGameState);
	NewUnitState.RandomizeStats();

	SetDenmotherAppearance(NewUnitState);

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
		
	//	This should put the Denmother's recruit date at the start of the campaign, if I understand correctly.
	class'X2StrategyGameRulesetDataStructures'.static.SetTime(NewUnitState.m_RecruitDate, 0, 0, 0, 
		class'X2StrategyGameRulesetDataStructures'.default.START_MONTH, 
		class'X2StrategyGameRulesetDataStructures'.default.START_DAY, 
		class'X2StrategyGameRulesetDataStructures'.default.START_YEAR );

	NewUnitState.iNumMissions = 0;
	foreach NewGameState.IterateByClassType( class'XComGameState_Analytics', Analytics )
	{
		break;
	}
	if (Analytics == none)
	{
		Analytics = XComGameState_Analytics(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_Analytics'));
		if (Analytics != none)
		{
			Analytics = XComGameState_Analytics(NewGameState.ModifyStateObject(class'XComGameState_Analytics', Analytics.ObjectID));
		}
	}
	if (Analytics != none)
	{
		`LOG("Adding analytics values to generated unit", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		Analytics.AddValue( "ACC_UNIT_SERVICE_LENGTH", 0, NewUnitState.GetReference( ) );
		Analytics.AddValue( "ACC_UNIT_HEALING", 0, NewUnitState.GetReference( ) );
		Analytics.AddValue( "ACC_UNIT_SUCCESSFUL_ATTACKS", 0, NewUnitState.GetReference( ) );
		Analytics.AddValue( "ACC_UNIT_DEALT_DAMAGE", 0, NewUnitState.GetReference( ) );
		Analytics.AddValue( "ACC_UNIT_ABILITIES_RECIEVED", 0, NewUnitState.GetReference( ) );
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

static private function SetDenmotherAppearance(XComGameState_Unit UnitState)
{
	UnitState.kAppearance = default.MissionAppearance;

	UnitState.SetCountry(default.Country);
	UnitState.SetCharacterName("", default.strDenmotherNickName, "");
	if (DLCLoaded('DLC_2'))
	{
		UnitState.kAppearance.nmScars = default.AlienHuntersScar;
	}
	else
	{
		UnitState.kAppearance.nmScars = default.VanillaScar;
	}
	
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
			`LOG("Assigned player" @ SetTeam, class'Denmother'.default.bLog, 'IRIDENMOTHER');
			UnitState.SetControllingPlayer(PlayerState.GetReference());
			break;
		}
	}
	//	set AI Group for the new unit so it can be controlled by the player properly
	foreach History.IterateByClassType(class'XComGameState_AIGroup', Group)
	{
		if (Group.TeamName == SetTeam)
		{
			`LOG("Found group", class'Denmother'.default.bLog, 'IRIDENMOTHER');
			break;
		}
	}

	if( UnitState != none && Group != none )
	{
		PreviousGroupState = UnitState.GetGroupMembership(NewGameState);

		if( PreviousGroupState != none ) PreviousGroupState.RemoveUnitFromGroup(UnitState.ObjectID, NewGameState);

		`LOG("Assigned group" @ SetTeam, class'Denmother'.default.bLog, 'IRIDENMOTHER');
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

//	====================================================================
//			HELPER STATE FUNCTIONS
//	====================================================================
static private function XComGameState_ObjectivesList GetAndPrepObjectivesList(XComGameState NewGameState)
{
	local XComGameState_ObjectivesList	ObjectiveList;
	local XComGameStateHistory			History;

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

	return ObjectiveList;
}

static function XComGameState_HeadquartersXCom GetAndPrepXComHQ(XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom	XComHQ;

	foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}
	if (XComHQ == none)
	{
		XComHQ = `XCOMHQ;
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	}

	return XComHQ;
}

static function AddItemToHQInventory(name TemplateName, XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local X2ItemTemplate					ItemTemplate;
	local XComGameState_Item				ItemState;
	local X2ItemTemplateManager				ItemTemplateMgr;

	ItemTemplateMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	XComHQ = GetAndPrepXComHQ(NewGameState);

	ItemTemplate = ItemTemplateMgr.FindItemTemplate(TemplateName);
	if (ItemTemplate != none)
	{
		ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
		if (XComHQ.PutItemInInventory(NewGameState, ItemState))
		{
			`LOG("Added" @ TemplateName @ "to HQ ivnentory.", class'Denmother'.default.bLog, 'IRIDENMOTHER');
		}
	}
}