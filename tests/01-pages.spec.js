// Read-only: every page loads without errors and shows the full seeded data.
const { test, expect } = require('@playwright/test');
const { ACCOUNTS, GROUP, balance, totalActiveExpenses } = require('./fixtures');
const { expectHealthy, money, accountCard } = require('./helpers');

const pages = [
    '/pages/dashboard.cfm',
    '/pages/accounts.cfm?status=All',
    '/pages/account-form.cfm',
    `/pages/account-form.cfm?id=${ACCOUNTS.lasVegas.id}`,
    '/pages/expenses.cfm',
    '/pages/expense-form.cfm',
    `/pages/expense-form.cfm?id=${ACCOUNTS.lasVegas.id}-exp-0`,
    `/pages/expense-detail.cfm?id=${ACCOUNTS.lasVegas.id}-exp-0`,
    '/pages/groups.cfm?status=All',
    '/pages/group-form.cfm',
    `/pages/group-form.cfm?id=${GROUP.id}`,
    `/pages/group-detail.cfm?id=${GROUP.id}`,
    `/pages/group-members.cfm?groupId=${GROUP.id}`,
    '/pages/settlements.cfm',
    `/pages/settlement-form.cfm?groupId=${GROUP.id}`,
    '/pages/reports.cfm',
    '/pages/reports.cfm?generate=1&reportType=personal',
    `/pages/reports.cfm?generate=1&reportType=group&groupId=${GROUP.id}`,
    '/pages/import.cfm',
    '/pages/profile.cfm',
];

for (const url of pages) {
    test(`loads ${url}`, async ({ page }) => {
        const res = await page.goto(url);
        expect(res.status()).toBe(200);
        expect(page.url()).not.toContain('/login.cfm');
        await expectHealthy(page);
    });
}

test('account expense list shows every row the summary counts', async ({ page }) => {
    const a = ACCOUNTS.lasVegas;
    await page.goto(`/pages/expenses.cfm?accountId=${a.id}`);
    await expect(page.locator('.summary-bar')).toContainText(`${a.expenseCount} expense(s)`);
    await expect(page.locator('table tbody tr')).toHaveCount(a.expenseCount);
    await expect(page.getByText(`${a.name} deleted`)).toHaveCount(0);
});

test('all-expenses list is not capped by Firestore paging', async ({ page }) => {
    await page.goto('/pages/expenses.cfm');
    await expect(page.locator('.summary-bar')).toContainText(`${totalActiveExpenses} expense(s)`);
    await expect(page.locator('table tbody tr')).toHaveCount(totalActiveExpenses);
});

test('accounts list shows correct balances', async ({ page }) => {
    await page.goto('/pages/accounts.cfm');
    await expect(accountCard(page, ACCOUNTS.dailyCash.name)).toContainText(money('₹', balance(ACCOUNTS.dailyCash)));
    await expect(accountCard(page, ACCOUNTS.lasVegas.name)).toContainText(money('$', balance(ACCOUNTS.lasVegas)));
});

test('dashboard lists every active account', async ({ page }) => {
    await page.goto('/pages/dashboard.cfm');
    for (const a of Object.values(ACCOUNTS)) {
        await expect(page.getByRole('link', { name: a.name, exact: true }).first()).toBeVisible();
    }
});

test('personal report for one account', async ({ page }) => {
    const a = ACCOUNTS.lasVegas;
    await page.goto(`/pages/reports.cfm?generate=1&reportType=personal&accountId=${a.id}`);
    await expectHealthy(page);
    await expect(page.locator('.stat-card').filter({ hasText: 'Balance' })).toContainText(money('$', balance(a)));
});

test('group detail shows members and expenses', async ({ page }) => {
    await page.goto(`/pages/group-detail.cfm?id=${GROUP.id}`);
    for (const m of GROUP.members) await expect(page.getByText(m.name, { exact: true }).first()).toBeVisible();
    await expect(page.getByText(`${GROUP.name} expense 1`, { exact: true })).toBeVisible();
});

test('CSV export returns the account expenses', async ({ page }) => {
    const a = ACCOUNTS.lasVegas;
    const res = await page.request.get(`/pages/export.cfm?type=personal&accountId=${a.id}`);
    expect(res.status()).toBe(200);
    const body = await res.text();
    expect(body).toContain(`${a.name} expense 1`);
    expect(body).not.toContain(`${a.name} deleted`);
});
