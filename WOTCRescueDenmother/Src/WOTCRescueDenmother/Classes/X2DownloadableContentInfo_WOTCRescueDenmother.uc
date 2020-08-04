class X2DownloadableContentInfo_WOTCRescueDenmother extends X2DownloadableContentInfo;

//	TODO: better denmother positioning in mission
//	TODO: make her cosmetics not appear for randomly generated soldiers
//	todo: recover denmother's weapon if she's killed on the mission, but the mission is success
//		same, but if she's killed, and XCOM evacuates her body
//	One Good Eye ability - test it
//	none checks and log warnings

// GTS unlock allows to train other soldiers like that in GTS? IRIDenmotherUI.GTS_KeeperTraining


static event OnPostMission()
{
	local XComGameState_BattleData	BattleData;
	local XComGameStateHistory		History;
	local XComGameState				NewGameState;
	local XComGameState_Objective	ObjectiveState;
	local XComGameState_Unit		UnitState;

	`LOG("On Post Mission",, 'IRITEST');

	if (!class'Denmother'.static.IsMissionFirstRetaliation('OnPostMission'))
		return;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Generate Denmother Reward");

	//	Hide the objective so it doesn't appear on the Geoscape anymore
	ObjectiveState = class'Denmother'.static.GetDenmotherObjective();
	if (ObjectiveState != none)
	{
		`LOG("On Post Mission: Hiding denmother objective. Current status:" @ ObjectiveState.ObjState,, 'IRITEST');
		ObjectiveState.CompleteObjective(NewGameState);
		NewGameState.RemoveStateObject(ObjectiveState.ObjectID);
	}
	class'Denmother'.static.HideDenmotherObjective(NewGameState);

	UnitState = class'Denmother'.static.GetDenmotherCrewUnitState();
	if (UnitState != none && UnitState.IsAlive())
	{
		`LOG("On Post Mission: found Denmother in avenger crew.",, 'IRITEST');

		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
		if (class'Denmother'.static.WereCiviliansRescued(BattleData))
		{
			`LOG("On Post Mission: Civilians were rescued, setting good backstory",, 'IRITEST');
			UnitState.SetBackground(class'Denmother'.default.strDenmotherGoodBackground);

			//	This will unlock a resistance archive entry
			class'Denmother'.static.AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_3', NewGameState);
		}
		else
		{	
			`LOG("On Post Mission: Civilians were NOT rescued, setting bad backstory",, 'IRITEST');
			UnitState.SetBackground(class'Denmother'.default.strDenmotherBadBackground);

			class'Denmother'.static.AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_2', NewGameState);
		}
	}
	else `LOG("On Post Mission: no denmother in avenger crew.",, 'IRITEST');

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
	//}
	//else
	//{
	//	`LOG("Objective is complete or doesn't exist, doing nothing",, 'IRITEST');
	//}
}

/// <summary>
/// Called after the player exits the post-mission sequence while this DLC / Mod is installed.
/// </summary>
static event OnExitPostMissionSequence()
{
	if (class'Denmother'.static.IsMissionFirstRetaliation('OnExitPostMissionSequence'))
	{
		class'Denmother'.static.FinalizeDenmotherUnitForCrew();
	}
}



static function OnPostTemplatesCreated()
{
	local X2ItemTemplateManager ItemTemplateManager;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	AddCritUpgrade(ItemTemplateManager, 'CritUpgrade_Bsc');
	AddCritUpgrade(ItemTemplateManager, 'CritUpgrade_Adv');
	AddCritUpgrade(ItemTemplateManager, 'CritUpgrade_Sup');

	AddAimBonusUpgrade(ItemTemplateManager, 'AimUpgrade_Bsc');
	AddAimBonusUpgrade(ItemTemplateManager, 'AimUpgrade_Adv');
	AddAimBonusUpgrade(ItemTemplateManager, 'AimUpgrade_Sup');

	AddClipSizeBonusUpgrade(ItemTemplateManager, 'ClipSizeUpgrade_Bsc');
	AddClipSizeBonusUpgrade(ItemTemplateManager, 'ClipSizeUpgrade_Adv');
	AddClipSizeBonusUpgrade(ItemTemplateManager, 'ClipSizeUpgrade_Sup');

	AddFreeFireBonusUpgrade(ItemTemplateManager, 'FreeFireUpgrade_Bsc');
	AddFreeFireBonusUpgrade(ItemTemplateManager, 'FreeFireUpgrade_Adv');
	AddFreeFireBonusUpgrade(ItemTemplateManager, 'FreeFireUpgrade_Sup');

	AddReloadUpgrade(ItemTemplateManager, 'ReloadUpgrade_Bsc');
	AddReloadUpgrade(ItemTemplateManager, 'ReloadUpgrade_Adv');
	AddReloadUpgrade(ItemTemplateManager, 'ReloadUpgrade_Sup');

	AddMissDamageUpgrade(ItemTemplateManager, 'MissDamageUpgrade_Bsc');
	AddMissDamageUpgrade(ItemTemplateManager, 'MissDamageUpgrade_Adv');
	AddMissDamageUpgrade(ItemTemplateManager, 'MissDamageUpgrade_Sup');

	AddFreeKillUpgrade(ItemTemplateManager, 'FreeKillUpgrade_Bsc');
	AddFreeKillUpgrade(ItemTemplateManager, 'FreeKillUpgrade_Adv');
	AddFreeKillUpgrade(ItemTemplateManager, 'FreeKillUpgrade_Sup');
}


//	LASER SIGHT
static function AddCritUpgrade(X2ItemTemplateManager ItemTemplateManager, Name TemplateName)
{
	local X2WeaponUpgradeTemplate Template;

	Template = X2WeaponUpgradeTemplate(ItemTemplateManager.FindItemTemplate(TemplateName));

	Template.AddUpgradeAttachment('SOCKET_LaserSightHIGH', 'UIPawnLocation_WeaponUpgrade_AssaultRifle_Optic', "IRIDenmotherRifle.Meshes.SM_LaserSight", "", 'IRI_DenmotherRifle', , "", "img:///IRIDenmotherRifle.UI.Inv_DenmotherRifle_LaserSight", "img:///UILibrary_StrategyImages.X2InventoryIcons.Inv_weaponIcon_scope");
	Template.AddUpgradeAttachment('Laser', 'UIPawnLocation_WeaponUpgrade_AssaultRifle_Optic', "IRIDenmotherRifle.Meshes.SM_Laser", "", 'IRI_DenmotherRifle', , "", "", "");
}

//	SCOPE
static function AddAimBonusUpgrade(X2ItemTemplateManager ItemTemplateManager, Name TemplateName)
{
	local X2WeaponUpgradeTemplate Template;

	Template = X2WeaponUpgradeTemplate(ItemTemplateManager.FindItemTemplate(TemplateName));

	Template.AddUpgradeAttachment('SOCKET_ScopeHIGH', 'UIPawnLocation_WeaponUpgrade_AssaultRifle_Optic', "IRIDenmotherRifle.Meshes.SM_Scope", "", 'IRI_DenmotherRifle', , "", "img:///IRIDenmotherRifle.UI.Inv_DenmotherRifle_Scope", "img:///UILibrary_StrategyImages.X2InventoryIcons.Inv_weaponIcon_scope");	
}


//	HAIR TRIGGER
static function AddFreeFireBonusUpgrade(X2ItemTemplateManager ItemTemplateManager, Name TemplateName)
{
	local X2WeaponUpgradeTemplate Template;

	Template = X2WeaponUpgradeTemplate(ItemTemplateManager.FindItemTemplate(TemplateName));

	Template.AddUpgradeAttachment('Trigger', 'UIPawnLocation_WeaponUpgrade_AssaultRifle_Mag', "ConvAttachments.Meshes.SM_ConvTriggerB", "", 'IRI_DenmotherRifle', , "", "img:///IRIDenmotherRifle.UI.Inv_DenmotherRifle_Trigger", "img:///UILibrary_StrategyImages.X2InventoryIcons.Inv_weaponIcon_trigger");
}

//	EX MAG
static function AddClipSizeBonusUpgrade(X2ItemTemplateManager ItemTemplateManager, Name TemplateName)
{
	local X2WeaponUpgradeTemplate Template;

	Template = X2WeaponUpgradeTemplate(ItemTemplateManager.FindItemTemplate(TemplateName));

	Template.AddUpgradeAttachment('SOCKET_AmmoFeederHIGH', 'UIPawnLocation_WeaponUpgrade_Shotgun_Mag', "IRIDenmotherRifle.Meshes.SM_AmmoFeeder", "", 'IRI_DenmotherRifle', , "", "img:///IRIDenmotherRifle.UI.Inv_DenmotherRifle_Magazine", "img:///UILibrary_StrategyImages.X2InventoryIcons.Inv_weaponIcon_clip", class'X2Item_DefaultUpgrades'.static.NoReloadUpgradePresent);	
}

//	AUTO LOADER
static function AddReloadUpgrade(X2ItemTemplateManager ItemTemplateManager, Name TemplateName)
{
	local X2WeaponUpgradeTemplate Template;

	Template = X2WeaponUpgradeTemplate(ItemTemplateManager.FindItemTemplate(TemplateName));

	Template.AddUpgradeAttachment('SOCKET_AmmoFeederHIGH', 'UIPawnLocation_WeaponUpgrade_AssaultRifle_Mag', "IRIDenmotherRifle.Meshes.SM_AmmoFeeder", "", 'IRI_DenmotherRifle', , "", "img:///IRIDenmotherRifle.UI.Inv_DenmotherRifle_Magazine", "img:///UILibrary_StrategyImages.X2InventoryIcons.Inv_weaponIcon_clip");
}

//	STOCK
static function AddMissDamageUpgrade(X2ItemTemplateManager ItemTemplateManager, Name TemplateName)
{
	local X2WeaponUpgradeTemplate Template;

	Template = X2WeaponUpgradeTemplate(ItemTemplateManager.FindItemTemplate(TemplateName));
	
	Template.AddUpgradeAttachment('', 'UIPawnLocation_WeaponUpgrade_AssaultRifle_Stock', "", "", 'IRI_DenmotherRifle', , "", "img:///IRIDenmotherRifle.UI.Inv_DenmotherRifle_Stock", "img:///UILibrary_StrategyImages.X2InventoryIcons.Inv_weaponIcon_stock");
}

//	SUPPRESSOR
static function AddFreeKillUpgrade(X2ItemTemplateManager ItemTemplateManager, Name TemplateName)
{
	local X2WeaponUpgradeTemplate Template;

	Template = X2WeaponUpgradeTemplate(ItemTemplateManager.FindItemTemplate(TemplateName));

	Template.AddUpgradeAttachment('SOCKET_SuppressorHIGH', 'UIPawnLocation_WeaponUpgrade_AssaultRifle_Suppressor', "IRIDenmotherRifle.Meshes.SM_Suppressor", "", 'IRI_DenmotherRifle', , "", "img:///IRIDenmotherRifle.UI.Inv_DenmotherRifle_Suppressor", "img:///UILibrary_StrategyImages.X2InventoryIcons.Inv_weaponIcon_barrel");	
}


static function bool AbilityTagExpandHandler(string InString, out string OutString)
{
	local name TagText;
	
	TagText = name(InString);
	switch (TagText)
	{
	case 'IRI_ONE_GOOD_EYE_AIM':
		OutString = SetColor(class'X2Effect_OneGoodEye'.default.BonusAimPerShot);
		return true;
	case 'IRI_ONE_GOOD_EYE_CRIT':
		OutString = SetColor(class'X2Effect_OneGoodEye'.default.BonusCritPerShot);
		return true;
	case 'IRI_ONE_GOOD_EYE_STACKS':
		OutString = SetColor(class'X2Effect_OneGoodEye'.default.MaxStacks);
		return true;
	//	===================================================
	default:
            return false;
    }  
}

static function string SetColor(coerce string Value)
{	
	return "<font color='#918400'>" $ Value $ "</font>";
}