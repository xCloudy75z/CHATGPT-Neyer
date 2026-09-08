"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");
const test = require("node:test");

const { resolveSitePath } = require("./capture_public_site.cjs");

const siteRoot = path.resolve(__dirname, "..", "site");

test("resolveSitePath keeps decoded requests inside the site root", () => {
  assert.equal(
    resolveSitePath(siteRoot, "/method.html?view=full").relativePath,
    "method.html",
  );
  assert.equal(resolveSitePath(siteRoot, "/").relativePath, "index.html");
  assert.throws(
    () => resolveSitePath(siteRoot, "/%2e%2e/secret.html"),
    /outside the site root/,
  );
});
