class X2TargetingMethod_ResupplyAmmo extends X2TargetingMethod_Grenade;

//	This targeting method is a mix between Grenade and Top Down targeting.
//	It works the same as Top Down in all aspects, except it also draws a spline trajectory curve to the target's hitbox.

var private X2Camera_LookAtActor LookatCamera;
var protected int LastTarget;
var protected vector SourceUnitLocation;

function GetTargetLocations(out array<Vector> TargetLocations)
{
	local Vector Focus;

	TargetLocations.Length = 0;
	GetCurrentTargetFocus(Focus);
	TargetLocations.AddItem(Focus);
}

function GetGrenadeWeaponInfo(out XComWeapon WeaponEntity, out PrecomputedPathData WeaponPrecomputedPathData)
{
	local XComGameState_Item WeaponItem;
	//local X2WeaponTemplate WeaponTemplate;
	local XGWeapon WeaponVisualizer;

	WeaponItem = Ability.GetSourceWeapon();
	//WeaponTemplate = X2WeaponTemplate(WeaponItem.GetMyTemplate());
	WeaponVisualizer = XGWeapon(WeaponItem.GetVisualizer());

	// Tutorial Band-aid fix for missing visualizer due to cheat GiveItem
	if (WeaponVisualizer == none)
	{
		class'XGItem'.static.CreateVisualizer(WeaponItem);
		WeaponVisualizer = XGWeapon(WeaponItem.GetVisualizer());
		WeaponEntity = XComWeapon(WeaponVisualizer.CreateEntity(WeaponItem));

		if (WeaponEntity != none)
		{
			WeaponEntity.m_kPawn = FiringUnit.GetPawn();
		}
	}
	else
	{
		WeaponEntity = WeaponVisualizer.GetEntity();
	}

	WeaponPrecomputedPathData.InitialPathTime = 1.0f;
	WeaponPrecomputedPathData.MaxPathTime = 2.5f;
	WeaponPrecomputedPathData.MaxNumberOfBounces = 0;
}

/*
function name ValidateTargetLocations(const array<Vector> TargetLocations)
{
	local TTile TestLoc;
	if (TargetLocations.Length == 1)
	{
		if (bRestrictToSquadsightRange)
		{
			TestLoc = `XWORLD.GetTileCoordinatesFromPosition(TargetLocations[0]);
			if (!class'X2TacticalVisibilityHelpers'.static.CanSquadSeeLocation(AssociatedPlayerState.ObjectID, TestLoc))
				return 'AA_NotVisible';
		}
		return 'AA_Success';
	}
	return 'AA_NoTargets';
}*/

//	This is where the magic happens. 
//	Not sure how often this gets run, but it's necessary to adjust the grenade path every time,
//	else it just defaults to target's feet.
function Update(float DeltaTime)
{
	local vector TargetedLocation;

	super(X2TargetingMethod).Update(DeltaTime);
	
	GetCurrentTargetFocus(TargetedLocation);
	AdjustGrenadePath(TargetedLocation);	
}

//	This function will realign the projectile trajectory spline to target at the provided point in space

private function AdjustGrenadePath(vector TargetLocation)
{
	local vector vDif;
	local int iKeyframes;
	local int i;
	local float Alpha;
	local float PathLength;

	local vector LineMidPoint, CurveMidPoint;
	local vector CurveAdjust;
	local float AlphaCurveAdjust;

	iKeyframes = GrenadePath.iNumKeyframes;

	//	Calculate the vector difference between given vector location (target's chest/head) and the current end of the grenade path (target's feet)
	vDif = TargetLocation - GrenadePath.akKeyframes[iKeyframes - 1].vLoc;

	LineMidPoint = (TargetLocation + GrenadePath.akKeyframes[0].vLoc) / 2;
	CurveMidPoint = GrenadePath.akKeyframes[iKeyframes / 2].vLoc;

	//	Filthy hack. For some reason having it the same as in UnifiedProjectile doesn't work.
	CurveAdjust = (CurveMidPoint - LineMidPoint) / 2;

	//	Not sure if flipping these bools is necessary
	GrenadePath.bUseOverrideTargetLocation = true;
	GrenadePath.OverrideTargetLocation = TargetLocation;

	GrenadePath.bUseOverrideSourceLocation = true;
	GrenadePath.OverrideSourceLocation = GrenadePath.akKeyframes[0].vLoc;

	//	Cycle through current points of the path.
	for (i = 1; i < iKeyframes; i++)
	{	
		AlphaCurveAdjust = -(Abs(i - iKeyframes / 2) / (iKeyframes / 2)) * (Abs(i - iKeyframes / 2) / (iKeyframes / 2)) + 1.0f;
		//	This is used to "blend in" the current path point with the desired trajectory.
		//	Basically, the closer we are to the end of the path, the higher is the Alpha value, scaling from 0.0 at the start of the path, to 1.0 at the end of it.
		Alpha = float(i) / float(iKeyframes);	
		GrenadePath.akKeyframes[i].vLoc += vDif * Alpha - CurveAdjust * AlphaCurveAdjust;

		//	At the same time, adjust the points used to draw the path spline.
		//	Adjusting the path points themselves might not even be necessary, unless perhaps they're used for targeting validation.
		//	Adjusting the actual trajectory taken by the projectile is done in the X2UnifiedProjectile subclass.
		GrenadePath.kSplineInfo.Points[i].OutVal = GrenadePath.akKeyframes[i].vLoc;
	}	

	//	Once we're done adjusting the spline points, force redraw it.
	PathLength = GrenadePath.akKeyframes[GrenadePath.iNumKeyframes - 1].fTime - GrenadePath.akKeyframes[0].fTime;
	GrenadePath.kRenderablePath.UpdatePathRenderData(GrenadePath.kSplineInfo, PathLength, none, `CAMERASTACK.GetCameraLocationAndOrientation().Location);
	//GrenadePath.kRenderablePath.SetHidden(false);
}

//	When targeting an enemy unit, this function gives the vector location of the enemy's torso/head, this is normally the location around which the targeting reticule is drawn.
function bool GetCurrentTargetFocus(out Vector Focus)
{
	local Actor TargetedActor;
	local X2VisualizerInterface TargetVisualizer;

	TargetedActor = GetTargetedActor();

	if (TargetedActor != none)
	{
		TargetVisualizer = X2VisualizerInterface(TargetedActor);
		if( TargetVisualizer != None )
		{
			Focus = TargetVisualizer.GetTargetingFocusLocation();
		}
		else
		{
			Focus = TargetedActor.Location;
		}

		return true;
	}
	return false;
}

//	Mixed Grenade / Top Down Init
function Init(AvailableAction InAction, int NewTargetIndex)
{
	local XComWeapon			WeaponEntity;
	local PrecomputedPathData	WeaponPrecomputedPathData;
	local X2AbilityTemplate		AbilityTemplate;
	local TTile					UnitTileLocation;
	local array<TTile>			Tiles;
	local array<TTile>			ShowTiles;
	local GameRulesCache_VisibilityInfo DirectionInfo;
	local XComWorldData			WorldData;
	local TTile					TestTile;

	super(X2TargetingMethod).Init(InAction, NewTargetIndex);
	
	//	Init grenade path.
	GetGrenadeWeaponInfo(WeaponEntity, WeaponPrecomputedPathData);
	// Tutorial Band-aid #2 - Should look at a proper fix for this
	if (WeaponEntity.m_kPawn == none)
	{
		WeaponEntity.m_kPawn = FiringUnit.GetPawn();
	}

	GrenadePath = `PRECOMPUTEDPATH;
	GrenadePath.ClearOverrideTargetLocation(); // Clear this flag in case the grenade target location was locked.
	GrenadePath.ActivatePath(WeaponEntity, FiringUnit.GetTeam(), WeaponPrecomputedPathData);

	//	This seems to be necessary to make the grenade path visible?..
	//GrenadePath.SetFiringFromSocketPosition('gun_fire');

	//	Init splash radius visuals
	AbilityTemplate = Ability.GetMyTemplate();
	if (!AbilityTemplate.SkipRenderOfTargetingTemplate)
	{
		// setup the blast emitter
		ExplosionEmitter = `BATTLE.spawn(class'XComEmitter');
		if(AbilityIsOffensive)
		{
			ExplosionEmitter.SetTemplate(ParticleSystem(DynamicLoadObject("UI_Range.Particles.BlastRadius_Shpere", class'ParticleSystem')));
		}
		else
		{
			ExplosionEmitter.SetTemplate(ParticleSystem(DynamicLoadObject("UI_Range.Particles.BlastRadius_Shpere_Neutral", class'ParticleSystem')));
		}
		
		ExplosionEmitter.LifeSpan = 60 * 60 * 24 * 7; // never die (or at least take a week to do so)
	}

	//	Top Down Init
	//LookatCamera = new class'X2Camera_LookAtActor';
	//LookatCamera.UseTether = false;
	//`CAMERASTACK.AddCamera(LookatCamera);

	AOEMeshActor = `BATTLE.spawn(class'XComInstancedMeshActor');
	
	AbilityIsOffensive = GetAbilityIsOffensive();
	if(AbilityIsOffensive)
	{
		AOEMeshActor.InstancedMeshComponent.SetStaticMesh(StaticMesh(DynamicLoadObject("UI_3D.Tile.AOETile", class'StaticMesh')));
	}
	else
	{
		AOEMeshActor.InstancedMeshComponent.SetStaticMesh(StaticMesh(DynamicLoadObject("UI_3D.Tile.AOETile_Neutral", class'StaticMesh')));
	}

	WorldData = `XWORLD;
	// Draw the AOE around the source unit instead of around the target. Raise the origin point a bit so that it draws tiles over low cover.
	UnitState.GetKeystoneVisibilityLocation(UnitTileLocation);
	SourceUnitLocation = WorldData.GetPositionFromTileCoordinates(UnitTileLocation);
	//SourceUnitLocation.Z += 32;

	if( AbilityTemplate.AbilityTargetStyle != none )
	{
		AbilityTemplate.AbilityTargetStyle.GetValidTilesForLocation(Ability, SourceUnitLocation, Tiles);
	}
	foreach Tiles(TestTile)
	{
		if (WorldData.CanSeeTileToTile(UnitTileLocation, TestTile, DirectionInfo))
		{
			ShowTiles.AddItem(TestTile);
		}
	}

	if (ShowTiles.Length > 1)
	{
		DrawAOETiles(ShowTiles);
	}

	DirectSetTarget(0);
}

//	===================================================
//	Varius Top Down methods with minimal or no modifications.

function DirectSetTarget(int TargetIndex)
{
	local XComPresentationLayer Pres;
	local UITacticalHUD TacticalHud;
	local Actor TargetedActor;
	local TTile TargetedActorTile;
	local XGUnit TargetedPawn;
	local vector TargetedLocation;
	local XComWorldData World;
	local int NewTarget;
	//local array<Actor> CurrentlyMarkedTargets;

	World = `XWORLD;

	// put the targeting reticle on the new target
	Pres = `PRES;
	TacticalHud = Pres.GetTacticalHUD();

	// advance the target counter
	NewTarget = TargetIndex % Action.AvailableTargets.Length;
	if(NewTarget < 0) NewTarget = Action.AvailableTargets.Length + NewTarget;

	LastTarget = NewTarget;
	TacticalHud.TargetEnemy(Action.AvailableTargets[NewTarget].PrimaryTarget.ObjectID);

	// have the idle state machine look at the new target
	if (FiringUnit != none)
	{
		FiringUnit.IdleStateMachine.CheckForStanceUpdate();
	}

	//LookatCamera.ActorToFollow = FiringUnit;

	TargetedActor = GetTargetedActor();
	TargetedPawn = XGUnit(TargetedActor);
	if( TargetedPawn != none )
	{
		TargetedLocation = TargetedPawn.GetFootLocation();
		TargetedActorTile = World.GetTileCoordinatesFromPosition(TargetedLocation);
		TargetedLocation = World.GetPositionFromTileCoordinates(TargetedActorTile);
	}
	else
	{
		TargetedLocation = TargetedActor.Location;
	}
}

function Canceled()
{
	super(X2TargetingMethod).Canceled();

	//`CAMERASTACK.RemoveCamera(LookatCamera);
	GrenadePath.ClearPathGraphics();
	//ClearTargetedActors();
}

function Committed()
{
	Canceled();
}

function NextTarget()
{
	DirectSetTarget(LastTarget + 1);
}

function PrevTarget()
{
	DirectSetTarget(LastTarget - 1);
}

function int GetTargetIndex()
{
	return LastTarget;
}