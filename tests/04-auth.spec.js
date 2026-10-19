const { test, expect } = require('@playwright/test');

test('protected pages redirect to login when logged out', async ({ browser }) => {
    const context = await browser.newContext({ storageState: { cookies: [], origins: [] } });
    const page = await context.newPage();
    await page.goto('/pages/accounts.cfm');
    await expect(page).toHaveURL(/login\.cfm/);
    await context.close();
});

test('an expired session sends you to login instead of showing empty pages', async ({ browser }) => {
    // A session cookie the server has never seen behaves like an expired session
    const context = await browser.newContext({ storageState: { cookies: [
        { name: 'cfid', value: '00000000-0000-0000-0000-000000000000', domain: '127.0.0.1', path: '/' },
        { name: 'cftoken', value: '0', domain: '127.0.0.1', path: '/' },
    ], origins: [] } });
    const page = await context.newPage();
    await page.goto('/pages/expenses.cfm');
    await expect(page).toHaveURL(/login\.cfm/);
    await context.close();
});

// Runs last: logging out ends the shared session used by the other specs
test('logout ends the session', async ({ page }) => {
    await page.goto('/pages/dashboard.cfm');
    await page.getByRole('link', { name: /Logout/ }).click();
    await expect(page).toHaveURL(/login\.cfm/);
    await page.goto('/pages/dashboard.cfm');
    await expect(page).toHaveURL(/login\.cfm/);
});

// Regression: Lucee skips onSessionStart after sessionInvalidate(), so the session that follows a
// logout had no csrfToken and every list page crashed after its first row (on the Delete form).
test('after logout and login again, list pages render every row', async ({ page }) => {
    const { TEST_USER, ACCOUNTS } = require('./fixtures');
    await page.goto('/logout.cfm');
    await page.goto('/login.cfm');
    await page.locator('#email').fill(TEST_USER.email);
    await page.locator('#password').fill(TEST_USER.password);
    await page.locator('#loginBtn').click();
    await page.waitForURL(/\/pages\/dashboard\.cfm/);

    const a = ACCOUNTS.lasVegas;
    await page.goto(`/pages/expenses.cfm?accountId=${a.id}`);
    await expect(page.getByText('Application Error')).toHaveCount(0);
    await expect(page.locator('table tbody tr')).toHaveCount(a.expenseCount);
    await expect(page.getByRole('button', { name: 'Del' })).toHaveCount(a.expenseCount);
});
