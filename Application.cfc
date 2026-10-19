component {

    this.name = "SplitExpenseApp";
    this.sessionManagement = true;
    this.sessionTimeout = createTimeSpan(0, 2, 0, 0);
    this.clientManagement = false;

    function onApplicationStart() {
        loadConfig();
    }

    function onSessionStart() {
        initSession();
    }

    function onRequestStart(targetPage) {
        if (!application.keyExists("firebase") || !application.keyExists("currencies") || !application.keyExists("receiptsDir")) {
            loadConfig();
        }
        // Lucee does not call onSessionStart for the fresh session that follows sessionInvalidate()
        // (logout, expired login), so make sure the defaults exist on every request.
        if (!session.keyExists("csrfToken")) {
            initSession();
        }
    }

    // Fills in only missing keys, so a logged-in session that lacks a CSRF token keeps its login
    private function initSession() {
        var defaults = {
            isLoggedIn   : false,
            userId       : "",
            userName     : "",
            userEmail    : "",
            idToken      : "",
            refreshToken : "",
            csrfToken    : lCase(hash(createUUID() & createUUID() & getTickCount(), "SHA-256"))
        };
        for (var key in defaults) {
            if (!session.keyExists(key)) session[key] = defaults[key];
        }
    }

    function onError(exception, eventName) {
        writeOutput("<div style='font-family:sans-serif;padding:20px;'>
            <h2>Application Error</h2>
            <p>#htmlEditFormat(exception.message)#</p>
        </div>");
    }

    private function loadConfig() {
        // The test server (server-test.json) points this at .env.test so it talks to the local emulators
        var envFile = createObject("java", "java.lang.System").getProperty("SPLITWISE_ENV_FILE", ".env");
        var env = loadEnv(expandPath("/" & envFile));
        var required = ["FIREBASE_PROJECT_ID", "FIREBASE_API_KEY", "FIREBASE_AUTH_DOMAIN"];
        for (var key in required) {
            if (!len(env[key] ?: "")) {
                throw(type="ConfigError", message="Missing #key# in .env - copy .env.example to .env and fill in your Firebase project's credentials.");
            }
        }

        application.firebase = {
            projectId  : env.FIREBASE_PROJECT_ID,
            apiKey     : env.FIREBASE_API_KEY,
            authDomain : env.FIREBASE_AUTH_DOMAIN,
            databaseId : len(env.FIREBASE_DATABASE_ID ?: "") ? env.FIREBASE_DATABASE_ID : "(default)",
            // host:port of the local Firebase emulators; empty means the real Google endpoints
            firestoreEmulator : env.FIRESTORE_EMULATOR_HOST ?: "",
            authEmulator      : env.FIREBASE_AUTH_EMULATOR_HOST ?: ""
        };
        application.appName    = "Split Expense App";
        application.appVersion = "1.0";

        application.currencies = [
            {"code": "INR", "symbol": "₹",   "name": "Indian Rupee"},
            {"code": "USD", "symbol": "$",   "name": "US Dollar"},
            {"code": "EUR", "symbol": "€",   "name": "Euro"},
            {"code": "GBP", "symbol": "£",   "name": "British Pound"},
            {"code": "JPY", "symbol": "¥",   "name": "Japanese Yen"},
            {"code": "AUD", "symbol": "A$",  "name": "Australian Dollar"},
            {"code": "CAD", "symbol": "C$",  "name": "Canadian Dollar"},
            {"code": "SGD", "symbol": "S$",  "name": "Singapore Dollar"},
            {"code": "AED", "symbol": "AED", "name": "UAE Dirham"},
            {"code": "CHF", "symbol": "CHF", "name": "Swiss Franc"}
        ];
        application.defaultCurrency = "INR";
        application.currencySymbols = {};
        for (var c in application.currencies) {
            application.currencySymbols[c.code] = c.symbol;
        }

        application.currencySymbol = function(code) {
            var key = len(arguments.code ?: "") ? arguments.code : application.defaultCurrency;
            return structKeyExists(application.currencySymbols, key)
                ? application.currencySymbols[key]
                : application.currencySymbols[application.defaultCurrency];
        };

        // Receipt photos live outside the webroot so they can never be served directly -
        // the only access path is the ownership-gated pages/receipt-view.cfm.
        application.receiptsDir = len(env.RECEIPTS_DIR ?: "") ? env.RECEIPTS_DIR : "/Users/Yogesh/Documents/ClaudeCoding/SplitWiseClone_receipts/";
        if (!directoryExists(application.receiptsDir)) {
            directoryCreate(application.receiptsDir);
        }
    }

    // Minimal .env parser: KEY=VALUE per line, "#" comments, blank lines skipped,
    // optional surrounding quotes stripped. Returns {} if the file doesn't exist.
    private function loadEnv(required string path) {
        var result = {};
        if (!fileExists(arguments.path)) return result;

        var lines = listToArray(fileRead(arguments.path), chr(10), false, true);
        for (var line in lines) {
            var trimmed = trim(line);
            if (!len(trimmed) || left(trimmed, 1) == "##" || !find("=", trimmed)) continue;

            var key   = trim(left(trimmed, find("=", trimmed) - 1));
            var value = trim(mid(trimmed, find("=", trimmed) + 1, len(trimmed)));
            if (len(value) >= 2 && (left(value, 1) == '"' && right(value, 1) == '"' || left(value, 1) == "'" && right(value, 1) == "'")) {
                value = mid(value, 2, len(value) - 2);
            }
            result[key] = value;
        }
        return result;
    }

}
