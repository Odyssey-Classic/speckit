# server Charter

> Authoritative charter for the `server` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

The Odyssey engine — the authoritative server that runs persistent, shared
worlds: it simulates the world, holds authoritative state, enforces the rules
of play, and persists worlds over time.

## License side

AGPL-3.0 (engine core) — the server is the system that makes a world run;
network copyleft is what keeps the commons guarantee real for hosted software
(Principle III).

## In scope

- Authoritative world state and simulation
- Game rules and systems
- Player sessions and authentication
- World persistence and migration
- In-world moderation and safety tooling
- Server-side enforcement of fairness

## Out of scope

- Presentation, rendering, and input handling
- The shared protocol contract
- Operator and host-facing tooling
- Cross-server identity and discovery
