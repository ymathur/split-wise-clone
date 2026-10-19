// Create / edit / delete flows for expenses, groups, members, settlements and CSV import.
const { test, expect } = require('@playwright/test');
const { ACCOUNTS, GROUP } = require('./fixtures');
const { expectHealthy } = require('./helpers');

test.describe.configure({ mode: 'serial' });

test('add, edit and delete a personal expense', async ({ page }) => {
    const a = ACCOUNTS.lasVegas;
    await page.goto(`/pages/expense-form.cfm?accountId=${a.id}`);
    await page.locator('#accountId').selectOption({ label: a.name });
    await page.locator('#date').fill('2026-10-10');
    await page.locator('#description').fill('Playwright coffee');
    await page.locator('#amount').fill('4.5');
    await page.getByRole('button', { name: 'Save Expense' }).click();
    await page.waitForURL(/expenses\.cfm\?saved=1/);
    await expectHealthy(page);

    await page.goto(`/pages/expenses.cfm?accountId=${a.id}`);
    const row = page.locator('table tbody tr').filter({ hasText: 'Playwright coffee' });
    await expect(row).toContainText('$4.50');

    await row.getByRole('link', { name: 'Edit' }).click();
    await page.locator('#amount').fill('6');
    await page.getByRole('button', { name: 'Update Expense' }).click();
    await page.waitForURL(/expenses\.cfm\?saved=1/);
    await page.goto(`/pages/expenses.cfm?accountId=${a.id}`);
    await expect(page.locator('table tbody tr').filter({ hasText: 'Playwright coffee' })).toContainText('$6.00');

    page.once('dialog', (d) => d.accept());
    await page.locator('table tbody tr').filter({ hasText: 'Playwright coffee' }).getByRole('button', { name: 'Del' }).click();
    await page.waitForURL(/expenses\.cfm\?deleted=1/);
    await page.goto(`/pages/expenses.cfm?accountId=${a.id}`);
    await expect(page.getByText('Playwright coffee')).toHaveCount(0);
    await expect(page.locator('table tbody tr')).toHaveCount(a.expenseCount);
});

test('add a group expense split equally', async ({ page }) => {
    await page.goto('/pages/expense-form.cfm');
    await page.locator('#typeGroup').check();
    await page.locator('#groupId').selectOption(GROUP.id);
    // Members load over AJAX (api/get-members.cfm) once a group is picked
    await expect(page.locator('#paidByMemberId option', { hasText: GROUP.members[1].name })).toHaveCount(1);
    await page.locator('#paidByMemberId').selectOption(GROUP.members[1].id);
    await page.locator('#date').fill('2026-10-11');
    await page.locator('#description').fill('Playwright dinner');
    await page.locator('#amount').fill('900');
    await page.getByRole('button', { name: 'Save Expense' }).click();
    await page.waitForURL(/group-detail\.cfm\?.*saved=1/);
    await expectHealthy(page);
    await expect(page.getByText('Playwright dinner')).toBeVisible();
});

// Regression: editing a group expense soft-deletes its old splits; those used to be counted
// again, so every edit inflated member shares and balances.
test('editing a group expense leaves member balances unchanged', async ({ page }) => {
    const balancesCard = page.locator('.card').filter({ has: page.getByRole('heading', { name: 'Member Balances' }) });
    await page.goto(`/pages/group-detail.cfm?id=${GROUP.id}`);
    const before = await balancesCard.innerText();

    await page.goto('/pages/expense-form.cfm?id=grp-exp-0');
    await page.getByRole('button', { name: 'Update Expense' }).click();
    await page.waitForURL(/group-detail\.cfm\?.*saved=1/);
    await expect(balancesCard).toHaveText(before);
});

test('add a member to the group', async ({ page }) => {
    await page.goto(`/pages/group-members.cfm?groupId=${GROUP.id}`);
    await page.locator('#memberName').fill('New Friend');
    await page.getByRole('button', { name: 'Add Member' }).click();
    await page.waitForURL(/added=1/);
    await expect(page.getByText('New Friend')).toBeVisible();
});

test('record a settlement', async ({ page }) => {
    await page.goto(`/pages/settlement-form.cfm?groupId=${GROUP.id}`);
    await page.locator('#fromMemberId').selectOption(GROUP.members[1].id);
    await page.locator('#toMemberId').selectOption(GROUP.members[0].id);
    await page.locator('#amount').fill('250');
    await page.getByRole('button', { name: 'Record Settlement' }).click();
    await page.waitForURL(/settlements\.cfm\?.*saved=1/);
    await expectHealthy(page);
    await expect(page.getByText('250.00').first()).toBeVisible();
});

test('create a group', async ({ page }) => {
    await page.goto('/pages/group-form.cfm');
    await page.locator('#groupName').fill('Playwright Group');
    await page.getByRole('button', { name: 'Create Group' }).click();
    await page.waitForURL(/groups\.cfm\?saved=1/);
    await expect(page.getByText('Playwright Group')).toBeVisible();
});

test('import personal expenses from CSV', async ({ page }) => {
    const a = ACCOUNTS.dailyCash;
    await page.goto('/pages/import.cfm');
    await page.locator('#accountId').selectOption(a.id);
    await page.locator('#csvFile').setInputFiles({
        name    : 'import.csv',
        mimeType: 'text/csv',
        buffer  : Buffer.from('date,amount,description,category,paymentMode,notes\n2026-10-12,42,Imported lunch,Food,Cash,\n'),
    });
    await page.getByRole('button', { name: 'Preview Import' }).click();
    await expectHealthy(page);
    await expect(page.getByText('Imported lunch')).toBeVisible();
    await page.getByRole('button', { name: 'Import Selected' }).click();
    await expectHealthy(page);

    await page.goto(`/pages/expenses.cfm?accountId=${a.id}`);
    await expect(page.getByText('Imported lunch')).toBeVisible();
});
