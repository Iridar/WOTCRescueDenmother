class X2DownloadableContentInfo_WOTCRescueDenmother extends X2DownloadableContentInfo;

/*
Ammo Belt as secondary weapon. Confers Resupply Ammo ability that reloads the weapon of a nearby soldier. Can pass on special Ammo effects? Requires perk? Ability is turn ending by default?
Can be used at range by default? Longer range for bondmates.
Use magazine model of the target soldier. Will have to use grenade trajectory repurposes for a single target ability.
Use regular "give" animation at melee range, and grenade underhand animation at other times.


Polish camera movement, right it now has three (!) camera pans.

Changelog:
Keeper Training unlock in Guerilla Tactics School will now cost 150 supplies on Legendary difficulty, more in line with other GTS unlocks.
Denmother will now correctly work on new-style Haven Assaults. 
First Aid ability from the eponymous mod will now work on Denmother during Haven defense.
Added "GiveDenmother" command that will add Denmother to your crew, regardless of your campaign status.

Tests:


*/

//	TODO: better denmother positioning in mission
//	Check how many civilians need to be rescued to get the "good" story: minimal amount.

static event OnPostMission()
{
	local XComGameState				NewGameState;
	local XComGameState_Objective	ObjectiveState;

	if (!class'Denmother'.static.IsMissionFirstRetaliation('OnPostMission'))
		return;

	`LOG("On Post Mission", class'Denmother'.default.bLog, 'IRIDENMOTHER');

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Remove Denmother Objective");

	//	Hide the objective so it doesn't appear on the Geoscape anymore
	ObjectiveState = class'Denmother'.static.GetDenmotherObjectiveState();
	if (ObjectiveState != none)
	{
		`LOG("On Post Mission: Hiding denmother objective. Current status:" @ ObjectiveState.ObjState, class'Denmother'.default.bLog, 'IRIDENMOTHER');
		ObjectiveState.CompleteObjective(NewGameState);
		NewGameState.RemoveStateObject(ObjectiveState.ObjectID);
	}
	class'Denmother'.static.HideDenmotherObjective(NewGameState);

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}
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

exec function GiveDenmother()
{
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;
	local XComGameState_HeadquartersXCom	XComHQ;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Give Denmother");

	UnitState = class'Denmother'.static.CreateDenmotherUnit(NewGameState, true);

	class'Denmother'.static.GiveOneGoodEyeAbility(UnitState, NewGameState);

	UnitState.SetCharacterName(class'Denmother'.default.strDenmotherFirstName, class'Denmother'.default.strDenmotherLastName, class'Denmother'.default.strDenmotherNickName);

	UnitState.kAppearance = class'Denmother'.default.AvengerAppearance;
	if (class'Denmother'.static.DLCLoaded('DLC_2'))
	{
		UnitState.kAppearance.nmScars = class'Denmother'.default.AlienHuntersScar;
	}
	else
	{
		UnitState.kAppearance.nmScars = class'Denmother'.default.VanillaScar;
	}
	UnitState.StoreAppearance(); 

	UnitState.SetBackground(class'Denmother'.default.strDenmother_Background_Good);
	
	class'Denmother'.static.AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem_Good', NewGameState);

	XComHQ = class'Denmother'.static.GetAndPrepXComHQ(NewGameState);
	XComHQ.AddToCrew(NewGameState, UnitState);

	`GAMERULES.SubmitGameState(NewGameState);
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

static event InstallNewCampaign(XComGameState StartState)
{
	if (class'Denmother'.default.NoDenmotherCosmeticsOnRandomlyGeneratedSoldiers)
	{
		RemoveCosmeticsFromThisModFromRandomGeneration();
	}
}

//	Removes the possibility of randomly generated soldiers having cosmetic parts from this mod, hopefully.
static function RemoveCosmeticsFromThisModFromRandomGeneration()
{
	local XComOnlineProfileSettings		ProfileSettings;
	local int Index;

	ProfileSettings = `XPROFILESETTINGS;
	for(Index = 0; Index < ProfileSettings.Data.PartPackPresets.Length; ++Index)
	{
		if(ProfileSettings.Data.PartPackPresets[Index].PartPackName == name(default.DLCIdentifier))
		{
			ProfileSettings.Data.PartPackPresets[Index].ChanceToSelect = 0;
		}
	}
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