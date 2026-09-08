"use strict";

const assert = require("node:assert/strict");
const fsp = require("node:fs/promises");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const { createSiteServer, reviewCaptureFileName, resolveSitePath, runCapture } = require("./capture_public_site.cjs");

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

test("review capture names retain method and walkthrough evidence only", () => {
  assert.equal(reviewCaptureFileName("method.html", "desktop"), "method-desktop.png");
  assert.equal(reviewCaptureFileName("test-workflow.html", "phone"), "test-workflow-phone.png");
  assert.equal(reviewCaptureFileName("index.html", "desktop"), null);
});

async function closeServer(server) {
  if (!server || !server.listening) {
    return;
  }
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

async function startServer(server) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen({ host: "127.0.0.1", port: 0 }, resolve);
  });
  const address = server.address();
  assert.ok(address && typeof address !== "string");
  return `http://127.0.0.1:${address.port}`;
}

test("createSiteServer rejects a real junction or symlink escape over HTTP", async () => {
  const fixtureRoot = await fsp.mkdtemp(path.join(os.tmpdir(), "neyer-capture-site-"));
  const siteRoot = path.join(fixtureRoot, "site");
  const outsideRoot = path.join(fixtureRoot, "outside");
  const escapePath = path.join(siteRoot, "escape");
  let server;
  try {
    await fsp.mkdir(siteRoot);
    await fsp.mkdir(outsideRoot);
    await fsp.writeFile(path.join(outsideRoot, "sentinel.txt"), "OUTSIDE-SITE-SENTINEL");
    await fsp.symlink(outsideRoot, escapePath, process.platform === "win32" ? "junction" : "dir");
    server = createSiteServer(siteRoot);
    const baseUrl = await startServer(server);

    const response = await fetch(`${baseUrl}/escape/sentinel.txt`);

    assert.equal(response.status, 403);
    assert.doesNotMatch(await response.text(), /OUTSIDE-SITE-SENTINEL/);
  } finally {
    await closeServer(server);
    await fsp.rm(fixtureRoot, { force: true, recursive: true });
  }
});

test("runCapture closes its listening server when browser launch rejects", async () => {
  const fixtureRoot = await fsp.mkdtemp(path.join(os.tmpdir(), "neyer-capture-launch-"));
  const siteRoot = path.join(fixtureRoot, "site");
  let server;
  try {
    await fsp.mkdir(siteRoot);
    await assert.rejects(
      runCapture({
        repositoryRoot: fixtureRoot,
        chromium: { launch: async () => { throw new Error("simulated launch failure"); } },
        edgeExecutable: "controlled-browser.exe",
        createServer: (root) => {
          server = createSiteServer(root);
          return server;
        },
      }),
      /simulated launch failure/,
    );
    assert.ok(server, "capture should have created a server before launch");
    assert.equal(server.listening, false);
    const listeningServers = process._getActiveHandles().filter(
      (handle) => handle instanceof http.Server && handle.listening,
    );
    assert.equal(listeningServers.length, 0);
  } finally {
    await closeServer(server);
    await fsp.rm(fixtureRoot, { force: true, recursive: true });
  }
});
