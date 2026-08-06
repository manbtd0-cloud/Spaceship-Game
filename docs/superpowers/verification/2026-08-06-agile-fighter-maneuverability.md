# Agile Fighter Maneuverability Verification

**Date:** 2026-08-06  
**Repository:** `manbtd0-cloud/Spaceship-Game`  
**Branch:** `agent/playable-flight-room`  
**Status:** VERIFIED

## Automated Windows gate

The complete authoritative verifier passed on Godot 4.7.1:

```text
Schema-5 fighter contract validation passed.
Deterministic fighter thruster action matrix validation passed.
PASS: 39 suites
PASS: inertial rigid-body velocity preservation (speed drift 0.000000000 m/s, direction drift 0.000000000 degrees)
Main scene booted without reported parser, path, runtime, orphan-node, or retained-resource errors.
```

## Manual acceptance

Ahmad launched the production game and confirmed the agile-fighter handling correction is working.

Accepted behavior includes:

- stronger pitch, yaw, and roll response;
- stronger sideways and vertical translation;
- stronger reverse braking;
- stable angular-rate limits rather than unbounded spin acceleration;
- full counter-torque above the angular limits;
- Smart Stabilize remaining effective;
- existing Assisted, AI Assisted, Inertial, firing, boost, cameras, pause, and reset behavior remaining functional.

## Locked production profile

```text
Mass: 8500 kg
Forward force: 150000 N
Reverse force: 110000 N
Strafe/vertical force: 150000 N
Pitch torque: 190000 Nm
Yaw torque: 230000 Nm
Roll torque: 210000 Nm
Pitch limit: 100 deg/s
Yaw limit: 100 deg/s
Roll limit: 150 deg/s
Normal speed limit: 160 m/s
Boost speed limit: 240 m/s
Boost multiplier: 1.8
```

The maneuverability correction is closed and verified.
