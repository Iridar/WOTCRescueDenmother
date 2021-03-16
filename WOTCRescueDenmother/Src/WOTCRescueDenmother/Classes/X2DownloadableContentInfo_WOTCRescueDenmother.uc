class X2DownloadableContentInfo_WOTCRescueDenmother extends X2DownloadableContentInfo;

/*
Denmother can break concealment if enemies stumble upon her?
Denmother spawns standing?


LWOTC tests?

TODO:
PullAlly prefer into cover

Additional abilities: 
- Belt Feed: Resupplying adjacent allies makes their attacks non-turn ending, but only while Keeper remains adjacent. Also grants infinite ammo?
- Resupplying puts on Overwatch?
- Ammo Pocket?
- Give out bandages? Can be used individually by soldiers to heal and stop bleeding. Can be used on others.
- Deploy sandbags / cover?
- Deploy rope / ladder / grapple hook?
- Convert Overwatch actions to regular ones for a single target?
- Repair (heal robotics)?
- Some kind of scavenge ability?

- Supply Run: Using Resupply Ammo grants a Move-only action.
- Logistics Expert: grant abilities to grapple to an ally, and grapple an ally to you, as well as to use grapple to collect loot.
- Zipline: set up a zipline that can be used by all allied units.

Tests:

//	Sweep Objective complete
//		Alive? Add to crew -handled
//		Dead? Add to crew - h

//	Sweep Objective NOT complete
//		Alive (= evacuated)? Add to crew, got the right portrait, bad backstory. -- CHECKED
//		Dead? Not in the crew, not in the morgue, no weapon. -- CHECKED, no backstory
//		Denmother evacced, but rest of the squad is dead? -- expected behavior: you have denmother walk out of skyranger, and she's on the reward screen, bad backstory. -- CHECKED.
//		Denmother is not evacced, and the squad is dead? --expected behavior: no denmother, end screen mentions her as VIP lost -- CHECK, no backstory

Texture2D'UILibrary_PerkIcons.UIPerk_codex_superposition'
Texture2D'UILibrary_PerkIcons.UIPerk_codex_techvulnerability'
Texture2D'UILibrary_PerkIcons.UIPerk_codex_teleport'
Texture2D'UILibrary_PerkIcons.UIPerk_disoriented'
Texture2D'UILibrary_PerkIcons.UIPerk_drop_unit'
Texture2D'UILibrary_PerkIcons.UIPerk_eaglesnest'
Texture2D'UILibrary_XPACK_Common.PerkIcons.UIPerk_exchange'
Texture2D'UILibrary_XPACK_Common.PerkIcons.UIPerk_fullthrottle'

Texture2D'UILibrary_PerkIcons.UIPerk_grapple'
Texture2D'UILibrary_XPACK_Common.PerkIcons.UIPerk_grapple'
Texture2D'UILibrary_PerkIcons.UIPerk_height'

Texture2D'UILibrary_PerkIcons.UIPerk_holotargeting'
Texture2D'UILibrary_XPACK_Common.PerkIcons.UIPerk_mobilityprotocol'

Texture2D'UILibrary_PerkIcons.UIPerk_savior'
Texture2D'UILibrary_XPACK_Common.PerkIcons.UIPerk_parkour'
Texture2D'UILibrary_PerkIcons.UIPerk_item_storagemodule'

Texture2D'UILibrary_XPACK_Common.PerkIcons.UIPerk_juggernaut'

Texture2D'UILibrary_XPACK_Common.PerkIcons.UIPerk_leap'

Lock door
Texture2D'UILibrary_PerkIcons.UIPerk_locked'

Belt Feed:
Texture2D'UILibrary_PerkIcons.UIPerk_maximumordanance'


Texture2D'UILibrary_PerkIcons.UIPerk_sprinter'

Dash icon
Texture2D'UILibrary_PerkIcons.UIPerk_stickandmove'

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
	local XComGameState NewGameState;

	if (class'Denmother'.static.IsMissionFirstRetaliation('OnExitPostMissionSequence'))
	{
		class'Denmother'.static.FinalizeDenmotherUnitForCrew();
	}

	if (class'Denmother'.static.LWOTC_IsCurrentMissionIsRetaliation())
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Denmother: Marking First Retalliation Complete.");
		class'Denmother'.static.AddItemToHQInventory('IRI_Denmother_ObjectiveDummyItem', NewGameState);
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
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
	class'Denmother'.static.AddItemToHQInventory('IRI_Keeper_SupplyPack', NewGameState);	

	XComHQ = class'Denmother'.static.GetAndPrepXComHQ(NewGameState);
	XComHQ.AddToCrew(NewGameState, UnitState);

	`GAMERULES.SubmitGameState(NewGameState);
}

static function OnPostTemplatesCreated()
{
	local X2ItemTemplateManager ItemTemplateManager;

	PatchCharacterTemplates();

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

static private function PatchCharacterTemplates()
{
    local X2CharacterTemplateManager    CharMgr;
    local X2CharacterTemplate           CharTemplate;
	local array<X2DataTemplate>			DifficultyVariants;
	local X2DataTemplate				DifficultyVariant;
	local X2DataTemplate				DataTemplate;
	local XComContentManager			Content;
	
    CharMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	Content = `CONTENT;

	//	Cycle through all "humanoid" character templates
	foreach CharMgr.IterateTemplates(DataTemplate, none)
	{
		CharMgr.FindDataTemplateAllDifficulties(DataTemplate.DataName, DifficultyVariants);
		foreach DifficultyVariants(DifficultyVariant)
		{
			CharTemplate = X2CharacterTemplate(DifficultyVariant);

			if (CharTemplate != none && CharTemplate.bIsSoldier && CharTemplate.UnitHeight == 2 && CharTemplate.UnitSize == 1)
			{
				//	Add AnimSet with catching spare magazines thrown by Resupply Ammo ability.
				CharTemplate.AdditionalAnimSets.AddItem(AnimSet(Content.RequestGameArchetype("IRIKeeperBackpack.Anims.AS_CatchSupplies")));
			}
		}
	}
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
	case 'PullAllyCooldown':
		OutString = SetColor(class'X2Ability_Denmother'.default.PullAllyCooldown);
		return true;
	case 'ResupplyAmmoCooldown':
		OutString = SetColor(class'X2Ability_Denmother'.default.ResupplyAmmoCooldown);
		return true;
	case 'BandageThrowCooldown':
		OutString = SetColor(class'X2Ability_Denmother'.default.BandageThrowCooldown);
		return true;
	case 'BandageThrowCharges':
		OutString = SetColor(class'X2Ability_Denmother'.default.BandageThrowCharges);
		return true;
	case 'BandageThrowHeal':
		OutString = SetColor(class'X2Ability_Denmother'.default.BandageThrowHeal);
		return true;
	case 'BandageThrowDuration':
		OutString = SetColor(class'X2Ability_Denmother'.default.BandageThrowDuration + 1);
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