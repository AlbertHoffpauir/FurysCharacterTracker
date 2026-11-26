// Screenshots of the offline viewer for a look-over: the board on a few tabs and every window.
//   node shots.js <page.html> <out folder> [now]
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [html, out, now] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1500, height: 900 }, deviceScaleFactor: 1 });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto('file://' + path.resolve(html) + (now ? '#now=' + now : ''));
  const shot = (name) => page.screenshot({ path: path.join(out, name + '.png') });
  await shot('board-overview');
  for (const tab of ['class', 'traits', 'daily', 'weekly', 'points', 'wallet', 'progress', 'sets']) {
    await page.click(`nav div[data-id="${tab}"]`);
    await shot('board-' + tab);
  }
  await page.click('nav div[data-id="overview"]');
  await page.click('thead th:nth-child(4)');
  await page.hover('tbody tr:nth-child(3) td:nth-child(5)');
  await shot('sorted-and-tip');
  for (const [button, name] of [['#startButton', 'start'], ['#footer-timers', 'timers'], ['#footer-brag', 'brag'], ['#footer-copy', 'copy']]) {
    await page.click(button);
    await shot('window-' + name);
    await page.keyboard.press('Escape');
  }
  await page.click('tbody tr:nth-child(3) td:first-child');
  await shot('window-details');
  await page.keyboard.press('Escape');
  await page.click('tbody tr:first-child td:first-child', { button: 'right' });
  await shot('row-menu');
  await page.keyboard.press('Escape');
  const [download] = await Promise.all([page.waitForEvent('download'), page.click('#footer-export')]);
  const file = path.join(out, download.suggestedFilename());
  await download.saveAs(file);
  console.log('saved for Excel:', download.suggestedFilename());
  if (await page.locator('#account option').count() > 1) {
    await page.selectOption('#account', '2');
    await shot('board-second-account');
  }
  console.log('page errors:', errors.length);
  errors.forEach((e) => console.log('  ', e));
  await browser.close();
  process.exit(errors.length ? 1 : 0);
})();
