class X2EventListener_Denmother extends X2EventListener;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_TacticalListenerTemplate());
	Templates.AddItem(Create_StrategyListenerTemplate());
	Templates.AddItem(CreateOnGetLocalizedCategoryListenerTemplate());

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
	local X2StrategyElementTemplateManager	StratMgr;
	local X2ObjectiveTemplate				NewObjectiveTemplate;
	local XComGameState_Objective			NewObjectiveState;

	local XComGameState_Unit				UnitState;
	local vector							Position;

	`LOG("Post Aliens Spawned ListenerEventFunction triggered", class'Denmother'.default.bLog, 'IRIDENMOTHER');
	//	=================================================================
	//	INITIAL CHECKS -> Make sure this is the first retaliation in the campaign, exit otherwise.

	if (class'Denmother'.static.IsMissionFirstRetaliation('PostAliensSpawned'))
	{
		//	=================================================================
		//	CREATE AND DEPLOY DENMOTHER 

		`LOG("This is First retaliation, creating soldier.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

		//	Generate unit
		UnitState = class'Denmother'.static.CreateDenmotherUnit(NewGameState);

		`LOG("Old position:" @ `XWORLD.GetPositionFromTileCoordinates(UnitState.TileLocation), class'Denmother'.default.bLog, 'IRIDENMOTHER');
		Position = GetDenmotherSpawnPosition();
		`LOG("New position:" @ Position, class'Denmother'.default.bLog, 'IRIDENMOTHER');

		// Denmother starts concealed with 0 tile detection radius to prevent enemies from reacting to her.
		UnitState.SetIndividualConcealment(true, NewGameState);

		//	Teleport the unit
		UnitState.SetVisibilityLocationFromVector(Position);
		UnitState.bRequiresVisibilityUpdate = true;

		AddStrategyUnitToBoard(UnitState, NewGameState);

		//	=================================================================
		//	CREATE AND INJECT TRACKING OBJECTIVE
		StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

		NewObjectiveTemplate = X2ObjectiveTemplate(StratMgr.FindStrategyElementTemplate('IRI_Rescue_Denmother_Objective'));
		NewObjectiveState = NewObjectiveTemplate.CreateInstanceFromTemplate(NewGameState);
		NewObjectiveState.StartObjective(NewGameState, true);

		//	Hack, store the reference to Denmother's tactical unit state in the objective
		NewObjectiveState.MainObjective = UnitState.GetReference();
	}
	return ELR_NoInterrupt;
}

static private function vector GetDenmotherSpawnPosition()
{
	local vector				Position;
	local int					i;
	local XComGameState_Unit	UnitState;
	local XComWorldData			World;
	local XComGameStateHistory	History;
	local TTile					Tile;

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

	`LOG("Found this many civilians in the Game State:" @ i - 1, class'Denmother'.default.bLog, 'IRIDENMOTHER');
	Position /= i;
	
	`LOG("Average civvies :" @ Position, class'Denmother'.default.bLog, 'IRIDENMOTHER');
	//	At this point in time, Position will hold coordinates of a center point between all civvies

	Position = World.FindClosestValidLocation(Position,/*bool bAllowFlying*/ false,/*bool bPrioritizeZLevel*/ false,/*bool bAvoidNoSpawnZones=false*/true); 
	
	`LOG("Valid spawn posi:" @ Position, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	World.GetFloorTileForPosition(Position, Tile);
	Position = World.GetPositionFromTileCoordinates(Tile);

	`LOG("Floor tile posit:" @ Position, class'Denmother'.default.bLog, 'IRIDENMOTHER');

	return Position;

	//	Doesn't appear to do anything
	//Position = World.GetValidSpawnLocation(Position);

	//Tile = World.GetTileCoordinatesFromPosition(Position);
	

	//return World.GetPositionFromTileCoordinates(Tile);
}

static private function TTile SeekValidFloorPosition(const TTile Tile)
{
}

static private function AddStrategyUnitToBoard(XComGameState_Unit Unit, XComGameState NewGameState)
{
	local StateObjectReference			ItemReference;
	local XComGameState_Item			ItemState;
	local X2AbilityTemplate				AbilityTemplate;
    local X2AbilityTemplateManager		AbilityTemplateManager;	

	class'Denmother'.static.SetGroupAndPlayer(Unit, eTeam_XCom, NewGameState);

	// add item states. This needs to be done so that the visualizer sync picks up the IDs and creates their visualizers -LEB
	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ItemReference.ObjectID));
		ItemState.BeginTacticalPlay(NewGameState);   // this needs to be called explicitly since we're adding an existing state directly into tactical
		NewGameState.AddStateObject(ItemState);

		// add any cosmetic items that might exists
		ItemState.CreateCosmeticItemUnit(NewGameState);
	}

	//	I assume this triggers the unit's abilities that activate at "UnitPostBeginPlay"
	Unit.BeginTacticalPlay(NewGameState); 

	//	Just this once, give Denmother autoactivating self-target ability that will knock her out and apply bleedout
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate('IRI_KnockoutAndBleedoutSelf');
	class'X2TacticalGameRuleset'.static.InitAbilityForUnit(AbilityTemplate, Unit, NewGameState);
}

static function CHEventListenerTemplate Create_StrategyListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_Denmother_Strategy');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('ValidateGTSClassTraining', ELR_GTS, ELD_Immediate);
	if (class'Denmother'.default.bAccelerateDenmotherHealing)
	{
		Template.AddCHEvent('PostMissionUpdateSoldierHealing', ListenerEventFunction_Healing, ELD_OnStateSubmitted);
	}

	return Template;
}

static function EventListenerReturn ListenerEventFunction_Healing(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState									NewGameState;
	local XComGameState_Unit							UnitState;
	local XComGameState_HeadquartersProjectHealSoldier	HealingProject;
	local XComGameState_DenmotherHealingProject			NewHealingProject;
	local UnitValue										UV;
	local XComGameStateHistory							History;
	local XComGameState_HeadquartersXCom				XComHQ;

	UnitState = XComGameState_Unit(EventSource);

	if (UnitState.GetUnitValue('IRI_ThisUnitIsDenmother_Value', UV) && UnitState.IsAlive() && class'Denmother'.static.IsMissionFirstRetaliation('PostMissionUpdateSoldierHealing'))
	{
		`LOG("PostMissionUpdateSoldierHealing ListenerEventFunction triggered for Denmother.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

		History = `XCOMHISTORY;
		foreach History.IterateByClassType(class'XComGameState_HeadquartersProjectHealSoldier', HealingProject)
		{
			if (HealingProject.ProjectFocus == UnitState.GetReference())
			{
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Replacing Denmother Healing Project");

				`LOG("Replacing Denmother Healing Project.", class'Denmother'.default.bLog, 'IRIDENMOTHER');

				XComHQ = class'Denmother'.static.GetAndPrepXComHQ(NewGameState);

				XComHQ.Projects.RemoveItem(HealingProject.GetReference());
				NewGameState.RemoveStateObject(HealingProject.ObjectID);

				NewHealingProject = XComGameState_DenmotherHealingProject(NewGameState.CreateNewStateObject(class'XComGameState_DenmotherHealingProject'));
				NewHealingProject.SetProjectFocus(UnitState.GetReference());
				XComHQ.Projects.AddItem(NewHealingProject.GetReference());

				`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
				return ELR_NoInterrupt;
			}
		}
	}
	
	return ELR_NoInterrupt;
}



static function EventListenerReturn ELR_GTS(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComLWTuple				OverrideTuple;
	local X2SoldierClassTemplate	SoldierClassTemplate;

	OverrideTuple = XComLWTuple(EventData);

	if (OverrideTuple != none)
	{
		SoldierClassTemplate = X2SoldierClassTemplate(OverrideTuple.Data[1].o);
		if (SoldierClassTemplate != none && SoldierClassTemplate.DataName == 'Keeper')
		{
			`LOG("Running GTS check for Keeper class" @ OverrideTuple.Data[0].b, class'Denmother'.default.bLog, 'IRIDENMOTHER');
			if (IsSoldierUnlockTemplatePurchased('IRI_Keeper_GTS_Unlock'))
			{
				OverrideTuple.Data[0].b = true;
			}
		}
	}
	return ELR_NoInterrupt;
}

static private function bool IsSoldierUnlockTemplatePurchased(const name SoldierUnlockTemplateName)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local name TemplateName;

	XComHQ = `XCOMHQ;

	foreach XComHQ.SoldierUnlockTemplates(TemplateName)
	{
		if (TemplateName == SoldierUnlockTemplateName)
		{
			return true;
		}
	}
	return false;
}


static function CHEventListenerTemplate CreateOnGetLocalizedCategoryListenerTemplate()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_RocketsGetLocalizedCategory');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('GetLocalizedCategory', OnGetLocalizedCategory, ELD_Immediate);
	return Template;
}

static function EventListenerReturn OnGetLocalizedCategory(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
    local XComLWTuple		Tuple;
    local X2WeaponTemplate	Template;
	local X2ItemTemplate	SupplyPackItemTemplate;

    Template = X2WeaponTemplate(EventSource);

    if (Template.WeaponCat == 'IRI_SupplyPack')
    {	
		SupplyPackItemTemplate = class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindItemTemplate('IRI_Keeper_SupplyPack');
		if (SupplyPackItemTemplate != none)
		{
			Tuple = XComLWTuple(EventData);
			Tuple.Data[0].s = SupplyPackItemTemplate.FriendlyName;
		}
    }
    return ELR_NoInterrupt;
}