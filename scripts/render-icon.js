// Renders Resources/AppIcon.svg to Resources/AppIcon.png (1024) and the asset-catalog sizes.
// Usage: node scripts/render-icon.js   (needs Playwright's Chromium)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..');
const svg = fs.readFileSync(path.join(root, 'Resources/AppIcon.svg'), 'utf8');
const catalog = path.join(root, 'App/Assets.xcassets/AppIcon.appiconset');
const sizes = [[16,1],[16,2],[32,1],[32,2],[128,1],[128,2],[256,1],[256,2],[512,1],[512,2]];
(async () => {
  const browser = await chromium.launch();
  const render = async (px, out) => {
    const page = await browser.newPage({ viewport: { width: px, height: px }, deviceScaleFactor: 1 });
    await page.setContent(`<html><body style="margin:0;background:transparent">${svg.replace('width="1024" height="1024"', `width="${px}" height="${px}"`)}</body></html>`);
    await page.screenshot({ path: out, omitBackground: true });
    await page.close();
  };
  await render(1024, path.join(root, 'Resources/AppIcon.png'));
  const images = [];
  for (const [s, scale] of sizes) {
    const name = `icon_${s}x${s}${scale === 2 ? '@2x' : ''}.png`;
    await render(s * scale, path.join(catalog, name));
    images.push({ size: `${s}x${s}`, idiom: 'mac', filename: name, scale: `${scale}x` });
  }
  fs.writeFileSync(path.join(catalog, 'Contents.json'), JSON.stringify({ images, info: { version: 1, author: 'xcode' } }, null, 2));
  await browser.close();
})();
