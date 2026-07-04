import { test } from "node:test";
import assert from "node:assert/strict";
import { add } from "./index.js";

test("add(2, 2) equals 4", () => {
  assert.strictEqual(add(2, 2), 4);
});
