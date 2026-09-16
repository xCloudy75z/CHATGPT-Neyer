const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const runtimeModules = process.env.NEYER_RUNTIME_MODULES;
if (!runtimeModules) {
  throw new Error('NEYER_RUNTIME_MODULES must point to the bundled node_modules folder.');
}
const { chromium } = require(path.join(runtimeModules, 'playwright'));

async function main() {
  const projectRoot = path.resolve(__dirname, '..');
  const guidePath = path.join(projectRoot, 'site', 'index.html');
  const outputFolder = path.join(projectRoot, 'audit', 'v114', 'site');
  fs.mkdirSync(outputFolder, { recursive: true });

  const browser = await chromium.launch({
    headless: true,
    executablePath: 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
    await page.goto(pathToFileURL(guidePath).href);

    const tabNames = [
      'Start here',
      'Manual code check',
      'Understand the method',
      'Operate V1.14',
      'Read your results',
      'Evidence and problems',
    ];
    for (const tabName of tabNames) {
      const tab = page.getByRole('tab', { name: tabName });
      await tab.click();
      if ((await tab.getAttribute('aria-selected')) !== 'true') {
        throw new Error(`Tab did not become selected: ${tabName}`);
      }
      const panelId = await tab.getAttribute('aria-controls');
      if (!panelId || !(await page.locator(`#${panelId}`).isVisible())) {
        throw new Error(`Matching panel did not become visible: ${tabName}`);
      }
    }

    const phoneOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    if (phoneOverflow > 1) {
      throw new Error(`Phone layout overflows by ${phoneOverflow}px`);
    }
    const pageText = await page.locator('body').innerText();
    for (const unwantedText of [
      'Run the Published Example',
      'Keep two studies separate',
      'zero-failure demonstration',
    ]) {
      if (pageText.includes(unwantedText)) {
        throw new Error(`Mentor guide still contains extra wording: ${unwantedText}`);
      }
    }
    await page.getByRole('tab', { name: 'Start here' }).click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(outputFolder, 'phone-start.png'), fullPage: true });
    await page.getByRole('tab', { name: 'Operate V1.14' }).click();
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(outputFolder, 'phone-operate.png'), fullPage: true });

    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.getByRole('tab', { name: 'Manual code check' }).click();
    await page.waitForTimeout(500);
    const desktopOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    if (desktopOverflow > 1) {
      throw new Error(`Desktop layout overflows by ${desktopOverflow}px`);
    }
    const rows = await page.locator('tr[data-test-number]').count();
    if (rows !== 20) {
      throw new Error(`Expected 20 reference rows, found ${rows}`);
    }
    await page.screenshot({ path: path.join(outputFolder, 'desktop-repeat.png'), fullPage: true });
  } finally {
    await browser.close();
  }
  console.log('V1.14 public guide browser check passed');
}

main().catch(error => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
