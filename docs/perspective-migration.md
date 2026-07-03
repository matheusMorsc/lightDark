# Migration: Top-Down → Don't Starve-Style Perspective

Pure 2D. No 3D, no isometric diamond grid. The trick Don't Starve uses (and we copy) is:

> **The ground stays a flat top-down plane. The *objects* are tall, feet-anchored billboards, Y-sorted, with foreshortened vertical movement.**

That means your gameplay logic (distances, overlaps, tile coords) barely changes. The work is in scene structure, sprite anchoring, collision shapes, and art direction.

---

## 0. Architecture audit — keep vs. rewrite

### Stays unchanged (logic is perspective-agnostic)
| System | File | Why it survives |
|---|---|---|
| Health/hunger/inventory/crafting | `autoload/game_state.gd` | Pure state + signals, zero spatial code |
| Item definitions | `autoload/item_db.gd` | Data only |
| HUD | `ui/hud.gd`, `ui/inventory_slot.gd` | Screen-space UI |
| Enemy AI *logic* | `entities/enemy.gd` | Distance-based chase/attack works identically on the new plane |
| Resource gathering *logic* | `entities/resource_node.gd` | `hit()` interface is spatial-agnostic |
| Lighting | Lit addon setup | 2D lights don't care about perspective; occluder *shapes* change, setup doesn't |
| Audio, cursor manager | mostly | CursorManager reach-check may need the depth tolerance from §6 |

### Needs modification (visual/spatial layer)
| System | File | Change |
|---|---|---|
| Scene tree | `test_biome.tscn` | Add Y-sorted `Entities` container (§4) |
| Every entity scene | `entities/*.tscn` | Re-anchor origin to feet, flatten collider to base ellipse (§3, §5) |
| Player movement | `player/player.gd` | Y foreshortening (~0.8×), diagonal anims optional (§6) |
| Attack area | `player/player.tscn` | Flattened ellipse + facing offset (§6) |
| Ground tilemap | `world/cave_floor.gd/.tscn` | Art restyle only — code survives (§2) |
| Organic walls | `world/organic_wall.gd` | Add "top face" polygon + taller texture treatment (§7) |
| Camera | `player/player.tscn` PCam | Slight downward frame offset, maybe zoom-out (§1) |

### New systems to build
- `HeightSprite` component — fake vertical height (§3)
- `WallPiece` scene template + occlusion fade (§7)
- `WorldLayer` / layer manager for bunker floors (§8)
- `VisibleOnScreenEnabler2D` pass on decor (§9)

### Delete
- `TileMapLayer3D-*/` folder in project root — unused 3D addon, pure clutter.

---

## 1. Migration plan (phased, each phase ships playable)

**Phase 1 — Structure (1–2 days).** Y-sort container, feet-anchor every entity, flatten colliders. Game looks ~same but depth sorting is now correct. This is the foundation; do it before any art.

**Phase 2 — Movement & feel (half day).** Y foreshortening on player + enemies, attack ellipse, camera offset. Game now *feels* angled.

**Phase 3 — Art direction (ongoing).** Taller sprites (1.5–2.5× height vs. width), ground restyle, drop shadows everywhere. This is where the perspective actually appears — no code required beyond Phase 1 anchoring rules.

**Phase 4 — Walls & rooms (2–3 days).** `WallPiece` system, occlusion fade, room interiors.

**Phase 5 — Bunker layers (1–2 days).** `WorldLayer` manager, stairs/hatches, per-layer ambient light.

**Phase 6 — Performance pass.** Screen enablers, light budget, chunking if needed.

Rule of thumb throughout: **logical position = feet position on the ground plane.** Everything else is offset upward from there.

---

## 2. Tilemaps for angled terrain

**Do NOT use isometric tile shapes.** Keep `TileMapLayer` in square mode. Don't Starve's ground is literally a flat texture seen from above — the angle illusion comes from the objects standing on it.

What changes:

1. **Ground tiles stay square, flat, low-contrast.** Your `cave_floor.gd` random-variant generator survives as-is. Just make the tiles read as "surface you look *down at an angle* onto": avoid tile art with baked-in top-down details like visible rims around every tile. Soft noise, cracks, gradients.
2. **Remove all "wall" tiles from the tilemap.** Anything with height (walls, cliffs, boulders) becomes a *scene* (StaticBody2D + tall sprite), not a tile — tiles can't Y-sort against the player convincingly at 16px. You already do this (`cave_wall.tscn`, `organic_wall.tscn`) — good, keep going.
3. **Edge/transition tiles sell depth cheap.** Where floor meets void or water, use a "drop-off" edge tile: floor color on top ~60%, a dark vertical face strip on the bottom ~40%. That single art trick makes the ground read as a slab with thickness (Core Keeper does this too, DS does it at world edges).
4. **Consider bumping tile size to 32px** for the new art. 16px tiles fight with tall sprites at DS-like proportions. Purely an art call; `TileMapLayer` doesn't care.

Optional layer split (all `TileMapLayer` nodes, no code):
```
World/
  GroundLayer        # base floor, y_sort off, z_index -10
  GroundDetailLayer  # cracks, stains, transitions, z_index -9
  Entities (Node2D, y_sort_enabled)   # everything that stands
```

---

## 3. Faking height and elevation

Two separate concepts — keep them separate in code:

**A. Sprite height (visual only).** The sprite is drawn *upward* from the logical feet position. Rule for every entity scene:

- Node origin (position) = feet on the ground.
- Sprite is offset up: `offset.y = -sprite_height/2` (or set `centered = false` and position accordingly).
- Collider sits at origin (feet), flattened (§5).
- Shadow blob at origin. You already have `ShadowBlob` on the player — **add one to every standing object.** Shadows are 50% of the DS depth illusion. Make it a tiny reusable scene:

```gdscript
# components/drop_shadow.gd — attach to a Sprite2D with the blob texture
extends Sprite2D
@export var width: float = 24.0
func _ready() -> void:
    z_index = -1          # under the owner's sprite, still y-sorted with owner
    modulate.a = 0.5
    scale = Vector2(width / texture.get_width(), width * 0.45 / texture.get_height())
```

**B. Airborne height (jumps, knockback, dropped-item bounce).** Never move the body's Y for this — that changes the *ground* position and breaks sorting/collision. Add a visual-only height channel:

```gdscript
# components/height_sprite.gd
## Separates logical ground position from visual height.
## Attach to any Node2D that holds the visuals (sprite + shadow).
extends Node2D

var height: float = 0.0:          # world px above ground
    set(v):
        height = v
        _sprite.position.y = _base_sprite_y - height
        _shadow.scale = _base_shadow_scale * clampf(1.0 - height / 80.0, 0.4, 1.0)
        _shadow.modulate.a = 0.5 * clampf(1.0 - height / 120.0, 0.3, 1.0)

var velocity_h: float = 0.0       # vertical velocity, px/s
@export var gravity: float = 600.0
@onready var _sprite: Node2D = $"../AnimatedSprite2D"
@onready var _shadow: Node2D = $"../ShadowBlob"
@onready var _base_sprite_y: float = _sprite.position.y
@onready var _base_shadow_scale: Vector2 = _shadow.scale

func _physics_process(delta: float) -> void:
    if height > 0.0 or velocity_h > 0.0:
        velocity_h -= gravity * delta
        height = maxf(0.0, height + velocity_h * delta)

func hop(strength: float = 180.0) -> void:
    velocity_h = strength
```

Use `hop()` for knockback on `Enemy.hit()`, item drops, etc. Cheap, sells depth hard.

**C. Elevation tiers (cliffs/plateaus).** Skip true elevation. In DS-style, "higher ground" is: a cliff-face *object* (tall sprite, solid collider) + a separate walkable region behind it + a ramp/stairs object that's just a collision gap. Logically it's all one flat plane. If you later need real tiers, that's the `WorldLayer` system from §8 with a Y-offset — don't build it until you need it.

---

## 4. Y-sorting

The one structural change that everything else depends on.

**Scene tree contract:**

```
TestBiome (Node2D)
├── GroundLayer (TileMapLayer)            # y_sort OFF
├── Entities (Node2D)  ← y_sort_enabled = true
│   ├── Player
│   ├── Enemy1..N
│   ├── TreePine1..N, all decor, walls, resource nodes...
├── LitCanvasModulate, post-process, HUD (CanvasLayer)
```

`y_sort_enabled` on the parent sorts all children by `global_position.y`. That's why the feet-anchor rule in §3 is non-negotiable: **a node's Y position IS its sort key.**

Rules for tall/wide objects:

1. **Sort point = base of the object.** For `tree_pine.tscn` today, origin is mid-trunk (sprite offset -6, collider at +6). Fix: move the node so origin is where trunk meets ground; sprite offset becomes fully negative; collider centered on origin.
2. **Wide objects (fallen log, long wall):** one node can only have one sort Y. Split anything wider than ~1.5 tiles into segments, or accept minor sort errors on its ends. Walls: one `WallPiece` per tile (§7) solves this naturally.
3. **Composite objects** (campfire + flames, statue + glow): keep all visuals inside the one Y-sorted node; use `z_index` for intra-object layering (shadow -1, body 0, glow +1). `z_index` stacks *within* the same sort position — perfect for this.
4. **Flat-on-ground things** (rugs, veins, pustules, water edges, item drops before pickup): don't Y-sort them against the player at all. Put them on a `GroundDetail` node *outside* `Entities`, `z_index = -5`. A flat thing that Y-sorts pops in front of feet — classic ugly bug.
5. If sorting ever looks wrong on a specific entity, add a `Marker2D` mental check: is its origin at its feet? 95% of Y-sort bugs are anchor bugs.

Migration script hint — rather than re-editing 50 decor scenes by hand, write a one-off editor script that, per scene: reads collider position, shifts all children by `-collider_bottom`, so origin lands at the base. Then eyeball each.

---

## 5. Collisions for angled sprites

**Collider = the object's *footprint on the ground*, not its silhouette.**

- Shape: flattened ellipse. Godot has no ellipse shape, and scaling a `CollisionShape2D` is a known perf/behavior trap. Use a **horizontal `CapsuleShape2D` (rotated 90°)** — capsule with `radius = footprint_depth/2`, `height = footprint_width`, node `rotation = PI/2`. For near-round footprints a plain small `CircleShape2D` is fine.
- Proportions: width ≈ visual base width, depth ≈ 40–60% of that. Player: today you have a rectangle; replace with capsule ~ radius 5, height 14, rotated, positioned at feet.
- Trees/statues: footprint of the trunk/base only. Canopy never collides — the player walking "behind" a tree overlaps its canopy visually (Y-sort handles the draw order) and that's exactly the DS look.
- `motion_mode = MOTION_MODE_FLOATING` on player/enemies: **keep**, it's correct for this.
- **Light occluders shrink too.** Your `tree_pine` occluder is the full silhouette — in an angled world, shadows should be cast by the *base*, roughly matching the footprint, or shadows look like the object is a cardboard cutout glued to the floor. Rebuild `OccluderPolygon2D`s as squashed ellipses around the base. (`organic_wall.gd` already generates occluder = footprint — that one's already right.)

Physics layers (name them in Project Settings):
```
1: world_solid   (walls, cliffs, big rocks)
2: player
3: enemies
4: interactables (Area2D: pickups, stations)
```
Player mask: 1. Enemies mask: 1,2 (or just 1 if they shouldn't push the player). Attack detection stays overlap-based, no layer changes needed there.

---

## 6. Player movement & attack hitboxes

**Movement — one line sells the whole perspective.** In an angled view, a step "north" covers less screen distance than a step "east":

```gdscript
# player.gd — _physics_process
const Y_FORESHORTEN := 0.8   # DS uses roughly this; tune 0.75–0.9

var input_vector := _get_input_vector()
velocity = input_vector * speed
velocity.y *= Y_FORESHORTEN
move_and_slide()
```

Apply the same factor in `enemy.gd`'s chase velocity so enemies move in the same "space":

```gdscript
velocity = (_player.global_position - global_position).normalized() * speed
velocity.y *= 0.8
```

Everything else in your movement (8-dir input, facing from dominant axis, footsteps by distance) survives. Later, DS-style really wants **diagonal facing sprites** (6–8 directions with left/right flip) — that's an animation-set upgrade in `_update_facing`, not an architecture change. Your `_facing: String` pattern extends cleanly to `"down_right"` etc.

**Attack hitbox.** Two changes to your `AttackArea`:

1. Shape: flattened capsule (same recipe as §5) instead of a circle — a circle reaches too far "up/down" in foreshortened space.
2. Offset it toward facing, and add a *depth tolerance* check so you can't hit things whose feet are far above/below yours:

```gdscript
const ATTACK_REACH := 24.0
const ATTACK_DEPTH_TOLERANCE := 20.0   # max feet-Y difference to connect

func _update_attack_area_position() -> void:   # call from _update_facing
    var dir := Vector2.ZERO
    match _facing:
        "right": dir = Vector2.RIGHT
        "left":  dir = Vector2.LEFT
        "up":    dir = Vector2(0, -Y_FORESHORTEN)
        "down":  dir = Vector2(0,  Y_FORESHORTEN)
    attack_area.position = dir * ATTACK_REACH

func _attack() -> void:
    sprite.play("attack_" + _facing)
    _attack_anim_timer = ATTACK_ANIM_DURATION
    for body in attack_area.get_overlapping_bodies():
        if body == self: continue
        if not body.has_method("hit"): continue
        if absf(body.global_position.y - global_position.y) > ATTACK_DEPTH_TOLERANCE:
            continue   # feet too far apart in depth — visual overlap only
        body.hit(attack_damage)
```

The depth check matters because tall sprites overlap on screen a lot in this perspective; without it you hit things you're clearly "behind". Same tolerance idea belongs in `CursorManager`'s reach check and in `enemy.gd`'s `attack_radius` (compare positions with `y` scaled by `1/0.8` to measure distance in "world" rather than screen space — or simpler, just keep radii generous; at your scale it's barely noticeable).

---

## 7. Walls and rooms that feel like real spaces

The DS/Core Keeper wall illusion = every wall tile is **two visual parts**: a tall *front face* and a *top cap*, with the collider only at the base.

**`WallPiece` scene template** (one per tile of wall; instanced or placed by your building system):

```
WallPiece (StaticBody2D)          # origin at base center, layer world_solid
├── FaceSprite (Sprite2D)         # tall front face, offset.y = -face_h/2
├── TopSprite (Sprite2D)          # cap, offset.y = -face_h - cap_h/2, z_index = 1
├── CollisionShape2D              # rectangle: tile wide, ~60% tile deep, at origin
└── LightOccluder2D               # footprint-sized (base only)
```

Behavior you get for free from Y-sort with base anchoring:
- **South walls** (below the player) draw *in front of* the player → you see the wall face, the player is "inside" the room. Correct.
- **North walls** (above the player) draw *behind* → you see the player against the wall's face. Correct.

Two additions that make rooms feel real:

1. **Occlusion fade** — when the player walks behind a south wall (or any tall object), fade it so the player isn't hidden:

```gdscript
# components/occluder_fade.gd — Area2D child of WallPiece/tree, sized like the
# sprite's upper body, monitoring player only (mask = player layer)
extends Area2D
@export var target: CanvasItem
var _tw: Tween
func _ready() -> void:
    body_entered.connect(func(_b): _fade(0.45))
    body_exited.connect(func(_b): _fade(1.0))
func _fade(a: float) -> void:
    if _tw: _tw.kill()
    _tw = create_tween()
    _tw.tween_property(target, "modulate:a", a, 0.15)
```

Attach the Area2D covering the region *behind* the tall part (i.e., above the base, where a hidden player would stand). Apply to trees and big statues too.

2. **Interior floor swap** — rooms get their own floor tiles (planks etc.) on the ground layer. Combined with wall faces + your Lit lighting (dark ambient outside, warm point light inside), enclosure reads instantly.

Your procedural `organic_wall.gd` blobs: keep the generator, add the two-part treatment — render the blob polygon twice: the footprint polygon as the "top" (rock surface texture), and an extruded skirt (polygon translated down by `wall_height`, joined along the south edge) as the dark "face". Same jitter code, one extra `Polygon2D`. Collision + occluder stay footprint-based as they already are.

**Doorways** are just wall-piece gaps. Optional door = StaticBody2D that toggles `collision_layer` and swaps sprite.

---

## 8. Underground bunker layers

Don't stack floors spatially in one scene with camera tricks — with an infinite 2D plane per floor you'll collide layer contents eventually, and Lit lights/occluders from other floors will leak. Use **one scene-instance per layer, only the active layer in the tree**:

```gdscript
# autoload/world_layers.gd
extends Node
## Holds layer scenes; swaps which one is active. GameState (health,
## inventory) is already an autoload, so it survives swaps for free.

var layers := {
    "surface": preload("res://world/test_biome.tscn"),
    "bunker_1": preload("res://world/bunker_1.tscn"),
}
var current: Node = null
var _states := {}   # layer_id -> persisted state (depleted nodes, placed buildings)

func switch_to(layer_id: String, spawn_point: String) -> void:
    var root := get_tree().current_scene
    if current:
        _states[current.name] = current.save_state()   # implement per-layer
        current.queue_free()
    current = layers[layer_id].instantiate()
    root.add_child(current)
    if _states.has(layer_id):
        current.load_state(_states[layer_id])
    var player: Node2D = get_tree().get_first_node_in_group("player")
    player.reparent(current.get_node("Entities"))
    player.global_position = current.get_node("Spawns/" + spawn_point).global_position
```

- **Transition object** = `Hatch` (Area2D + prompt) calling `WorldLayers.switch_to("bunker_1", "from_surface")`. Add a 0.2s fade-to-black; underground needs no loading tricks at your scale.
- **Perspective underground:** identical rules — flat floor tilemap, tall wall pieces (§7) around every room, lower ceiling illusion via a slightly stronger occlusion-fade and a **darker `LitCanvasModulate`** per layer (e.g. surface `0.1,0.1,0.13` → bunker `0.04,0.04,0.06`). Ceiling supports/pipes as `z_index`-raised decor on north walls sell "underground" cheaply.
- **Persistence:** each layer scene implements `save_state()/load_state()` returning a Dictionary (depleted resource nodes, placed structures, enemy states). Keep it dumb: arrays of `{scene_path, position, custom}`.
- Player, camera, HUD, autoloads never reload — only the world swaps. Your Phantom Camera on the player travels with it via `reparent`.

---

## 9. Performance

At your current scale nothing is slow; these keep it that way as content grows:

1. **`VisibleOnScreenEnabler2D`** in every decor/entity scene, wrapping `_physics_process`-heavy or animated children. For enemies: let it disable `process` when off-screen; AI at 160px detection radius doesn't need to tick 2000px away. One node, zero code.
2. **Light budget.** Lit-style raymarched 2D lights are your real cost center. Cap simultaneous lights; give torches/campfires an `Area2D` (or distance check on a 0.5s timer) that disables their light beyond ~1.5 screens.
3. **Occluders:** footprint-sized occluders (§5) are also cheaper than silhouettes — fewer polygon points, less shadow work.
4. **TileMapLayer** already renders in internal quadrant chunks — your 130×130 fill is fine. If floors grow much bigger, generate only a region around the player and expand lazily (your `_generate_floor` loop becomes "ensure cells around camera exist").
5. **Y-sort cost is trivial** in Godot 4 for hundreds of nodes; don't optimize it. If you someday hit thousands of *static* decor items, bake them into a `TileMapLayer` with per-tile `y_sort_origin` — but not before profiling says so.
6. **Pooling:** only worth it for frequently spawned things (hit particles, item drops). Enemies at your counts: `queue_free()` is fine.
7. Layer swapping (§8) is itself the biggest perf feature: only one floor of the world exists at a time.

---

## 10. Concrete first steps (Phase 1 checklist)

1. Delete `TileMapLayer3D-*/` folder.
2. In `test_biome.tscn`: create `Entities` (Node2D, `y_sort_enabled = true`), move Player, enemies, resource nodes, all decor/walls under it. Ground `TileMapLayer` and water/veins/flat decor stay outside.
3. Fix anchors in entity scenes (start with player, enemy, tree_pine, cave_wall): shift children so node origin = feet; collider → rotated capsule at origin; occluder → base ellipse.
4. `player.gd` / `enemy.gd`: add `velocity.y *= 0.8`.
5. `player.tscn`: AttackArea → flattened capsule; `player.gd`: facing offset + depth tolerance (§6).
6. Add `drop_shadow.gd` blob to every standing entity.
7. Run around. Y-sort correct + shadows + foreshortening already reads ~70% Don't Starve, even with current art.

Then Phase 3 (taller art) is where it fully lands — sprites drawn 1.5–2.5× taller than wide, bases slightly widened, subtle vertical gradient (darker at feet) baked into the art.
