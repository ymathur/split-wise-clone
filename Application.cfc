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
    }

    function onRequestStart(targetPage) {
        if (!application.keyExists("firebase")) {
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
        application.currency   = "₹";
    }

}
