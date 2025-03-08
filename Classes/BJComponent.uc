class BJComponent extends GGMutatorComponent;

struct JarObj{
	var Actor act;
	var EPhysics oldPhys;
	var bool oldRagdoll;
	var bool oldCollideWorld;
	var PrimitiveComponent comp;
};

var GGGoat gMe;
var GGMutator myMut;
var StaticMeshComponent jarMesh;
var array<JarObj> jarStack;
var bool canSwap;
var SoundCue pushSound;
var SoundCue popSound;
var float offset;
var bool isLickPressed;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		jarMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponent( jarMesh, 'Spine_01', vect(0.f, 0.f, 30.f));

		offset=gMe.mCachedSlotNr;
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( newKey == 'FOUR' || (newKey == 'XboxTypeS_DPad_Up' && isLickPressed))
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "core=" $ coreMesh);
			pushJar();
		}

		if( newKey == 'FIVE' || (newKey == 'XboxTypeS_DPad_Down' && isLickPressed))
		{
			popJar();
		}

		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			isLickPressed=true;
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			isLickPressed=false;
		}
	}
}

function Actor FindTargetActor()
{
	local vector hitLocation, hitNormal, traceStart, traceEnd;
	local Actor hitActor, actorFound;

	traceStart = gMe.Location;
	traceEnd = traceStart + Normal(Vector(gMe.Rotation))*600;
	//DrawDebugLine (traceStart, traceEnd, 0, 0, 0, true);

	foreach myMut.TraceActors (class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart, gMe.GetCollisionExtent())
	{
		if(GGGoat(hitActor) == gMe)
			continue;

		if(GGScoreActorInterface(hitActor) != none)
		{
			actorFound=hitActor;
			break;
		}
	}

	return actorFound;
}

function pushJar()
{
	local Actor targetActor;
	local vector targetDest;
	local JarObj newObj;

	if(!canSwap)
	{
		return;
	}
	canSwap=false;

	targetActor=gMe.mGrabbedItem;
	if(targetActor == none)
	{
		targetActor=FindTargetActor();
		if(targetActor == none)
		{
			canSwap=true;
			return;
		}
	}
	else
	{
		gMe.DropGrabbedItem();
	}

	gMe.PlaySound(pushSound);

	newObj.act=targetActor;

	//Compute object destination
	targetDest=vect(0, 0, -1000) + (vect(1, 0, 0) * jarStack.Length * 1000) + (vect(0, 1, 0) * offset * 1000);

	//Teleport actor to inventory location
	SetInventoryPhysics(newObj, true);
	targetActor.SetLocation(targetDest);

	jarStack.AddItem(newObj);
	//myMut.WorldInfo.Game.Broadcast(myMut, "push newObj(" $ newObj.act $ ", " $ newObj.phys $ ", " $ newObj.ragdoll $ ")");

	canSwap=true;
}

function popJar()
{
	local Actor targetActor;
	local vector targetDest;
	local JarObj newObj;

	if(!canSwap || jarStack.Length == 0)
	{
		return;
	}
	canSwap=false;
	gMe.PlaySound(popSound);

	newObj=jarStack[jarStack.Length-1];
	targetActor=newObj.act;

	//Compute object destination
	targetDest=GetSpawnLocationForItem(newObj);
	//myMut.WorldInfo.Game.Broadcast(myMut, "targetDest=" $ targetDest);

	//Teleport actor to new location
	targetActor.SetLocation(targetDest);
	if(newObj.comp != none) newObj.comp.SetRBPosition(targetActor.Location);
	SetInventoryPhysics(newObj, false);

	jarStack.RemoveItem(newObj);
	//myMut.WorldInfo.Game.Broadcast(myMut, "pop newObj(" $ newObj.act $ ", " $ newObj.phys $ ", " $ newObj.ragdoll $ ")");

	canSwap=true;
}

function SetInventoryPhysics(out JarObj obj, bool active)
{
	local GGNpc npc;
	local GGPawn gpawn;
	local GGGoat goat;
	local GGKActor kact;

	gpawn=GGPawn(obj.act);
	npc=GGNpc(obj.act);
	goat=GGGoat(obj.act);
	kact=GGKActor(obj.act);

	if(active) obj.oldPhys=obj.act.Physics;

	if(gpawn != none)
	{
		gpawn.mesh.SetHasPhysicsAssetInstance( !active );
		gpawn.mesh.SetNotifyRigidBodyCollision( !active );
		gpawn.mesh.SetTraceBlocking( !active, !active );
		//Manage ragdoll
		if(active)
		{
			obj.oldRagdoll=gpawn.mIsRagdoll;
			obj.comp=gpawn.mesh;
			if(!gpawn.mIsRagdoll)
			{
				gpawn.SetRagdoll(true);
			}
			if(npc != none)
			{
				npc.DisableStandUp( class'GGNpc'.const.SOURCE_INVENTORY );
			}
		}
		else
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, gpawn $ " phys=" $ gpawn.Physics $ ", ragdoll=" $ gpawn.mIsRagdoll);
			gpawn.SetPhysics(PHYS_RigidBody);
			if(npc != none)
			{
				npc.EnableStandUp( class'GGNpc'.const.SOURCE_INVENTORY );
			}
			//myMut.WorldInfo.Game.Broadcast(myMut, gpawn $ " phys=" $ gpawn.Physics $ ", oldRagdoll=" $ obj.oldRagdoll);
			if(!obj.oldRagdoll && gpawn.mIsRagdoll)
			{
				if(npc != none)
				{
					if(GGAIController(npc.Controller) != none)
					{
						GGAIController(npc.Controller).StandUp();
					}
					if(npc.mIsRagdoll)
					{
						npc.StandUp();
					}
				}
				else if(goat != none)
				{
					goat.StandUp();
				}
			}

			if(!gpawn.mIsRagdoll)
			{
				gpawn.SetPhysics(PHYS_Falling);
			}
		}
	}
	else if(kact != none)
	{
		obj.comp=kact.StaticMeshComponent;
		kact.StaticMeshComponent.SetNotifyRigidBodyCollision( !active );
		kact.StaticMeshComponent.SetTraceBlocking( !active, !active );
		if(!active) kact.SetPhysics(PHYS_RigidBody);
		kact.StaticMeshComponent.SetBlockRigidBody( !active );
		kact.StaticMeshComponent.WakeRigidBody();
	}
	else
	{
		//Manage collisions
		if(active)
		{
			obj.comp=obj.act.CollisionComponent;
		}
		else
		{
			obj.act.SetPhysics( obj.oldPhys );
		}

		if(GGInterpActor(obj.act) == none)//Haxx to preven interpactors from losing collisions
		{
			obj.comp.SetNotifyRigidBodyCollision( !active );
			obj.comp.SetTraceBlocking( !active, !active );
			obj.comp.SetBlockRigidBody( !active );
		}
	}

	if(active) obj.act.SetPhysics( PHYS_None );

	if(GGInterpActor(obj.act) == none) obj.act.SetCollision( !active, !active );

	if(active)
	{
		obj.oldCollideWorld = obj.act.bCollideWorld;
		obj.act.bCollideWorld = false;
	}
	else
	{
		obj.act.bCollideWorld = obj.oldCollideWorld;
	}

	obj.act.SetHidden(active);
}

function vector GetSpawnLocationForItem( JarObj item )
{
	local GGGoat goat;
	local Actor itemActor, hitActor;
	local vector spawnLocation, spawnDir, itemExtent, itemExtentOffset, traceStart, traceEnd, traceExtent, hitLocation, hitNormal;
	local float itemExtentCylinderRadius;
	local box itemBoundingBox;

	spawnLocation = vect( 0, 0, 0 );

	goat = gMe;
	itemActor = item.act;
	if( goat != none && itemActor != none )
	{
		if( goat.Mesh.GetSocketByName( 'headSocket' ) != none )
		{
			goat.mesh.GetSocketWorldLocationAndRotation( 'headSocket', spawnLocation  );
		}
		else
		{
			// Avoid putting the stuff in origo.
			spawnLocation = goat.Location;
		}

		spawnDir = vector( goat.Rotation );

		itemActor.GetComponentsBoundingBox( itemBoundingBox );

		itemExtent = ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f;
		itemExtentOffset = itemBoundingBox.Min + ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f - itemActor.Location;
		itemExtentCylinderRadius = Sqrt( itemExtent.X * itemExtent.X + itemExtent.Y * itemExtent.Y );

		// Now try fit the thingy into the world.
		// Trace forward.
		traceStart = spawnLocation;
		traceEnd = spawnLocation + spawnDir * itemExtentCylinderRadius * 2.0f;

		hitActor = myMut.Trace( hitLocation, hitNormal, traceEnd, traceStart, false );
		if( hitActor == none )
		{
			hitLocation = traceEnd;
		}

		spawnLocation = hitLocation - spawnDir * itemExtentCylinderRadius;

		//DrawDebugLine( traceStart, traceEnd, 255, 0, 0, true );
		//DrawDebugSphere( hitLocation, 10.0f, 16, 255, 0, 0, true );
		//DrawDebugBox( spawnLocation, vect( 10, 10, 10 ), 255, 0, 0, true );

		// Trace downward.
		traceStart = spawnLocation + vect( 0, 0, 1 ) * itemExtent.Z * 2.0f;
		traceEnd = spawnLocation - vect( 0, 0, 1 ) * itemExtent.Z;
		traceExtent = itemExtent;

		hitActor = myMut.Trace( hitLocation, hitNormal, traceEnd, traceStart, false, traceExtent );
		if( hitActor == none )
		{
			hitLocation = traceEnd;
		}

		// The bounding box's location is not the same as the actors location so we need an offset.
		spawnLocation = hitLocation - itemExtentOffset;

		//DrawDebugLine( traceStart, traceEnd, 255, 255, 0, true );
		//DrawDebugSphere( hitLocation, 10.0f, 16, 255, 255, 0, true );
		//DrawDebugBox( spawnLocation, vect( 10, 10, 10 ), 255, 255, 0, true );
		//DrawDebugBox( hitLocation, traceExtent, 255, 255, 255, true );
	}
	else
	{
		`Log( "Bottomless Jar failed to find spawn point for item actor " $ itemActor );
	}

	return spawnLocation;
}

function bool wasActorRagdoll(Actor act)
{
	local GGNpc npc;
	local GGGoat goat;
	local bool wasRagdoll;

	npc=GGNpc(act);
	goat=GGGoat(act);

	wasRagdoll=false;
	if(npc != none && npc.mIsRagdoll)
	{
		wasRagdoll=true;
		npc.CollisionComponent = npc.Mesh;
		npc.SetPhysics( PHYS_Falling );
		npc.SetRagdoll( false );
	}
	if(goat != none && goat.mIsRagdoll)
	{
		wasRagdoll=true;
		goat.CollisionComponent = goat.Mesh;
		goat.SetPhysics( PHYS_Falling );
		goat.SetRagdoll( false );
	}

	return wasRagdoll;
}

function resetActorRagdoll(Actor act, bool wasRagdoll)
{
	local GGNpc npc;
	local GGGoat goat;

	if(!wasRagdoll)
	{
		return;
	}

	npc=GGNpc(act);
	goat=GGGoat(act);

	if(npc != none)
	{
		npc.SetRagdoll( true );
	}
	if(goat != none)
	{
		goat.SetRagdoll( true );
	}
}

defaultproperties
{
	canSwap=true

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Living_Room_01.Mesh.Colored_Vase_01'
		Rotation=(Pitch=-16384, Yaw=0, Roll=0)
	End Object
	jarMesh=StaticMeshComp1

	pushSound=SoundCue'Goat_Sounds.Cue.Effect_builderGoat_removal'
	popSound=SoundCue'Goat_Sounds.Cue.HeadButt_Cue'
}