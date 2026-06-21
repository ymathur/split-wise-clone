component {

    this.name = "SplitExpenseApp";
    this.sessionManagement = true;
    this.sessionTimeout = createTimeSpan(0, 2, 0, 0);
    this.clientManagement = false;

    function onApplicationStart() {
        loadConfig();
    }

    function onSessionStart() {
        session.isLoggedIn = false;
        session.userId    = "";
        session.userName  = "";
        session.userEmail = "";
        session.idToken   = "";
        session.csrfToken = lCase(hash(createUUID() & createUUID() & getTickCount(), "SHA-256"));
    }

    function onRequestStart(targetPage) {
        if (!application.keyExists("firebase") || !application.keyExists("currencies") || !application.keyExists("receiptsDir")) {
            loadConfig();
        }
    }

    function onError(exception, eventName) {
        writeOutput("<div style='font-family:sans-serif;padding:20px;'>
            <h2>Application Error</h2>
            <p>#htmlEditFormat(exception.message)#</p>
        </div>");
    }

    private function loadConfig() {
        var env = loadEnv(expandPath("/.env"));
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
            databaseId : len(env.FIREBASE_DATABASE_ID ?: "") ? env.FIREBASE_DATABASE_ID : "(default)"
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
        application.receiptsDir = "/Users/Yogesh/Documents/ClaudeCoding/SplitWiseClone_receipts/";
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
