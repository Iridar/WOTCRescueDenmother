class X2Action_GrappleGetOverHere extends X2Action_ViperGetOverHere;

// Same as original, except without the StartTargetFaceViper() part that uses idle state machine to face the shooter. This interrupts the Raise Hand play animation action.

var private CustomAnimParams Params;

simulated state Executing
{

Begin:
	PreviousWeapon = XComWeapon(UnitPawn.Weapon);
	UnitPawn.SetCurrentWeapon(XComWeapon(UseWeapon.m_kEntity));

	Unit.CurrentFireAction = self;
	Params.AnimName = StartAnimName;
	UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params);

	//Wait for our turn to complete so that we are facing mostly the right direction when the target's RMA animation starts
	while(FocusUnitPawn.m_kGameUnit.IdleStateMachine.IsEvaluatingStance())
	{
		Sleep(0.01f);
	}

	while (!ProjectileHit)
	{
		Sleep(0.01f);
	}

	Params.AnimName = StopAnimName;
	FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params));

	FocusUnitPawn.m_kGameUnit.IdleStateMachine.CheckForStanceUpdateOnIdle();

	UnitPawn.SetCurrentWeapon(PreviousWeapon);

	CompleteAction();
}