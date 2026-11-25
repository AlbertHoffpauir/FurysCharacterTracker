// Opens a local HTML file in headless Chromium, optionally runs a function exposed by the page,
// and saves a screenshot. Used to check the offline viewer.
//   node shot.js <html file> <png file> [width] [height] [expression to evaluate and print]
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [html, png, width, height, expr] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: Number(width) || 1600, height: Number(height) || 900 } });
  page.on('pageerror', (e) => console.log('PAGE ERROR:', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.log('CONSOLE ERROR:', m.text()); });
  await page.goto('file://' + path.resolve(html));
  if (expr) console.log(await page.evaluate(expr));
  if (png && png !== '-') await page.screenshot({ path: png });
  await browser.close();
})();
