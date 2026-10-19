// Logs in once through the real login page (Firebase Auth emulator) and saves the session
// cookie for the other specs.
const { test: setup, expect } = require('@playwright/test');
const { TEST_USER } = require('./fixtures');

setup('log in', async ({ page }) => {
    await page.goto('/login.cfm');
    await page.locator('#email').fill(TEST_USER.email);
    await page.locator('#password').fill(TEST_USER.password);
    await page.locator('#loginBtn').click();
    await page.waitForURL(/\/pages\/dashboard\.cfm/);
    await expect(page.getByRole('heading', { name: /Welcome/ })).toBeVisible();
    await page.context().storageState({ path: 'tests/.auth/user.json' });
});
