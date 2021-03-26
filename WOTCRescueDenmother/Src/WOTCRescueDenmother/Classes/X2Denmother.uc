class X2Denmother extends Object config (DenmotherConfig);


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

var config bool bAccelerateDenmotherHealing;
var config float bHealthMultiplier;

var config bool NoDenmotherCosmeticsOnRandomlyGeneratedSoldiers;

//	====================================================================
//			INTERFACE FUNCTIONS FOR THE OBJECTIVE SYSTEM
//	====================================================================

static final function bool IsMissionFirstRetaliation(name LogName)
{
	local XComGameState_MissionCalendar		CalendarState;
	local XComGameStateHistory				History;
	local XComGameState_MissionSite			MissionState;
	local XComGameState_BattleData			BattleData;

	`LOG("IsMissionFirstRetaliation check by:" @ LogName, class'X2Denmother'.default.bLog, 'IRIDENMOTHER');

	if (LWOTC_IsCurrentMissionIsRetaliation() && !LWOTC_IsFirstDenmotherSpawn())
	{
		`LOG("LWOTC_IsCurrentMissionIsRetaliation check succeeds.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
		return true;
	}

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleData == none)
	{
		`LOG("IsMissionFirstRetaliation WARNING, no Battle Data, check fails.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
	}

	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));
	if (MissionState == none)
	{
		`LOG("IsMissionFirstRetaliation WARNING, no Mission State, check fails.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
	}

	if (MissionState.Source == 'MissionSource_Retaliation')
	{
		CalendarState = XComGameState_MissionCalendar(History.GetSingleGameStateObjectForClass(class'XComGameState_MissionCalendar'));
		if (CalendarState == none)
		{
			`LOG("IsMissionFirstRetaliation WARNING, no Calendar State, check fails.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			return false;
		}
		//	I.e. return "true" if calendar DID NOT create multiple retaliation missions yet
		if (!CalendarState.HasCreatedMultipleMissionsOfSource('MissionSource_Retaliation'))
		{
			`LOG("IsMissionFirstRetaliation check succeeds, this is first retaliation.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			return true;
		}
		`LOG("IsMissionFirstRetaliation check fails, this retaliation is not first.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
		return false;
		
	}

	`LOG("IsMissionFirstRetaliation check fails, different mission source:" @ MissionState.Source, class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
	return false;
}

static final function bool LWOTC_IsCurrentMissionIsRetaliation()
{
    local String MissionType;

    MissionType = LWOTC_GetCurrentMissionType();
    return MissionType == "Terror_LW" || MissionType == "Invasion_LW" || MissionType=="Defend_LW";
}

static private function bool LWOTC_IsFirstDenmotherSpawn()
{
	local XComGameState_HeadquartersXCom XComHQ;

	XComHQ = `XCOMHQ;

	return !XComHQ.HasItemByName('IRI_Denmother_ObjectiveDummyItem');
}

static function string LWOTC_GetCurrentMissionType()
{
    local XComGameStateHistory History;
    local XComGameState_BattleData BattleData;
    local GeneratedMissionData GeneratedMission;
    local XComGameState_HeadquartersXCom XComHQ;

    History = `XCOMHISTORY;
    XComHQ = `XCOMHQ;

    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
    GeneratedMission = XComHQ.GetGeneratedMissionData(BattleData.m_iMissionID);
    if (GeneratedMission.Mission.sType == "")
    {
        // No mission type set. This is probably a tactical quicklaunch.
        return `TACTICALMISSIONMGR.arrMissions[BattleData.m_iMissionType].sType;
    }

    return GeneratedMission.Mission.sType;
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
			`LOG("GetDenmotherTacticalUnitState: Found Denmother Tactical Unit State, she's alive:" @ UnitState.IsAlive(), class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			return UnitState;
		}
		`LOG("GetDenmotherTacticalUnitState: did not find Denmother Unit State", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
		return none;
	}
	`LOG("GetDenmotherTacticalUnitState: did not find Denmother Objective State", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');	
	return none;
}

static function XComGameState_Unit GetDenmotherHistoryUnitState()
{	
	local XComGameStateHistory				History;
	local XComGameState_Unit				UnitState;
	local UnitValue							UV;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if (UnitState.GetUnitValue('IRI_ThisUnitIsDenmother_Value', UV))
		{
			`LOG("GetDenmotherHistoryUnitState: found Denmother Unit State.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			return UnitState;
		}
	}
	`LOG("GetDenmotherHistoryUnitState: did not find Denmother Unit State.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
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

	for (idx = 0; idx < BattleData.MapData.ActiveMission.MissionObjectives.Length; idx++)
	{
		// Old style and new style haven assaults respectively.
		if (BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'Rescue_T1' || BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'SaveCivilians')
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
			`LOG("IsSweepObjectiveComplete:" @ BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName @ BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted, class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			if (BattleData.MapData.ActiveMission.MissionObjectives[idx].ObjectiveName == 'Sweep')
			{
				return BattleData.MapData.ActiveMission.MissionObjectives[idx].bCompleted;
			}
		}
	}
	return false;
}

static function GiveOneGoodEyeAbility(XComGameState_Unit UnitState, XComGameState NewGameState)
{	
	local SoldierClassAbilityType AbilityStruct;
	local int Index;

	AbilityStruct.AbilityName = 'IRI_OneGoodEye_Passive';
	UnitState.AbilityTree[0].Abilities.AddItem(AbilityStruct);

	Index = UnitState.AbilityTree[0].Abilities.Length - 1;

	UnitState.BuySoldierProgressionAbility(NewGameState, 0, Index);
}

static function FinalizeDenmotherUnitForCrew()
{
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;
	local XComGameState_BattleData			BattleData;	
	local XComGameState_HeadquartersXCom	XComHQ;

	UnitState = GetDenmotherHistoryUnitState();
	if (UnitState != none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Finalizing Denmother Unit");

		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));

		UnitState.ClearUnitValue('IRI_ThisUnitIsDenmother_Value');	
		UnitState.ClearUnitValue('IRI_Denmother_Evacuated_Value');				

		GiveOneGoodEyeAbility(UnitState, NewGameState);

		UnitState.SetCharacterName(class'X2Denmother'.default.strDenmotherFirstName, class'X2Denmother'.default.strDenmotherLastName, class'X2Denmother'.default.strDenmotherNickName);

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
			`LOG("FinalizeDenmotherUnitForCrew: Denmother is dead, setting dead backstory.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			UnitState.SetBackground(class'X2Denmother'.default.strDenmother_Background_Dead);
			//	This will unlock "Denmother died" dossier.
			AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_Dead', NewGameState);
		}
		else if (class'X2Denmother'.static.WereCiviliansRescued(BattleData))
		{
			`LOG("FinalizeDenmotherUnitForCrew: Civilians were rescued, setting good backstory.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			UnitState.SetBackground(class'X2Denmother'.default.strDenmother_Background_Good);
			AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_Good', NewGameState);
			
		}
		else
		{	
			`LOG("FinalizeDenmotherUnitForCrew: Civilians were NOT rescued, setting bad backstory.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			UnitState.SetBackground(class'X2Denmother'.default.strDenmother_Background_Bad);
			AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_Bad', NewGameState);
		}

		if (UnitState.IsAlive())
		{
			XComHQ = class'X2Denmother'.static.GetAndPrepXComHQ(NewGameState);
			XComHQ.AddToCrew(NewGameState, UnitState);
		}
		//else // Unnecessary, handled by the game automatically by moving dead units from squad. 
		//{
		//	XComHQ.DeadCrew.AddItem(UnitState.GetReference());
		//}		

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		// Show pop-up after submitting the gamestate so that Denmother's name and appearance have a chance to update for the portrait.
		if (UnitState.IsAlive())
		{
			`HQPRES.UINewStaffAvailable(UnitState.GetReference());
		}
	}
}

//	====================================================================
//			CREATE DENMOTHER UNIT STATE AND CUSTOMIZE APPEARANCE
//	====================================================================

static function XComGameState_Unit CreateDenmotherUnit(XComGameState NewGameState, optional bool bDebug = false)
{
	local XComGameState_Unit				NewUnitState;
	local XComGameState_Analytics			Analytics;
	local int								idx, StartingIdx;

	NewUnitState = CreateSoldier(NewGameState);
	NewUnitState.RandomizeStats();

	if (!bDebug)
	{
		//	Cleaned up manually in FinalizeDenmother
		NewUnitState.SetUnitFloatValue('IRI_ThisUnitIsDenmother_Value', 1, eCleanup_Never);
	}

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
		`LOG("Adding analytics values to generated unit", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
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

	//	set AI Group for the new unit so it can be controlled by the player properly
	foreach History.IterateByClassType(class'XComGameState_AIGroup', Group)
	{
		if (Group.TeamName == SetTeam)
		{
			PreviousGroupState = UnitState.GetGroupMembership(NewGameState);
			if (PreviousGroupState != none) 
			{
				`LOG("Removing Denmother from group:" @ PreviousGroupState.TeamName, class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
				PreviousGroupState.RemoveUnitFromGroup(UnitState.ObjectID, NewGameState);
			}

			`LOG("Assigned group to Denmother:" @ Group.TeamName, class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			Group = XComGameState_AIGroup(NewGameState.ModifyStateObject(class'XComGameState_AIGroup', Group.ObjectID));
			Group.AddUnitToGroup(UnitState.ObjectID, NewGameState);
			break;
		}
	}

	// assign the new unit to the human team -LEB
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if (PlayerState.GetTeam() == SetTeam)
		{
			`LOG("Assigned player to Denmother:" @ PlayerState.GetTeam(), class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
			UnitState.SetControllingPlayer(PlayerState.GetReference());
			break;
		}
	}
}

static function bool DLCLoaded(name DLCName)
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
			`LOG("Added" @ TemplateName @ "to HQ ivnentory.", class'X2Denmother'.default.bLog, 'IRIDENMOTHER');
		}
	}
}