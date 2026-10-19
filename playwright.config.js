// End-to-end tests. Run with `npm test`, which starts the Firebase Auth + Firestore emulators
// and then runs Playwright. Playwright starts a separate Lucee server on :8889 (server-test.json)
// that reads .env.test, so tests never touch the real Firebase project or the :8888 dev server.
const { defineConfig } = require('@playwright/test');

const BOX = process.env.BOX_BIN || '/Users/Yogesh/Downloads/commandbox/box';

module.exports = defineConfig({
    testDir       : './tests',
    globalSetup   : require.resolve('./tests/global-setup.js'),
    // Specs share one seeded dataset and some change it, so run them in file order, one at a time
    fullyParallel : false,
    workers       : 1,
    timeout       : 60_000,
    expect        : { timeout: 10_000 },
    reporter      : [['list'], ['html', { open: 'never' }]],
    use: {
        baseURL   : 'http://127.0.0.1:8889',
        trace     : 'retain-on-failure',
        screenshot: 'only-on-failure',
    },
    projects: [
        { name: 'setup', testMatch: /auth\.setup\.js/ },
        {
            name        : 'e2e',
            testMatch   : /.*\.spec\.js/,
            dependencies: ['setup'],
            use         : { storageState: 'tests/.auth/user.json' },
        },
    ],
    webServer: {
        command            : `"${BOX}" server start serverConfigFile=server-test.json --console`,
        url                : 'http://127.0.0.1:8889/login.cfm',
        reuseExistingServer: true,
        timeout            : 180_000,
    },
});
