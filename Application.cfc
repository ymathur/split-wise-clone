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
        if (!application.keyExists("firebase") || !application.keyExists("currencies")) {
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
        application.firebase = {
            projectId  : "split-expense-app-c673a",
            apiKey     : "AIzaSyC0V8jRmb7-Dh06qdIm95f-_RkZ9S9I0WY",
            authDomain : "split-expense-app-c673a.firebaseapp.com",
            databaseId : "(default)"
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
    }

}
