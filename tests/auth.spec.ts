import { test, expect } from '@playwright/test';

const USERNAME = process.env.TEST_USERNAME ?? 'test';
const PASSWORD = process.env.TEST_PASSWORD ?? 'test';

// Extra pause between each step so a human can follow along.
const STEP_PAUSE_MS = Number(process.env.STEP_PAUSE_MS ?? 1500);
const pause = (page: import('@playwright/test').Page) =>
  page.waitForTimeout(STEP_PAUSE_MS);

test('login flow: / → keycloak → / → /oauth/userinfo', async ({ page }) => {
  await test.step('1. visit / unauthenticated → expect redirect to Keycloak', async () => {
    await page.goto('/');
    // Wait for Keycloak login URL.
    await page.waitForURL(/\/auth\/realms\/proxy\/protocol\/openid-connect\/auth/, {
      timeout: 30_000,
    });
    await expect(page.locator('#username')).toBeVisible();
    await expect(page.locator('#password')).toBeVisible();
    await pause(page);
  });

  await test.step('2. submit credentials on Keycloak login form', async () => {
    await page.locator('#username').fill(USERNAME);
    await pause(page);
    await page.locator('#password').fill(PASSWORD);
    await pause(page);
    await page.locator('#kc-login').click();
  });

  await test.step('3. redirected back to / and see the nginx landing page', async () => {
    await page.waitForURL((url) => url.pathname === '/', { timeout: 30_000 });
    await expect(
      page.getByRole('heading', { name: 'auth2-proxy' }),
    ).toBeVisible();
    await expect(page.getByText(/HAProxy \+ oauth2-proxy \+ Keycloak/i)).toBeVisible();
    await pause(page);
  });

  await test.step('4. /oauth/userinfo returns the authenticated identity', async () => {
    // Navigate the browser so it's visible. /oauth/userinfo returns JSON;
    // browsers render it as plain text we can read out of the page.
    await page.goto('/oauth/userinfo');
    const body = await page.locator('body').innerText();
    const userinfo = JSON.parse(body);
    expect(userinfo.email).toBe('test@example.com');
    expect(userinfo.preferredUsername ?? userinfo.user).toBe(USERNAME);
    await pause(page);
  });

  await test.step('5. /page shows the user (sanity check on upstream headers)', async () => {
    await page.goto('/page');
    await expect(page.getByRole('heading', { name: /signed in/i })).toBeVisible();
    await expect(page.getByText(USERNAME)).toBeVisible();
    await pause(page);
  });
});
