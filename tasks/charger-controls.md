# Spec: Charger control assists

## Objective

Add an opt-in Charger steering assist that blends an active charge toward the player's WASD direction, falling back to the camera direction when no movement input exists. The user can choose a 0–100% strength. Investigate an actual Charger no-cooldown implementation without adding a cosmetic-only toggle.

## Commands

- Lint: `selene NULLSCAPE`
- Format check: `stylua --check NULLSCAPE`
- Build: `rojo build default.project.json -o NULLSCAPE.rbxlx`

## Boundaries

- Always: keep each option disabled by default; only act while the native Charger charge state is active; persist settings.
- Ask first: add dependencies or modify game/server remotes.
- Never: claim a cooldown bypass works unless it changes the native ability state.

## Success criteria

- Charger UI exposes a steering toggle and 0–100% strength slider.
- During a native charge, WASD takes precedence over camera forward; camera forward is used when WASD is idle.
- Disabling the feature or changing class stops the assist and disconnects it on cleanup.
- No cooldown is implemented only if a native Charger cooldown interface is discoverable and verifiable.

## Testing strategy

Run Luau lint/format checks and a Rojo build. Runtime behavior requires an in-game Charger session because the native ability module is not part of this repository.
