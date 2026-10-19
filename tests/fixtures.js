// Seeded test data shared by global-setup.js and the specs. These are emulator-only test values.

const TEST_USER = {
    email   : 'tester@splitwise.test',
    password: 'emulator-only-password',
    name    : 'Test User',
};

// Personal accounts. expenseCount/expenseAmount describe the seeded Active expenses;
// deletedCount extra expenses are seeded with status "Deleted" and must never show up.
const ACCOUNTS = {
    dailyCash : { id: 'acc-daily-cash',  name: 'Daily Cash',       currency: 'INR', opening: 100000, expenseCount: 320, expenseAmount: 10,  deletedCount: 0 },
    lasVegas  : { id: 'acc-las-vegas',   name: 'Las Vegas 2026',   currency: 'USD', opening: 1876,   expenseCount: 27,  expenseAmount: 20,  deletedCount: 5 },
    toClose   : { id: 'acc-to-close',    name: 'Account To Close', currency: 'INR', opening: 1000,   expenseCount: 2,   expenseAmount: 100, deletedCount: 0 },
    overspent : { id: 'acc-overspent',   name: 'Overspent',        currency: 'INR', opening: 100,    expenseCount: 1,   expenseAmount: 150, deletedCount: 0 },
};

const GROUP = {
    id          : 'grp-himachal',
    name        : 'Himachal 2026',
    currency    : 'INR',
    members     : [{ id: 'mem-me', name: 'Me' }, { id: 'mem-friend', name: 'Friend' }],
    expenseCount: 6,
    expenseAmount: 1000, // paid by "Me", split equally
};

const balance = (a) => a.opening - a.expenseCount * a.expenseAmount;
const totalActiveExpenses = Object.values(ACCOUNTS).reduce((n, a) => n + a.expenseCount, 0) + GROUP.expenseCount;

module.exports = { TEST_USER, ACCOUNTS, GROUP, balance, totalActiveExpenses, PROJECT_ID: 'demo-splitwise' };
