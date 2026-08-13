# JOSEONLIKE

Joseon-inspired pixel roguelike survival action RPG. Godot 4.7, GDScript, mobile-first.

- How development runs (read first): [CLAUDE.md](CLAUDE.md)
- What to build next: [ROADMAP.md](ROADMAP.md) · [TASKS.md](TASKS.md)
- Game design: [JOSEONLIKE_GDD.md](JOSEONLIKE_GDD.md)
- Code contract, interfaces and data schemas: [ARCHITECTURE.md](ARCHITECTURE.md)
- Assets (production frozen): [ASSET_REQUIREMENTS.md](ASSET_REQUIREMENTS.md) ·
  [ASSET_LICENSES.md](ASSET_LICENSES.md) · [ASSET_SPEC.md](ASSET_SPEC.md)

## Run

```bash
godot --path .
```

## Test

```bash
godot --headless --path . --script tests/run_tests.gd
```

## Milestone 1

Vertical slice: camp → character select → Bamboo Forest → auto combat → level-up →
boss → results, with progression persisted.
