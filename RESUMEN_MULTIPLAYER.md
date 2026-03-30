# Resumen: Lógica Multijugador con RPC

## ¿Qué es RPC?

**RPC (Remote Procedure Call)** es un sistema que permite ejecutar funciones en otras máquinas de la red. En Godot, se usa con el decorador `@rpc` para marcar funciones que pueden ser llamadas desde otros clientes.

## Concepto Principal: Cliente-Servidor

```
El SERVIDOR (Host) es la autoridad
    ↓
Toma todas las decisiones importantes
    ↓
Los CLIENTES solo envían comandos y reciben actualizaciones
```

### ¿Por qué este modelo?

1. **Previene trampas**: Los clientes no pueden hacer cambios directos
2. **Consistencia**: Todos ven el mismo estado del juego
3. **Simplicidad**: Una sola fuente de verdad

## Flujo de Juego Multijugador

### 1. Spawning de Unidades

```
CLIENTE                    SERVIDOR                    TODOS LOS CLIENTES
   │                          │                              │
   │──request_spawn_unit()──→ │                              │
   │                          │                              │
   │                          │ Valida recursos              │
   │                          │ Genera ID único              │
   │                          │                              │
   │                          │──spawn_unit_at()────────────→│
   │                          │                              │
   │←─────────────────────────┴──────────────────────────────┤
   │                  Todos instancian la unidad             │
```

**Código ejemplo:**
```gdscript
# Cliente solicita
func on_spawn_button_pressed():
    request_spawn_unit.rpc("roman_warrior", my_team_id)

# Servidor valida y confirma
@rpc("any_peer", "reliable")
func request_spawn_unit(unit_type: String, team_id: int):
    if not multiplayer.is_server():
        return

    if player_has_resources(sender):
        spawn_unit_at.rpc(unit_type, position, team_id, new_id)

# Todos ejecutan
@rpc("authority", "call_local", "reliable")
func spawn_unit_at(unit_type: String, pos: Vector3, team: int, id: int):
    var unit = SCENES[unit_type].instantiate()
    unit.network_id = id
    add_child(unit)
```

### 2. Movimiento de Unidades

```
SERVIDOR (cada 0.05s)           CLIENTES
      │                            │
      │─sync_units_snapshot()────→ │
      │  {pos, rot, health, ...}   │
      │                            │
      │                            │ Interpola suavemente
      │                            │ entre snapshots
```

**Dos opciones:**

#### Opción A: Snapshot (Recomendada para tu juego)
- Servidor envía estado completo periódicamente
- Simple y robusto
- Bueno para unidades con IA

```gdscript
# Servidor (cada 50ms)
@rpc("authority", "unreliable_ordered")
func sync_units_snapshot(units: Array):
    pass  # Clientes reciben y actualizan

# Cliente interpola
func _process(delta):
    position = position.lerp(target_position, 10.0 * delta)
```

#### Opción B: Event-Based
- Solo envía cuando algo importante cambia
- Ahorra ancho de banda
- Más complejo

```gdscript
@rpc("authority", "reliable")
func unit_state_changed(unit_id: int, new_state: int):
    pass

@rpc("authority", "reliable")
func unit_take_damage(unit_id: int, damage: int):
    pass
```

### 3. Sistema de Combate

```
SERVIDOR (simula combate)
    │
    │ Detecta colisión/rango
    │ Calcula daño
    │ Actualiza salud
    │
    │──apply_damage()──→ TODOS
    │
Todos actualizan visualmente
```

**Código:**
```gdscript
# Solo el servidor ejecuta la lógica de ataque
func try_attack():
    if not multiplayer.is_server():
        return  # Clientes no atacan directamente

    if can_attack(target):
        apply_damage.rpc(target.network_id, stats.damage)

# Todos aplican el resultado
@rpc("authority", "call_local", "reliable")
func apply_damage(target_id: int, damage: int):
    var unit = UnitManager.get_unit_by_id(target_id)
    unit.current_health -= damage
    if unit.current_health <= 0:
        unit.die()
```

## Componentes Clave a Implementar

### 1. UnitManager (Autoload)
```gdscript
# Gestiona IDs únicos para cada unidad
extends Node

var _next_id = 0
var _units = {}  # {id: unit_node}

func register_unit(unit) -> int:
    var id = _next_id
    _next_id += 1
    _units[id] = unit
    return id

func get_unit_by_id(id: int):
    return _units.get(id)
```

### 2. Network ID en MeleeUnit
```gdscript
class_name MeleeUnit

var network_id: int = -1  # Asignado por servidor

func _ready():
    if multiplayer.is_server():
        network_id = UnitManager.register_unit(self)
```

### 3. Sistema de Recursos
```gdscript
# En autoload Game
var player_resources = {}  # {player_id: gold}

@rpc("authority", "call_local", "reliable")
func sync_resources(player_id: int, gold: int):
    player_resources[player_id] = gold
    update_ui()
```

## Tipos de RPC en Godot

### Atributos del decorador @rpc

1. **Autoridad**: ¿Quién puede llamar?
   - `"any_peer"`: Cualquier cliente puede llamar
   - `"authority"`: Solo el servidor puede llamar

2. **Modo de llamada**:
   - `"call_local"`: También ejecuta en quien lo envía
   - Sin este flag: Solo ejecuta en receptores

3. **Confiabilidad**:
   - `"reliable"`: Garantiza entrega (TCP-like)
   - `"unreliable"`: Puede perderse (UDP)
   - `"unreliable_ordered"`: Puede perderse pero mantiene orden

### Patrones Comunes

```gdscript
# Cliente solicita, servidor valida
@rpc("any_peer", "reliable")
func request_something():
    if not multiplayer.is_server():
        return
    # validar...
    confirm_something.rpc()

# Servidor notifica a todos
@rpc("authority", "call_local", "reliable")
func confirm_something():
    # Todos ejecutan esto

# Actualización frecuente, puede perderse
@rpc("authority", "unreliable_ordered")
func sync_position(pos: Vector3):
    pass
```

## Optimizaciones

### 1. Tick Rate
```gdscript
# No enviar cada frame, sino cada X ms
var tick_rate = 0.05  # 20 Hz
var timer = 0.0

func _process(delta):
    if not multiplayer.is_server():
        return

    timer += delta
    if timer >= tick_rate:
        timer = 0.0
        sync_units()
```

### 2. Relevancia (Culling)
```gdscript
# Solo sincronizar unidades cercanas
func get_relevant_units(player_pos: Vector3) -> Array:
    var relevant = []
    for unit in all_units:
        if unit.position.distance_to(player_pos) < 50.0:
            relevant.append(unit)
    return relevant
```

### 3. Agregación
```gdscript
# Enviar múltiples updates en un solo RPC
@rpc("authority", "unreliable_ordered")
func sync_multiple_units(units_data: Array):
    # [{id, pos, rot}, {id, pos, rot}, ...]
    for data in units_data:
        update_unit(data)
```

### 4. Delta Compression
```gdscript
# Solo enviar si cambió significativamente
var last_synced_pos: Vector3

func should_sync():
    return position.distance_to(last_synced_pos) > 0.1
```

## Plan de Implementación Paso a Paso

### Paso 1: UnitManager (Fundamental)
```gdscript
# Crear autoloads/unit_manager.gd
extends Node

var _next_id = 0
var _units = {}

func register_unit(unit) -> int:
    if not multiplayer.is_server():
        return -1
    var id = _next_id
    _next_id += 1
    _units[id] = unit
    return id

func get_unit_by_id(id: int):
    return _units.get(id)
```

### Paso 2: Modificar MeleeUnit
```gdscript
# En scripts/MeleeUnit.gd
var network_id: int = -1

func _ready():
    # ... código existente ...
    if multiplayer.is_server():
        network_id = UnitManager.register_unit(self)
```

### Paso 3: Sistema de Spawn
```gdscript
# Crear scripts/spawn_controller.gd
extends Node

const UNITS = {
    "roman_warrior": preload("res://Scenes/roman_warrior.tscn")
}

@rpc("any_peer", "reliable")
func request_spawn(unit_type: String, team: int):
    if not multiplayer.is_server():
        return

    var sender = multiplayer.get_remote_sender_id()
    # Validar recursos...

    var id = UnitManager.get_next_id()
    spawn_unit.rpc(unit_type, get_spawn_pos(), team, id)

@rpc("authority", "call_local", "reliable")
func spawn_unit(type: String, pos: Vector3, team: int, id: int):
    var unit = UNITS[type].instantiate()
    unit.network_id = id
    unit.team_id = team
    unit.global_position = pos
    add_child(unit)
```

### Paso 4: Sincronización Básica
```gdscript
# En MeleeUnit.gd
var _sync_timer = 0.0
var _tick_rate = 0.05

func _physics_process(delta):
    # ... lógica existente ...

    if multiplayer.is_server():
        _sync_timer += delta
        if _sync_timer >= _tick_rate:
            _sync_timer = 0.0
            sync_state.rpc(global_position, rotation.y, current_health)

@rpc("authority", "unreliable_ordered")
func sync_state(pos: Vector3, rot: float, health: int):
    if multiplayer.is_server():
        return
    # Clientes interpolan
    target_position = pos
    target_rotation = rot
    current_health = health
```

### Paso 5: Testing
```gdscript
# Usar lobby/lobby_test.gd existente
# Probar con 2-3 instancias del juego
# Verificar que unidades aparecen en todos los clientes
```

## Checklist de Implementación

### Básico
- [ ] Crear UnitManager autoload
- [ ] Añadir network_id a MeleeUnit
- [ ] Implementar sistema de spawn con RPC
- [ ] Sincronizar posición de unidades
- [ ] Probar con 2 clientes

### Intermedio
- [ ] Sistema de daño server-authoritative
- [ ] Sincronización de salud
- [ ] Muerte y limpieza de unidades
- [ ] Recursos por jugador
- [ ] Validación de spawn (recursos suficientes)

### Avanzado
- [ ] Interpolación suave en clientes
- [ ] Optimización con culling
- [ ] Agregación de updates
- [ ] Manejo de desconexión
- [ ] UI de estado de red

## Debugging

### Herramientas útiles
```gdscript
# Ver qué RPCs se están llamando
func _ready():
    multiplayer.peer_packet.connect(func(id, packet):
        print("[NET] Packet from %d: %d bytes" % [id, packet.size()])
    )

# Mostrar ping
func _process(_delta):
    $PingLabel.text = "Ping: %d ms" % multiplayer.get_peer_ping(1)

# Simular lag (para testing)
func simulate_lag(ms: int):
    await get_tree().create_timer(ms / 1000.0).timeout
```

## Preguntas Frecuentes

### ¿Por qué el servidor hace todo?
- Previene cheating
- Mantiene consistencia
- Es el estándar en juegos multijugador

### ¿Y si el servidor tiene lag?
- Todos experimentan el mismo lag
- Es mejor consistente con lag que inconsistente sin lag
- Se puede implementar client-side prediction (avanzado)

### ¿Cuántas unidades soporta?
- Depende de la optimización
- Con este sistema: ~200-300 unidades
- Más allá requiere técnicas avanzadas

### ¿Funciona en Internet o solo LAN?
- ENet funciona en ambos
- Para Internet necesitas port forwarding o servidor dedicado
- Para testing local es suficiente

## Recursos Adicionales

- Documentación oficial de Godot: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- Tu código existente en `autoloads/lobby.gd` ya tiene ejemplos de RPC
- El sistema de roles en `lobby/waiting_screen.gd` usa RPCs similares

## Conclusión

La clave del multijugador con RPC es:

1. **Servidor = Autoridad**: El servidor decide todo
2. **Clientes = Solicitan**: Los clientes piden permiso
3. **RPC = Comunicación**: Los RPCs transmiten comandos y actualizaciones
4. **Network IDs = Referencias**: Cada entidad tiene un ID único
5. **Sincronización = Regular**: Actualizaciones frecuentes mantienen consistencia

Con este sistema, puedes crear un juego multijugador robusto y resistente a trampas.
