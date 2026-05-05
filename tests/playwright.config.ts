import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';

// BASE_URL wins outright — set by the helm test recipes since they don't
// have a .env to point at. Otherwise fall back to HOST_IP/HOST_PORT, which
// the docker-compose .env populates.
dotenv.config({ path: '../docker-compose/.env' });

const host = process.env.HOST_IP ?? '127.0.0.1';
const port = process.env.HOST_PORT ?? '80';
const scheme = process.env.SCHEME ?? 'http';
const baseURL =
  process.env.BASE_URL ??
  (port ? `${scheme}://${host}:${port}` : `${scheme}://${host}`);

// SLOW_MO=ms — pause between every action so a human can watch.
// HEADLESS=true — flip to true in CI (default is headed so you can see it run).
const slowMo = Number(process.env.SLOW_MO ?? 800);
const headless = process.env.HEADLESS === 'true';

export default defineConfig({
  testDir: '.',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  timeout: 90_000,
  use: {
    baseURL,
    headless,
    launchOptions: { slowMo },
    viewport: { width: 1280, height: 800 },
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    ignoreHTTPSErrors: true,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
