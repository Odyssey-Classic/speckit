# client Charter

> Authoritative charter for the `client` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

The web-first player client — the player's window into a world run elsewhere.
It presents world state and captures player intent, delivered web-first per the
constitution's Engine Identity, and holds no authority over the world.

## License side

Apache-2.0 (ecosystem edge) — a client carries no license friction for people
building on the ecosystem (Principle III).

## In scope

- Rendering and presentation of world state
- Capturing and sending player input and intent
- The default experience's UX and accessibility

## Out of scope

- Authoritative world state or rules
- World persistence
- The shared protocol contract
- Operator and host-facing tooling
