# Disposable Development Environment Recovery

The Shattered Orbit development sandbox is disposable. **GitHub is the only persistent project state.**

Do not rely on `/mnt/data`, installed tools, extracted binaries, symlinks, caches, `.godot/`, or local worktrees surviving between sessions or chats.

## Source of truth

Repository:

```text
manbtd0-cloud/Spaceship-Game
```

Authoritative integration branch:

```text
agent/playable-flight-room
```

Feature work may use temporary branches/worktrees, but a verified milestone is not durable until its code, scripts, configs, generated source assets, tests, manifests, and documentation are stored in GitHub.

## Fresh-environment recovery

### 1. Restore tools

Provide or extract the Godot **4.7.1 Standard** executable for the current OS. On Linux, a typical session-local location is:

```text
/mnt/data/godot-bin/Godot_v4.7.1-stable_linux.x86_64
```

That path is only an example for a disposable sandbox and must never be treated as persistent state.

Blender 5.2 LTS is required only for asset-generation/export work. Python 3 is required for the fighter/asset contract validators.

### 2. Reconstruct the repository from GitHub

Prefer a normal Git clone/fetch when network credentials are available:

```bash
git clone <repository-url>
cd Spaceship-Game
git switch agent/playable-flight-room
```

If the execution harness exposes GitHub through a connector rather than direct Git networking, reconstruct from the current GitHub branch/tree. Do not substitute an older uploaded ZIP for the authoritative branch. An uploaded archive may be used only as a bulk cache for unchanged files when every changed authoritative file is overlaid from GitHub and the baseline verification is rerun.

### 3. Import the project

Linux example:

```bash
GODOT_BIN=/path/to/Godot_v4.7.1-stable_linux.x86_64
"$GODOT_BIN" --headless --audio-driver Dummy --path . --editor --quit
```

Allow the first import to finish. Audio/model `.import` metadata and `.godot/` caches may be recreated locally.

### 4. Run the authoritative verifier

Windows:

```powershell
.\tools\verify\verify.ps1
```

Linux:

```bash
GODOT_BIN=/path/to/Godot_v4.7.1-stable_linux.x86_64 bash ./tools/verify/verify.sh
```

If a transported archive has converted the shell script to CRLF or removed its executable bit, normalize only the disposable sandbox copy or invoke it explicitly through `bash`; do not make a repository change solely to compensate for the transport artifact.

The verifier is the gate for schema-5 fighter geometry, deterministic thruster mapping, the full GDScript suite, and inertial rigid-body preservation.

### 5. Runtime smoke

Run the real main scene for several physics seconds. In a headless Linux sandbox, use a virtual display and dummy audio if needed:

```bash
timeout 12s xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path .
```

An intentional timeout is acceptable when the process remains healthy until termination. Parser, node-path, shader, resource-load, or repeated runtime errors are not acceptable.

### 6. Continue only from verified GitHub state

Create a new isolated feature branch/worktree from the current authoritative GitHub head. Verify the clean baseline before editing. During substantial milestones, persist coarse recovery checkpoints to GitHub so a sandbox loss cannot erase completed work.

## Rule

```text
GitHub = persistent project state
sandbox = disposable workstation
```
