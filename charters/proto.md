# proto Charter

> Authoritative charter for the `proto` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

The shared protocol contract — the message definitions and generated bindings
that let Odyssey applications interoperate. Its whole reason to exist is to be
the agreed contract between the applications that speak it.

## License side

Apache-2.0 (ecosystem edge) — the protocol must be frictionless to build
against (Principle III).

## In scope

- Protocol and message schema definitions
- Generated bindings
- Versioning of the contract

## Out of scope

- Game or business logic
- Transport and runtime behavior
- Anything internal to a single application
