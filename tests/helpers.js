const { expect } = require('@playwright/test');

// Fails if the page shows the CFML error handler or any server-side error alert
async function expectHealthy(page) {
    await expect(page.getByText('Application Error')).toHaveCount(0);
    await expect(page.locator('.alert-danger:visible')).toHaveCount(0);
}

const money = (symbol, n) => symbol + n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// The accounts list renders one .list-card per account
const accountCard = (page, name) => page.locator('.list-card').filter({ has: page.getByRole('link', { name, exact: true }) });

module.exports = { expectHealthy, money, accountCard };
