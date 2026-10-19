// Close an account -> leftover goes to cash in hand -> reuse it in a new / running account.
const { test, expect } = require('@playwright/test');
const { ACCOUNTS, balance } = require('./fixtures');
const { expectHealthy, money, accountCard } = require('./helpers');

test.describe.configure({ mode: 'serial' });

const cashLine = (page) => page.locator('.alert-info').filter({ hasText: 'Cash in Hand' });

async function closeAccount(page, name) {
    await page.goto('/pages/accounts.cfm');
    page.once('dialog', (d) => d.accept());
    await accountCard(page, name).getByRole('button', { name: 'Close' }).click();
    await page.waitForURL(/accounts\.cfm\?closed=1/);
    await expectHealthy(page);
}

const leftover   = balance(ACCOUNTS.toClose);   // 800
const shortfall  = balance(ACCOUNTS.overspent); // -50
const useAmount  = 500;

test('closing an account moves its balance to cash in hand', async ({ page }) => {
    await closeAccount(page, ACCOUNTS.toClose.name);
    await expect(cashLine(page)).toContainText(money('₹', leftover));
    await expect(accountCard(page, ACCOUNTS.toClose.name)).toHaveCount(0); // gone from Active list

    await page.goto('/pages/accounts.cfm?status=Closed');
    const card = accountCard(page, ACCOUNTS.toClose.name);
    await expect(card).toContainText('Balance: ' + money('₹', 0));
    await expect(card.getByRole('button', { name: 'Close' })).toHaveCount(0);
});

test('closed account is not offered for new expenses or imports', async ({ page }) => {
    for (const url of ['/pages/expense-form.cfm', '/pages/import.cfm']) {
        await page.goto(url);
        await expect(page.locator('#accountId option', { hasText: ACCOUNTS.toClose.name })).toHaveCount(0);
        await expect(page.locator('#accountId option', { hasText: ACCOUNTS.dailyCash.name })).toHaveCount(1);
    }
});

test('closing an overspent account takes the shortfall from cash in hand', async ({ page }) => {
    await closeAccount(page, ACCOUNTS.overspent.name);
    await expect(cashLine(page)).toContainText(money('₹', leftover + shortfall));
});

test('new account can use cash in hand', async ({ page }) => {
    await page.goto('/pages/account-form.cfm');
    await page.locator('#accountName').fill('Fresh Start');
    await page.locator('#currency').selectOption('INR');
    await expect(page.locator('#cashHint')).toContainText(money('₹', leftover + shortfall));
    await page.locator('#openingAmount').fill('0');
    await page.locator('#cashAmount').fill(String(useAmount));
    await page.getByRole('button', { name: 'Create Account' }).click();
    await page.waitForURL(/accounts\.cfm\?saved=1/);

    await expect(accountCard(page, 'Fresh Start')).toContainText('Balance: ' + money('₹', useAmount));
    await expect(cashLine(page)).toContainText(money('₹', leftover + shortfall - useAmount));
});

test('cannot take more than is in cash in hand', async ({ page }) => {
    const available = leftover + shortfall - useAmount;
    await page.goto('/pages/account-form.cfm');
    await page.locator('#accountName').fill('Too Greedy');
    await page.locator('#currency').selectOption('INR');
    await page.locator('#cashAmount').fill(String(available + 1));
    await page.getByRole('button', { name: 'Create Account' }).click();
    await expect(page.locator('.alert-danger')).toContainText(`Only ${money('₹', available)} is available`);

    await page.goto('/pages/accounts.cfm');
    await expect(accountCard(page, 'Too Greedy')).toHaveCount(0);
});

test('cash in hand is per currency', async ({ page }) => {
    await page.goto('/pages/account-form.cfm');
    await page.locator('#currency').selectOption('USD');
    await expect(page.locator('#cashHint')).toContainText(money('$', 0));
});

test('a running account can add from cash in hand', async ({ page }) => {
    const a = ACCOUNTS.dailyCash;
    await page.goto(`/pages/account-form.cfm?id=${a.id}`);
    await page.locator('#cashAmount').fill('100');
    await page.getByRole('button', { name: 'Update Account' }).click();
    await page.waitForURL(/accounts\.cfm\?saved=1/);
    await expect(accountCard(page, a.name)).toContainText('Balance: ' + money('₹', balance(a) + 100));
    await expect(cashLine(page)).toContainText(money('₹', leftover + shortfall - useAmount - 100));
});

test('dashboard shows cash in hand', async ({ page }) => {
    await page.goto('/pages/dashboard.cfm');
    await expect(page.locator('.stat-card').filter({ hasText: 'Cash in Hand' })).toContainText(money('₹', leftover + shortfall - useAmount - 100));
});
