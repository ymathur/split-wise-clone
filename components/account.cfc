component {

    variables.fb      = "";
    variables.userId  = "";
    variables.idToken = "";

    function init(required fb, required string userId, required string idToken) {
        variables.fb      = arguments.fb;
        variables.userId  = arguments.userId;
        variables.idToken = arguments.idToken;
        return this;
    }

    function createAccount(required struct data) {
        var id  = variables.fb.generateId();
        var now = variables.fb._now();
        var doc = {
            "accountId"     : id,
            "userId"        : variables.userId,
            "accountName"   : arguments.data.accountName,
            "currency"      : len(arguments.data.currency ?: "") ? arguments.data.currency : application.defaultCurrency,
            "openingAmount" : val(arguments.data.openingAmount ?: 0),
            "startDate"     : arguments.data.startDate ?: dateFormat(now(), "yyyy-mm-dd"),
            "notes"         : arguments.data.notes ?: "",
            "status"        : "Active",
            "createdAt"     : now,
            "updatedAt"     : now
        };
        var result = variables.fb.setDocument("accounts", id, doc, variables.idToken);
        if (result.success) return id;
        throw(type="FirestoreError", message=result.error ?: "Failed to create account");
    }

    function getAccounts(string status = "Active") {
        var filters = [
            variables.fb.fieldFilter("userId", "EQUAL", variables.userId)
        ];
        if (len(arguments.status) && arguments.status != "All") {
            arrayAppend(filters, variables.fb.fieldFilter("status", "EQUAL", arguments.status));
        }
        var result = variables.fb.queryCollection(
            collection = "accounts",
            filters    = filters,
            idToken    = variables.idToken
        );
        if (!result.success) return [];
        var list = arrayFilter(result.data, function(a) { return a.status != "Deleted"; });
        arraySort(list, function(a, b) { return compare(b.createdAt, a.createdAt); });
        for (var a in list) _ensureCurrency(a);
        return list;
    }

    function getAccount(required string accountId) {
        var result = variables.fb.getDocument("accounts", arguments.accountId, variables.idToken);
        if (result.success && result.data.userId == variables.userId) {
            _ensureCurrency(result.data);
            return result.data;
        }
        throw(type="NotFoundError", message="Account not found");
    }

    // Backfills currency on accounts created before this field existed, so
    // every caller can safely read acc.currency without a missing-key error.
    private function _ensureCurrency(required struct acc) {
        if (!len(arguments.acc.currency ?: "")) {
            arguments.acc.currency = application.defaultCurrency;
        }
    }

    function updateAccount(required string accountId, required struct data) {
        var existing = getAccount(arguments.accountId);
        var updates = {
            "accountName"   : arguments.data.accountName   ?: existing.accountName,
            "currency"      : len(arguments.data.currency ?: "") ? arguments.data.currency : (existing.currency ?: application.defaultCurrency),
            "openingAmount" : val(arguments.data.openingAmount ?: existing.openingAmount),
            "startDate"     : arguments.data.startDate     ?: existing.startDate,
            "notes"         : arguments.data.notes         ?: existing.notes,
            "status"        : arguments.data.status        ?: existing.status,
            "updatedAt"     : variables.fb._now()
        };
        var result = variables.fb.updateDocument("accounts", arguments.accountId, updates, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message=result.error ?: "Failed to update account");
    }

    function deleteAccount(required string accountId) {
        getAccount(arguments.accountId); // verify ownership
        var result = variables.fb.softDelete("accounts", arguments.accountId, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message="Failed to delete account");
    }

    // Returns {openingAmount, totalExpenses, balance}
    function getAccountBalance(required string accountId) {
        var account = getAccount(arguments.accountId);
        var filters = [
            variables.fb.fieldFilter("accountId",   "EQUAL", arguments.accountId),
            variables.fb.fieldFilter("userId",      "EQUAL", variables.userId),
            variables.fb.fieldFilter("expenseType", "EQUAL", "Personal")
        ];
        var expResult = variables.fb.queryCollection(
            collection = "expenses",
            filters    = filters,
            idToken    = variables.idToken
        );
        var totalExpenses = 0;
        if (expResult.success) {
            for (var e in expResult.data) {
                if (e.status != "Deleted") totalExpenses += val(e.amount);
            }
        }
        return {
            openingAmount  : val(account.openingAmount),
            totalExpenses  : totalExpenses,
            balance        : val(account.openingAmount) - totalExpenses
        };
    }

}
