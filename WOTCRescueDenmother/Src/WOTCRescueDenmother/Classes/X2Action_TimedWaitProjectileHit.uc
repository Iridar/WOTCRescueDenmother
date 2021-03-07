class X2Action_TimedWaitProjectileHit extends X2Action_TimedWait;

DefaultProperties
{
	InputEventIDs.Add( "Visualizer_AbilityHit" )
	InputEventIDs.Add( "Visualizer_ProjectileHit" )
	OutputEventIDs.Add( "Visualizer_AbilityHit" )
	OutputEventIDs.Add( "Visualizer_ProjectileHit" )
}