// Wipes the emulators and seeds a known dataset before every run.
// Documents are written with the emulator's "Bearer owner" admin token, which bypasses
// security rules for seeding only; the app itself still goes through firestore.rules.
const { TEST_USER, ACCOUNTS, GROUP, PROJECT_ID } = require('./fixtures');

const FIRESTORE = 'http://127.0.0.1:8080';
const AUTH      = 'http://127.0.0.1:9099';
const DOCS      = `${FIRESTORE}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function call(url, options = {}) {
    const res = await fetch(url, options);
    if (!res.ok) throw new Error(`${options.method || 'GET'} ${url} -> ${res.status} ${await res.text()}`);
    return res.status === 204 ? null : res.json();
}

// Same typing rules as components/firebase.cfc _typedValue, so seeded docs look app-written
function typed(v) {
    if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
    return { stringValue: String(v) };
}

async function put(collection, id, data) {
    const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, typed(v)]));
    await call(`${DOCS}/${collection}?documentId=${encodeURIComponent(id)}`, {
        method : 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
        body   : JSON.stringify({ fields }),
    });
}

// Writes many docs per request; seeding 350+ expenses one by one is slow
async function putMany(collection, docs) {
    for (let i = 0; i < docs.length; i += 200) {
        const writes = docs.slice(i, i + 200).map(({ id, data }) => ({
            update: {
                name  : `projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${id}`,
                fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, typed(v)])),
            },
        }));
        await call(`${DOCS}:commit`, {
            method : 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
            body   : JSON.stringify({ writes }),
        });
    }
}

const now = '2026-10-01T10:00:00Z';
const day = (n) => `2026-0${1 + Math.floor(n / 28) % 9}-${String(1 + (n % 28)).padStart(2, '0')}`;

module.exports = async () => {
    await call(`${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' });
    await call(`${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: 'DELETE' });

    const user = await call(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`, {
        method : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body   : JSON.stringify({ email: TEST_USER.email, password: TEST_USER.password, displayName: TEST_USER.name, returnSecureToken: true }),
    });
    const userId = user.localId;

    await put('users', userId, { userId, name: TEST_USER.name, email: TEST_USER.email, createdAt: now, updatedAt: now });

    const expenses = [];
    const expense = (id, extra) => expenses.push({ id, data: {
        expenseId: id, userId, accountId: '', groupId: '', expenseType: 'Personal', date: '2026-01-01',
        description: '', category: 'Food', amount: 0, paidByMemberId: '', paymentMode: 'Cash',
        splitType: 'Equal', notes: '', receiptFile: '', status: 'Active', createdAt: now, updatedAt: now, ...extra,
    } });

    for (const a of Object.values(ACCOUNTS)) {
        await put('accounts', a.id, {
            accountId: a.id, userId, accountName: a.name, currency: a.currency, openingAmount: a.opening,
            startDate: '2026-01-01', notes: '', status: 'Active', createdAt: now, updatedAt: now,
        });
        for (let i = 0; i < a.expenseCount; i++) {
            expense(`${a.id}-exp-${i}`, { accountId: a.id, date: day(i), description: `${a.name} expense ${i + 1}`, amount: a.expenseAmount });
        }
        for (let i = 0; i < a.deletedCount; i++) {
            expense(`${a.id}-del-${i}`, { accountId: a.id, description: `${a.name} deleted ${i + 1}`, amount: 999, status: 'Deleted' });
        }
    }

    await put('groups', GROUP.id, {
        groupId: GROUP.id, ownerUserId: userId, groupName: GROUP.name, currency: GROUP.currency, description: '',
        startDate: '2026-01-01', endDate: '', openingAmount: 0, status: 'Active', createdAt: now, updatedAt: now,
    });
    for (const m of GROUP.members) {
        await put('groupMembers', m.id, { memberId: m.id, groupId: GROUP.id, name: m.name, email: '', mobile: '', linkedUserId: '', status: 'Active', createdAt: now });
    }
    const splits = [];
    for (let i = 0; i < GROUP.expenseCount; i++) {
        const id = `grp-exp-${i}`;
        expense(id, { groupId: GROUP.id, expenseType: 'Group', date: day(i), description: `${GROUP.name} expense ${i + 1}`,
                      amount: GROUP.expenseAmount, paidByMemberId: GROUP.members[0].id });
        for (const m of GROUP.members) {
            splits.push({ id: `${id}-${m.id}`, data: { splitId: `${id}-${m.id}`, expenseId: id, groupId: GROUP.id, memberId: m.id,
                                                       shareAmount: GROUP.expenseAmount / GROUP.members.length, createdAt: now } });
        }
    }

    await putMany('expenses', expenses);
    await putMany('expenseSplits', splits);
};
