import { test } from "node:test";
import assert from "node:assert/strict";
import { add } from "./index.js";

// Deliberately wrong expectation so `npm test` fails - this fixture exists
// to prove the `tests` gate category blocks (see ../README.md).
test("add(2, 2) equals 5", () => {
  assert.strictEqual(add(2, 2), 5);
});
