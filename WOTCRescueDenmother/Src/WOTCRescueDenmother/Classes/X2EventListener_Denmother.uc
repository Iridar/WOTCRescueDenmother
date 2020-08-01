class X2EventListener_Denmother extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_TacticalListenerTemplate());

	return Templates;
}

static function CHEventListenerTemplate Create_TacticalListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_Denmother');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = false;

	Template.AddCHEvent('PostAliensSpawned', ListenerEventFunction_Immediate, ELD_Immediate);

	return Template;
}

static function EventListenerReturn ListenerEventFunction_Immediate(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	//local XComTacticalMissionManager		MissionManager;
	local XComGameState_MissionCalendar		CalendarState;
	local XComGameStateHistory				History;
	local XComGameState_MissionSite			MissionState;
	local XComGameState_BattleData			BattleData;
	local X2CharacterTemplateManager		CharMgr;
    local X2CharacterTemplate				CharTemplate;
	local XComGameState_Unit				UnitState; //, XComUnitState;
	local vector							Position;
	//local XGUnit						Unit;

	`LOG("Post Aliens Spawned ListenerEventFunction triggered",, 'IRITEST');

	History = `XCOMHISTORY;
	//MissionManager = `TACTICALMISSIONMGR;
	//`LOG("Mission name:" @ MissionManager.ActiveMission.MissionName @ MissionManager.ActiveMission.sType @ MissionManager.ActiveMission.MissionFamily,, 'IRITEST');
	//if (MissionManager.ActiveMission.MissionName != 'MissionSource_Retaliation')
	//	return ELR_NoInterrupt;

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));

	`LOG("Mission name:" @ MissionState.Source,, 'IRITEST');

	if (MissionState.Source != 'MissionSource_Retaliation')
		return ELR_NoInterrupt;

	`LOG("Mission name check passed, this is retaliation",, 'IRITEST');

	CalendarState = XComGameState_MissionCalendar(History.GetSingleGameStateObjectForClass(class'XComGameState_MissionCalendar'));
	if (CalendarState.HasCreatedMultipleMissionsOfSource('MissionSource_Retaliation'))
		return ELR_NoInterrupt;

	`LOG("This is First retaliation, creating soldier.",, 'IRITEST');

	//	Generate unit
	CharMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	CharTemplate = CharMgr.FindCharacterTemplate('Soldier');

	UnitState = CharTemplate.CreateInstanceFromTemplate(NewGameState);

	UnitState.SetCurrentStat(eStat_SightRadius, 3);
	//UnitState.SetIndividualConcealment(true, NewGameState);
	//UnitState.bHasSuperConcealment = true;

	class'Denmother'.static.SetUpDenmother(UnitState);
	UnitState.TacticalTag = 'IRI_DenmotherReward_Tag';
	UnitState.ApplyInventoryLoadout(NewGameState);

	`LOG("Old position:" @ `XWORLD.GetPositionFromTileCoordinates(UnitState.TileLocation),, 'IRITEST');
	Position = GetDenmotherSpawnPosition();
	`LOG("New position:" @ Position,, 'IRITEST');

	//	Teleport the unit
	UnitState.SetVisibilityLocationFromVector(Position);
	UnitState.bRequiresVisibilityUpdate = true;

	AddStrategyUnitToBoard(UnitState, NewGameState);

	return ELR_NoInterrupt;
}

static private function vector GetDenmotherSpawnPosition()
{
	local vector				Position;
	local int					i;
	local XComGameState_Unit	UnitState;
	local XComWorldData			World;
	local XComGameStateHistory	History;

	World = `XWORLD;
	History = `XCOMHISTORY;

	i = 1;
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{	
		//	Cycle through all civilans currently present on the mission
		if (UnitState.IsCivilian() && !UnitState.bRemovedFromPlay)
		{
			Position += World.GetPositionFromTileCoordinates(UnitState.TileLocation);
			i++;
		}
	}

	`LOG("Found this many civilians in the Game State:" @ i - 1,, 'IRITEST');
	Position /= i;

	`LOG("Initial position:" @ Position,, 'IRITEST');

	Position = World.GetValidSpawnLocation(Position);

	`LOG("Valid spawn posi:" @ Position,, 'IRITEST');

	return Position;
}

private static function AddStrategyUnitToBoard(XComGameState_Unit Unit, XComGameState NewGameState /*, Vector SpawnLocation*/)
{
	local StateObjectReference			ItemReference;
	local XComGameState_Item			ItemState;
	local X2AbilityTemplate         AbilityTemplate;
    local X2AbilityTemplateManager  AbilityTemplateManager;	

	class'Denmother'.static.SetGroupAndPlayer(Unit, eTeam_Neutral, NewGameState);

	// add item states. This needs to be done so that the visualizer sync picks up the IDs and creates their visualizers -LEB
	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ItemReference.ObjectID));
		ItemState.BeginTacticalPlay(NewGameState);   // this needs to be called explicitly since we're adding an existing state directly into tactical
		NewGameState.AddStateObject(ItemState);

		// add any cosmetic items that might exists
		ItemState.CreateCosmeticItemUnit(NewGameState);
	}

	// add abilities -LEB
	// Must happen after items are added, to do ammo merging properly. -LEB
	//`TACTICALRULES.InitializeUnitAbilities(NewGameState, Unit);

	//	I assume this triggers the unit's abilities that activate at "UnitPostBeginPlay"
	Unit.BeginTacticalPlay(NewGameState); 

	//	Just this once, give Denmother autoactivating self-target ability that will knock her out and apply bleedout
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
    AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate('IRI_KnockoutAndBleedoutSelf');
	class'X2TacticalGameRuleset'.static.InitAbilityForUnit(AbilityTemplate, Unit, NewGameState);
}