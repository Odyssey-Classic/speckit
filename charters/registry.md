# registry Charter

> Authoritative charter for the `registry` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

The identity and server-directory service that Odyssey game servers register
with — how worlds are discovered and how identity is anchored across servers.

## License side

AGPL-3.0 (engine core) — the registry is a world-running system of the engine;
network copyleft protects the commons for hosted software (Principle III).

## In scope

- Server registration and the discovery directory
- Cross-server identity anchoring
- The service's own authentication and data protection

## Out of scope

- Running or simulating a world
- Player-facing presentation
- Operator and host-facing tooling
- The shared protocol contract
