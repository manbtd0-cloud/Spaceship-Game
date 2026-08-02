# Source-Exact Thruster Visuals Design

## Problem

The current runtime exhaust uses generated cone meshes placed at inferred socket transforms. The controller can select the correct channels while the visual still appears detached, inward-facing, or otherwise wrong because the replacement geometry is not the geometry authored with the ship.

Moving offsets or rotating the cones again would remain guesswork.

## Authoritative evidence

The preserved Blender source contains eleven `EngineFire*` mesh objects representing twelve physical exhaust plumes:

- `EngineFire`: two main exhausts, each composed of layered disconnected mesh islands;
- `EngineFire.001` and `.004`: two retro exhausts;
- `.002` through `.010` excluding `.004`: eight maneuvering exhausts.

These meshes were authored against the actual vents. Their transformed vertices therefore define the authoritative visual position, shape, and outward direction.

## Decision

The canonical fighter exporter will repurpose the exact source exhaust geometry as hidden runtime-controlled effect templates.

It will no longer generate procedural cone geometry for ship exhaust.

For every physical plume the exporter will:

1. identify its exact source mesh-island group;
2. copy its vertices and faces from the evaluated Blender mesh;
3. transform those vertices from source world space into approved `Cube` local space;
4. apply the approved hull centering and uniform scale;
5. place the resulting mesh under a semantic `ThrusterEffects` hierarchy with identity transforms;
6. assign a transparent zero-emission material for import;
7. record source object, source component indices, vertex count, face count, bounds, and a deterministic geometry digest in the manifest.

The existing `Thrusters` empties remain authoritative for force position and reaction direction. The new `ThrusterEffects` meshes are authoritative for visual shape and placement.

## Runtime hierarchy

```text
SmallSciFiFighter
├── SmallSciFiFighterMesh
├── Thrusters
│   ├── Main
│   │   ├── MainLeft
│   │   └── MainRight
│   ├── Retro
│   │   ├── RetroLeft
│   │   └── RetroRight
│   └── Maneuver
│       └── eight semantic sockets
└── ThrusterEffects
    ├── Main
    │   ├── MainLeftEffect
    │   └── MainRightEffect
    ├── Retro
    │   ├── RetroLeftEffect
    │   └── RetroRightEffect
    └── Maneuver
        └── eight semantic effect meshes
```

All effect mesh transforms are identity relative to `ThrusterEffects`; their vertices are already expressed in the canonical fighter frame. This removes runtime offset, rotation, pivot, and axis conversion from visual placement.

## Runtime behavior

`ShipThrusterVisualController` resolves one socket and one source-exact effect mesh per channel.

- Sockets feed the geometry-driven wrench allocator.
- Effect meshes remain hidden at zero intensity.
- Intensity changes visibility, alpha, and emission energy only.
- Boost increases brightness and opacity on active translational exhausts.
- Runtime code does not move, rotate, or reshape the source-exact meshes.
- A missing socket or effect disables the visual contract and reports the exact semantic path.

## Mechanical verification gates

The export is accepted only when all gates pass:

1. exactly twelve physical plume groups exist;
2. every group has source faces and at least four vertices;
3. every semantic socket path and effect path is unique;
4. main/retro/maneuver counts are `2/2/8`;
5. the nozzle-side sample is closer to the hull than the far-side sample;
6. exhaust and reaction directions are finite, normalized, and opposite;
7. every exported effect record identifies the exact raw source component indices;
8. every exported effect geometry digest is generated from canonical vertex and face data;
9. effect mesh transforms are identity;
10. Godot imports twelve effect meshes and they are all hidden at idle.

## Guarantee boundary

This design guarantees that runtime exhaust placement and shape are derived directly from the source Blender exhaust geometry under the same canonical transform as the hull. There are no hand-authored runtime offsets or replacement cones left to misalign.

It does not claim that the original artist's exhaust design is physically realistic; it guarantees faithful alignment to the authored ship model.
