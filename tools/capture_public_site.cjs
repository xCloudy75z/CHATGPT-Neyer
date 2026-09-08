"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const http = require("node:http");
const path = require("node:path");

const PUBLIC_PAGES = [
  "index.html",
  "method.html",
  "planner.html",
  "test-workflow.html",
  "results.html",
  "physical-setup.html",
  "audit.html",
  "evidence.html",
];

const VIEWPORTS = [
  { name: "desktop", width: 1440, height: 1100 },
  { name: "phone", width: 390, height: 844 },
];

const REVIEW_CAPTURE_PAGES = new Set(["method.html", "test-workflow.html"]);

const CONTENT_TYPES = new Map([
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mlx", "application/octet-stream"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".txt", "text/plain; charset=utf-8"],
]);

function resolveSitePath(siteRoot, requestUrl) {
  const rawPath = requestUrl.split(/[?#]/, 1)[0] || "/";
  let decodedPath;
  try {
    decodedPath = decodeURIComponent(rawPath);
  } catch {
    throw new Error("request path has invalid URL encoding");
  }
  const normalizedPath = decodedPath.replace(/\\/g, "/");
  const relativePath = normalizedPath === "/" ? "index.html" : normalizedPath.replace(/^\/+/, "");
  const root = path.resolve(siteRoot);
  const target = path.resolve(root, relativePath);
  const relativeTarget = path.relative(root, target);
  if (relativeTarget === "" || relativeTarget.startsWith("..") || path.isAbsolute(relativeTarget)) {
    throw new Error("request path is outside the site root");
  }
  return { target, relativePath: relativeTarget.split(path.sep).join("/") };
}

async function resolveRealSiteFile(siteRoot, requestUrl) {
  const { target, relativePath } = resolveSitePath(siteRoot, requestUrl);
  const [realRoot, realTarget] = await Promise.all([
    fsp.realpath(siteRoot),
    fsp.realpath(target),
  ]);
  const relativeTarget = path.relative(realRoot, realTarget);
  if (relativeTarget === "" || relativeTarget.startsWith("..") || path.isAbsolute(relativeTarget)) {
    throw new Error("request path is outside the real site root");
  }
  return { target: realTarget, relativePath };
}

function createSiteServer(siteRoot) {
  const root = path.resolve(siteRoot);
  return http.createServer(async (request, response) => {
    if (!request.url || !["GET", "HEAD"].includes(request.method || "")) {
      response.writeHead(405, { Allow: "GET, HEAD" });
      response.end();
      return;
    }
    let target;
    try {
      ({ target } = await resolveRealSiteFile(root, request.url));
    } catch (error) {
      if (error && error.code === "ENOENT") {
        response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        response.end("Not found");
        return;
      }
      response.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
      response.end(`Forbidden: ${error.message}`);
      return;
    }
    try {
      const details = await fsp.stat(target);
      if (!details.isFile()) {
        response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        response.end("Not found");
        return;
      }
      response.writeHead(200, {
        "Cache-Control": "no-store",
        "Content-Type": CONTENT_TYPES.get(path.extname(target).toLowerCase()) || "application/octet-stream",
        "X-Content-Type-Options": "nosniff",
      });
      if (request.method === "HEAD") {
        response.end();
      } else {
        fs.createReadStream(target).pipe(response);
      }
    } catch (error) {
      if (error && error.code === "ENOENT") {
        response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        response.end("Not found");
        return;
      }
      response.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Unable to read requested site file");
    }
  });
}

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen({ host: "127.0.0.1", port: 0 }, resolve);
  });
  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("capture server did not expose a loopback port");
  }
  return `http://127.0.0.1:${address.port}`;
}

async function closeListeningServer(server) {
  if (!server.listening) {
    return;
  }
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

function preferredEdgeExecutable() {
  const candidates = [
    process.env.PROGRAMFILES && path.join(process.env.PROGRAMFILES, "Microsoft", "Edge", "Application", "msedge.exe"),
    process.env["PROGRAMFILES(X86)"] && path.join(process.env["PROGRAMFILES(X86)"], "Microsoft", "Edge", "Application", "msedge.exe"),
  ].filter(Boolean);
  return candidates.find((candidate) => fs.existsSync(candidate));
}

function pngDimensions(pngPath) {
  const header = fs.readFileSync(pngPath).subarray(0, 24);
  if (header.toString("hex", 0, 8) !== "89504e470d0a1a0a") {
    throw new Error(`not a PNG file: ${pngPath}`);
  }
  return { width: header.readUInt32BE(16), height: header.readUInt32BE(20) };
}

function reviewCaptureFileName(pageName, viewportName) {
  if (!REVIEW_CAPTURE_PAGES.has(pageName)) {
    return null;
  }
  return `${path.basename(pageName, ".html")}-${viewportName}.png`;
}

async function inspectPage(page, url, viewport) {
  const result = await page.goto(url, { waitUntil: "networkidle" });
  if (!result || result.status() !== 200) {
    throw new Error(`${url} returned ${result ? result.status() : "no response"}`);
  }
  const layout = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  if (layout.scrollWidth > viewport.width || layout.scrollWidth > layout.clientWidth) {
    throw new Error(`${url} has horizontal overflow (${layout.scrollWidth}px > ${viewport.width}px)`);
  }
  return layout;
}

async function runCapture({
  repositoryRoot = path.resolve(__dirname, ".."),
  chromium: suppliedChromium,
  edgeExecutable: suppliedEdgeExecutable,
  createServer = createSiteServer,
} = {}) {
  const siteRoot = path.join(repositoryRoot, "site");
  const auditDirectory = path.join(repositoryRoot, "audit", "site");
  const chromium = suppliedChromium || require("playwright").chromium;
  const edgeExecutable = suppliedEdgeExecutable || preferredEdgeExecutable();
  if (!edgeExecutable) {
    throw new Error("no verified local Microsoft Edge executable was found");
  }
  await fsp.mkdir(auditDirectory, { recursive: true });
  const server = createServer(siteRoot);
  let browser;
  let operationFailed = false;
  const results = [];
  try {
    const baseUrl = await listen(server);
    browser = await chromium.launch({
      executablePath: edgeExecutable,
      headless: true,
      args: ["--disable-background-networking", "--disable-component-update", "--disable-gpu"],
    });
    for (const viewport of VIEWPORTS) {
      const context = await browser.newContext({ viewport: { width: viewport.width, height: viewport.height }, deviceScaleFactor: 1 });
      const page = await context.newPage();
      for (const pageName of PUBLIC_PAGES) {
        const layout = await inspectPage(page, `${baseUrl}/${pageName}`, viewport);
        results.push({ viewport: viewport.name, pageName, ...layout });
        const reviewCapture = reviewCaptureFileName(pageName, viewport.name);
        if (reviewCapture) {
          const reviewImagePath = path.join(auditDirectory, reviewCapture);
          await page.screenshot({ path: reviewImagePath, fullPage: true });
          results.push({
            viewport: viewport.name,
            pageName: `${pageName}:inspection-capture`,
            ...pngDimensions(reviewImagePath),
          });
        }
      }
      await page.goto(`${baseUrl}/index.html`, { waitUntil: "networkidle" });
      const focus = await page.locator(".primary-action").evaluate((element) => {
        element.focus();
        const style = getComputedStyle(element);
        return { outlineColor: style.outlineColor, outlineStyle: style.outlineStyle, outlineWidth: style.outlineWidth };
      });
      if (focus.outlineStyle === "none" || focus.outlineWidth === "0px") {
        throw new Error(`${viewport.name} primary action has no visible focus outline`);
      }
      const imagePath = path.join(auditDirectory, `site-${viewport.name}.png`);
      await page.screenshot({ path: imagePath, fullPage: true });
      const image = pngDimensions(imagePath);
      results.push({ viewport: viewport.name, pageName: "focus", ...focus });
      results.push({ viewport: viewport.name, pageName: "capture", ...image });
      await context.close();
    }
  } catch (error) {
    operationFailed = true;
    throw error;
  } finally {
    let cleanupError;
    if (browser) {
      try {
        await browser.close();
      } catch (error) {
        cleanupError = error;
      }
    }
    try {
      await closeListeningServer(server);
    } catch (error) {
      cleanupError ||= error;
    }
    if (!operationFailed && cleanupError) {
      throw cleanupError;
    }
  }
  return { edgeExecutable, results };
}

if (require.main === module) {
  runCapture().then(({ edgeExecutable, results }) => {
    console.log(`Browser: ${edgeExecutable}`);
    for (const result of results) {
      console.log(JSON.stringify(result));
    }
  }).catch((error) => {
    console.error(`Capture failed: ${error.stack || error.message}`);
    process.exitCode = 1;
  });
}

module.exports = {
  createSiteServer,
  pngDimensions,
  resolveRealSiteFile,
  resolveSitePath,
  reviewCaptureFileName,
  runCapture,
};
