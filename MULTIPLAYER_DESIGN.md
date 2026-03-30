# Diseño de Lógica Multijugador con RPC para el Juego

## Resumen Ejecutivo

Este documento describe una arquitectura completa para implementar la lógica multijugador en el juego usando el sistema RPC (Remote Procedure Call) de Godot. El juego es un RTS (Real-Time Strategy) de combate con unidades militares, y necesita sincronización en tiempo real entre múltiples jugadores.

## Arquitectura Actual

### Infraestructura Existente
- **Motor**: Godot 4.6
- **Networking**: ENetMultiplayerPeer (protocolo UDP confiable)
- **Modelo**: Cliente-Servidor (autoridad en servidor)
- **RPC System**: Sistema `@rpc` nativo de Godot
- **Autoloads**: Game, Lobby, Debug

### Componentes Clave
1. **Lobby System**: Host/Join screens, waiting room, role selection
2. **Player Management**: Sistema de PlayerData con índices, roles y votos
3. **Units**: MeleeUnit con IA básica (IDLE, CHASE, ATTACK, DEAD)
4. **Castles**: Base castles como puntos de spawn

## Propuesta de Diseño Multijugador

### 1. Arquitectura General

#### 1.1 Modelo de Autoridad
```
CLIENT-SERVER MODEL
┌─────────────┐
│   Server    │ ◄── Autoridad completa del juego
│  (Host)     │     - Valida acciones
│             │     - Simula física
└──────┬──────┘     - Resuelve combate
       │            - Gestiona spawning
       │
   ┌───┴────┬────────┐
   │        │        │
┌──▼──┐ ┌──▼──┐ ┌──▼──┐
│Client│ │Client│ │Client│
│  1   │ │  2   │ │  3   │
└──────┘ └──────┘ └──────┘
```

**Ventajas de este modelo:**
- Previene cheating (el servidor valida todo)
- Sincronización consistente
- El servidor tiene la "verdad" única del juego

### 2. Sistema de Sincronización por Capas

#### Capa 1: Sincronización de Estado del Juego
**Componentes a sincronizar:**
- Gold/Recursos de cada jugador
- Estado de las bases/castillos
- Contador de unidades vivas
- Fase del juego (preparación, combate, finalizado)

**Implementación RPC:**
```gdscript
# En autoload/game.gd o nuevo game_state.gd
@rpc("authority", "call_local", "reliable")
func sync_game_state(game_data: Dictionary) -> void:
    # Actualizar recursos, estados globales
    pass

@rpc("any_peer", "reliable")
func request_spawn_unit(unit_type: String, position: Vector3, team_id: int) -> void:
    # Cliente solicita spawn al servidor
    pass

@rpc("authority", "call_local", "reliable")
func spawn_unit_confirmed(unit_id: int, unit_type: String, position: Vector3, team_id: int) -> void:
    # Servidor confirma y todos instancian
    pass
```

#### Capa 2: Sincronización de Unidades
**Datos críticos por unidad:**
- ID único (asignado por servidor)
- Posición y rotación
- Estado de salud
- Estado de IA (IDLE, CHASE, ATTACK, DEAD)
- Target actual

**Estrategia de sincronización:**

**Opción A: Snapshot System (Recomendado)**
```gdscript
# Server envía snapshots periódicos (10-20 Hz)
@rpc("authority", "unreliable_ordered")
func sync_units_snapshot(units_data: Array[Dictionary]) -> void:
    # [{id, pos, rot, health, state, target_id}, ...]
    pass
```

**Opción B: Event-Based System**
```gdscript
# Solo sincronizar eventos importantes
@rpc("authority", "reliable")
func unit_state_changed(unit_id: int, new_state: int) -> void:
    pass

@rpc("authority", "reliable")
func unit_take_damage(unit_id: int, damage: int, new_health: int) -> void:
    pass

@rpc("authority", "reliable")
func unit_died(unit_id: int) -> void:
    pass
```

#### Capa 3: Input del Jugador
**Modelo Client-Side Prediction + Server Reconciliation**
```gdscript
# Cliente envía comandos, no ejecuta directamente
@rpc("any_peer", "reliable")
func player_command_spawn(unit_type: String, spawn_point: Vector3) -> void:
    if not multiplayer.is_server():
        return

    # Validar comando
    if can_afford_unit(sender_id, unit_type):
        spawn_unit_for_player(sender_id, unit_type, spawn_point)
```

### 3. Sistema de Sincronización de Unidades (Detallado)

#### 3.1 Node Sync vs Manual RPC

**Opción 1: MultiplayerSynchronizer (Automático)**
```gdscript
# Añadir a cada unidad
# Ventajas: Automático, menos código
# Desventajas: Más ancho de banda, menos control

@export var sync_position := true
@export var sync_health := true

func _ready():
    var sync = MultiplayerSynchronizer.new()
    sync.root_path = get_path()
    sync.replication_interval = 0.1  # 10 Hz
    add_child(sync)
```

**Opción 2: RPC Manual (Recomendado para tu juego)**
```gdscript
# Mayor control y optimización
# Servidor actualiza periódicamente

var _tick_rate := 0.05  # 20 Hz
var _sync_timer := 0.0

func _physics_process(delta: float) -> void:
    if not multiplayer.is_server():
        return

    _sync_timer += delta
    if _sync_timer >= _tick_rate:
        _sync_timer = 0.0
        _broadcast_unit_state()

func _broadcast_unit_state() -> void:
    var state_data = {
        "id": unit_network_id,
        "pos": global_position,
        "rot": rotation.y,
        "health": current_health,
        "state": current_state
    }
    sync_unit_state.rpc(state_data)

@rpc("authority", "unreliable_ordered")
func sync_unit_state(data: Dictionary) -> void:
    if multiplayer.is_server():
        return
    # Clientes aplican interpolación
    _target_position = data.pos
    _target_rotation = data.rot
    current_health = data.health
    current_state = data.state
```

#### 3.2 Interpolación en Cliente (Suavizado)
```gdscript
# Cliente interpola para compensar latencia
var _target_position: Vector3
var _target_rotation: float
var _interpolation_speed := 10.0

func _physics_process(delta: float) -> void:
    if not multiplayer.is_server():
        # Cliente interpola
        global_position = global_position.lerp(_target_position, _interpolation_speed * delta)
        rotation.y = lerp_angle(rotation.y, _target_rotation, _interpolation_speed * delta)
```

### 4. Sistema de Gestión de Unidades

#### 4.1 Network ID Manager
```gdscript
# autoloads/unit_manager.gd
extends Node

var _next_unit_id := 0
var _units_by_id: Dictionary = {}  # {network_id: unit_node}

func register_unit(unit: MeleeUnit) -> int:
    if not multiplayer.is_server():
        return -1

    var id = _next_unit_id
    _next_unit_id += 1
    _units_by_id[id] = unit
    return id

func get_unit_by_id(id: int) -> MeleeUnit:
    return _units_by_id.get(id)

@rpc("authority", "call_local", "reliable")
func spawn_unit_at(unit_type: String, position: Vector3, team_id: int, network_id: int) -> void:
    # Instanciar unidad con network_id específico
    pass
```

#### 4.2 Spawning System
```gdscript
# Controlador de spawn en escena principal
extends Node

const UNIT_SCENES = {
    "roman_warrior": preload("res://Scenes/roman_warrior.tscn"),
    "roman_heavy": preload("res://Scenes/roman_heavy.tscn")
}

@rpc("any_peer", "reliable")
func request_spawn_unit(unit_type: String, team_id: int) -> void:
    if not multiplayer.is_server():
        return

    var sender_id = multiplayer.get_remote_sender_id()
    var player = Game.get_player(sender_id)

    # Validaciones
    if not can_spawn_unit(player, unit_type):
        notify_spawn_failed.rpc_id(sender_id, "Not enough resources")
        return

    # Deducir recursos
    deduct_resources(player, unit_type)

    # Generar ID y posición
    var network_id = UnitManager.get_next_id()
    var spawn_pos = get_spawn_position(team_id)

    # Notificar a todos los clientes
    spawn_unit_at.rpc(unit_type, spawn_pos, team_id, network_id)

@rpc("authority", "call_local", "reliable")
func spawn_unit_at(unit_type: String, position: Vector3, team_id: int, network_id: int) -> void:
    var unit_scene = UNIT_SCENES[unit_type]
    var unit = unit_scene.instantiate()
    unit.team_id = team_id
    unit.network_id = network_id
    unit.global_position = position
    add_child(unit)
    UnitManager.register_unit(network_id, unit)
```

### 5. Sistema de Combate

#### 5.1 Damage System (Server-Authoritative)
```gdscript
# En MeleeUnit.gd
func try_attack() -> void:
    if not multiplayer.is_server():
        return  # Solo el servidor ejecuta ataques

    if target == null:
        return

    if attack_timer.is_stopped() and is_instance_valid(target):
        if global_position.distance_to(target.global_position) <= stats.attack_range:
            # Servidor aplica daño y notifica
            apply_damage_to_unit.rpc(target.network_id, stats.damage)
            attack_timer.start()
            # Animación se puede ejecutar localmente
            notify_attack_animation.rpc(network_id)

@rpc("authority", "call_local", "reliable")
func apply_damage_to_unit(target_id: int, damage: int) -> void:
    var unit = UnitManager.get_unit_by_id(target_id)
    if unit:
        unit.take_damage(damage)

@rpc("authority", "unreliable")
func notify_attack_animation(attacker_id: int) -> void:
    var unit = UnitManager.get_unit_by_id(attacker_id)
    if unit:
        unit.start_attack_animation()
```

### 6. Sistema de Recursos y Economía

#### 6.1 Player Resources
```gdscript
# En autoloads/game.gd
var player_resources: Dictionary = {}  # {player_id: gold}

@rpc("authority", "call_local", "reliable")
func sync_player_resources(player_id: int, gold: int) -> void:
    player_resources[player_id] = gold
    # Actualizar UI

@rpc("any_peer", "reliable")
func request_resource_update(amount: int) -> void:
    if not multiplayer.is_server():
        return

    var sender_id = multiplayer.get_remote_sender_id()
    # Validar y actualizar
    player_resources[sender_id] += amount
    sync_player_resources.rpc(sender_id, player_resources[sender_id])
```

### 7. Optimizaciones de Red

#### 7.1 Relevancia y Culling
```gdscript
# Solo sincronizar unidades visibles o cercanas al jugador
func get_relevant_units(player_id: int) -> Array[int]:
    var player = Game.get_player(player_id)
    var player_camera_pos = get_player_camera_position(player_id)

    var relevant = []
    for unit_id in UnitManager._units_by_id:
        var unit = UnitManager.get_unit_by_id(unit_id)
        if unit.global_position.distance_to(player_camera_pos) < 50.0:
            relevant.append(unit_id)

    return relevant
```

#### 7.2 Agregación de Updates
```gdscript
# Enviar múltiples updates en un solo RPC
@rpc("authority", "unreliable_ordered")
func sync_multiple_units(units_data: Array) -> void:
    # [{id, pos, rot, health}, {id, pos, rot, health}, ...]
    for data in units_data:
        var unit = UnitManager.get_unit_by_id(data.id)
        if unit:
            unit.apply_sync_data(data)
```

#### 7.3 Delta Compression
```gdscript
# Solo enviar datos que cambiaron significativamente
var _last_synced_position: Vector3
var _position_delta_threshold := 0.1

func should_sync_position() -> bool:
    return global_position.distance_to(_last_synced_position) > _position_delta_threshold
```

### 8. Manejo de Conexión/Desconexión

#### 8.1 Player Disconnect
```gdscript
# En autoloads/lobby.gd
func _handle_peer_disconnected(id: int) -> void:
    # Remover unidades del jugador
    UnitManager.remove_player_units(id)

    # Redistribuir recursos si es necesario
    if Game.redistribute_on_disconnect:
        redistribute_player_resources(id)

    # Actualizar estado del juego
    Game.remove_player(id)

    # Notificar a otros jugadores
    notify_player_left.rpc(id)
```

#### 8.2 Reconnection (Opcional, avanzado)
```gdscript
# Sistema para permitir reconexión
var _disconnected_players: Dictionary = {}  # {player_id: {timestamp, state}}

func handle_player_reconnect(player_id: int) -> void:
    if player_id in _disconnected_players:
        # Restaurar estado del jugador
        var saved_state = _disconnected_players[player_id]
        restore_player_state.rpc_id(player_id, saved_state)
```

### 9. Sincronización de Estado del Juego

#### 9.1 Game Phase System
```gdscript
# autoloads/game.gd
enum GamePhase {
    SETUP,      # Preparación inicial
    PLAYING,    # Juego activo
    ENDED       # Juego terminado
}

var current_phase: GamePhase = GamePhase.SETUP

@rpc("authority", "call_local", "reliable")
func set_game_phase(phase: GamePhase) -> void:
    current_phase = phase
    emit_signal("phase_changed", phase)

@rpc("authority", "call_local", "reliable")
func sync_game_victory(winning_team: int) -> void:
    set_game_phase(GamePhase.ENDED)
    show_victory_screen(winning_team)
```

### 10. Testing y Debugging

#### 10.1 Network Debugger
```gdscript
# autoloads/network_debug.gd
extends Node

var log_rpc_calls := true
var show_latency := true
var simulate_lag := 0  # ms

func _ready():
    if OS.has_feature("editor"):
        multiplayer.peer_packet.connect(_log_packet)

func _log_packet(peer_id: int, packet: PackedByteArray):
    if log_rpc_calls:
        print("[NET] Packet from %d: %d bytes" % [peer_id, packet.size()])
```

#### 10.2 Test Scenarios
```gdscript
# lobby/lobby_test.gd (ya existe)
# Mejorar para probar:
# - Spawn masivo de unidades
# - Desconexión forzada
# - Lag simulado
# - Múltiples clientes locales
```

### 11. UI y Feedback

#### 11.1 Network Status Indicator
```gdscript
# Mostrar ping, packet loss
@onready var network_label: Label = $NetworkStatus

func _process(delta: float) -> void:
    if Game.is_online():
        var ping = multiplayer.get_peer_ping(1)  # Ping al servidor
        network_label.text = "Ping: %d ms" % ping
```

#### 11.2 Unit Selection y Commands
```gdscript
# Sistema de input del jugador
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            # Click para spawnear
            var spawn_pos = get_world_position_from_mouse()
            request_spawn_unit.rpc("roman_warrior", get_current_team_id())
```

## Implementación por Fases

### Fase 1: Fundamentos (Recomendado empezar aquí)
- [ ] Sistema de Network ID para unidades
- [ ] Spawning básico con RPC
- [ ] Sincronización de posición de unidades
- [ ] Autoload UnitManager

### Fase 2: Combate
- [ ] Sistema de daño server-authoritative
- [ ] Sincronización de salud
- [ ] Muerte y remoción de unidades
- [ ] Animaciones de ataque replicadas

### Fase 3: Economía
- [ ] Sistema de recursos por jugador
- [ ] Costo de unidades
- [ ] Validación de spawn
- [ ] UI de recursos

### Fase 4: Game State
- [ ] Fases del juego
- [ ] Condiciones de victoria
- [ ] Sistema de castillos/bases
- [ ] Pantalla de fin de juego

### Fase 5: Optimización
- [ ] Interpolación suave
- [ ] Culling de relevancia
- [ ] Agregación de updates
- [ ] Compresión de datos

### Fase 6: Polish
- [ ] Manejo de reconexión
- [ ] Network debugging tools
- [ ] Indicadores visuales de red
- [ ] Sistema de chat (opcional)

## Consideraciones Importantes

### Performance
- **Tick Rate**: 20 Hz para snapshots (suficiente para RTS)
- **Reliable vs Unreliable**: Comandos = reliable, posición = unreliable_ordered
- **Max Units**: Considerar límite de ~200-300 unidades totales

### Security
- **Validación Server-Side**: TODO debe validarse en servidor
- **Anti-cheat**: El cliente nunca debe poder modificar datos críticos
- **Rate Limiting**: Limitar comandos por segundo por jugador

### Scalability
- **Max Players**: 2-4 jugadores recomendado
- **Bandwidth**: ~50-100 KB/s por cliente (estimado)
- **Server Hosting**: Usar dedicado para partidas serias

## Archivos a Crear/Modificar

### Nuevos Archivos
```
autoloads/
  ├── unit_manager.gd         # Gestión de IDs y referencias
  ├── network_debug.gd        # Debugging de red
  └── resource_manager.gd     # Economía del juego

scripts/
  ├── game_controller.gd      # Lógica principal del juego
  └── spawn_controller.gd     # Control de spawning
```

### Archivos a Modificar
```
scripts/
  └── MeleeUnit.gd            # Añadir network_id, RPCs

autoloads/
  ├── game.gd                 # Añadir recursos, fases
  └── lobby.gd                # Mejorar manejo de desconexión

project.godot                 # Registrar nuevos autoloads
```

## Conclusión

Este diseño proporciona una arquitectura robusta y escalable para implementar multijugador en el juego usando RPC. El enfoque client-server con autoridad en servidor previene cheating y mantiene consistencia, mientras que las optimizaciones propuestas aseguran buen rendimiento.

**Próximos pasos recomendados:**
1. Implementar UnitManager (autoload)
2. Añadir network_id a MeleeUnit
3. Crear sistema de spawning con RPC
4. Probar con 2 clientes en lobby_test
5. Iterar y optimizar basándose en testing

**Nota**: Este es un diseño completo pero no implementado. Cada sección puede adaptarse según las necesidades específicas del juego.
