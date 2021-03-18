class X2Effect_BandageThrow extends X2Effect_Persistent;

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_Unit SourceUnit;

	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);

	// Handle Supply RUn interaction. Easier to do here than via separate effect, in this case.
	// Exit if self-targeted.
	if (ApplyEffectParameters.SourceStateObjectRef == ApplyEffectParameters.TargetStateObjectRef)
		return;

	SourceUnit = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	if (SourceUnit == none)
	{
		SourceUnit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	}
	
	if (SourceUnit != none && SourceUnit.HasSoldierAbility('IRI_SupplyRun'))
	{
		SourceUnit.ActionPoints.AddItem(class'X2CharacterTemplateManager'.default.MoveActionPoint);		
	}
}


simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local X2Action_PlaySoundAndFlyOver		SoundAndFlyOver;
	local X2Action_PlayAnimation			PlayAnimation;
	local XComGameState_Unit				SourceUnit;
	local XComGameStateContext_Ability		Context;
	local X2AbilityTemplate					AbilityTemplate;
	local VisualizationActionMetadata		ShooterMetadata;
	local XComGameStateHistory				History;

	if (EffectApplyResult == 'AA_Success')
	{	
		Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
		History = `XCOMHISTORY;

		//	Play catch animation only if the ability was not self-targeted.
		if (Context.InputContext.PrimaryTarget != Context.InputContext.SourceObject)
		{
			PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
			PlayAnimation.Params.AnimName = 'HL_CatchSupplies';

			PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, ActionMetadata.LastActionAdded));
			PlayAnimation.Params.AnimName = 'NO_ApplyBandages';
		}

		// This will play the "X HP Healed" flyover.
		//super.AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, EffectApplyResult);

		// Handle Supply Run flyover.
		if (Context.InputContext.PrimaryTarget != Context.InputContext.SourceObject)
		{
			SourceUnit = XComGameState_Unit(History.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID));
			if (SourceUnit.HasSoldierAbility('IRI_SupplyRun', true))
			{
				AbilityTemplate = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('IRI_SupplyRun');
				if (AbilityTemplate != none)
				{
					ShooterMetadata.StateObject_OldState = History.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
					ShooterMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID);
					ShooterMetadata.VisualizeActor = History.GetVisualizer(Context.InputContext.SourceObject.ObjectID);

					SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(ShooterMetadata, Context, false, ActionMetadata.LastActionAdded));
					SoundAndFlyOver.SetSoundAndFlyOverParameters(None, AbilityTemplate.LocFlyOverText, '', eColor_Good, AbilityTemplate.IconImage);
				}
			}
		}
	}	
}
/*
simulated function AddX2ActionsForVisualization_Removed(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult, XComGameState_Effect RemovedEffect)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(ActionMetadata.StateObject_NewState);
	if (UnitState != none)
	{
		
	}
	super.AddX2ActionsForVisualization_Removed(VisualizeGameState, ActionMetadata, EffectApplyResult, RemovedEffect);
}*/

defaultproperties
{
	EffectName = "IRI_BandageThrow_Effect"
}