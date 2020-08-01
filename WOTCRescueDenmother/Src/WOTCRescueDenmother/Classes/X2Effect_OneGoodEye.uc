class X2Effect_OneGoodEye extends X2Effect_Persistent config(ClassData);

var config int BonusAimPerShot;
var config int BonusCritPerShot;
var config int MaxStacks;

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager EventMgr;
	local Object EffectObj;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;
	EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', ZeroInListener, ELD_OnStateSubmitted, , `XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.TargetStateObjectRef.ObjectID),, EffectObj);
}

static function EventListenerReturn ZeroInListener(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Ability AbilityState;
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState;
	local XComGameState_Item SourceWeapon;
	local UnitValue UValue;
	local XComGameState_Effect EffectState;

	if (GameState.GetContext().InterruptionStatus == eInterruptionStatus_Interrupt)
		return ELR_NoInterrupt;

	AbilityState = XComGameState_Ability(EventData);
	UnitState = XComGameState_Unit(EventSource);
	EffectState = XComGameState_Effect(CallbackData);
	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	
	if (AbilityState != none && UnitState != none && AbilityContext != none && EffectState != none && AbilityState.IsAbilityInputTriggered())
	{
		SourceWeapon = AbilityState.GetSourceWeapon();
		if (AbilityState.GetMyTemplate().Hostility == eHostility_Offensive && SourceWeapon != none && SourceWeapon.InventorySlot == eInvSlot_PrimaryWeapon)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("ZeroIn Increment");
			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
			UnitState.GetUnitValue('IRI_ZeroInShots', UValue);
			UnitState.SetUnitFloatValue('IRI_OneGoodEye_Shots', UValue.fValue + 1, eCleanup_BeginTactical);
			UnitState.SetUnitFloatValue('IRI_OneGoodEye_Target', AbilityContext.InputContext.PrimaryTarget.ObjectID, eCleanup_BeginTactical);

			if (UnitState.ActionPoints.Length > 0)
			{
				//	show flyover for boost, but only if they have actions left to potentially use them
				NewGameState.ModifyStateObject(class'XComGameState_Ability', EffectState.ApplyEffectParameters.AbilityStateObjectRef.ObjectID);		//	create this for the vis function
				XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = EffectState.TriggerAbilityFlyoverVisualizationFn;
			}
		}
		else
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("ZeroIn Reset");
			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
			UnitState.ClearUnitValue('IRI_OneGoodEye_Shots');
			UnitState.ClearUnitValue('IRI_OneGoodEye_Target');
		}
		SubmitNewGameState(NewGameState);
	}
	return ELR_NoInterrupt;
}


function GetToHitModifiers(XComGameState_Effect EffectState, XComGameState_Unit Attacker, XComGameState_Unit Target, XComGameState_Ability AbilityState, class<X2AbilityToHitCalc> ToHitType, bool bMelee, bool bFlanking, bool bIndirectFire, out array<ShotModifierInfo> ShotModifiers)
{
	local XComGameState_Item SourceWeapon;
	local ShotModifierInfo ShotMod;
	local UnitValue ShotsValue, TargetValue;

	Attacker.GetUnitValue('IRI_OneGoodEye_Target', TargetValue);
	if (TargetValue.fValue != Target.ObjectID)
		return;
		
	SourceWeapon = AbilityState.GetSourceWeapon();
	if (SourceWeapon != none && SourceWeapon.InventorySlot == eInvSlot_PrimaryWeapon && !bIndirectFire)
	{
		Attacker.GetUnitValue('IRI_OneGoodEye_Shots', ShotsValue);

		if (ShotsValue.fValue > default.MaxStacks)
			ShotsValue.fValue = default.MaxStacks;
		
		if (ShotsValue.fValue > 0)
		{
			ShotMod.ModType = eHit_Success;
			ShotMod.Reason = FriendlyName;
			ShotMod.Value = ShotsValue.fValue * default.BonusAimPerShot;
			ShotModifiers.AddItem(ShotMod);

			ShotMod.ModType = eHit_Crit;
			ShotMod.Reason = FriendlyName;
			ShotMod.Value = ShotsValue.fValue * default.BonusCritPerShot;
			ShotModifiers.AddItem(ShotMod);			
		}
	}
}

static private function SubmitNewGameState(out XComGameState NewGameState)
{
	local X2TacticalGameRuleset TacticalRules;
	local XComGameStateHistory History;

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		TacticalRules = `TACTICALRULES;
		TacticalRules.SubmitGameState(NewGameState);
	}
	else
	{
		History = `XCOMHISTORY;
		History.CleanupPendingGameState(NewGameState);
	}
}

defaultproperties
{
	DuplicateResponse = eDupe_Ignore
	EffectName = "IRI_OneGoodEye_Effect"
}