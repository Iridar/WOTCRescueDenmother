class X2Action_PlayIdleAnimation extends X2Action_PlayAnimation;

// Play different idle animations depending on cover, and end early if the unit is hit by ability/projectile.

function Init()
{
	super.Init();

	switch (Unit.m_eCoverState)
	{
	case eCS_LowLeft:
	case eCS_LowRight:
		Params.AnimName = 'LL_IdleAlert';
		break;
	case eCS_HighLeft:
	case eCS_HighRight:
		Params.AnimName = 'HL_IdleAlert';
		break;
	case eCS_None:
		Params.AnimName = 'NO_IdleAlertGunDwn';
		break;
	}
}

DefaultProperties
{
	InputEventIDs.Add( "Visualizer_AbilityHit" )
	InputEventIDs.Add( "Visualizer_ProjectileHit" )
	OutputEventIDs.Add( "Visualizer_AbilityHit" )
	OutputEventIDs.Add( "Visualizer_ProjectileHit" )
}