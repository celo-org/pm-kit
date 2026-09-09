// Preview smoke. What green means, exactly and nothing more:
//   every listed route on the preview returned < 400, rendered visible text, showed no framework error
//   overlay, and produced zero console errors, zero uncaught exceptions, and zero failed same-origin
//   requests — on a desktop and a mobile viewport.
// It does not prove the page is correct, laid out right, or that money moves. Those are the browser
// pass in /write-pr + /review-pr and, for bigger payment changes, an optional real transaction
// verified at the receipt (engineering-rules §3).
import { test, expect } from '@playwright/test';

const routes = (process.env.SMOKE_ROUTES ?? '/')
  .split(',')
  .map((r) => r.trim())
  .filter(Boolean);
const ignore = process.env.SMOKE_IGNORE_CONSOLE ? new RegExp(process.env.SMOKE_IGNORE_CONSOLE) : null;
// Next.js prod error page, Next.js dev overlay, generic 500 page.
const ERROR_OVERLAY = /Application error: a client-side exception|Unhandled Runtime Error|Internal Server Error/;

for (const route of routes) {
  test(`${route} loads with zero console errors`, async ({ page, baseURL }) => {
    const origin = new URL(baseURL!).origin;
    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    const failedRequests: string[] = [];

    page.on('console', (m) => {
      if (m.type() === 'error' && !(ignore && ignore.test(m.text()))) consoleErrors.push(m.text());
    });
    page.on('pageerror', (e) => pageErrors.push(String(e)));
    page.on('requestfailed', (r) => {
      const why = r.failure()?.errorText ?? '';
      // ERR_ABORTED is the page cancelling its own request (navigation, prefetch, Vercel toolbar
      // probe) — not a server failure. Anything else on our origin is.
      if (r.url().startsWith(origin) && why !== 'net::ERR_ABORTED') failedRequests.push(`${r.url()} ${why}`.trim());
    });

    const response = await page.goto(route, { waitUntil: 'load' });
    expect(response, `no response for ${route}`).not.toBeNull();
    // A preview behind Vercel Authentication 302s to the Vercel login (off-origin). Say so, don't
    // let a login page's console decide the verdict.
    expect(
      new URL(page.url()).origin,
      `${route} redirected off-origin to ${page.url()} — Vercel Authentication? set VERCEL_AUTOMATION_BYPASS_SECRET`,
    ).toBe(origin);
    expect(response!.status(), `${route} returned HTTP ${response!.status()}`).toBeLessThan(400);

    // Let client-side rendering and first fetches settle; pollers must not hang the test.
    await page.waitForLoadState('networkidle', { timeout: 5_000 }).catch(() => {});

    const bodyText = (await page.locator('body').innerText()).trim();
    expect(bodyText.length, 'page rendered no visible text').toBeGreaterThan(0);
    expect(bodyText, 'framework error overlay visible').not.toMatch(ERROR_OVERLAY);

    await test.info().attach(route, { body: await page.screenshot({ fullPage: true }), contentType: 'image/png' });

    expect(pageErrors, 'uncaught exceptions').toEqual([]);
    expect(failedRequests, 'failed same-origin requests').toEqual([]);
    expect(consoleErrors, 'console errors').toEqual([]);
  });
}
