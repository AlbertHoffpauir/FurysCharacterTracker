// Runs a filled-in viewer page in headless Chromium and prints the dump (dev/dump.lua) the page's
// own Lua produces, so it can be compared with the game build's dump.
//   node viewer_dump.js <page.html> <dump.lua> <now> <out file>
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const [html, dumpLua, now, out] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto('file://' + path.resolve(html) + '#now=' + now);
  const started = Date.now();
  const text = await page.evaluate((src) => { fengari.load(src, '@dump.lua')(); return fengari.load('return FCT_Dump(true)')(); }, fs.readFileSync(dumpLua, 'utf8'));
  fs.writeFileSync(out, text);
  console.log('dump from the browser:', text.split('\n').length, 'lines in', Date.now() - started, 'ms; page errors:', errors.length);
  errors.forEach((e) => console.log('  ', e));
  await browser.close();
  process.exit(errors.length ? 1 : 0);
})();
