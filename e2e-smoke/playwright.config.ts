// Config for the preview smoke. Driven entirely by env so the reusable workflow (and a person at a
// terminal) can point it at any deployment:
//   SMOKE_URL                        preview URL (required)
//   SMOKE_ROUTES                     comma-separated routes, default "/"
//   SMOKE_IGNORE_CONSOLE             regex for known console noise (wallet-provider warnings, etc.)
//   VERCEL_AUTOMATION_BYPASS_SECRET  sent as a header when the preview sits behind Vercel Authentication
import { defineConfig, devices } from '@playwright/test';

const url = process.env.SMOKE_URL;
if (!url) throw new Error('SMOKE_URL is required: the preview URL to smoke');
const bypass = process.env.VERCEL_AUTOMATION_BYPASS_SECRET;

export default defineConfig({
  testDir: '.',
  testMatch: 'smoke.spec.ts',
  timeout: 60_000,
  retries: 1,
  fullyParallel: true,
  reporter: [['list'], ['html', { open: 'never' }], ...(process.env.CI ? [['github'] as const] : [])],
  use: {
    baseURL: url,
    screenshot: 'on',
    trace: 'retain-on-failure',
    // Context-level headers apply to the document request too, so a protected preview opens.
    extraHTTPHeaders: bypass
      ? { 'x-vercel-protection-bypass': bypass, 'x-vercel-set-bypass-cookie': 'true' }
      : {},
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
});
