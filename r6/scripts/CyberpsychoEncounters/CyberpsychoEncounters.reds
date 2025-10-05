import Utils2077.AIUtils.MountEntityToVehicle
import Utils2077.MiscUtils.DelayDaemon
import Utils2077.SpawnUtils.{findValidSpawnPointInCube,
                             GetNearbyVehicleSpawnPoints}
import Utils2077.SpatialUtils.{GetDistrictManager,
                               GetCurrentDistrict,
                               HasSpaceInFrontOfPoint,
                               GetEntitiesInPrism,
                               IsPlayerNearQuestMappin,
                               isPointInAnyLoadedSecurityAreaRadius}

// This is here to prevent police from going ballistic on civs.
@wrapMethod(AIActionHelper)
public final static func TryChangingAttitudeToHostile(owner: ref<ScriptedPuppet>,
                                                      target: ref<GameObject>) -> Bool {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if psychoSys.isCyberpsychoEventInProgress() && owner.IsPrevention() {
        if (target as ScriptedPuppet).IsCivilian() || (target as ScriptedPuppet).IsCrowd() {
            return false;
        };
    };
    return wrappedMethod(owner, target);
};

// This is here to prevent police from going completely nuts on all civs when
// hitting cars while leaving.
@wrapMethod(VehicleComponent)
protected cb func OnGridDestruction(evt: ref<VehicleGridDestructionEvent>) -> Bool {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
        if psychoSys.isCyberpsychoCombatStarted()
        || psychoSys.lastEncounterSeconds < Cast<Uint32>(45) {
            if this.GetVehicle().IsPrevention() && evt.rammedOtherVehicle {
                return false;
            };
        };
    return wrappedMethod(evt);
};

// This is here to redirect maxtac fear event to psycho instead of the player.
@wrapMethod(PsychoSquadAvHelperClass)
private final func OnMaxTacFearEventDelayed(evt: ref<MaxTacFearEvent>) -> Void {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    if psychoSys.isCyberpsychoCombatStarted() {
        let psycho = GameInstance.FindEntityByID(gi, psychoSys.cyberpsychoID) as GameObject;
        evt.player = psycho;
    };
    wrappedMethod(evt);
};

// This is here to stop maxtac from automatically turning hostile to the player.
@wrapMethod(PsychoSquadAvHelperClass)
public final static func GetOffAV(go: ref<GameObject>) -> Void {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    let gi: GameInstance = GetGameInstance();
    if psychoSys.isCyberpsychoCombatStarted() {
        let psycho = GameInstance.FindEntityByID(gi, psychoSys.cyberpsychoID) as GameObject;
        psychoSys.GetOffAVPsycho(psycho, go);
        return;
    };
    wrappedMethod(go);
};

// This is here to redirect detection from the player to the cyberpsycho.
@wrapMethod(DetectPlayerFromAV)
protected func Activate(context: ScriptExecutionContext) -> Void {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    let gi: GameInstance = GetGameInstance();
    let av: ref<GameObject> = ScriptExecutionContext.GetOwner(context);
    if psychoSys.isCyberpsychoCombatStarted() {
        let cyberpsycho = GameInstance.FindEntityByID(gi, psychoSys.cyberpsychoID) as ScriptedPuppet;
        psychoSys.MaxtacDetectPsychoFromAV(av, cyberpsycho);
        return;
    };
    wrappedMethod(context);
};

// This is here to redirect the maxtac's threat injection
// to the cyberpsycho instead of player
@wrapMethod(RegisterPsychoSquadPassengers)
protected func Activate(context: ScriptExecutionContext) -> Void {
    let go: ref<GameObject> = ScriptExecutionContext.GetOwner(context);
    let gi: GameInstance = go.GetGame();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    let i: Int32;
    let passenger: wref<ScriptedPuppet>;
    let passengers: array<wref<GameObject>>;
    let gi: GameInstance = go.GetGame();
    let id: EntityID = go.GetEntityID();
    if psychoSys.isCyberpsychoCombatStarted() {
        VehicleComponent.GetAllPassengers(gi, id, false, passengers);
        i = 0;
        while i < ArraySize(passengers) {
          passenger = passengers[i] as ScriptedPuppet;
          passenger.TryRegisterToPrevention();
          i += 1;
        };
        return;
    };
    wrappedMethod(context);
};

// This is here to manage visbility of the psycho's stealth mappin
// so that it doesn't z tear with the actual cyberpsycho mappin.
@wrapMethod(MinimapStealthMappinController)
protected func Update() -> Void {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    let cyberpsychoID = psychoSys.cyberpsychoID;
    if (this.m_mappin as StealthMappin).GetGameObject().GetEntityID() == cyberpsychoID {
        if !psychoSys.isCyberpsychoDefeated() {
            this.SetForceShow(false);
            this.SetForceHide(true);
            return;
        } else {
            this.SetForceShow(true);
            this.SetForceHide(false);
        };
    };
    wrappedMethod();
};

//Here to prevent police from being aggro'd by player when shot during psycho
//event
@wrapMethod(StealthMappinController)
private final func UpdateNPCDetection(percent: Float) -> Void {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    let preventionSys = GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem;
    if psychoSys.isCyberpsychoCombatStarted() {
        if this.m_ownerNPC.IsPrevention()
        && Equals(preventionSys.GetHeatStage(), EPreventionHeatStage.Heat_0) {
            this.m_isInCombatWithPlayer = false;
        };
    };
    wrappedMethod(percent);
};

// see the big-brained stuff in StealthMappinController.UpdateNPCDetection to
// understand why this is necessary.
@wrapMethod(StealthMappinController)
private final func UpdateNameplateColor(isHostile: Bool) -> Void {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    let preventionSys = GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem;
    if psychoSys.isCyberpsychoCombatStarted() {
        if isHostile
        && this.m_ownerNPC.IsPrevention()
        && Equals(preventionSys.GetHeatStage(), EPreventionHeatStage.Heat_0) {
            return;
        };
    };
    wrappedMethod(isHostile);
};

// FIXME This is a workaround to a bug where spawned police turn
// hostile to the player if the cyberpsycho detects the player. 
// Technically works but a real fix should be found.
@wrapMethod(TargetTrackingExtension)
protected cb func OnEnemyThreatDetected(th: ref<EnemyThreatDetected>) -> Bool {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if psychoSys.isCyberpsychoCombatStarted() {
        if (th.threat as ScriptedPuppet).IsPlayer()
        && (th.owner as ScriptedPuppet).IsPrevention() {
            return false;
        };
    };
    return wrappedMethod(th);
}

// When Prevention units are spawned in they something causes all commands to be
// cancelled and this join traffic function is started. This is here to prevent
// that when spawning in the police convoy.
@wrapMethod(JoinTrafficInPoliceVehicle)
protected func Activate(context: ScriptExecutionContext) -> Void {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if psychoSys.isCyberpsychoCombatStarted() {
        let vehID = this.m_vehicle.GetEntityID();
        for squad in psychoSys.groundPoliceSquads {
            if squad[0] == vehID {
                return;
            };
        };
        return;
    };
    wrappedMethod(context);
};

// This is here so that the custom cyberpsycho map pin can be registered.
@wrapMethod(MinimapContainerController)
public func CreateMappinUIProfile(mappin: wref<IMappin>,
                                  mappinVariant: gamedataMappinVariant, 
                                  customData: ref<MappinControllerCustomData>) -> MappinUIProfile {
    let UIProfile = wrappedMethod(mappin, mappinVariant, customData);
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if Equals(mappin.GetNewMappinID(), psychoSys.cyberpsychoMappinID) {
        return MappinUIProfile.Create(r"base\\gameplay\\gui\\widgets\\minimap\\minimap_world_encounter_mappin.inkwidget",
                                      t"MappinUISpawnProfile.WorldEncounter",
                                      t"MinimapMappinUIProfile.CyberpsychoEncountersEvent");
    };
    return UIProfile;
};

// This is here to prevent the cyberpsycho from idling and standing in place
// when they run out of targets.
@wrapMethod(NPCStatesComponent)
private final func ChangeHighLevelState(newState: gamedataNPCHighLevelState) -> Void {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if psychoSys.isCyberpsychoEventInProgress()
    && (this.GetOwner() as ScriptedPuppet).GetEntityID() == psychoSys.cyberpsychoID
    && Equals(newState, gamedataNPCHighLevelState.Relaxed) {
        return;
    };
    wrappedMethod(newState);
};

// This is here to prevent the cyberpsycho from idling and standing in place
// when they run out of targets.
@wrapMethod(StackRelaxedState)
public func GetDesiredHighLevelState(context: ScriptExecutionContext) -> gamedataNPCHighLevelState {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if psychoSys.isCyberpsychoEventInProgress()
    && context.GetOwner().GetEntityID() == psychoSys.cyberpsychoID {
        return gamedataNPCHighLevelState.Alerted;
    };
    return gamedataNPCHighLevelState.Relaxed;
}

// This is here to prevent the cyberpsycho from idling and standing in place
// when they run out of targets.
@wrapMethod(RelaxedState)
public func GetDesiredHighLevelState(context: ScriptExecutionContext) -> gamedataNPCHighLevelState {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if psychoSys.isCyberpsychoEventInProgress()
    && context.GetOwner().GetEntityID() == psychoSys.cyberpsychoID {
        return gamedataNPCHighLevelState.Alerted;
    };
    return gamedataNPCHighLevelState.Relaxed;
}

// This is here to prevent cyberpsycho from idling in place if there's no
// nearby targets.
@wrapMethod(NPCPuppet)
public final static func ChangeHighLevelState(obj: ref<GameObject>,
                                              newState: gamedataNPCHighLevelState) -> Void {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if psychoSys.isCyberpsychoEventInProgress()
    && Equals(newState, gamedataNPCHighLevelState.Relaxed)
    && obj.GetEntityID() == psychoSys.cyberpsychoID
    && Equals(newState, gamedataNPCHighLevelState.Relaxed) {
        return;
    };
    wrappedMethod(obj, newState);
};

// This is here to prevent civs from attacking
// the player when a cyberpsycho attack is underway.
@wrapMethod(ReactionManagerComponent)
private final func ShouldTriggerAggressiveCrowdNPCCombat(stimEvent: ref<StimuliEvent>) -> Bool {
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(GetGameInstance());
    if psychoSys.isCyberpsychoEventInProgress() && !psychoSys.isCyberpsychoDefeated() {
        return false;
    };
    return wrappedMethod(stimEvent);
};

// This is here so that the cyberpsycho can't immediately get taken out by
// a panic driving civ.
@wrapMethod(DamageSystem)
private final func ProcessVehicleHit(hitEvent: ref<gameHitEvent>) -> Void {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    let vehicleHitEvent: ref<gameVehicleHitEvent> = hitEvent as gameVehicleHitEvent;
    wrappedMethod(hitEvent);
    if IsDefined(vehicleHitEvent)
    && psychoSys.isCyberpsychoEventInProgress()
    && hitEvent.target == GameInstance.FindEntityByID(gi, psychoSys.cyberpsychoID) {
        hitEvent.attackComputed.MultAttackValue(0.10);
    };
};

// This is here so that players cannot just go on a rampage without police
// responding.
@wrapMethod(ScriptedPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    if !psychoSys.isCyberpsychoCombatStarted() || psychoSys.isCyberpsychoDefeated() {
        return wrappedMethod(evt);
    };

    if evt.instigator.IsPlayer() {
        let isCiv = this.IsCivilian();
        let isPolice = this.IsPrevention();
        if isCiv {
           psychoSys.playerCivsKilled += Cast<Uint8>(1u);
        } else {
            if isPolice {
                psychoSys.playerCopsKilled += Cast<Uint8>(1u);
            };
        };

        if psychoSys.playerCivsKilled > Cast<Uint8>(1u)
        || psychoSys.playerCopsKilled > Cast<Uint8>(0u) {
            let preventionSys = GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem;
            preventionSys.TogglePreventionSystem(true);
            preventionSys.ChangeHeatStage(EPreventionHeatStage.Heat_3, "EnterCombat");
        };
    };
    return wrappedMethod(evt);
};

// This is here so that players cannot just go on a rampage during psycho events
// without police responding.
@wrapMethod(ScriptedPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    if !psychoSys.isCyberpsychoCombatStarted() || psychoSys.isCyberpsychoDefeated() {
        return wrappedMethod(evt);
    };

    let attackData = evt.attackData;
    if attackData.instigator.IsPlayer() {
        let isPolice = this.IsPrevention();
        let attackType = attackData.attackType;

        if !isPolice {
            return wrappedMethod(evt);
        };

        psychoSys.playerCopHitCount += Cast<Uint8>(1u);
        if psychoSys.playerCopHitCount > Cast<Uint8>(3)
        || AttackData.IsHack(attackType)
        || attackData.minimumHealthPercent > 60.00  {
            let preventionSys = GameInstance.GetScriptableSystemsContainer(gi).Get(n"PreventionSystem") as PreventionSystem;
            preventionSys.TogglePreventionSystem(true);
            GameInstance.GetPreventionSpawnSystem(gi).TogglePreventionActive(true);
            preventionSys.ChangeHeatStage(EPreventionHeatStage.Heat_3, "EnterCombat");
        };
    };
    return wrappedMethod(evt);
};

// This is here to prevent police from reacting to all player hits.
@wrapMethod(PreventionSystem)
public final static func ShouldPreventionSystemReactToDamageDealt(puppet: wref<ScriptedPuppet>) -> Bool {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    if psychoSys.isCyberpsychoCombatStarted() && !psychoSys.isCyberpsychoDefeated() {
        return false;
    };
    return wrappedMethod(puppet);
};

// This is here to prevent police from going ballistic on all nearby civs.
@wrapMethod(GameObject)
public final static func ChangeAttitudeToHostile(owner: wref<GameObject>,
                                                 target: wref<GameObject>) -> Void {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    if psychoSys.isCyberpsychoEventInProgress()
    && owner.IsPrevention()
    && (target as ScriptedPuppet).IsCivilian() {
        return;
    };
    wrappedMethod(owner, target);
};

@addMethod(GameInstance)
public final static func GetCyberpsychoEncountersSystem(self: GameInstance) -> ref<CyberpsychoEncountersEventSystem> {
    let container = GameInstance.GetScriptableSystemsContainer(self);
    return container.Get(n"CyberpsychoEncountersEventSystem") as CyberpsychoEncountersEventSystem;
};

struct CyberpsychoEncountersSpawnPointSearchParams {
    let search_size: Float;
    let sector_size: Float;
    let deadzone: Float;
}

struct CyberpsychoEncountersDistrictPoliceDelays {
    let ncpdDelay: Int16;
    let maxtacDelay: Int16;
}

/*
struct CyberpsychoEncountersDaemonEvent {
    let sender: ref<CyberpsychoEncountersDaemonEvent>;
}
*/
struct CyberpsychoEncountersEventRequest {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
}

struct CyberpsychoEncountersPsychoAttachedEvent { //extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let cyberpsycho: ref<NPCPuppet>;
    let isFirstAttach: Bool;
}

struct CyberpsychoEncountersPsychoDetatchedEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let cyberpsychoID: EntityID;
}
struct CyberpsychoEncountersEventStartedEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let psychoID: EntityID;
    let isHeatActive: Bool;
}

struct CyberpsychoEncountersNewTargetsRequestedEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let cyberpsycho: ref<NPCPuppet>;
}

struct CyberpsychoEncountersPsychoCombatStartedEvent{//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let cyberpsycho: ref<NPCPuppet>;
}

struct CyberpsychoEncountersGroundNCPDConvoyRequestedEvent {//extends CyberpsychoEncountersDaemonEvent {
}

struct CyberpsychoEncountersGroundNCPDConvoyVehicleAttachedEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let vehicleSquad: array<EntityID>;
}

struct CyberpsychoEncountersGroundNCPDConvoyVehicleArrivedEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let vehicleSquad: array<EntityID>;
}

struct CyberpsychoEncountersStartMaxtacAVRequest {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayCallback>;
}

struct CyberpsychoEncountersCyberpsychoDeathEvent {
    let cyberpsycho: ref<NPCPuppet>;
}

struct CyberpsychoEncountersPlayerSecondsAwayEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let distance: Float;
}

struct CyberpsychoEncountersUnitsDeletionRequestedEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
    let units: array<EntityID>;
    let allUnitsDeleted: Bool;
}

struct StartCyberpsychoEncountersDaemonEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
}

struct CyberpsychoEncountersGroundNCPDLeaveRequestedEvent {//extends CyberpsychoEncountersDaemonEvent {
    let sender: ref<DelayDaemon>;
}

class CyberpsychoEncountersEventStarterDaemon extends DelayDaemon {

    func Call() -> Void {
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(this.gi);
        let delaySys = GameInstance.GetDelaySystem(this.gi);
        if psychoSys.TryStartNewCyberpsychoEvent() {
            this.Stop();
        } else {
            this.Repeat();
        };
    };
}

class UpdateCyberpsychoEncountersCyberpsychoAttachmentDaemon extends DelayDaemon {
    let cyberpsychoID: EntityID;
    let wasPsychoAttached: Bool = false;
    let isFirstAttach: Bool = true;

    func Call() -> Void {
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(this.gi);
        let delaySys = GameInstance.GetDelaySystem(this.gi);
        let cback_ID: DelayID;
        let psycho = (GameInstance.FindEntityByID(this.gi, this.cyberpsychoID) as NPCPuppet);
        if !IsDefined(psycho) || !psycho.IsAttached() {
            if this.wasPsychoAttached {
                let evt = new CyberpsychoEncountersPsychoDetatchedEvent(this, this.cyberpsychoID);
                evt.sender = this;
                psychoSys.OnCyberpsychoDetached(evt);
                this.wasPsychoAttached = false;
            };
        } else {
            if !this.wasPsychoAttached {
                let evt = new CyberpsychoEncountersPsychoAttachedEvent(this,
                                                                       psycho,
                                                                       this.isFirstAttach);
                evt.sender = this;
                psychoSys.OnCyberpsychoAttached(evt);

                this.isFirstAttach = false;
                this.wasPsychoAttached = true;
            };
        };
        this.Repeat();
    };
}

class UpdateCyberpsychoEncountersTargetsDaemon extends DelayDaemon {
    let cyberpsycho: ref<NPCPuppet>;

    func Call() -> Void {
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(this.gi);
        let delaySys = GameInstance.GetDelaySystem(this.gi);
        let player = GetPlayer(this.gi);
        let psycho = this.cyberpsycho;
        let evt = new CyberpsychoEncountersNewTargetsRequestedEvent(this,
                                                                 this.cyberpsycho);
        psychoSys.SetupNearbyCrowdForCyberpsychoCombat(evt);
        this.Repeat();
    };
}

class CyberpsychoEncountersPsychoCombatStartedDaemon extends DelayDaemon {
    let cyberpsycho: ref<NPCPuppet>;

    func Call() -> Void {
        /* Trying to access NpcStateComponent will crash game if the
           NPC is not attached. */
        if this.cyberpsycho.IsAttached() {
            let psychoStatesComp = this.cyberpsycho.GetStatesComponent();
            let upper_body = psychoStatesComp.GetCurrentUpperBodyState();

            if Equals(upper_body, gamedataNPCUpperBodyState.Attack)
            || Equals(upper_body, gamedataNPCUpperBodyState.ChargedAttack)
            || this.HasCyberpsychoWeaponBeenFired() {
                let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(this.gi);
                let evt = new CyberpsychoEncountersPsychoCombatStartedEvent(this, this.cyberpsycho);
                psychoSys.OnCyberpsychoCombatStarted(evt);
            };
        };
        this.Repeat();
    };

    func HasCyberpsychoWeaponBeenFired() -> Bool {
        return IsDefined(GameObject.GetActiveWeapon(this.cyberpsycho))
        && GameObject.GetActiveWeapon(this.cyberpsycho).GetMagazinePercentage() < 1.00
        && GameObject.GetActiveWeapon(this.cyberpsycho).GetMagazinePercentage() >= 0.00;
    };
}

public class CyberpsychoDeathListener extends ScriptStatPoolsListener {
    public let cyberpsycho: wref<NPCPuppet>;

    protected cb func OnStatPoolAdded() -> Bool {
        let gi: GameInstance = this.cyberpsycho.GetGame();
        let statPoolsSystem = GameInstance.GetStatPoolsSystem(gi);
        let cyberpsycho_stats_ID = Cast<StatsObjectID>(this.cyberpsycho.GetEntityID());
        if this.cyberpsycho.IsDefeatMechanicActive() {
          statPoolsSystem.RequestSettingStatPoolValueCustomLimit(cyberpsycho_stats_ID,
                                                                 gamedataStatPoolType.Health,
                                                                 0.10,
                                                                 null);
        } else {
          statPoolsSystem.RequestSettingStatPoolValueCustomLimit(cyberpsycho_stats_ID,
                                                                 gamedataStatPoolType.Health,
                                                                 0.00,
                                                                 null);
        };
    };

  protected cb func OnStatPoolCustomLimitReached(value: Float) -> Bool {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    let evt = new CyberpsychoEncountersCyberpsychoDeathEvent(this.cyberpsycho);
    psychoSys.OnCyberpsychoIsDead(evt);
  };

  protected cb func OnStatPoolMinValueReached(value: Float) -> Bool {
    let gi: GameInstance = GetGameInstance();
    let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
    if !psychoSys.isCyberpsychoDefeated() {
        let evt = new CyberpsychoEncountersCyberpsychoDeathEvent(this.cyberpsycho);
        psychoSys.OnCyberpsychoIsDead(evt);
    };
  };
}

class CyberpsychoEncountersPlayerSecondsAwayDaemon extends DelayDaemon {
    let psycho_detatched_pos: Vector4;

    func Call() -> Void {
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(this.gi);
        let delaySys = GameInstance.GetDelaySystem(this.gi);
        let player_pos = GetPlayer(this.gi).GetWorldPosition();
        let distance = Vector4.DistanceSquared(player_pos, this.psycho_detatched_pos);
        if distance > 5625.00 { // > 75m
            let evt = new CyberpsychoEncountersPlayerSecondsAwayEvent(this, distance);
            evt.sender = this;
            psychoSys.OnPlayerSecondAway(evt);
        };
        this.Repeat();
    };
}

class CyberpsychoEncountersNCPDGroundPoliceDeletionDaemon extends DelayDaemon {
    let units: array<array<EntityID>>;

    func Call() -> Void {
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(this.gi);
        let units_to_delete: array<EntityID>;
        let player: ref<PlayerPuppet> = GetPlayer(this.gi);
        let player_pos: Vector4 = player.GetWorldPosition();
        let i = 0;
        while i < ArraySize(this.units) {
            let ii = 0;
            while ii < ArraySize(this.units[i]) {
                let unitID = this.units[i][ii];
                let unit: wref<Entity> = GameInstance.FindEntityByID(this.gi,
                                                                     unitID);
                let unit_pos = unit.GetWorldPosition();
                // the Distance check below is because some units do not detach
                // for some reason even though they're very far from the player.
                if !IsDefined(unit)
                || !unit.IsAttached()
                || Vector4.DistanceSquared(player_pos, unit_pos) > 62500.00 {
                    ArrayPush(units_to_delete, unitID);
                    ArrayRemove(this.units[i], unitID);
                };
                ii += 1;
            };

            if ArraySize(this.units[i]) == 0 {
                ArrayRemove(this.units, this.units[i]);
            };

            i += 1;
        };

        if ArraySize(units_to_delete) > 0 {
            let all_units_deleted: Bool;
            FTLog(s"[CyberpsychoEncountersNCPDGroundPoliceDeletionDaemon][Call]: Deleting units: \(units_to_delete)");
            if ArraySize(this.units) == 0 {
                all_units_deleted = true;
                FTLog(s"[CyberpsychoEncountersNCPDGroundPoliceDeletionDaemon][Call]: All units deleted");
            };
            let evt = new CyberpsychoEncountersUnitsDeletionRequestedEvent(this,
                                                                        units_to_delete,
                                                                        all_units_deleted);
            evt.sender = this;
            psychoSys.OnGroundNCPDUnitsDeletionRequested(evt);
        };
        this.Repeat();
    };

}

class CyberpsychoEncountersLastEncounterSecondsDaemon extends DelayDaemon {

    func Start(gi: GameInstance, opt isAffectedByTimeDilation: Bool) -> Void {
        super.Start(gi, 120.00, isAffectedByTimeDilation);
    };

    func Call() -> Void {
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(this.gi);
        let delaySys = GameInstance.GetDelaySystem(this.gi);
        let district_name = GetCurrentDistrict().GetDistrictRecord().EnumName();
        let cooldown_seconds = psychoSys.GetCooldownSeconds();
        psychoSys.AddlastEncounterSeconds(120u);
        FTLog(s"[CyberpsychoEncountersLastEncounterSecondsDaemon][Call]: seconds: \(psychoSys.lastEncounterSeconds)");
        FTLog(s"[CyberpsychoEncountersLastEncounterSecondsDaemon][Call]: cooldown seconds: \(cooldown_seconds)");
        if psychoSys.lastEncounterSeconds > cooldown_seconds
        && psychoSys.ShouldStartCyberpsychoEvent() {
            let req = new CyberpsychoEncountersEventRequest(this);
            req.sender = this;
            psychoSys.RequestStartCyberpsychoEvent(req);
        };
        this.Repeat();
    };
}

class CyberpsychoEncountersDelayPreventionSystemToggledCallback extends DelayCallback {
    let toggle: Bool;

    func Call() -> Void {
        let gi: GameInstance = GetGameInstance();
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        preventionSys.TogglePreventionSystem(this.toggle);
    };
}

class CyberpsychoEncountersConvoyVehicleAttachmentDaemon extends DelayDaemon {
    let vehicleSquad: array<EntityID>;
    let isAttached: Bool = false;

    func Call() -> Void {
        let gi: GameInstance = GetGameInstance();
        let vehicleID = this.vehicleSquad[0];
        let veh_obj = GameInstance.FindEntityByID(gi, vehicleID) as WheeledObject;
        let delaySys = GameInstance.GetDelaySystem(gi);
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        if !IsDefined(veh_obj) {
            this.Repeat();
            return;
        };
        let evt = new CyberpsychoEncountersGroundNCPDConvoyVehicleAttachedEvent(this, this.vehicleSquad);
        psychoSys.OnGroundNCPDConvoyVehicleAttached(evt);
    };
}

class StartRandomCyberpsychoGroundNCPDResponseCallback extends DelayCallback {

    func Call() -> Void {
        let gi: GameInstance = GetGameInstance();
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
        psychoSys.TryStartGroundNCPDResponse();
    };
}

class CyberpsychoEncountersConvoyVehicleArrivalDaemon extends DelayDaemon  {
    let cyberpsycho: ref<NPCPuppet>;
    let vehicleSquad: array<EntityID>;

    func Call() -> Void {
        let gi: GameInstance = GetGameInstance();
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
        let delaySys = GameInstance.GetDelaySystem(gi);
        let vehID = this.vehicleSquad[0];
        let veh_obj = GameInstance.FindEntityByID(gi, vehID) as VehicleObject;
        let veh_pos = veh_obj.GetWorldPosition();
        let psycho_pos = this.cyberpsycho.GetWorldPosition();
        if IsDefined(veh_obj)
        && Vector4.DistanceSquared(veh_pos, psycho_pos) < 5625.00 {
            let evt = new CyberpsychoEncountersGroundNCPDConvoyVehicleArrivedEvent(this, this.vehicleSquad);
            evt.sender = this;
            evt.vehicleSquad = this.vehicleSquad;
            psychoSys.OnGroundNCPDVehicleHasArrived(evt);
        };
        this.Repeat();
    };
}

class StartCyberpsychoEncountersMaxtacAVResponseCallback extends DelayCallback {

    func Call() -> Void {
        let gi: GameInstance = GetGameInstance();
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
        let evt = new CyberpsychoEncountersStartMaxtacAVRequest(this);
        psychoSys.SpawnMaxTacAV();
    };
}

public class CyberpsychoEncountersEventSystem extends ScriptableSystem {
    let settings: ref<CyberpsychoEncountersSettings>;

    persistent let lastEncounterSeconds: Uint32;

    let districtManager: ref<DistrictManager>;

    let isCyberpsychoEventInProgress: Bool = false;

    let playerSecondsAway: Uint16;

    let playerCivsKilled: Uint8;

    let playerCopsKilled: Uint8;

    let playerCopHitCount: Uint8;

    persistent let groundPoliceSquads: array<array<EntityID>>;

    persistent let isUnitDeletionPending: Bool;

    persistent let cyberpsychoID: EntityID;

    let cyberpsychoMappinID: NewMappinID;

    persistent let cyberpsychoIsDead: Bool = false;

    persistent let isCyberpsychoCombatStarted: Bool = false;

    let lastEncounterSecondsDaemon: ref<CyberpsychoEncountersLastEncounterSecondsDaemon>;

    let eventStarterDaemon: ref<CyberpsychoEncountersEventStarterDaemon>;

    let cyberpsychoAttachmentDaemon: ref<UpdateCyberpsychoEncountersCyberpsychoAttachmentDaemon>;

    let cyberpsychoCombatStartedDaemon: ref<CyberpsychoEncountersPsychoCombatStartedDaemon>;

    let cyberpsychoTargetDaemon: ref<UpdateCyberpsychoEncountersTargetsDaemon>;

    let cyberpsychoDeathListener: ref<CyberpsychoDeathListener>;

    let playerSecondsAwayDaemon: ref<CyberpsychoEncountersPlayerSecondsAwayDaemon>;

    private func OnAttach() -> Void {
        //ModSettings.RegisterListenerToClass(this);
        ModSettings.RegisterListenerToModifications(this);
    };


    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
        let gi: GameInstance = GetGameInstance();
        this.settings = new CyberpsychoEncountersSettings();
        this.districtManager = GetDistrictManager();
        FTLog(s"[CyberpsychoEncountersEventSystem][OnRestored]: Units pending deletion? \(this.isUnitDeletionPending)");
        if this.isUnitDeletionPending {
            let deletionDaemon = new CyberpsychoEncountersNCPDGroundPoliceDeletionDaemon();
            deletionDaemon.units = this.groundPoliceSquads;
            deletionDaemon.Start(gi, 1.00, false);
        };
        if EntityID.IsDefined(this.cyberpsychoID) {
            let psycho = GameInstance.FindEntityByID(gi, this.cyberpsychoID);
            FTLog("[CyberpsychoEncountersEventSystem][OnRestored]: Leftover psycho defined, creating deletion daemon.");
            let attachmentDaemon = new UpdateCyberpsychoEncountersCyberpsychoAttachmentDaemon();
            attachmentDaemon.cyberpsychoID = this.cyberpsychoID;
            attachmentDaemon.isFirstAttach = false;
            attachmentDaemon.wasPsychoAttached = true;
            attachmentDaemon.Start(gi, 0.10, false);
            this.cyberpsychoAttachmentDaemon = attachmentDaemon;
        };
        this.StartNewMinutesSinceLastEncounterCallback();
    };

    private func OnDetatch() -> Void {
    };

    public cb func OnModSettingsChange() -> Void {
        this.settings = new CyberpsychoEncountersSettings();
        //this.OnCooldownMinutesChanged();
    };

    func GetFrequencyMultiplier() -> Float {
        return this.settings.encounterMultiplier;
    };

    func OnFrequencyMultiplierChanged(new_val: Float) -> Void {
        //this.encounterMultiplier = new_val;
        this.settings.encounterMultiplier = new_val;
    };

    func GetEncounterMultiplier() -> Float {
        if this.settings.encounterMultiplier == 0.00 {
            return 1.00;
        };

        return this.settings.encounterMultiplier;
    };

    func GetCooldownSeconds() -> Uint32 {
        if this.settings.cooldownMinutes == 0 {
            return 300u;
        };
        return Cast<Uint32>(this.settings.cooldownMinutes) * 60u;
    };

    func GetCivilianClosestToCyberpsycho(cyberpsycho: ref<NPCPuppet>,
                                         max_distance: Float) -> ref<Entity> {
        let gi: GameInstance = GetGameInstance();
        let cyberpsychoID = cyberpsycho.GetEntityID();
        let psycho_pos = cyberpsycho.GetWorldPosition();
        let psycho_xform = cyberpsycho.GetWorldTransform();

        let psycho_front = (psycho_xform.GetForward() * max_distance);
        let psycho_right = (psycho_xform.GetRight() * max_distance);
        let psycho_front_left = (psycho_pos + psycho_front) - psycho_right;
        let psycho_front_right = (psycho_pos + psycho_front) + psycho_right;
        let psycho_back_left = (psycho_pos - psycho_front) - psycho_right;
        let psycho_back_right = (psycho_pos - psycho_front) + psycho_right;
        let query_box: array<Vector2> = [Vector4.Vector4To2(psycho_front_left),
                                         Vector4.Vector4To2(psycho_front_right),
                                         Vector4.Vector4To2(psycho_back_left),
                                         Vector4.Vector4To2(psycho_back_right)];
        let ents = GetEntitiesInPrism(GameInstance.GetEntityList(gi),
                                      query_box,
                                      psycho_pos.Z - 20.00,
                                      psycho_pos.Z + 20.00,
                                      99999,
                                      [n"ScriptedPuppet", n"vehicleCarBaseObject"]);
        let closest_ent: wref<Entity>;
        let closest_ent_distance: Float = 999999.00;
        for e in ents {
            let eID = e.GetEntityID();
            if eID != cyberpsychoID && !(e as GameObject).IsPlayer() {
                let this_ent_distance = Vector4.DistanceSquared(psycho_pos, e.GetWorldPosition());
                let ent_as_puppet: wref<ScriptedPuppet> = (e as ScriptedPuppet);
                let ent_as_car: wref<CarObject> = (e as CarObject);
                if this_ent_distance < closest_ent_distance {
                    if IsDefined(ent_as_puppet) && !ent_as_puppet.IsPlayer() && ent_as_puppet.IsActive() {
                        closest_ent = e;
                        closest_ent_distance = this_ent_distance;
                    } else {
                        if IsDefined(ent_as_car) {
                            let passengers: array<wref<GameObject>>;
                            VehicleComponent.GetAllPassengers(gi, eID, false, passengers);
                            for p in passengers {
                                if p.IsActive() {
                                    closest_ent = p;
                                    closest_ent_distance = this_ent_distance;
                                    break;
                               };
                            };
                        };
                    };
                };
            };
        };

        return closest_ent;
    };

    func RequestStartCyberpsychoEvent(req: CyberpsychoEncountersEventRequest) -> Void {
        let gi: GameInstance = GetGameInstance();
        req.sender.Stop();
        FTLog("[CyberpsychoEncountersEventSystem][RequestStartCyberpsychoEvent]: New event requested");
        let starter = new CyberpsychoEncountersEventStarterDaemon();
        starter.Start(gi, 1.00, false);
    };

    func TryStartNewCyberpsychoEvent() -> Bool {
        FTLog("[CyberpsychoEncountersEventSystem][TryStartNewCyberpsychoEvent]: Starting new cyberpsycho event.");
        let gi: GameInstance = GetGameInstance();
        let player = GetPlayer(gi);
        let delaySys = GameInstance.GetDelaySystem(gi);
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        let district_name = GetCurrentDistrict().GetDistrictRecord().EnumName();
        let center: Vector4 = player.GetWorldPosition();
        let player_vehicle = player.GetMountedVehicle() as VehicleObject;
        if this.isCyberpsychoEventInProgress {
            FTLogError("[CyberpsychoEncountersEventSystem][TryStartNewCyberpsychoEvent]: TRIED TO START PSYCHO EVENT WHEN PSYCHO EVENT STILL IN PROGRESS");
            return false;
        };

        if EntityID.IsDefined(this.cyberpsychoID) {
            FTLogWarning("[CyberpsychoEncountersEventSystem][TryStartNewCyberpsychoEvent]: TRIED TO START PSYCHO EVENT WHEN PREVIOUS CYBERPSYCHO STILL DEFINED");
            return false;
        };

        if this.isUnitDeletionPending {
            return false;
        };

        let scene_tier = PlayerPuppet.GetSceneTier(player);
        if scene_tier != 1 {
            return false;
        };

        if player_vehicle.IsInAir() {
            return false;
        };

        if IsDefined(player_vehicle) {
            let speed = player_vehicle.GetCurrentSpeed();
            FTLog(s"[CyberpsychoEncountersEventSystem][TryStartNewCyberpsychoEvent]: player in moving vehicle, speed: \(speed))");
            if speed > AbsF(0.01) {
                /* GetCyberpsychoSpawnPoint calls
                   AINavigationSystemd.FindPointInBoxForCharacter to find start
                   points but the function will return all zero'd vectors if the
                   player is in a car that's moving. */
                return false;
                //let offsetDist = LerpF(speed / 30.00, 20.00, 60.00, true);
                //center = (center + offsetDist) * player_vehicle.GetWorldForward();
            };
        };

        let psycho_spawn_point = this.getCyberpsychoSpawnPoint(center, district_name);
        if Vector4.IsXYZZero(psycho_spawn_point) {
            return false;
        };

        let cyberpsychoSpec = this.GetCyberpsychoEntitySpec(district_name);
        cyberpsychoSpec.position = psycho_spawn_point;

        SaveLocksManager.RequestSaveLockAdd(gi, n"CyberpsychoEncountersEventInProgress");
        FastTravelSystem.AddFastTravelLock(n"CyberpsychoEncountersEventInProgress", gi);
        let district_name = GetCurrentDistrict().GetDistrictRecord().EnumName();
        FTLog(s"[CyberpsychoEncountersEventSystem][TryStartNewCyberpsychoEvent]: Starting cyberpsycho event: \(district_name)");

        let attachmentDaemon = new UpdateCyberpsychoEncountersCyberpsychoAttachmentDaemon();
        let psychoID = this.SpawnCyberpsycho(cyberpsychoSpec);
        FTLog(s"[CyberpsychoEncountersEventSystem][TryStartNewCyberpsychoEvent]: Cyberpsycho entity ID: \(psychoID)");
        attachmentDaemon.cyberpsychoID = psychoID;
        this.cyberpsychoID = psychoID;
        attachmentDaemon.Start(gi, 0.10, false);
        this.cyberpsychoAttachmentDaemon = attachmentDaemon;
        this.lastEncounterSecondsDaemon.Stop();
        return true;
    };

    func SpawnCyberpsycho(psycho_spec: ref<DynamicEntitySpec>) -> EntityID {
        let gi: GameInstance = GetGameInstance();
        let delaySys = GameInstance.GetDelaySystem(gi);
        let dynamicEntSys = GameInstance.GetDynamicEntitySystem();
        return dynamicEntSys.CreateEntity(psycho_spec);
    };

    func OnCyberpsychoFirstAttached(evt: CyberpsychoEncountersPsychoAttachedEvent) -> Void {
        let gi: GameInstance = GetGameInstance();
        let delaySys = GameInstance.GetDelaySystem(gi);
        let cyberpsycho = evt.cyberpsycho;
        let cyberpsycho_tt = cyberpsycho.GetTargetTrackerComponent();
        this.cyberpsychoIsDead = false;
        this.isCyberpsychoEventInProgress = true;
        cyberpsycho_tt.SetThreatBaseMul(GetPlayer(gi), 5.00);
        NPCPuppet.ChangeHighLevelState(cyberpsycho,
                                       gamedataNPCHighLevelState.Alerted);
        StimBroadcasterComponent.BroadcastStim(cyberpsycho,
                                               gamedataStimType.SpreadFear,
                                               10.00);
        let closest_ent = this.GetCivilianClosestToCyberpsycho(evt.cyberpsycho, 30.00);
        let closest_as_veh = closest_ent as VehicleObject;
        if IsDefined(closest_as_veh) {
            this.SetupCrowdVehiclePassengersForPsychoCombat(closest_as_veh,
                                                            evt.cyberpsycho,
                                                            false);
        } else {
            let closest_as_puppet = closest_ent as ScriptedPuppet;
            if IsDefined(closest_as_puppet) {
                closest_as_puppet.GetSensesComponent().IgnoreLODChange(true);
                this.TrySettingUpCrowdEntityForPsychoCombat(closest_as_puppet,
                                                            cyberpsycho,
                                                            false);
                TargetTrackingExtension.InjectThreat(cyberpsycho,
                                                      closest_ent,
                                                      0.01,
                                                      -1.00);
            };
        };

        let psychoTargetsDaemon = new UpdateCyberpsychoEncountersTargetsDaemon();
        psychoTargetsDaemon.cyberpsycho = evt.cyberpsycho;
        this.cyberpsychoTargetDaemon = psychoTargetsDaemon;
        psychoTargetsDaemon.Start(gi, 0.10, false);

        let psychoCombatDaemon = new CyberpsychoEncountersPsychoCombatStartedDaemon();
        psychoCombatDaemon.cyberpsycho = evt.cyberpsycho;
        psychoCombatDaemon.Start(gi, 0.10, true);
    };

    func RegisterPsychoMappin(cyberpsycho: ref<NPCPuppet>) -> NewMappinID {
        let mappinSys = GameInstance.GetMappinSystem(GetGameInstance());
        let pin_data = new MappinData();
        let dummy_v3: Vector3;
        pin_data.mappinType = t"Mappins.CyberpsychoEncounters_Psycho_Mappin_Definition";
        pin_data.variant = gamedataMappinVariant.HuntForPsychoVariant;
        pin_data.active = true;
        pin_data.visibleThroughWalls = true;
        return mappinSys.RegisterMappinWithObject(pin_data,
                                                  cyberpsycho,
                                                  n"roleMappin",
                                                  dummy_v3);
    };

    func OnCyberpsychoAttached(evt: CyberpsychoEncountersPsychoAttachedEvent) -> Void {
        FTLog("[CyberpsychoEncountersEventSystem][OnCyberpsychoAttached]: Cyberpsycho attached.");
        if evt.isFirstAttach {
            this.OnCyberpsychoFirstAttached(evt);
        };
        let gi: GameInstance = GetGameInstance();
        let delaySys = GameInstance.GetDelaySystem(gi);
        let cyberpsycho_stats_ID = Cast<StatsObjectID>(evt.cyberpsycho.GetEntityID());
        this.cyberpsychoDeathListener = new CyberpsychoDeathListener();
        this.cyberpsychoDeathListener.cyberpsycho = evt.cyberpsycho;
        GameInstance.GetStatPoolsSystem(gi).RequestRegisteringListener(cyberpsycho_stats_ID,
                                                                       gamedataStatPoolType.Health,
                                                                       this.cyberpsychoDeathListener);
        this.cyberpsychoTargetDaemon.Start(GetGameInstance(), 0.10, false);
        // Use the regular stealth loot icon if the psycho is defeated.
        if !this.isCyberpsychoDefeated() {
            this.cyberpsychoMappinID = this.RegisterPsychoMappin(evt.cyberpsycho);
        };
        if IsDefined(this.playerSecondsAwayDaemon) {
            this.playerSecondsAwayDaemon.Stop();
        };
        this.playerSecondsAway = Cast<Uint16>(0u);
    };

    func StartPsychoCombatWithNearbyPreventionUnits(cyberpsycho: ref<NPCPuppet>) -> Void {
        let gi: GameInstance = GetGameInstance();
        let magnitude = 150.00;
        let psycho_xform = cyberpsycho.GetWorldTransform();
        let psycho_pos = psycho_xform.GetWorldPosition().ToVector4();
        let psycho_front = (psycho_xform.GetForward() * magnitude);
        let psycho_right = (psycho_xform.GetRight() * magnitude);
        let psycho_front_left = (psycho_pos + psycho_front) - psycho_right;
        let psycho_front_right = (psycho_pos + psycho_front) + psycho_right;
        let psycho_back_left = (psycho_pos - psycho_front) - psycho_right;
        let psycho_back_right = (psycho_pos - psycho_front) + psycho_right;
        let query_box: array<Vector2> = [Vector4.Vector4To2(psycho_front_left),
                                         Vector4.Vector4To2(psycho_front_right),
                                         Vector4.Vector4To2(psycho_back_left),
                                         Vector4.Vector4To2(psycho_back_right)];

        let ents = GetEntitiesInPrism(GameInstance.GetEntityList(gi),
                                      query_box,
                                      psycho_pos.Z - 20.00,
                                      psycho_pos.Z + 20.00,
                                      99999,
                                      [n"ScriptedPuppet"]);
        for e in ents {
            let e_as_veh: wref<VehicleObject> = e as VehicleObject;
            if IsDefined(e_as_veh) {
                this.SetupCrowdVehiclePassengersForPsychoCombat(e_as_veh,
                                                                cyberpsycho,
                                                                true);
            } else {
                this.TrySettingUpPreventionPuppetForCyberpsychoCombat((e as ScriptedPuppet),
                                                                      cyberpsycho);
            };
        };
    };

    func OnCyberpsychoCombatStarted(evt: CyberpsychoEncountersPsychoCombatStartedEvent) -> Void {
        let gi: GameInstance = GetGameInstance();
        let delaySys = GameInstance.GetDelaySystem(gi);
        let cyberpsycho = evt.cyberpsycho;
        let psychoStimBroadcaster = cyberpsycho.GetStimBroadcasterComponent();
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        evt.sender.Stop();
        this.isCyberpsychoCombatStarted = true;
        if Equals(preventionSys.GetHeatStage(), EPreventionHeatStage.Heat_0) {
            preventionSys.TogglePreventionSystem(false);
        } else {
            if Equals(preventionSys.GetHeatStage(), EPreventionHeatStage.Heat_1) {
                let preventionForceDeescalateRequest: ref<PreventionForceDeescalateRequest>;
                preventionForceDeescalateRequest = new PreventionForceDeescalateRequest();
                let blink_duration = TweakDBInterface.GetFloat(t"PreventionSystem.setup.forcedDeescalationUIStarsBlinkingDurationSeconds", 4.00);
                preventionForceDeescalateRequest.fakeBlinkingDuration = blink_duration;
                preventionForceDeescalateRequest.telemetryInfo = "QuestEvent";
                preventionSys.QueueRequest(preventionForceDeescalateRequest);
                let DisablePreventionCback = new CyberpsychoEncountersDelayPreventionSystemToggledCallback();
                DisablePreventionCback.toggle = false;
                delaySys.DelayCallback(DisablePreventionCback, blink_duration + 0.10, true);
            };
        };
        /* This is here so crowd traffic vehicles will enter panic driving.
           For some strange reason they don't enter panic driving for combat
           or terror stim. */
        this.cyberpsychoMappinID = this.RegisterPsychoMappin(evt.cyberpsycho);
        psychoStimBroadcaster.AddActiveStimuli(cyberpsycho,
                                               gamedataStimType.VehicleHit,
                                               -1.00,
                                               150.00);
        StimBroadcasterComponent.BroadcastStim(cyberpsycho,
                                               gamedataStimType.Terror,
                                               150.00);
        this.StartPsychoCombatWithNearbyPreventionUnits(cyberpsycho);
        let district_name = GetCurrentDistrict().GetDistrictRecord().EnumName();
        let response_delays = this.GetCyberpsychoPoliceResponseDelays(district_name);
        if response_delays.ncpdDelay != Cast<Int16>(-1) {
            let ncpdResponseCback = new StartRandomCyberpsychoGroundNCPDResponseCallback();
            FTLogWarning(s"[CyberpsychoEncountersEventSystem][OnCyberpsychoCombatStarted]: QUEUED POLICE CONVOY RESPONSE IN \(response_delays) SECONDS");
            let ncpd_delay = Cast<Float>(response_delays.ncpdDelay);
            let cback_ID = delaySys.DelayCallback(ncpdResponseCback,
                                                  ncpd_delay,
                                                  true);
        };

        if response_delays.maxtacDelay != Cast<Int16>(-1) {
            let maxtacResponseCback = new StartCyberpsychoEncountersMaxtacAVResponseCallback();
            let maxtac_delay = Cast<Float>(response_delays.maxtacDelay);
            let cback_ID = delaySys.DelayCallback(maxtacResponseCback,
                                                  maxtac_delay,
                                                  true);
        };
    };

    func OnCyberpsychoDetached(evt: CyberpsychoEncountersPsychoDetatchedEvent) -> Void {
        FTLog("[CyberpsychoEncountersEventSystem][OnCyberpsychoDetatched]: Cyberpsycho detatched.");
        let gi: GameInstance = GetGameInstance();
        let mappinSys = GameInstance.GetMappinSystem(gi);
        this.cyberpsychoTargetDaemon.Stop();
        let gi: GameInstance = GetGameInstance();
        let delaySys = GameInstance.GetDelaySystem(gi);
        let playerSecondsAwayDaemon = new CyberpsychoEncountersPlayerSecondsAwayDaemon();
        this.playerSecondsAwayDaemon = playerSecondsAwayDaemon;
        this.playerSecondsAwayDaemon.psycho_detatched_pos = GetPlayer(gi).GetWorldPosition();
        this.playerSecondsAwayDaemon.Start(gi, 1.00, true);
    };

    func CanEntityBeSetupForPsychoCombat(e: wref<Entity>,
                                         cyberpsycho: ref<ScriptedPuppet>) -> Bool {
        if !IsDefined(e) {
            return false;
        };

        return !(e as ScriptedPuppet).GetSensesComponent().IsEnabled()
        && e.IsAttached()
        && !(e as ScriptedPuppet).IsDead()
        && !(e as GameObject).IsPlayer()
        && !(e as GameObject).IsPrevention()
        && !(e as ScriptedPuppet).IsCharacterChildren()
        && ((e as ScriptedPuppet).IsCivilian() || (e as ScriptedPuppet).IsCrowd());
    };

    func TrySettingUpCrowdEntityForPsychoCombat(e: wref<ScriptedPuppet>,
                                                cyberpsycho: ref<ScriptedPuppet>,
                                                shouldWakeUpPrevention: Bool,
                                                opt GroundPoliceConvoy: array<array<EntityID>>) -> Bool {

        if !IsDefined(e) {
            return false;
        };

        if shouldWakeUpPrevention
        && this.TrySettingUpPreventionPuppetForCyberpsychoCombat(e,
                                                                 cyberpsycho,
                                                                 GroundPoliceConvoy) {
            return true;
        };

        if !this.CanEntityBeSetupForPsychoCombat(e, cyberpsycho) {
            return false;
        };

        let psychoSenseComp = cyberpsycho.GetSensesComponent();
        let entSenseComp = e.GetSensesComponent();
        let eID: EntityID = e.GetEntityID();
        entSenseComp.Toggle(true);
        entSenseComp.ToggleComponent(true);
        entSenseComp.IgnoreLODChange(true);
        psychoSenseComp.SetDetectionMultiplier(eID, 9999.00);
        return true;
    };

    func TrySettingUpPreventionPuppetForCyberpsychoCombat(e: wref<ScriptedPuppet>,
                                                          cyberpsycho: ref<ScriptedPuppet>,
                                                          opt groundPoliceConvoy: array<array<EntityID>>) -> Bool {
            if !IsDefined(e) || !(e as ScriptedPuppet).IsPrevention() {
                return false;
            };
            let gi: GameInstance = GetGameInstance();
            let entID = e.GetEntityID();
            let eSenseComp = e.GetSensesComponent();
            let psychoID = cyberpsycho.GetEntityID();
            if this.isEntityPartOfGroundPoliceSquad(entID, groundPoliceConvoy) {
                return false;
            };

            eSenseComp.SetDetectionMultiplier(psychoID, 100.00);
            TargetTrackingExtension.InjectThreat(e, cyberpsycho, 1.00, -1.00);
            return true;
    };

    func SetupNearbyCrowdForCyberpsychoCombat(evt: CyberpsychoEncountersNewTargetsRequestedEvent) -> Void {
        if !IsDefined(evt.cyberpsycho) || !evt.cyberpsycho.IsAttached() {
            return;
        };

        let gi: GameInstance = GetGameInstance();
        let ents: array<wref<Entity>>;
        let attempts = 0;
        let magnitude: Float = 50.00;
        let psycho_xform = evt.cyberpsycho.GetWorldTransform();
        let psycho_pos = psycho_xform.GetWorldPosition().ToVector4();
        let psycho_front = (psycho_xform.GetForward() * magnitude);
        let psycho_right = (psycho_xform.GetRight() * magnitude);
        let psycho_front_left = (psycho_pos + psycho_front) - psycho_right;
        let psycho_front_right = (psycho_pos + psycho_front) + psycho_right;
        let psycho_back_left = (psycho_pos - psycho_front) - psycho_right;
        let psycho_back_right = (psycho_pos - psycho_front) + psycho_right;
        let query_box: array<Vector2> = [Vector4.Vector4To2(psycho_front_left),
                                         Vector4.Vector4To2(psycho_front_right),
                                         Vector4.Vector4To2(psycho_back_left),
                                         Vector4.Vector4To2(psycho_back_right)];

        let ents = GetEntitiesInPrism(GameInstance.GetEntityList(gi),
                                      query_box,
                                      psycho_pos.Z - 20.00,
                                      psycho_pos.Z + 20.00,
                                      99999,
                                      [n"ScriptedPuppet", n"vehicleCarBaseObject"]);
        for e in ents {
            let e_as_car: wref<VehicleObject> = (e as VehicleObject);
            let e_as_puppet: wref<ScriptedPuppet> = (e as ScriptedPuppet);
            if IsDefined(e_as_puppet) {
                this.TrySettingUpCrowdEntityForPsychoCombat(e_as_puppet,
                                                            evt.cyberpsycho,
                                                            this.isCyberpsychoCombatStarted,
                                                            this.groundPoliceSquads);
            } else {

                if IsDefined(e_as_car) {
                    this.SetupCrowdVehiclePassengersForPsychoCombat(e_as_car,
                                                                    evt.cyberpsycho,
                                                                    this.isCyberpsychoCombatStarted,
                                                                    this.groundPoliceSquads);
                };
            };
        };
    };

    func SetupCrowdVehiclePassengersForPsychoCombat(veh: wref<VehicleObject>,
                                                    psycho: ref<ScriptedPuppet>,
                                                    isCyberpsychoCombatStarted: Bool,
                                                    opt groundPoliceSquads: array<array<EntityID>>) -> Void {
        if !IsDefined(veh) || !veh.IsAttached() || !veh.IsDestroyed() {
            return;
        };

        let gi: GameInstance = GetGameInstance();
        let vehID: EntityID = veh.GetEntityID() ;
        let veh_pos: Vector4 = veh.GetWorldPosition();
        let passengers: array<wref<GameObject>>;
        let psycho_pos: Vector4 = psycho.GetWorldPosition();
        let square_psycho_dist: Float = Vector4.DistanceSquared(psycho_pos,
                                                                veh_pos);
        let should_exit: Bool = (isCyberpsychoCombatStarted
                                 && RandRange(0, 2) == 1
                                 && veh.GetCurrentSpeed() < 5.00
                                 && square_psycho_dist < 225.00);

        VehicleComponent.GetAllPassengers(gi, vehID, false, passengers);
        for p in passengers {
            this.TrySettingUpCrowdEntityForPsychoCombat((p as ScriptedPuppet),
                                                        psycho,
                                                        isCyberpsychoCombatStarted,
                                                        groundPoliceSquads);
            /* Force some nearby car passengers to exit vehicles
               to prevent large amounts of panic driving vehicles,
               which cause lots of car explosions and pile-ups and
               is just generally annoying. */
            if should_exit {
                let exitEvt = new VehicleUnableToStartPanicDriving();
                exitEvt.forceExitVehicle = true;
                veh.OnUnableToStartPanicDriving(exitEvt);
            };
            /* A lower threat mult is set for vehicle passengers since the 
               cyberpsycho tends to not aim high enough to actually hit the
               passenger and subsequenty gets stuck on them. This makes it more
               likely that the cyberpsycho will prefer on foot NPCs. */
            psycho.GetTargetTrackerComponent().SetThreatBaseMul(p, 0.25);
        };
    };

    func FindNCPDGroundConvoySpawnpoints(cyberpsycho: ref<NPCPuppet>,
                                         veh_fwd: Vector4,
                                         out spawn_points: array<Vector4>) -> Bool {
        let NavSys = GameInstance.GetNavigationSystem(GetGameInstance());
        let psycho_pos: Vector4 = cyberpsycho.GetWorldPosition();
        let start_pos: Vector4;
        let pursuit_points: array<Vector4>;
        let fallback_pursuit_points: array<Vector4>;
        let player_fwd: Vector4 = GetPlayer(GetGameInstance()).GetWorldForward();
        let vehicleNavAgentSize = IntEnum<NavGenAgentSize>(1);
        let success = NavSys.FindPursuitPointsRange(psycho_pos,
                                                    psycho_pos,
                                                    player_fwd,
                                                    30.00,
                                                    120.00,
                                                    1,
                                                    false,
                                                    vehicleNavAgentSize,
                                                    pursuit_points,
                                                    fallback_pursuit_points);
        let i = 0;

        if !success {
            return false;
        };

        start_pos = pursuit_points[0];
        if Vector4.IsXYZZero(start_pos) {
            FTLogWarning("[CyberpsychoEncountersEventSystem][FindNCPDGroundConvoySpawnpoints]: FAILED TO FIND GROUND CONVOY SPAWNPOINT: PURSUIT POINT VECTOR IS ZERO");
            return false;
        };
        while i < 3 {
            let iF: Float = Cast<Float>(i);
            let distance = new Vector4(-veh_fwd.X + (7.00 * iF),
                                       -veh_fwd.Y + (7.00 * iF),
                                       veh_fwd.Z,
                                       1.00);
            let pos = start_pos + distance;
            ArrayPush(spawn_points, pos);
            i += 1;
        };

        return true;
    };

    func TryStartGroundNCPDResponse() -> Bool {
        if this.isCyberpsychoDefeated() {
            return false;
        };
        let gi: GameInstance = GetGameInstance();
        let dynamicEntSys = GameInstance.GetDynamicEntitySystem();
        let delaySys = GameInstance.GetDelaySystem(gi);
        let MountingFacility = GameInstance.GetMountingFacility(gi);
        let NavSys = GameInstance.GetNavigationSystem(gi);
        let groundPoliceSquadsEntitySpecs = this.GetCyberpsychoGroundPoliceEntitySpecs();
        let vehicle_recordID = groundPoliceSquadsEntitySpecs[0][0].recordID;
        let veh_TDBID = TweakDBInterface.GetRecord(vehicle_recordID);
        let veh_record = veh_TDBID as Vehicle_Record;
        let veh_data_package = veh_record.VehDataPackage();
        let vehicle_seats: array<wref<VehicleSeat_Record>>;
        let veh_fwd = groundPoliceSquadsEntitySpecs[0][0].orientation.GetForward();
        let cyberpsycho = GameInstance.FindEntityByID(GetGameInstance(),
                                                      this.cyberpsychoID) as NPCPuppet;
        let psycho_pos: Vector4 = cyberpsycho.GetWorldPosition();
        let spawn_points: array<Vector4>;
        if this.isCyberpsychoDefeated() {
            return false;
        };

        if !this.FindNCPDGroundConvoySpawnpoints(cyberpsycho,
                                                 veh_fwd,
                                                 spawn_points) {
            FTLogWarning("[CyberpsychoEncountersEventSystem][TryStartGroundNCPDResponse]: FAILED TO FIND GROUND PURSUIT VEHICLE POINT, FALLING BACK TO ON FOOT UNITS");
            if this.TryCreateGroundNCPDFallbackUnits(cyberpsycho,
                                                     groundPoliceSquadsEntitySpecs) {
                return true;
            };
        };

        veh_data_package.VehSeatSet().VehSeats(vehicle_seats);

        // For some reason the hellhound data package only contains the two
        // front seats even though it has two back seats.
        if StrContains(NameToString(veh_record.DisplayName()), "Hellhound") {
            ArrayPush(vehicle_seats,
                      TweakDBInterface.GetVehicleSeatRecord(t"Vehicle.SeatBackLeft"));
            ArrayPush(vehicle_seats,
                      TweakDBInterface.GetVehicleSeatRecord(t"Vehicle.SeatBackRight"));
        };

        // We remove the driver seat record so a driver does not spawn in order
        // to workaround an issue where spawining a driver cancels the drive to
        // point command.
        ArrayRemove(vehicle_seats,
                    TweakDBInterface.GetVehicleSeatRecord(t"Vehicle.SeatFrontLeft"));

        let i: Int32 = 0;
        while i < ArraySize(groundPoliceSquadsEntitySpecs) {
            let cur_vehicle_entity_IDs: array<EntityID>;
            let cur_vehicle_spec = groundPoliceSquadsEntitySpecs[i][0];
            let veh_fwd = cur_vehicle_spec.orientation.GetForward();
            let distance = new Vector4(-veh_fwd.X + (7.00 * Cast<Float>(i)),
                                       -veh_fwd.Y + (7.00 * Cast<Float>(i)),
                                       veh_fwd.Z,
                                       1);
            let veh_pos = spawn_points[i] + distance;
            cur_vehicle_spec.position = veh_pos;
            let vehID = dynamicEntSys.CreateEntity(cur_vehicle_spec);
            ArrayPush(cur_vehicle_entity_IDs, vehID);
            let ii: Int32 = 0;
            while ii < ArraySize(vehicle_seats) {
                let s = vehicle_seats[ii];

                // this startes at 1 because item 0 is the vehicle
                // and this loop is solely for passengers
                let passenger = groundPoliceSquadsEntitySpecs[i][ii + 1];
                passenger.position = veh_pos;
                let npcID = dynamicEntSys.CreateEntity(passenger);
                ArrayPush(cur_vehicle_entity_IDs, npcID);
                MountEntityToVehicle(npcID, vehID, s, true, false, true);
                ii = ii + 1;
            };
            let attachmentDaemon = new CyberpsychoEncountersConvoyVehicleAttachmentDaemon();
            attachmentDaemon.vehicleSquad = cur_vehicle_entity_IDs;
            attachmentDaemon.Start(gi, 0.50, false);
            ArrayPush(this.groundPoliceSquads, cur_vehicle_entity_IDs);
            i = i + 1;
        };
        return true;
    };

    func TryCreateGroundNCPDFallbackUnits(cyberpsycho: ref<NPCPuppet>,
                                       groundPoliceSquadsEntitySpecs: array<array<ref<DynamicEntitySpec>>>) -> Bool {
        let NavSys = GameInstance.GetNavigationSystem(GetGameInstance());
        let dynamicEntSys = GameInstance.GetDynamicEntitySystem();
        let psycho_pos = cyberpsycho.GetWorldPosition();
        let i = 0;
        while i < ArraySize(groundPoliceSquadsEntitySpecs) {
            let squadIDs: array<EntityID>;
            let squadSpecs = groundPoliceSquadsEntitySpecs[i];
            // these start at 1 since the first spec is a vehicle spec
            // but the fallback is for human NPCs only.
            let ii = 1;
            let squad_point_array: array<Vector4>;
            let fallback_squad_point_array: array<Vector4>;
            let player_fwd: Vector4 = GetPlayer(GetGameInstance()).GetWorldForward();
            let pursuit_points_success = NavSys.FindPursuitPointsRange(psycho_pos,
                                                                       psycho_pos,
                                                                       player_fwd,
                                                                       15.00,
                                                                       50.00,
                                                                       1,
                                                                       false,
                                                                       NavGenAgentSize.Human,
                                                                       squad_point_array,
                                                                       fallback_squad_point_array);
            let squad_point: Vector4;
            if ArraySize(squad_point_array) > 0 {
                squad_point = squad_point_array[0];
            } else {
                if ArraySize(fallback_squad_point_array) > 0 {
                    squad_point = fallback_squad_point_array[0];
                } else {
                    FTLogWarning("[CyberpsychoEncountersEventSystem][TryCreateGroundNCPDFallbackUnits]: COULD NOT FIND ANY PURSUIT POINT FOR FALLBACK NCPD UNITS");
                    return false;
                };
            };
            let unit_points: array<Vector4>;
            let fallback_unit_points: array<Vector4>;
            let unit_point_success = NavSys.FindPursuitPointsRange(psycho_pos,
                                                                   psycho_pos,
                                                                   player_fwd,
                                                                   15.00,
                                                                   50.00,
                                                                   ArraySize(squadSpecs),
                                                                   false,
                                                                   NavGenAgentSize.Human,
                                                                   unit_points,
                                                                   fallback_unit_points);

            while ii < ArraySize(squadSpecs) {
                let npcSpec = squadSpecs[ii];
                let unit_pos: Vector4;
                if ArraySize(unit_points) > ii {
                    unit_pos = unit_points[ii];
                } else {
                    if ArraySize(fallback_unit_points) < ii {
                    FTLogWarning("[CyberpsychoEncountersEventSystem][TryCreateGroundNCPDFallbackUnits]: COULD NOT FIND A UNIQUE SPAWNPOINT FOR FALLBACK NCPD UNIT");
                        if ArraySize(fallback_unit_points) < 0 {
                            FTLogWarning("[CyberpsychoEncountersEventSystem][TryCreateGroundNCPDFallbackUnits]: COULD NOT FIND ANY SPAWNPOINT FOR FALLBACK NCPD UNIT");
                            return false;
                        };
                        unit_pos = fallback_unit_points[ArraySize(fallback_unit_points) - 1];
                    };
                };
                npcSpec.position = unit_pos;
                let npcID = dynamicEntSys.CreateEntity(npcSpec);
                let npc = GameInstance.FindEntityByID(GetGameInstance(), npcID);
                TargetTrackingExtension.InjectThreat((npc as ScriptedPuppet), cyberpsycho, 1.00, -1.00);
                ArrayPush(squadIDs, npcID);
                ii += 1;
            };
            ArrayPush(this.groundPoliceSquads, squadIDs);
            i += 1;
        };
        return true;
    };

    func TryCreateMaxtacFallbackUnits() -> Bool {
        let gi: GameInstance = GetGameInstance();
        let NavSys = GameInstance.GetNavigationSystem(gi);
        let MaxTacRecords: array<TweakDBID> = [t"Character.maxtac_av_mantis_wa",
                                               t"Character.maxtac_av_LMG_mb",
                                               t"Character.maxtac_av_riffle_ma",
                                               t"Character.maxtac_av_sniper_wa_elite"];
        let cyberpsycho = GameInstance.FindEntityByID(gi, this.cyberpsychoID);
        let psycho_pos = cyberpsycho.GetWorldPosition();
        let maxtac_points: array<Vector4>;
        let fallback_maxtac_points: array<Vector4>;
        let pursuit_points_success = NavSys.FindPursuitPointsRange(psycho_pos,
                                                                   psycho_pos,
                                                                   new Vector4(0.00, 0.00, 0.00, 0.00),
                                                                   15.00,
                                                                   50.00,
                                                                   4,
                                                                   false,
                                                                   NavGenAgentSize.Human,
                                                                   maxtac_points,
                                                                   fallback_maxtac_points);
        let squadIDs: array<EntityID>;
        let i = 0;
        while i < 4 {
            let maxtacSpec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
            maxtacSpec.recordID = MaxTacRecords[i];
            maxtacSpec.persistState = true;
            maxtacSpec.persistSpawn = true;
            maxtacSpec.alwaysSpawned = false;
            maxtacSpec.tags = [n"CyberpsychoEncounters_npc_maxtac"];
            if ArraySize(maxtac_points) > i {
                maxtacSpec.position = maxtac_points[i];
            } else {
                if ArraySize(fallback_maxtac_points) < i {
                    FTLogWarning("[CyberpsychoEncountersEventSystem][TryCreateMaxtacFallbackUnits]: COULD NOT FIND A UNIQUE SPAWNPOINT FOR FALLBACK UNIT");
                    if ArraySize(fallback_maxtac_points) < 0 {
                    FTLogWarning("[CyberpsychoEncountersEventSystem][TryCreateMaxtacFallbackUnits]: COULD NOT FIND ANY SPAWNPOINT FOR FALLBACK MAXTAC UNITS");
                        return false;
                    };
                    maxtacSpec.position = fallback_maxtac_points[-1];
                };
            };
            let npcID = GameInstance.GetDynamicEntitySystem().CreateEntity(maxtacSpec);
            ArrayPush(squadIDs, npcID);
            let npc = GameInstance.FindEntityByID(GetGameInstance(), npcID);
            TargetTrackingExtension.InjectThreat((npc as ScriptedPuppet),
                                                 cyberpsycho,
                                                 1.00,
                                                 -1.00);
            i += 1;
        };

        ArrayPush(this.groundPoliceSquads, squadIDs);
        return true;
    };

    func SendCyberpsychoChaseCommand(cyberpsycho: ref<NPCPuppet>,
                                     veh: ref<WheeledObject>) -> Void {
        let delaySys = GameInstance.GetDelaySystem(GetGameInstance());
        let drive_req = new DriveToPointAutonomousUpdate();
        drive_req.targetPosition = cyberpsycho.GetWorldPosition();
        drive_req.minimumDistanceToTarget = 25;
        drive_req.driveDownTheRoadIndefinitely = false;
        drive_req.maxSpeed = 50;
        drive_req.minSpeed = 15;
        drive_req.clearTrafficOnPath = false;
        let AIEvt = new AICommandEvent();
        let drive_cmd = drive_req.CreateCmd();
        AIEvt.command = drive_cmd;
        veh.QueueEvent(AIEvt);
        veh.GetAIComponent().SetDriveToPointAutonomousUpdate(drive_req);
        veh.GetAIComponent().SetInitCmd(drive_cmd);
    };

    func OnGroundNCPDConvoyVehicleAttached(evt: CyberpsychoEncountersGroundNCPDConvoyVehicleAttachedEvent) -> Void {
        let gi: GameInstance = GetGameInstance();
        let vehID = evt.vehicleSquad[0];
        let veh_obj = GameInstance.FindEntityByID(gi, vehID) as WheeledObject;
        let delaySys = GameInstance.GetDelaySystem(gi);
        evt.sender.Stop();
        let sirenDelayEvent = new VehicleSirenDelayEvent();
        sirenDelayEvent.lights = true;
        sirenDelayEvent.sounds = true;
        delaySys.DelayEvent(veh_obj, sirenDelayEvent, 0.10);
        veh_obj.GetVehicleComponent().OnVehicleSirenDelayEvent(sirenDelayEvent);
        let cyberpsycho = GameInstance.FindEntityByID(gi, this.cyberpsychoID) as NPCPuppet;
        this.SendCyberpsychoChaseCommand(cyberpsycho, veh_obj);
        let arrivalDaemon = new CyberpsychoEncountersConvoyVehicleArrivalDaemon();
        arrivalDaemon.cyberpsycho = cyberpsycho;
        arrivalDaemon.vehicleSquad = evt.vehicleSquad;
        arrivalDaemon.Start(gi, 1.00, true);
    };

    func OnGroundNCPDVehicleHasArrived(evt: CyberpsychoEncountersGroundNCPDConvoyVehicleArrivedEvent) -> Void {
        evt.sender.Stop();
        if this.isCyberpsychoDefeated() {
            return;
        };

        let gi: GameInstance = GetGameInstance();
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        let vehID = evt.vehicleSquad[0];
        let veh = GameInstance.FindEntityByID(gi, vehID);
        let passengers: array<wref<GameObject>>;
        /* If the driver is spawned earlier than here, such as when the actual
           drive to point autonomous command is issued, the ground vehicle will
           cancel the drive to point command and join traffic, and never reach 
           the cyberpsycho. We spawn the driver later (here) as a workaround so
           that the command doesn't get canceled until the units are already
           close. */

        let passenger = new DynamicEntitySpec();
        passenger.recordID = t"Character.ncpd_hwp_gunner2_defender_mb_rare";
        passenger.position = veh.GetWorldPosition();
        passenger.persistState = true;
        passenger.persistSpawn = true;
        passenger.alwaysSpawned = false;
        passenger.tags = [n"CyberpsychoEncounters_npc_police"];
        let npcID = GameInstance.GetDynamicEntitySystem().CreateEntity(passenger);
        let i = 0;
        while i < ArraySize(this.groundPoliceSquads) {
            let squadVehID = this.groundPoliceSquads[i][0];
            if squadVehID == vehID {
                ArrayPush(this.groundPoliceSquads[i], npcID);
                break;
            };
            i += 1;
        };
        let npc = GameInstance.FindEntityByID(gi, npcID);
        let seat_record = TweakDBInterface.GetVehicleSeatRecord(t"Vehicle.SeatFrontLeft");
        MountEntityToVehicle(npcID, vehID, seat_record, true, false, true);
        (npc as ScriptedPuppet).TryRegisterToPrevention();
        let cyberpsycho = GameInstance.FindEntityByID(gi, this.cyberpsychoID) as NPCPuppet;
        let i = 1;
        while i < ArraySize(evt.vehicleSquad) {
            let unit = evt.vehicleSquad[i];
            let npc = (GameInstance.FindEntityByID(gi, unit) as ScriptedPuppet);
            TargetTrackingExtension.InjectThreat(npc,
                                                 cyberpsycho,
                                                 1.00,
                                                 -1.00);
            NPCPuppet.ChangeHighLevelState(npc, gamedataNPCHighLevelState.Combat);
            i += 1;
        };
    };

    func isCyberpsychoDefeated() -> Bool {
        return this.cyberpsychoIsDead;
    };

    func isCyberpsychoEventInProgress() -> Bool {
        return this.isCyberpsychoEventInProgress;
    };

    func isCyberpsychoCombatStarted() -> Bool {
        return this.isCyberpsychoCombatStarted;
    };

    func OnCyberpsychoIsDead(evt: CyberpsychoEncountersCyberpsychoDeathEvent) -> Void {
        let gi: GameInstance = GetGameInstance();
        let psychoSys = GameInstance.GetCyberpsychoEncountersSystem(gi);
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        let delaySys = GameInstance.GetDelaySystem(gi);
        let mappinSys = GameInstance.GetMappinSystem(gi);
        let attitudeSys = GameInstance.GetAttitudeSystem(gi);
        let psychoStimBroacaster = evt.cyberpsycho.GetStimBroadcasterComponent();
        let cyberpsycho_stats_ID = Cast<StatsObjectID>(evt.cyberpsycho.GetEntityID());
        mappinSys.UnregisterMappin(this.cyberpsychoMappinID);
        attitudeSys.SetAttitudeGroupRelationfromTweakPersistent(t"Attitudes.Group_Police",
                                                                t"Attitudes.Group_Civilian",
                                                                EAIAttitude.AIA_Neutral);
        psychoStimBroacaster.RemoveActiveStimuliByName(evt.cyberpsycho,
                                                       gamedataStimType.VehicleHit);
        psychoStimBroacaster.RemoveActiveStimuliByName(evt.cyberpsycho,
                                                       gamedataStimType.Terror);
        GameInstance.GetStatPoolsSystem(gi).RequestUnregisteringListener(cyberpsycho_stats_ID,
                                                                         gamedataStatPoolType.Health,
                                                                         this.cyberpsychoDeathListener);
        this.cyberpsychoDeathListener = null;
        this.cyberpsychoIsDead = true;
        this.cyberpsychoTargetDaemon.Stop();
        this.EndNCPDNpcResponse(this.groundPoliceSquads);
        let EnablePreventionCback = new CyberpsychoEncountersDelayPreventionSystemToggledCallback();
        EnablePreventionCback.toggle = true;
        delaySys.DelayCallback(EnablePreventionCback, 5.00, true);
        this.lastEncounterSeconds = 0u;
        SaveLocksManager.RequestSaveLockRemove(gi, n"CyberpsychoEncountersEventInProgress");
        FastTravelSystem.RemoveFastTravelLock(n"CyberpsychoEncountersEventInProgress", gi);
    };

    func EndNCPDNpcResponse(groundPoliceSquads: array<array<EntityID>>) -> Void {
        let gi: GameInstance = GetGameInstance();
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        let reactionSystem: ref<ReactionSystem> = GameInstance.GetReactionSystem(gi);
        if NotEquals(preventionSys.GetHeatStage(), EPreventionHeatStage.Heat_0) {
            return;
        };

        let seat_priority_list: array<ref<VehicleSeat_Record>> = [TweakDBInterface.GetVehicleSeatRecord(t"Vehicle.SeatFrontLeft"), TweakDBInterface.GetVehicleSeatRecord(t"Vehicle.SeatFrontRight"), TweakDBInterface.GetVehicleSeatRecord(t"Vehicle.SeatBackLeft"), TweakDBInterface.GetVehicleSeatRecord(t"Vehicle.SeatBackRight")];

        let i: Int32 = 0;
        while i < ArraySize(groundPoliceSquads) {
            let squad = groundPoliceSquads[i];
            let vehID = squad[0];
            let slot_num: Int32 = 0;
            let ii: Int32 = 1;
            while ii < ArraySize(squad) {
                let npc = GameInstance.FindEntityByID(GetGameInstance(), squad[ii]);
                let slot = seat_priority_list[slot_num].SeatName();
                if this.TryMountGroundNCPDUnitToVehicle(npc, vehID, slot) {
                    slot_num += 1;
                } else {
                    let player_pos_v3 = Cast<Vector3>(GetPlayer(gi).GetWorldPosition());
                    reactionSystem.TryAndJoinTraffic((npc as GameObject),
                                                     player_pos_v3,
                                                     false);
                };
                ii += 1;
            };
            i += 1;
        };
    };

    func TryMountGroundNCPDUnitToVehicle(unit: ref<Entity>,
                                         vehID: EntityID,
                                         slot: CName) -> Bool {

        let gi: GameInstance = GetGameInstance();
        let veh: ref<VehicleObject> = GameInstance.FindEntityByID(gi, vehID) as VehicleObject;
        let unit_as_puppet = unit as ScriptedPuppet;
        let unit_as_g_obj = unit as GameObject;
        if !IsDefined(veh) || veh.IsDestroyed() {
            FTLog("[CyberpsychoEncountersEventSystem][TryMountGroundNCPDUnitToVehicle]: Failed to mount vehicle. Reason: Vehicle not drivable.");
            return false;
        };

        if !IsDefined(unit)
        || (unit_as_puppet).IsDead()
        || ScriptedPuppet.IsDefeated((unit_as_g_obj))
        || ScriptedPuppet.IsUnconscious((unit_as_g_obj)) {
            FTLog("[CyberpsychoEncountersEventSystem][TryMountGroundNCPDUnitToVehicle]: Failed to mount vehicle. Reason: failed puppet preconditions");
            return false;
        };

        let mountData = new MountEventData();
        mountData.slotName = slot;
        mountData.mountParentEntityId = vehID;
        mountData.isInstant = false;
        mountData.ignoreHLS = true;
        if Equals((unit_as_puppet).GetHighLevelStateFromBlackboard(),
                  gamedataNPCHighLevelState.Combat) {
            mountData.entrySlotName = n"combat";
        };
        let mountCommand = new AIMountCommand();
        mountCommand.mountData = mountData;
        let evt = new AICommandEvent();
        evt.command = mountCommand;
        unit.QueueEvent(evt);
        return true;
    };

    func OnPlayerSecondAway(evt: CyberpsychoEncountersPlayerSecondsAwayEvent) -> Void {
        this.playerSecondsAway += Cast<Uint16>(1);
        if evt.distance > 22500.00 || this.playerSecondsAway > Cast<Uint16>(45) { // > 150m
            evt.sender.Stop();
            this.CleanupCyberpsychoEvent();
        };
    };

    func CleanupCyberpsychoEvent() -> Void {
        let gi: GameInstance = GetGameInstance();
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        let delaySys = GameInstance.GetDelaySystem(gi);
        let mappinSys = GameInstance.GetMappinSystem(gi);
        FTLog("[CyberpsychoEncountersEventSystem][CleanupCyberpsychoEvent]: Cleaning up cyberpsycho event");
        mappinSys.UnregisterMappin(this.cyberpsychoMappinID);
        this.cyberpsychoAttachmentDaemon.Stop();
        GameInstance.GetDynamicEntitySystem().DeleteEntity(this.cyberpsychoID);
        this.cyberpsychoID = new EntityID();
        if ArraySize(this.groundPoliceSquads) > 0 {
            let deletionDaemon = new CyberpsychoEncountersNCPDGroundPoliceDeletionDaemon();
            deletionDaemon.units = this.groundPoliceSquads;
            deletionDaemon.Start(gi, 1.00, false);
            this.isUnitDeletionPending = true;
        };
        /* Sometimes players can miss the cyberpsycho event by leaving the area
           before the psycho attacks. This bypasses the cooldown if that happens
           so it takes less time for players to experience an actual attack with
           combat. */
        if !this.isCyberpsychoCombatStarted() && !this.isCyberpsychoDefeated() {
            this.lastEncounterSeconds = this.GetCooldownSeconds();
            FTLog("[CyberpsychoEncountersEventSystem][CleanupCyberpsychoEvent]: COMBAT NEVER STARTED, BYPASSING COOLDOWN SECONDS");
        } else {
            this.lastEncounterSeconds = 0u;
        };
        this.isCyberpsychoCombatStarted = false;
        preventionSys.TogglePreventionSystem(true);
        this.StartNewMinutesSinceLastEncounterCallback();
        SaveLocksManager.RequestSaveLockRemove(gi, n"CyberpsychoEncountersEventInProgress");
        FastTravelSystem.RemoveFastTravelLock(n"CyberpsychoEncountersEventInProgress", gi);
        this.isCyberpsychoEventInProgress = false;
        this.lastEncounterSecondsDaemon.Start(gi, 1.00, true);
    };

    func OnGroundNCPDUnitsDeletionRequested(evt: CyberpsychoEncountersUnitsDeletionRequestedEvent) -> Void {
        if evt.allUnitsDeleted {
            evt.sender.Stop();
            this.isUnitDeletionPending = false;
        };

        for unitID in evt.units {
            GameInstance.GetDynamicEntitySystem().DeleteEntity(unitID);
        };
    };

    func GetCyberpsychoCharacterPools(district_name: String) -> array<TweakDBID> {
        switch district_name {
            case "Northside":
            case "ArasakaWaterfront":
                return [t"CyberpsychoEncounters.Character_Pool_Maelstrom_Psychos"];
            case "LittleChina":
                return [t"CyberpsychoEncounters.Character_Pool_Maelstrom_Psychos",
                        t"CyberpsychoEncounters.Character_Pool_Tyger_Claw_Psychos"];
            case "Kabuki":
            case "JapanTown":
                return [t"CyberpsychoEncounters.Character_Pool_Mox_Psychos",
                        t"CyberpsychoEncounters.Character_Pool_Tyger_Claw_Psychos"];
            case "CharterHill":
                return [t"CyberpsychoEncounters.Character_Pool_Tyger_Claw_Psychos"];
            case "VistaDelRey":
            case "Heywood":
                return [t"CyberpsychoEncounters.Character_Pool_Sixth_Street_Psychos",
                        t"CyberpsychoEncounters.Character_Pool_Valentino_Psychos"];
            case "Glen":
                return [t"CyberpsychoEncounters.Character_Pool_Valentino_Psychos"];
            case "Arroyo":
            case "RanchoCoronado":
                return [t"CyberpsychoEncounters.Character_Pool_Sixth_Street_Psychos"];
            case "Pacifica":
            case "CoastView":
            case "WestWindEstate":
                return [t"CyberpsychoEncounters.Character_Pool_Scav_Psychos",
                        t"CyberpsychoEncounters.Character_Pool_Voodoo_Boy_Psychos"];

            case "Badlands_JacksonPlains":
            case "Badlands_LagunaBend":
            case "Badlands_RattlesnakeCreek":
            case "Badlands_RedPeaks":
            case "Badlands_RockyRidge":
            case "Badlands_SierraSonora":
            case "Badlands_SoCalBorderCrossing":
            case "Badlands_VasquezPass":
                return [t"CyberpsychoEncounters.Character_Pool_Wraith_Psychos"];
            default:
                return [];
        };

    };

    func GetCyberpsychoEntitySpec(district_name: String) -> ref<DynamicEntitySpec> {
        let pool: array<TweakDBID>;
        let psychoSpec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
        let psychoPools = this.GetCyberpsychoCharacterPools(district_name);
        let rand_pool_index = RandRange(0, ArraySize(psychoPools));
        psychoSpec.persistState = true;
        psychoSpec.persistSpawn = true;
        psychoSpec.alwaysSpawned = false;
        psychoSpec.tags = [n"CyberpsychoEncounters_npc_cyberpsycho"];

        if ArraySize(psychoPools) == 0 || RandRange(0, 4) == 0 {
            pool = TweakDBInterface.GetForeignKeyArray(t"CyberpsychoEncounters.Character_Pool_Generic_Psychos");
        } else {
            pool = TweakDBInterface.GetForeignKeyArray(psychoPools[rand_pool_index]);
        };

        let rand_record_index = RandRange(0, ArraySize(pool));
        psychoSpec.recordID = pool[rand_record_index];
        FTLog(s"[CyberpsychoEncountersEventSystem][GetCyberpsychoEntitySpec]: Cyberpsycho record ID: \(TDBID.ToStringDEBUG(psychoSpec.recordID))");
        return psychoSpec;
    };

    func GetCyberpsychoGroundPoliceEntitySpecs() -> array<array<ref<DynamicEntitySpec>>> {
        let ground_police_specs: array<array<ref<DynamicEntitySpec>>>;
        let squad_specs: array<ref<DynamicEntitySpec>>;
        let vehicle_spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
        let veh_record: TweakDBID;
        let police_record_IDs: array<TweakDBID> = [t"Character.ncpd_hwp_gunner2_defender_mb_rare",
                                                   t"Character.ncpd_police_shotgun3_crusher_mb_elite",
                                                   t"Character.ncpd_police_ranged2_copperhead_wa",
                                                   t"Character.ncpd_police_ranged2_copperhead_ma"];
        let n: Uint8 = Cast<Uint8>(RandRange(0, 10));
        let i: Int32 = 0;
        if n > Cast<Uint8>(8) {
            veh_record = t"Vehicle.v_standard3_militech_hellhound_police";
        } else {
            if n > Cast<Uint8>(6) {
              veh_record = t"Vehicle.v_standard25_thorton_merrimac_police";
            } else {
              veh_record = t"Vehicle.v_standard3_chevalier_emperor_police_prevention";
            };
        };


        vehicle_spec.recordID = veh_record;
        vehicle_spec.persistState = true;
        vehicle_spec.persistSpawn = true;
        vehicle_spec.alwaysSpawned = false;
        vehicle_spec.tags = [n"CyberpsychoEncounters_vehicle_police"];

        i = 0;
        while i < 3 {
            let squad_specs: array<ref<DynamicEntitySpec>>;
            ArrayPush(squad_specs, vehicle_spec);
            let ii = 0;
            while ii < 5 {
                let npc_spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
                npc_spec.recordID = police_record_IDs[ii];
                npc_spec.persistState = true;
                npc_spec.persistSpawn = true;
                npc_spec.alwaysSpawned = false;
                npc_spec.tags = [n"CyberpsychoEncounters_npc_police"];
                ArrayPush(squad_specs, npc_spec);
                ii += 1;
            };

            ArrayPush(ground_police_specs, squad_specs);
            i += 1;
        };
        return ground_police_specs;
    };

    func StartNewMinutesSinceLastEncounterCallback() -> Void {
        let gi: GameInstance = GetGameInstance();
        let lastEncounterSecondsDaemon = new CyberpsychoEncountersLastEncounterSecondsDaemon();
        this.lastEncounterSecondsDaemon = lastEncounterSecondsDaemon;
        lastEncounterSecondsDaemon.Start(gi, true);
    };

    func AddlastEncounterSeconds(seconds: Uint32) -> Void {
        this.lastEncounterSeconds = this.lastEncounterSeconds + seconds;
    };

    func ShouldStartCyberpsychoEvent() -> Bool {
        let gi: GameInstance = GetGameInstance();
        let scriptableContainer = GameInstance.GetScriptableSystemsContainer(gi);
        let preventionSys = scriptableContainer.Get(n"PreventionSystem") as PreventionSystem;
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let district_name = GetCurrentDistrict().GetDistrictRecord().EnumName();
        let district_chance: Int8;
        let questsContentSystem = GameInstance.GetQuestsContentSystem(gi);
        let previous_psychoID = this.cyberpsychoID;
        if EntityID.IsDefined(previous_psychoID) {
            return false;
        };

        let scene_tier = PlayerPuppet.GetSceneTier(player);
        if scene_tier != 1
        || preventionSys.IsPlayerInQuestArea()
        || questsContentSystem.IsTokensActivationBlocked()
        || IsPlayerNearQuestMappin(50.00)
        || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"NoCombat")
        || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"VehicleScene")
        || player.GetPuppetStateBlackboard().GetBool(GetAllBlackboardDefs().PuppetState.InAirAnimation)
        || Equals(player.m_securityAreaTypeE3HACK, ESecurityAreaType.SAFE) {
            return false;
        };

        // use RadialMenuHelper.IsWeaponsBlocked since it works as a test for
        // if the player is in an apartment and some other safe areas but not
        // other interiors where weapons may be blocked (like bars) which we
        // still want to allow cyberpsycho attacks to happen in.
        if RadialMenuHelper.IsWeaponsBlocked(player) {
            FTLog("[CyberpsychoEncountersEventSystem][ShouldStartCyberpsychoEvent]: Cannot start cyberpsycho event, RadialMenuHelper.IsWeaponsBlocked");
            return false;
        };


        district_chance = this.getDistrictSpawnChance(district_name);
        if district_chance == Cast<Int8>(-1) {
            FTLogError(s"[CyberpsychoEncountersEventSystem][ShouldStartCyberpsychoEvent]: District \(district_name) not found, exiting.");
            return false;
        };
        let cooldown_seconds = this.GetCooldownSeconds();

        if this.rollCyberPsychoEncounterChance(district_chance,
                                               this.lastEncounterSeconds,
                                               cooldown_seconds) < 60.00 {
            return false;
        };

        return true;
    };

    func getCyberpsychoSpawnPoint(center: Vector4,
                                  district_name: String) -> Vector4 {
        let gi: GameInstance = GetGameInstance();
        let NavSys = GameInstance.GetNavigationSystem(gi);
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let spawn_point_params = this.getDistrictSpawnPointSearchParams(district_name);
        let security_zone_filters = [ESecurityAreaType.SAFE,
                                            ESecurityAreaType.RESTRICTED,
                                            ESecurityAreaType.DANGEROUS,
                                            ESecurityAreaType.DISABLED];

        let player_fwd: Vector4 = GetPlayer(GetGameInstance()).GetWorldForward();
        let pursuit_points: array<Vector4>;
        let fallback_pursuit_points: array<Vector4>;
        let success = NavSys.FindPursuitPointsRange(player.GetWorldPosition(),
                                                    player.GetWorldPosition(),
                                                    player_fwd,
                                                    spawn_point_params.deadzone,
                                                    spawn_point_params.search_size,
                                                    1,
                                                    false,
                                                    NavGenAgentSize.Human,
                                                    pursuit_points,
                                                    fallback_pursuit_points);

        if success {
            let point = pursuit_points[0];
            FTLog(s"Found pursuit point: \(point)");
            if !isPointInAnyLoadedSecurityAreaRadius(point, security_zone_filters, true) {
                return point;
            };
            FTLog(s"Pursuit point in security area!");
        } else {
            return new Vector4(0.00, 0.00, 0.00, 0.00);
        };
    };

    func GetCyberpsychoPoliceResponseDelays(district_name: String) -> CyberpsychoEncountersDistrictPoliceDelays {
        let responseDelays: CyberpsychoEncountersDistrictPoliceDelays;
        switch district_name {
            case "ArasakaWaterfront":
            case "CharterHill":
            case "CityCenter":
            case "Columbarium":
            case "CorpoPlaza":
            case "Downtown":
            case "NorthOaks":
            case "Badlands_SoCalBorderCrossing":
                responseDelays.ncpdDelay = Cast<Int16>(RandRange(25, 50));
                responseDelays.maxtacDelay = Cast<Int16>(RandRange(45, 75));
                break;
            case "LittleChina":
            case "JapanTown":
            case "Glen":
            case "Wellsprings":
                responseDelays.ncpdDelay = Cast<Int16>(RandRange(45, 75));
                responseDelays.maxtacDelay = Cast<Int16>(RandRange(50, 80));
                break;
            case "Arroyo":
            case "Heywood":
            case "Kabuki":
            case "RanchoCoronado":
            case "SouthBadlands_TrailerPark":
            case "VistaDelRey":
            case "Watson":
                responseDelays.ncpdDelay = Cast<Int16>(RandRange(90, 120));
                responseDelays.maxtacDelay = Cast<Int16>(RandRange(75, 125));
                break;
            case "Dogtown":
                responseDelays.ncpdDelay = Cast<Int16>(-1);
                responseDelays.maxtacDelay = Cast<Int16>(RandRange(90, 140));
                break;
            default:
                responseDelays.ncpdDelay = Cast<Int16>(-1);
                responseDelays.maxtacDelay = Cast<Int16>(-1);
                break;
        };

        return responseDelays;
    };

    func getDistrictSpawnChance(district_name: String) -> Int8 {
        switch district_name {
            case "Badlands":
            case "Badlands_LagunaBend":
            case "NorthBadlands":
            case "Badlands_SierraSonora":
            case "Badlands_RedPeaks":
            case "Badlands_VasquezPass":
            case "Badlands_RattlesnakeCreek":
                return Cast<Int8>(34);
            case "NorthOaks":
            case "Badlands_NorthSunriseOilField":
            case "Badlands_JacksonPlains":
                return Cast<Int8>(35);
            case "Badlands_RockyRidge":
            case "SouthBadlands":
            case "SouthBadlands_TrailerPark":
                return Cast<Int8>(36);
            case "Badlands_BiotechnicaFlats":
                return Cast<Int8>(37);
            case "CityCenter":
            case "CharterHill":
            case "CorpoPlaza":
            case "Badlands_SoCalBorderCrossing":
            case "Westbrook":
                return Cast<Int8>(39);
            case "Arroyo":
            case "Downtown":
            case "Glen":
            case "Heywood":
            case "JapanTown":
            case "LittleChina":
            case "SantoDomingo":
            case "VistaDelRey":
            case "Kabuki":
            case "Wellsprings":
                return Cast<Int8>(40);
            case "Watson":
            case "ArasakaWaterfront":
            case "RanchoCoronado":
            case "SantoDomingo":
                return Cast<Int8>(41);
            case "Northside":
                return Cast<Int8>(42);
            case "Pacifica":
            case "Coastview":
            case "WestWindEstate":
            case "Dogtown":
                return Cast<Int8>(43);
            default:
                return Cast<Int8>(-1);
        };
    };

    func getDistrictSpawnPointSearchParams(district_name: String) -> CyberpsychoEncountersSpawnPointSearchParams {
        // TODO Make params for the bandlands sunset motel area
        // and check using point in polygon + Badlands_RedPeaks
        let params: CyberpsychoEncountersSpawnPointSearchParams;
        switch district_name {
            case "Badlands":
            case "BiotechnicaFlats":
            case "JacksonPlains":
            case "LagunaBend":
            case "NorthBadlands":
            case "NorthSunriseOilField":
            case "Badlands_RockyRidge":
            case "SierraSonora":
            case "SouthBadlands":
                params.search_size = 50.00;
                params.sector_size = 10.00;
                params.deadzone = 20.00;
                break;
            case "Kabuki":
            case "Columbarium":
                params.search_size = 20.00;
                params.sector_size = 5.00;
                params.deadzone = 10.00;
                break;
            case "Badlands_SoCalBorderCrossing":
                params.search_size = 50.00;
                params.sector_size = 10.00;
                params.deadzone = 20.00;
                break;
            default:
                params.search_size = 40.00;
                params.sector_size = 10.00;
                params.deadzone = 15.00;
        };
        return params;
    };

    func rollCyberPsychoEncounterChance(district_chance: Int8,
                                        last_encounter_seconds: Uint32,
                                        cooldown_seconds: Uint32) -> Float {
        let highway_mod: Float;
        let last_encounter_add: Float;
        let gi: GameInstance = GetGameInstance();
        let preventionSpawnSys = GameInstance.GetPreventionSpawnSystem(gi);
        let last_encounter_seconds = Cast<Float>(last_encounter_seconds);
        let cooldown_seconds = Cast<Float>(cooldown_seconds);
        last_encounter_add = ((last_encounter_seconds - cooldown_seconds) * 0.0012);
        last_encounter_add = MaxF(0.00, MinF(15.00, (last_encounter_add)));
        if preventionSpawnSys.IsPlayerOnHighway() {
            highway_mod = 20.00;
        } else {
            highway_mod = 0.00;
        };
        let rand_factor = RandRangeF(-20.00, 25.00);

        let encounter_mult = this.GetEncounterMultiplier();
        FTLog(s"[CyberpsychoEncountersEventSystem][rollCyberPsychoEncounterChange]: District points: \(district_chance)");
        FTLog(s"[CyberpsychoEncountersEventSystem][rollCyberPsychoEncounterChange]: last encounter additive points: \(last_encounter_add)");
        FTLog(s"[CyberpsychoEncountersEventSystem][rollCyberPsychoEncounterChange]: highway modifer points: \(highway_mod)");
        FTLog(s"[CyberpsychoEncountersEventSystem][rollCyberPsychoEncounterChange]: Random factor points: \(rand_factor)");
        FTLog(s"[CyberpsychoEncountersEventSystem][rollCyberPsychoEncounterChange]: Encounter multiplier: \(encounter_mult)");
        let roll = Cast<Float>(district_chance)
                   + last_encounter_add
                   + rand_factor
                   * encounter_mult
                   - highway_mod;
        FTLog(s"[CyberpsychoEncountersEventSystem][rollCyberPsychoEncounterChange]: Final roll score: \(roll)");
        return roll;
    };

    func isEntityPartOfGroundPoliceSquad(entID: EntityID,
                                         groundPoliceSquads: array<array<EntityID>>) -> Bool {
        for squad in groundPoliceSquads {
            for id in squad {
                if entID == id {
                    return true;
                };
            };
        };
        return false;
    };

    func SpawnMaxTacAV() -> Bool {
        let gi: GameInstance = GetGameInstance();
        let PrevSpawnSystem = GameInstance.GetPreventionSpawnSystem(gi);
        let psycho = GameInstance.FindEntityByID(gi, this.cyberpsychoID);
        let psycho_pos: Vector4 = psycho.GetWorldPosition();
        if this.isCyberpsychoDefeated() {
            return false;
        };
        FTLog(s"[CyberpsychoEncountersEventSystem][SpawnMaxTacAV]: Psycho position: \(psycho.GetWorldPosition())");
        let spawn_point: Vector4;
        let spawn_point_v3: Vector3;
        let maxtac_npc_records = [t"Character.maxtac_av_LMG_mb",
                                  t"Character.maxtac_av_mantis_wa",
                                  t"Character.maxtac_av_riffle_ma",
                                  t"Character.maxtac_av_sniper_wa_elite"];
        if !this.FindValidMaxtacAVSpawnPointAroundCyberpsycho(psycho_pos, spawn_point) {
            FTLogWarning("[CyberpsychoEncountersEventSystem][SpawnMaxTacAV]: COULD NOT FIND SPAWNPOINT AV!, STARTING GROUND FALLBACK");
            return this.TryCreateMaxtacFallbackUnits();
        };
        spawn_point_v3 = Vector4.Vector4To3(spawn_point);
        PrevSpawnSystem.RequestAVSpawnAtLocation(t"Vehicle.max_tac_av1",
                                                 spawn_point_v3);
        FTLog(s"[CyberpsychoEncountersEventSystem][SpawnMaxTacAV]: MaxTac spawn point: \(spawn_point)");
        return true;
    };

    func MaxtacDetectPsychoFromAV(av: ref<GameObject>,
                                  cyberpsycho: ref<ScriptedPuppet>) -> Void {
        let passengers: array<wref<GameObject>>;
        let puppet: ref<ScriptedPuppet>;
        let gi: GameInstance = av.GetGame();
        let id: EntityID = av.GetEntityID();
        let i: Int32;
        VehicleComponent.GetAllPassengers(gi, id, false, passengers);
        i = 0;
        while i < ArraySize(passengers) {
            puppet = passengers[i] as ScriptedPuppet;
            if AIActionHelper.TryChangingAttitudeToHostile(puppet, cyberpsycho) {
                TargetTrackingExtension.InjectThreat(puppet, cyberpsycho, 1.00, -1.00);
                NPCPuppet.ChangeHighLevelState(puppet, gamedataNPCHighLevelState.Combat);
            };
            i += 1;
        };
    };

    func GetOffAVPsycho(psycho: ref<GameObject>, go: ref<GameObject>) -> Void {
        let biggestDelay: Float;
        let evt: ref<PushAnimEventDelayed>;
        let i: Int32;
        let jumpDelay: Float;
        let numberOfLMGs: Int32;
        let numberOfMantisBlades: Int32;
        let numberOfSnipers: Int32;
        let passenger: wref<ScriptedPuppet>;
        let passengers: array<wref<GameObject>>;
        let gi: GameInstance = go.GetGame();
        let id: EntityID = go.GetEntityID();
        VehicleComponent.GetAllPassengers(gi, id, false, passengers);
        i = 0;
        while i < ArraySize(passengers) {
            jumpDelay = 0.00;
            passenger = passengers[i] as ScriptedPuppet;
            switch passenger.GetRecordID() {
                case t"Character.maxtac_av_mantis_wa_2nd_wave":
                case t"Character.maxtac_av_mantis_wa":
                    jumpDelay = 2.00 + Cast<Float>(numberOfMantisBlades) / 4.00;
                    numberOfMantisBlades += 1;
                    break;
                case t"Character.maxtac_av_riffle_ma_2nd_wave":
                case t"Character.maxtac_av_riffle_ma":
                case t"Character.maxtac_av_LMG_mb_2nd_wave":
                case t"Character.maxtac_av_LMG_mb":
                    jumpDelay = 0.50 + Cast<Float>(numberOfLMGs) / 4.00;
                    numberOfLMGs += 1;
                    break;
                case t"Character.maxtac_av_sniper_wa_elite_2nd_wave":
                case t"Character.maxtac_av_sniper_wa_elite":
                case t"Character.maxtac_av_netrunner_ma_2nd_wave":
                case t"Character.maxtac_av_netrunner_ma":
                    jumpDelay = 1.20 + Cast<Float>(numberOfSnipers) / 4.00;
                    numberOfSnipers += 1;
                    break;
                default:
                    jumpDelay = Cast<Float>(i);
            };
            if jumpDelay > biggestDelay {
                biggestDelay = jumpDelay;
            };
              StatusEffectHelper.ApplyStatusEffect(passenger, t"BaseStatusEffect.MaxtacFightStartHelperStatus", jumpDelay);
              GameInstance.GetDelaySystem(gi).DelayEvent(passenger, AIEvents.ExitVehicleEvent(), jumpDelay);
              if i == 0 {
                  StatusEffectHelper.ApplyStatusEffect(psycho, t"StatusEffect.HackReveal", passenger.GetEntityID());
              };
              i += 1;
        };
        if ArraySize(passengers) > 0 {
            biggestDelay += 2.00;
            evt = new PushAnimEventDelayed();
            evt.go = go;
            evt.eventName = n"close_door_event";
            GameInstance.GetDelaySystem(gi).DelayScriptableSystemRequest(n"PsychoSquadAvHelperClass", evt, biggestDelay);
        };
    };

    func FindValidMaxtacAVSpawnPointAroundCyberpsycho(psycho_pos: Vector4,
                                                      out spawn_point: Vector4) -> Bool {
        let NavSys = GameInstance.GetNavigationSystem(GetGameInstance());
        let road_points: array<Vector3> = GetNearbyVehicleSpawnPoints(psycho_pos,
                                                                      50.00,
                                                                      10.00,
                                                                      15.00,
                                                                      15);
        let isPointFound: Bool = false;
        let isPointFallback: Bool = false;
        let road_points_v4: array<Vector4>;
        let player_fwd: Vector4 = GetPlayer(GetGameInstance()).GetWorldForward();
        for point in road_points {
            ArrayPush(road_points_v4, Vector4.Vector3To4(point));
        };

        if this.FindValidAVSpawnPoint(road_points_v4, spawn_point, isPointFallback)
        && !isPointFallback {
            FTLog("[CyberpsychoEncountersEventSystem][FindValidMaxtacAVSpawnPointAroundCyberpsycho]: Found valid spawn point for AV.");
            return true;
        };

        let vehicleNavGenAgent = IntEnum<NavGenAgentSize>(1);
        let pursuit_points: array<Vector4>;
        let fallback_pursuit_points: array<Vector4>;
        NavSys.FindPursuitPointsRange(psycho_pos,
                                      psycho_pos,
                                      player_fwd,
                                      10.00,
                                      50.00,
                                      50,
                                      false,
                                      vehicleNavGenAgent,
                                      pursuit_points,
                                      fallback_pursuit_points);
        if this.FindValidAVSpawnPoint(pursuit_points,
                                      spawn_point,
                                      isPointFallback) {
            return true;
        };

        if !Vector4.IsXYZZero(spawn_point) {
            return true;
        };

        return this.FindValidAVSpawnPoint(fallback_pursuit_points,
                                          spawn_point,
                                          isPointFallback);
    };

    func FindValidAVSpawnPoint(points: array<Vector4>,
                               out valid_point: Vector4,
                               out isFallback: Bool) -> Bool {
        let gi: GameInstance = GetGameInstance();
        let fallback_point: Vector4;
        let isFallbackFound: Bool = false;
        let player_pos = GetPlayer(gi).GetWorldPosition();
        for point in points {
            /* The AV always spawns with a -90 degree rotation from the player
               so the door faces the player. This isn't perfect though since
               the AV continues to rotate if the play moves. */
            let direction = Vector4.Normalize(player_pos - point);
            direction = Vector4.RotByAngleXY(direction,  -90.00);
            if this.isPointSuitableForAVSpawn(point, direction, false) {
                valid_point = point;
                return true;
            } else {
                if !isFallbackFound
                && this.isPointSuitableForAVSpawn(point, direction, true) {
                    fallback_point = point;
                    isFallbackFound = true;
                };
            };
        };
        if !Vector4.IsXYZZero(fallback_point) {
            FTLogWarning(s"[CyberpsychoEncountersEventSystem][FindValidAVSpawnPoint] USING FALLBACK POINT \(fallback_point)");
            valid_point = fallback_point;
            isFallback = true;
            return true;
        };

        FTLogWarning(s"[CyberpsychoEncountersEventSystem][FindValidAVSpawnPoint] FAILED TO FIND AV SPAWNPOINT");
        return false;
    };

    func isPointSuitableForAVSpawn(v4: Vector4,
                                   fwd: Vector4,
                                   isFallbackDimensions: Bool) -> Bool {
        let width: Float = 10.00;
        let length: Float = 10.00;
        /* The large height is to prevent the AV from spawning directly under a
           bridge or building. */
        let height: Float = 30.00;
        fwd.Z = 0.00;
        fwd.W = 0.00;
        v4 = v4 - (fwd * 6.30);
        if isFallbackDimensions {
          width = 5.00;
        };
        return HasSpaceInFrontOfPoint(v4, fwd, 0.00, width, length, height);
    };

    func FindCyberpsychoMappin(MappinID: NewMappinID) -> wref<IMappin> {
        let gi: GameInstance = GetGameInstance();
        let MappinSys = GameInstance.GetMappinSystem(gi);
        let mappins: array<ref<IMappin>> = MappinSys.GetAllMappins();
        let pin: wref<IMappin>;
        for pin in mappins {
            if Equals(MappinID, pin.GetNewMappinID()) {
                return pin;
            };
        };
        return pin;
    };

    func DEBUG_StressTestCyberpsychoChanceRolls(district_name: String,
                                                start_last_encounter_seconds: Uint32,
                                                cooldown_seconds: Uint32,
                                                min_roll_needed: Float) -> Void {
        let i = 0;
        let roll: Float = 0.00;
        let district_chance: Int8;
        let last_encounter_seconds = start_last_encounter_seconds;
        district_chance = this.getDistrictSpawnChance(district_name);
        if district_chance == Cast<Int8>(-1) {
            FTLogWarning(s"[CyberpsychoEncountersEventSystem][DEBUG_StrestTestCyberpsychoChanceRolls]: INVALID DISTRICTNAME: \(district_name)");
            return;
        };
        while roll < min_roll_needed {
            if last_encounter_seconds > cooldown_seconds {
                roll = this.rollCyberPsychoEncounterChance(district_chance,
                                                           last_encounter_seconds,
                                                           cooldown_seconds);

            };
            last_encounter_seconds += 120u;
            i += 1;
            if i > 20000 {
                FTLogWarning(s"[CyberpsychoEncountersEventSystem][DEBUG_StressTestCyberpsychoChanceRolls]: COULD NOT GET SUCCESFFUL ROLL");
                break;
            };
        };
        FTLog(s"[CyberpsychoEncountersEventSystem][DEBUG_StressTestCyberpsychoChanceRolls]: Total roles until success \(i + 1)");
        let iF = Cast<Uint32>(i);
        FTLog(s"[CyberpsychoEncountersEventSystem][DEBUG_StressTestCyberpsychoChanceRolls]: Total seconds until success \((last_encounter_seconds))");
        FTLog(s"[CyberpsychoEncountersEventSystem][DEBUG_StressTestCyberpsychoChanceRolls]: Total minutes until success \(Cast<Float>(last_encounter_seconds) / 60.00)");
    };
}

public class CyberpsychoEncountersSettings {
    @runtimeProperty("ModSettings.mod", "Random Cyberpsychos")
    @runtimeProperty("ModSettings.displayName", "Cooldown Minutes")
    @runtimeProperty("ModSettings.description", "Minimum amount of minutes between two cyberpsycho attacks.")
    @runtimeProperty("ModSettings.step", "5")
    @runtimeProperty("ModSettings.min", "5")
    @runtimeProperty("ModSettings.max", "60")
    @runtimeProperty("ModSettings.dependency", "enabled")
    let cooldownMinutes: Int32 = 15;

    @runtimeProperty("ModSettings.mod", "Random Cyberpsychos")
    @runtimeProperty("ModSettings.displayName", "Encounter Multiplier")
    @runtimeProperty("ModSettings.description", "Modifies how frequently cyberpsycho attacks occur. Higher values increase frequency.")
    @runtimeProperty("ModSettings.step", "0.05")
    @runtimeProperty("ModSettings.min", "0.65")
    @runtimeProperty("ModSettings.max", "1.50")
    @runtimeProperty("ModSettings.dependency", "enabled")
    let encounterMultiplier: Float = 1.00;
}
