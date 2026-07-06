import { test } from "node:test";
import assert from "node:assert/strict";
import { merge } from "./index.js";

test("merge combines two plain objects", () => {
  assert.deepStrictEqual(merge({ a: 1 }, { b: 2 }), { a: 1, b: 2 });
});
