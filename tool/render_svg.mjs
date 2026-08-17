// Renders an SVG file to a PNG at a given size, using the Chromium that
// Playwright already ships. Kept separate from make_icons.py because the
// rendering is the only part that needs a browser.
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { readFileSync } from 'node:fs';

const [svgPath, outPath, size, transparent] = process.argv.slice(2);
const html = `<!doctype html><html><head><style>
  html,body{margin:0;padding:0;width:100%;height:100%;background:transparent}
  svg{width:100vw;height:100vh;display:block}
</style></head><body>${readFileSync(svgPath, 'utf8')}</body></html>`;

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const page = await browser.newPage({
  viewport: { width: +size, height: +size },
  deviceScaleFactor: 1,
});
await page.setContent(html, { waitUntil: 'load' });
await page.waitForTimeout(200);
await page.screenshot({ path: outPath, omitBackground: transparent === 'transparent' });
await browser.close();
