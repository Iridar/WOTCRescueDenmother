class X2UnifiedProjectile_ResupplyAmmo extends X2UnifiedProjectile;
/*
function ConfigureNewProjectile(X2Action_Fire InFireAction, 
								AnimNotify_FireWeaponVolley InVolleyNotify,
								XComGameStateContext_Ability AbilityContext,
								XComWeapon InSourceWeapon)
{
	super.ConfigureNewProjectile(InFireAction, InVolleyNotify, AbilityContext, InSourceWeapon);

	bWasHit = AbilityContext.IsResultContextHit();
}
*/

//A projectile instance's time has come - create the particle effect and start updating it in Tick
function FireProjectileInstance(int Index)
{		
	//Hit location and hit location modifying vectors
	local Vector SourceLocation;
	local Vector HitLocation;
	local Vector HitNormal;
	local Vector AimLocation;
	local Vector TravelDirection;
	local Vector TravelDirection2D;
	local float DistanceTravelled;	
	local Vector ParticleParameterDistance;
	local Vector ParticleParameterTravelledDistance;
	local Vector ParticleParameterTrailDistance;
	local EmitterInstanceParameterSet EmitterParameterSet; //The parameter set to use for the projectile
	local float SpreadScale;
	local Vector SpreadValues;
	local XGUnit TargetVisualizer;
	local XComGameState_Ability AbilityState;
	local X2AbilityTemplate AbilityTemplate;
	local bool bAllowSpread;
	local array<ProjectileTouchEvent> OutTouchEvents;
	local float HorizontalSpread, VerticalSpread, SpreadLerp;
	local XKeyframe LastGrenadeFrame, LastGrenadeFrame2;
	local Vector GrenadeImpactDirection;
	local TraceHitInfo GrenadeTraceInfo;
	local XComGameState_Unit ShooterState;

	local SkeletalMeshActorSpawnable CreateSkeletalMeshActor;
	local XComAnimNodeBlendDynamic tmpNode;
	local CustomAnimParams AnimParams;
	local AnimSequence FoundAnimSeq;
	local AnimNodeSequence PlayingSequence;

	local float TravelDistance;
	local bool bDebugImpactEvents;
	local bool bCollideWithUnits;

	// Variables for Issue #10
	local XComLWTuple Tuple;

	//local ParticleSystem AxisSystem;
	//local ParticleSystemComponent PSComponent;

	ShooterState = XComGameState_Unit( `XCOMHISTORY.GetGameStateForObjectID( SourceAbility.InputContext.SourceObject.ObjectID ) );
	AbilityState = XComGameState_Ability( `XCOMHISTORY.GetGameStateForObjectID( AbilityContextAbilityRefID ) );
	AbilityTemplate = AbilityState.GetMyTemplate( );
	
	SetupAim( Index, AbilityState, AbilityTemplate, SourceLocation, AimLocation);


	if (SourceAbility.IsResultContextMiss()) 
	{
		`LOG("Firing missed projectile at:" @ StoredInputContext.TargetLocations[0],, 'WOTCMoreSparkWeapons');
		AimLocation = StoredInputContext.TargetLocations[0];
	}

	bProjectileFired = true;

	//Calculate the travel direction for this projectile
	TravelDirection = AimLocation - SourceLocation;
	TravelDistance = VSize(TravelDirection);
	TravelDirection2D = TravelDirection;
	TravelDirection2D.Z = 0.0f;
	TravelDirection2D = Normal(TravelDirection2D);
	TravelDirection = Normal(TravelDirection);
	
	//If spread values are set, apply them in this block
	bAllowSpread = !Projectiles[Index].ProjectileElement.bTriggerHitReact;

	if(bAllowSpread && Projectiles[Index].ProjectileElement.ApplySpread)
	{
		//If the hit was a critical hit, tighten the spread significantly
		switch (AbilityContextHitResult)
		{
			case eHit_Crit: SpreadScale = Projectiles[Index].ProjectileElement.CriticalHitScale;
				break;
			case eHit_Miss: SpreadScale = Projectiles[Index].ProjectileElement.MissShotScale;
				break;
			default:
				if (AbilityTemplate.bIsASuppressionEffect)
				{
					SpreadScale = Projectiles[Index].ProjectileElement.SuppressionShotScale;
				}
				else
				{
					SpreadScale = 1.0f;
				}
		}

		if (TravelDistance >= Projectiles[Index].ProjectileElement.LongRangeDistance)
		{
			HorizontalSpread = Projectiles[Index].ProjectileElement.LongRangeSpread.HorizontalSpread;
			VerticalSpread = Projectiles[Index].ProjectileElement.LongRangeSpread.VerticalSpread;
		}
		else
		{
			SpreadLerp = TravelDistance / Projectiles[Index].ProjectileElement.LongRangeDistance;

			HorizontalSpread = SpreadLerp * Projectiles[ Index ].ProjectileElement.LongRangeSpread.HorizontalSpread + 
				(1.0f - SpreadLerp) * Projectiles[ Index ].ProjectileElement.ShortRangeSpread.HorizontalSpread;
			VerticalSpread = SpreadLerp * Projectiles[ Index ].ProjectileElement.LongRangeSpread.VerticalSpread + 
				(1.0f - SpreadLerp) * Projectiles[ Index ].ProjectileElement.ShortRangeSpread.VerticalSpread;
		}

		HorizontalSpread *= SpreadScale;
		VerticalSpread *= SpreadScale;

		// convert from full angle spread to half angle spread for the rand computation
		HorizontalSpread /= 2.0f;
		VerticalSpread /= 2.0f;

		// convert from angle measurements to radians
		HorizontalSpread *= DegToRad;
		VerticalSpread *= DegToRad;

		//Apply the spread values - lookup into the precomputed random spread table
		SpreadValues = RandomSpreadValues[ Projectiles[ Index ].VolleyIndex ].SpreadValues[ Projectiles[ Index ].MultipleProjectileIndex ];

		// Randomize the travel direction based on the spread table and scalars
		TravelDirection = VRandCone3( TravelDirection, HorizontalSpread, VerticalSpread, SpreadValues.X, SpreadValues.Y );
	
		//Recalculate aim based on the spread
		AimLocation = SourceLocation + TravelDirection * TravelDistance;
		TravelDirection2D = TravelDirection;
		TravelDirection2D.Z = 0.0f;
		TravelDirection2D = Normal( TravelDirection2D );
	}

	//Build the HitLocation
	bDebugImpactEvents = false;

	if( OrdnanceType != '' )
	{
		//when firing a single projectile, we can just fall back on the targeting path for now, since it would otherwise require re-calculating the trajectory
		Projectiles[Index].GrenadePath = `PRECOMPUTEDPATH;

		Projectiles[Index].GrenadePath.bNoSpinUntilBounce = true;

		//We don't start at the beginning of the path, especially for underhand throws
		Projectiles[Index].AliveTime = FindPathStartTime(Index, SourceLocation);

		HitNormal = -TravelDirection;
		HitLocation = AimLocation;
	}
	else if ((Projectiles[ Index ].ProjectileElement.ReturnsToSource && (AbilityContextHitResult == eHit_Miss)) ||
			 (Projectiles[ Index ].ProjectileElement.bAttachToTarget && (AbilityContextHitResult != eHit_Miss)))
	{
		// if the projectile comes back, only trace out to the aim location and no further		
		`XWORLD.GenerateProjectileTouchList(ShooterState, SourceLocation, AimLocation, OutTouchEvents, bDebugImpactEvents);

		HitLocation = OutTouchEvents[ OutTouchEvents.Length - 1 ].HitLocation;
		HitNormal = OutTouchEvents[OutTouchEvents.Length - 1].HitNormal;
		Projectiles[ Index ].ImpactInfo = OutTouchEvents[ OutTouchEvents.Length - 1 ].TraceInfo;
	}
	else
	{	
		//We want to allow some of the projectiles to go past the target if they don't hit it, so we set up a trace here that will not collide with the target. That way
		//the event list we generate will include impacts behind the target, but only for traveling type projectiles.
		//ranged types should hit the target so that InitialTargetDistance is the distance to the thing being hit.

		bCollideWithUnits = (Projectiles[Index].ProjectileElement.UseProjectileType != eProjectileType_Traveling);

		ProjectileTrace(HitLocation, HitNormal, SourceLocation, TravelDirection, bCollideWithUnits);
		HitLocation = HitLocation + (TravelDirection * 0.0001f); // move us KINDA_SMALL_NUMBER along the direction to be sure and get all the events we want
		`XWORLD.GenerateProjectileTouchList(ShooterState, SourceLocation, HitLocation, OutTouchEvents, bDebugImpactEvents);
		Projectiles[Index].ImpactInfo = OutTouchEvents[OutTouchEvents.Length - 1].TraceInfo;
	}
	
	//Derive the end time from the travel distance and speed if we are not of the grenade type.
	Projectiles[Index].AdjustedTravelSpeed = Projectiles[Index].ProjectileElement.TravelSpeed;      //  initialize to base travel speed
	DistanceTravelled = VSize(HitLocation - SourceLocation);

	//	=======================================================================================================================
	Projectiles[Index].ImpactEvents = StoredInputContext.ProjectileEvents;
	
	
	//Mark this projectile as having been fired
	Projectiles[Index].bFired = true;
	Projectiles[Index].bConstantComplete = false;
	Projectiles[Index].LastImpactTime = 0.0f;

	//Set up the initial source & target location
	Projectiles[Index].InitialSourceLocation = SourceLocation;
	Projectiles[Index].InitialTargetLocation = HitLocation;		
	Projectiles[Index].InitialTargetNormal = HitNormal;
	Projectiles[Index].InitialTravelDirection = TravelDirection;	
	Projectiles[Index].InitialTargetDistance = VSize(AimLocation - Projectiles[Index].InitialSourceLocation);

	TargetVisualizer = XGUnit( `XCOMHISTORY.GetVisualizer( AbilityContextPrimaryTargetID ) );
	if (TargetVisualizer != none)
	{
		Projectiles[Index].VisualizerToTargetOffset = Projectiles[Index].InitialTargetLocation - TargetVisualizer.Location;
	}

	//Create an actor that travels through space using the settings given by the projectile element definition
	if( Projectiles[Index].ProjectileElement.AttachSkeletalMesh == none )
	{
		Projectiles[Index].SourceAttachActor = Spawn(class'DynamicPointInSpace', self, , Projectiles[Index].InitialSourceLocation, rotator(Projectiles[Index].InitialTravelDirection));	
		Projectiles[Index].TargetAttachActor = Spawn(class'DynamicPointInSpace', self, , Projectiles[Index].InitialSourceLocation, rotator(Projectiles[Index].InitialTravelDirection));

		CreateProjectileCollision(Projectiles[Index].TargetAttachActor);
	}
	else
	{
		Projectiles[Index].SourceAttachActor = Spawn(class'DynamicPointInSpace', self, , Projectiles[Index].InitialSourceLocation, rotator(Projectiles[Index].InitialTravelDirection));


		CreateSkeletalMeshActor = Spawn(class'SkeletalMeshActorSpawnable', self, , Projectiles[Index].InitialSourceLocation, rotator(Projectiles[Index].InitialTravelDirection));
		Projectiles[Index].TargetAttachActor = CreateSkeletalMeshActor;

		//	ADDED BY IRIDAR

		//CreateSkeletalMeshActor.SkeletalMeshComponent.SetSkeletalMesh(Projectiles[Index].ProjectileElement.AttachSkeletalMesh);

		CreateSkeletalMeshActor.SkeletalMeshComponent.SetSkeletalMesh(GetProjectileSkeletalMesh());
		//	END OF ADDED

		if (Projectiles[Index].ProjectileElement.CopyWeaponAppearance && SourceWeapon.m_kGameWeapon != none)
		{
			SourceWeapon.m_kGameWeapon.DecorateWeaponMesh(CreateSkeletalMeshActor.SkeletalMeshComponent);
		}
		CreateSkeletalMeshActor.SkeletalMeshComponent.SetAnimTreeTemplate(Projectiles[Index].ProjectileElement.AttachAnimTree);
		CreateSkeletalMeshActor.SkeletalMeshComponent.AnimSets.AddItem(Projectiles[Index].ProjectileElement.AttachAnimSet);
		CreateSkeletalMeshActor.SkeletalMeshComponent.UpdateAnimations();

		CreateProjectileCollision(Projectiles[Index].TargetAttachActor);

		// literally, the only thing that sets this variable is AbilityGrenade - Josh
		if (AbilityState.GetMyTemplate().bHideWeaponDuringFire)
			SourceWeapon.Mesh.SetHidden(true);

		tmpNode = XComAnimNodeBlendDynamic(CreateSkeletalMeshActor.SkeletalMeshComponent.Animations.FindAnimNode('BlendDynamic'));
		if (tmpNode != none)
		{
			AnimParams.AnimName = 'NO_Idle';
			AnimParams.Looping = true;
			tmpNode.PlayDynamicAnim(AnimParams);
		}
	}

	// handy debugging helper, just uncomment this and the declarations at the top
	//	AxisSystem = ParticleSystem( DynamicLoadObject( "FX_Dev_Steve_Utilities.P_Axis_Display", class'ParticleSystem' ) );
	//	PSComponent = new(Projectiles[Index].TargetAttachActor) class'ParticleSystemComponent';
	//	PSComponent.SetTemplate(AxisSystem);
	//	PSComponent.SetAbsolute( false, false, false );
	//	PSComponent.SetTickGroup( TG_EffectsUpdateWork );
	//	PSComponent.SetActive( true );
	//	Projectiles[Index].TargetAttachActor.AttachComponent( PSComponent );

	if( Projectiles[Index].GrenadePath != none )
	{
		Projectiles[Index].GrenadePath.bUseOverrideSourceLocation = true;
		Projectiles[Index].GrenadePath.OverrideSourceLocation = Projectiles[Index].InitialSourceLocation;

		Projectiles[Index].GrenadePath.bUseOverrideTargetLocation = true;
		if (SourceAbility.IsResultContextMiss())
		{	
			Projectiles[Index].GrenadePath.OverrideTargetLocation = StoredInputContext.TargetLocations[0];
			AdjustGrenadePath(Projectiles[Index].GrenadePath, StoredInputContext.TargetLocations[0]);
		}
		else
		{
			Projectiles[Index].GrenadePath.OverrideTargetLocation = TargetVisualizer.GetTargetingFocusLocation();
			AdjustGrenadePath(Projectiles[Index].GrenadePath, TargetVisualizer.GetTargetingFocusLocation());
		}

		//	=======================================================================================================================================
		
		Projectiles[Index].GrenadePath.bUseOverrideTargetLocation = false;
		Projectiles[Index].GrenadePath.bUseOverrideSourceLocation = false;
		Projectiles[Index].EndTime = Projectiles[Index].StartTime + Projectiles[Index].GrenadePath.GetEndTime();
		
		if (Projectiles[ Index ].GrenadePath.iNumKeyframes > 1)
		{
			// get the rough direction of travel at the end of the path.  TravelDirection is from the source to the target
			LastGrenadeFrame = Projectiles[ Index ].GrenadePath.ExtractInterpolatedKeyframe( Projectiles[ Index ].GrenadePath.GetEndTime( ) );
			LastGrenadeFrame2 = Projectiles[ Index ].GrenadePath.ExtractInterpolatedKeyframe( Projectiles[ Index ].GrenadePath.GetEndTime( ) - 0.05f );
			if (VSize( LastGrenadeFrame.vLoc - LastGrenadeFrame2.vLoc ) == 0)
			{
				`redscreen("Grenade path with EndTime and EndTime-.05 with the same point. ~RussellA");
			}

			GrenadeImpactDirection = Normal( LastGrenadeFrame.vLoc - LastGrenadeFrame2.vLoc );

			// don't use the projectile trace, because we don't want the usual minimal arming distance and other features of that trace.
			// really just trying to get the actual surface normal at the point of impact.  HitLocation and AimLocation should basically be the same.
			Trace( HitLocation, HitNormal, AimLocation + GrenadeImpactDirection * 5, AimLocation - GrenadeImpactDirection * 5, true, vect( 0, 0, 0 ), GrenadeTraceInfo );
			Projectiles[Index].ImpactInfo = GrenadeTraceInfo;
		}
		else
		{
			// Not enough keyframes to figure out a direction of travel... a straight up vector as a normal should be a reasonable fallback...
			HitNormal.X = 0.0f;
			HitNormal.Y = 0.0f;
			HitNormal.Z = 1.0f;
		}

		Projectiles[ Index ].InitialTargetNormal = HitNormal;
	}


	Projectiles[ Index ].SourceAttachActor.SetPhysics( PHYS_Projectile );
	Projectiles[ Index ].TargetAttachActor.SetPhysics( PHYS_Projectile );

	switch( Projectiles[Index].ProjectileElement.UseProjectileType )
	{
	case eProjectileType_Traveling:
		if( Projectiles[Index].GrenadePath == none ) //If there is a grenade path, we move along that
		{
			Projectiles[Index].TargetAttachActor.Velocity = Projectiles[Index].InitialTravelDirection * Projectiles[Index].AdjustedTravelSpeed;
		}
		break;
	case eProjectileType_Ranged:
	case eProjectileType_RangedConstant:
		Projectiles[Index].SourceAttachActor.Velocity = vect(0, 0, 0);
		Projectiles[Index].TargetAttachActor.Velocity = Projectiles[Index].InitialTravelDirection * Projectiles[Index].AdjustedTravelSpeed;
		break;
	}

	if( Projectiles[Index].ProjectileElement.UseParticleSystem != none )
	{
		EmitterParameterSet = Projectiles[Index].ProjectileElement.DefaultParticleSystemInstanceParameterSet;
		if( bWasHit && Projectiles[Index].ProjectileElement.bPlayOnHit && Projectiles[Index].ProjectileElement.PlayOnHitOverrideInstanceParameterSet != none )
		{
			EmitterParameterSet = Projectiles[Index].ProjectileElement.PlayOnHitOverrideInstanceParameterSet;
		}
		else if( !bWasHit && Projectiles[Index].ProjectileElement.bPlayOnMiss && Projectiles[Index].ProjectileElement.PlayOnMissOverrideInstanceParameterSet != none )
		{
			EmitterParameterSet = Projectiles[Index].ProjectileElement.PlayOnMissOverrideInstanceParameterSet;
		}

		//Spawn the effect
		switch(Projectiles[Index].ProjectileElement.UseProjectileType)
		{
		case eProjectileType_Traveling:
			//For this style of projectile, the effect is attached to the moving point in space
			if( EmitterParameterSet != none )
			{
				Projectiles[Index].ParticleEffectComponent = WorldInfo.MyEmitterPool.SpawnEmitter(Projectiles[Index].ProjectileElement.UseParticleSystem, 
					Projectiles[Index].InitialSourceLocation, 
					rotator(TravelDirection),
					Projectiles[Index].TargetAttachActor,,,,
					EmitterParameterSet.InstanceParameters);
			}
			else
			{
				Projectiles[Index].ParticleEffectComponent = 
					WorldInfo.MyEmitterPool.SpawnEmitter(Projectiles[Index].ProjectileElement.UseParticleSystem, 
					Projectiles[Index].InitialSourceLocation, 
					rotator(TravelDirection),
					Projectiles[Index].TargetAttachActor);
			}
			break;
		case eProjectileType_Ranged:
		case eProjectileType_RangedConstant:
			//For this style of projectile, the point in space is motionless
			if( EmitterParameterSet != none )
			{
				Projectiles[Index].ParticleEffectComponent = WorldInfo.MyEmitterPool.SpawnEmitter(Projectiles[Index].ProjectileElement.UseParticleSystem, 
					Projectiles[Index].InitialSourceLocation, 
					rotator(TravelDirection),
					Projectiles[Index].SourceAttachActor,,,,
					EmitterParameterSet.InstanceParameters);
			}
			else
			{
				Projectiles[Index].ParticleEffectComponent = WorldInfo.MyEmitterPool.SpawnEmitter(Projectiles[Index].ProjectileElement.UseParticleSystem, 
					Projectiles[Index].InitialSourceLocation, 
					rotator(TravelDirection),
					Projectiles[Index].SourceAttachActor);
			}
			break;
		}

		Projectiles[Index].ParticleEffectComponent.SetScale( Projectiles[Index].ProjectileElement.ParticleScale );
		Projectiles[Index].ParticleEffectComponent.OnSystemFinished = OnParticleSystemFinished;

		DistanceTravelled = Min( DistanceTravelled, Projectiles[ Index ].ProjectileElement.MaxTravelDistanceParam );
		//Tells the particle system how far the projectile must travel to reach its target
		ParticleParameterDistance.X = DistanceTravelled;
		ParticleParameterDistance.Y = DistanceTravelled;
		ParticleParameterDistance.Z = DistanceTravelled;
		Projectiles[Index].ParticleEffectComponent.SetVectorParameter('Target_Distance', ParticleParameterDistance);
		Projectiles[Index].ParticleEffectComponent.SetFloatParameter('Target_Distance', DistanceTravelled);

		ParticleParameterDistance.X = DistanceTravelled;
		ParticleParameterDistance.Y = DistanceTravelled;
		ParticleParameterDistance.Z = DistanceTravelled;
		Projectiles[ Index ].ParticleEffectComponent.SetVectorParameter( 'Initial_Target_Distance', ParticleParameterDistance );
		Projectiles[ Index ].ParticleEffectComponent.SetFloatParameter( 'Initial_Target_Distance', DistanceTravelled );

		//Tells the particle system how far we have moved
		ParticleParameterTravelledDistance.X = 0.0f;
		ParticleParameterTravelledDistance.Y = 0.0f;
		ParticleParameterTravelledDistance.Z = 0.0f;
		Projectiles[Index].ParticleEffectComponent.SetVectorParameter('Traveled_Distance', ParticleParameterTravelledDistance);
		Projectiles[Index].ParticleEffectComponent.SetFloatParameter('Traveled_Distance', 0.0f);

		if( Projectiles[Index].ProjectileElement.MaximumTrailLength > 0.0f )
		{
			ParticleParameterTrailDistance.X = 0.0f;
			ParticleParameterTrailDistance.Y = 0.0f;
			ParticleParameterTrailDistance.Z = 0.0f;
			Projectiles[Index].ParticleEffectComponent.SetVectorParameter('Trail_Distance', ParticleParameterTrailDistance);
			Projectiles[Index].ParticleEffectComponent.SetFloatParameter('Trail_Distance', 0.0f);
		}
	}

	`log("********************* PROJECTILE Element #"@self.Name@Index@"FIRED *********************************", , 'DevDestruction');
	`log("StartTime:"@Projectiles[Index].StartTime, , 'DevDestruction');
	`log("EndTime:"@Projectiles[Index].EndTime, , 'DevDestruction');
	`log("InitialSourceLocation:"@Projectiles[Index].InitialSourceLocation, , 'DevDestruction');
	`log("InitialTargetLocation:"@Projectiles[Index].InitialTargetLocation, , 'DevDestruction');
	`log("InitialTravelDirection:"@Projectiles[Index].InitialTravelDirection, , 'DevDestruction');
	`log("Projectile actor location is "@Projectiles[Index].SourceAttachActor.Location, , 'DevDestruction');
	`log("Projectile actor velocity is set to:"@Projectiles[Index].TargetAttachActor.Velocity, , 'DevDestruction');
	`log("******************************************************************************************", , 'DevDestruction');

	if( Projectiles[Index].ProjectileElement.bPlayWeaponAnim )
	{
		AnimParams.AnimName = 'FF_FireA';
		AnimParams.Looping = false;
		AnimParams.Additive = true;

		FoundAnimSeq = SkeletalMeshComponent(SourceWeapon.Mesh).FindAnimSequence(AnimParams.AnimName);
		if( FoundAnimSeq != None )
		{
			//Tell our weapon to play its fire animation
			if( SourceWeapon.AdditiveDynamicNode != None )
			{
				PlayingSequence = SourceWeapon.AdditiveDynamicNode.PlayDynamicAnim(AnimParams);
				PlayingSequences.AddItem(PlayingSequence);
				SetTimer(PlayingSequence.AnimSeq.SequenceLength, false, nameof(BlendOutAdditives), self);
			}
			
		}
	}

	if( Projectiles[Index].ProjectileElement.FireSound != none )
	{
		//Play a fire sound if specified
		// Start Issue #10 Trigger an event that allows to override the default projectile sound
		Tuple = new class'XComLWTuple';
		Tuple.Id = 'ProjectilSoundOverride';
		Tuple.Data.Add(3);

		// The SoundCue to play instead of the AKEvent, used as reference
		Tuple.Data[0].kind = XComLWTVObject;
		Tuple.Data[0].o = none;

		// Projectile Element ObjectArchetype Pathname Parameter
		Tuple.Data[1].kind = XComLWTVString;
		Tuple.Data[1].s = PathName(Projectiles[Index].ProjectileElement.ObjectArchetype);

		// Ability Context Ref Parameter
		Tuple.Data[2].kind = XComLWTVInt;
		Tuple.Data[2].i = AbilityContextAbilityRefID;

		`XEVENTMGR.TriggerEvent('OnProjectileFireSound', Tuple, Projectiles[Index].ProjectileElement, none);
		if (Tuple.Data[0].o != none)
		{
			Projectiles[Index].SourceAttachActor.PlaySound(SoundCue(Tuple.Data[0].o));
		}
		else
		{
			Projectiles[Index].SourceAttachActor.PlayAkEvent(Projectiles[Index].ProjectileElement.FireSound);
		}
		// End Issue #10
	}
}

private function SkeletalMesh GetProjectileSkeletalMesh()
{
	local XComGameState_Unit		TargetUnit;
	local XComGameState_Item		PrimaryWeapon;
	local X2WeaponTemplate			PrimaryWeaponTemplate;
	local SkeletalMesh				ReturnMesh;
	
	TargetUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AbilityContextPrimaryTargetID));
	if (TargetUnit == none)
		return GetPlaceholderMesh();

	//`LOG("GetProjectileSkeletalMesh target unit:" @ TargetUnit.GetFullName() @ TargetUnit.GetSoldierClassTemplateName(),, 'IRITEST');

	PrimaryWeapon = TargetUnit.GetPrimaryWeapon();
	if (PrimaryWeapon == none)
		return GetPlaceholderMesh();

	PrimaryWeaponTemplate = X2WeaponTemplate(PrimaryWeapon.GetMyTemplate());
	if (PrimaryWeaponTemplate == none)
		return GetPlaceholderMesh();
		
	ReturnMesh = GetMagazineMesh(PrimaryWeaponTemplate, PrimaryWeapon);
	if (ReturnMesh != none)
		return ReturnMesh;

	//`LOG("Did not find the right mesh, falling back.",, 'IRITEST');

	//	Throw a generic rifle magazine if we can't determine how this weapon's magazine is supposed to look like.
	switch (PrimaryWeaponTemplate.WeaponTech)
	{
	case 'magnetic':
	case 'laser':
		return SkeletalMesh(`CONTENT.RequestGameArchetype("MagAssaultRifle.Meshes.SM_MagAssaultRifle_MagA"));
	case 'beam':
	case 'coil':
		return SkeletalMesh(`CONTENT.RequestGameArchetype("BeamAssaultRifle.Meshes.SM_BeamAssaultRifle_MagA"));
	case 'conventional':
		return SkeletalMesh(`CONTENT.RequestGameArchetype("ConvAssaultRifle.Meshes.SM_ConvAssaultRifle_MagA"));
	default:
		return GetPlaceholderMesh();
	}
}

private function SkeletalMesh GetPlaceholderMesh()
{
	return SkeletalMesh(`CONTENT.RequestGameArchetype("ConvAssaultRifle.Meshes.SM_ConvAssaultRifle_MagA"));
}

private function SkeletalMesh GetMagazineMesh(const X2WeaponTemplate LocWeaponTemplate, const XComGameState_Item ItemState)
{
	local delegate<X2TacticalGameRulesetDataStructures.CheckUpgradeStatus> ValidateAttachmentFn;
	local array<X2WeaponUpgradeTemplate>	UpgradeTemplates;
	local array<WeaponAttachment>			Attachments;
	local WeaponAttachment					Attachment;
	local array<name>						LikelySocketNames;
	local int	i, j, k;
	local bool	bReplaced;

	//`LOG("Begin GetMagazineMesh" @ LocWeaponTemplate.DataName @ ItemState.GetMyTemplateName(),, 'IRITEST');
	
	//  copy all default attachments from the weapon template
	for (i = 0; i < LocWeaponTemplate.DefaultAttachments.Length; ++i)
	{
		Attachments.AddItem(LocWeaponTemplate.DefaultAttachments[i]);
	}

	UpgradeTemplates = ItemState.GetMyWeaponUpgradeTemplates();
	for (i = 0; i < UpgradeTemplates.Length; ++i)
	{
		//	We're only interested in extended mags or autoloaders.
		if (InStr(UpgradeTemplates[i].DataName, "ReloadUpgrade") == INDEX_NONE &&
			InStr(UpgradeTemplates[i].DataName, "ClipSizeUpgrade") == INDEX_NONE)
		{
			continue;
		}

		for (j = 0; j < UpgradeTemplates[i].UpgradeAttachments.Length; ++j)
		{
			if (UpgradeTemplates[i].UpgradeAttachments[j].ApplyToWeaponTemplate != LocWeaponTemplate.DataName)
				continue;

			ValidateAttachmentFn = UpgradeTemplates[i].UpgradeAttachments[j].ValidateAttachmentFn;
			if( ValidateAttachmentFn != None && !ValidateAttachmentFn(UpgradeTemplates) )
			{
				continue;
			}

			bReplaced = false;
			//  look for sockets already known that an upgrade will replace
			for (k = 0; k < Attachments.Length; ++k)
			{
				if( Attachments[k].AttachSocket == UpgradeTemplates[i].UpgradeAttachments[j].AttachSocket )
				{
					Attachments[k].AttachMeshName = UpgradeTemplates[i].UpgradeAttachments[j].AttachMeshName;
					bReplaced = true;
					break;
				}
			}
			//  if not replacing an existing mesh, add the upgrade attachment as a new one
			if (!bReplaced)
			{
				Attachments.AddItem(UpgradeTemplates[i].UpgradeAttachments[j]);
			}
		}
	}	

	//`LOG("Found valid attachments:" @ Attachments.Length,, 'IRITEST');

	GetLikelyMagSocketNames(LocWeaponTemplate.DataName, LikelySocketNames);
	
	foreach Attachments(Attachment)
	{
		//`LOG("Looking at an attachment with socket:" @ Attachment.AttachSocket @ "and mesh:" @ Attachment.AttachMeshName,, 'IRITEST');
		if (LikelySocketNames.Find(Attachment.AttachSocket) != INDEX_NONE && Attachment.AttachMeshName != "")
		{
			//`LOG("It's valid, returning mesh",, 'IRITEST');
			return SkeletalMesh(`CONTENT.RequestGameArchetype(Attachment.AttachMeshName));
		}
	}
	return none;
}

private function GetLikelyMagSocketNames(const name WeaponTemplateName, out array<name> LikelySocketNames)
{
	local array<X2WeaponUpgradeTemplate>	UpgradeTemplates;
	local X2WeaponUpgradeTemplate			UpgradeTemplate;
	local WeaponAttachment					Attachment;

	GetMagazineUpgradeTemplates(UpgradeTemplates);
	foreach UpgradeTemplates(UpgradeTemplate)
	{
		foreach UpgradeTemplate.UpgradeAttachments(Attachment)
		{
			if (Attachment.ApplyToWeaponTemplate == WeaponTemplateName && Attachment.AttachSocket != '' && Attachment.AttachMeshName != "")
			{
				//`LOG("Found likely socket:" @ Attachment.AttachSocket,, 'IRITEST');
				LikelySocketNames.AddItem(Attachment.AttachSocket);
			}
		}
	}
}

static private function GetMagazineUpgradeTemplates(out array<X2WeaponUpgradeTemplate> m_arrWeaponUpgradeTemplates)
{
	local X2ItemTemplateManager ItemMgr;

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	m_arrWeaponUpgradeTemplates.AddItem(X2WeaponUpgradeTemplate(ItemMgr.FindItemTemplate('ClipSizeUpgrade_Bsc')));
	m_arrWeaponUpgradeTemplates.AddItem(X2WeaponUpgradeTemplate(ItemMgr.FindItemTemplate('ClipSizeUpgrade_Adv')));
	m_arrWeaponUpgradeTemplates.AddItem(X2WeaponUpgradeTemplate(ItemMgr.FindItemTemplate('ClipSizeUpgrade_Sup')));

	m_arrWeaponUpgradeTemplates.AddItem(X2WeaponUpgradeTemplate(ItemMgr.FindItemTemplate('ReloadUpgrade_Bsc')));
	m_arrWeaponUpgradeTemplates.AddItem(X2WeaponUpgradeTemplate(ItemMgr.FindItemTemplate('ReloadUpgrade_Adv')));
	m_arrWeaponUpgradeTemplates.AddItem(X2WeaponUpgradeTemplate(ItemMgr.FindItemTemplate('ReloadUpgrade_Sup')));
}

private function AdjustGrenadePath(XComPrecomputedPath GrenadePath, vector TargetLocation)
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
	for (i = 0; i < iKeyframes; i++)
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
}