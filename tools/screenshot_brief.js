// Renders docs/trinity-brief.html and saves screenshots to docs/screenshots/.
// Run from the repo root (needs Playwright + Chromium):  node tools/screenshot_brief.js
const path = require('path');
const { chromium } = require('playwright');
(async () => {
  const root = path.resolve(__dirname, '..');
  const out = f => path.join(root, 'docs', 'screenshots', f);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1200, height: 900 }, deviceScaleFactor: 2 });
  const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  await p.goto('file://' + path.join(root, 'docs', 'trinity-brief.html'));
  await p.waitForTimeout(800);
  await p.screenshot({ path: out('brief-hero.png') });
  for (const preset of ['strong', 'short', 'evening', 'overtime']) {
    await p.click(`[data-preset=${preset}]`);
    await p.locator('#simWatch').screenshot({ path: out(`face-${preset}.png`) });
  }
  console.log(errs.length ? 'page errors: ' + errs.join('; ') : 'screenshots saved, no page errors');
  await b.close();
})();
