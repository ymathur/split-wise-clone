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
        // Currency is locked once cash has moved in or out, so cash-in-hand totals stay in the right currency
        var currencyLocked = hasCashTransfers(arguments.accountId);
        var updates = {
            "accountName"   : arguments.data.accountName   ?: existing.accountName,
            "currency"      : (!currencyLocked && len(arguments.data.currency ?: "")) ? arguments.data.currency : (existing.currency ?: application.defaultCurrency),
            "openingAmount" : existing.status == "Closed" ? val(existing.openingAmount) : val(arguments.data.openingAmount ?: existing.openingAmount),
            "startDate"     : arguments.data.startDate     ?: existing.startDate,
            "notes"         : arguments.data.notes         ?: existing.notes,
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

    // An account's balance is the cash left, so only cash payments reduce it.
    // Older expenses saved without a payment mode count as cash.
    function isCashPayment(string paymentMode = "") {
        return !len(trim(arguments.paymentMode)) || trim(arguments.paymentMode) == "Cash";
    }

    // Returns {openingAmount, cashIn, totalExpenses, cashExpenses, otherExpenses, balance}
    // cashIn is the net of cash-in-hand transfers: + funded from cash, - moved to cash on close.
    // balance = opening + cashIn - cashExpenses; card/UPI/bank/other spending doesn't reduce it.
    function getAccountBalance(required string accountId) {
        var account = getAccount(arguments.accountId);
        var cashIn  = 0;
        for (var t in _getTransfers(arguments.accountId)) {
            cashIn += t.direction == "FromCash" ? val(t.amount) : -val(t.amount);
        }
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
        var cashExpenses  = 0;
        var otherExpenses = 0;
        if (expResult.success) {
            for (var e in expResult.data) {
                if (e.status == "Deleted") continue;
                if (isCashPayment(e.paymentMode ?: "")) cashExpenses += val(e.amount);
                else otherExpenses += val(e.amount);
            }
        }
        // A closed account's leftover was already moved to cash in hand when it was closed
        // (under whatever rule applied then), so it always shows zero
        var balance = account.status == "Closed" ? 0 : val(account.openingAmount) + cashIn - cashExpenses;
        return {
            openingAmount  : val(account.openingAmount),
            cashIn         : cashIn,
            totalExpenses  : cashExpenses + otherExpenses,
            cashExpenses   : cashExpenses,
            otherExpenses  : otherExpenses,
            balance        : balance
        };
    }

    // ── Cash in hand ─────────────────────────────────────────────────────
    // Cash in hand is not an account: it is the running total of cashTransfers.
    // Closing an account moves its balance ToCash; funding an account moves money FromCash.

    // Returns {currencyCode: amount} for every currency that has transfers
    function getCashInHand() {
        var byCur = {};
        for (var t in _getTransfers()) {
            var cur = len(t.currency ?: "") ? t.currency : application.defaultCurrency;
            byCur[cur] = (byCur[cur] ?: 0) + (t.direction == "ToCash" ? val(t.amount) : -val(t.amount));
        }
        for (var c in byCur) byCur[c] = round(byCur[c] * 100) / 100;
        return byCur;
    }

    // Moves the remaining balance (even if negative) to cash in hand and marks the account Closed
    function closeAccount(required string accountId) {
        var account = getAccount(arguments.accountId);
        if (account.status != "Active") throw(type="ValidationError", message="Only active accounts can be closed");
        var remaining = round(getAccountBalance(arguments.accountId).balance * 100) / 100;
        if (remaining != 0) {
            _createTransfer(arguments.accountId, account.currency, "ToCash", remaining, "Remaining balance on closing " & account.accountName);
        }
        var result = variables.fb.updateDocument("accounts", arguments.accountId, {
            "status"    : "Closed",
            "closedAt"  : variables.fb._now(),
            "updatedAt" : variables.fb._now()
        }, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message=result.error ?: "Failed to close account");
        return remaining;
    }

    // Moves money from cash in hand (same currency) into an active account
    function fundFromCash(required string accountId, required numeric amount) {
        var account = getAccount(arguments.accountId);
        if (account.status != "Active") throw(type="ValidationError", message="Only active accounts can be funded");
        if (arguments.amount <= 0) throw(type="ValidationError", message="Amount must be greater than zero");
        var available = getCashInHand()[account.currency] ?: 0;
        if (arguments.amount > available) {
            throw(type="ValidationError", message="Only " & application.currencySymbol(account.currency) & numberFormat(available, "9,999.00") & " is available in cash in hand");
        }
        _createTransfer(arguments.accountId, account.currency, "FromCash", arguments.amount, "Funded from cash in hand");
    }

    function hasCashTransfers(required string accountId) {
        return arrayLen(_getTransfers(arguments.accountId)) > 0;
    }

    private function _createTransfer(required string accountId, required string currency, required string direction, required numeric amount, string notes = "") {
        var id  = variables.fb.generateId();
        var now = variables.fb._now();
        var doc = {
            "transferId" : id,
            "userId"     : variables.userId,
            "accountId"  : arguments.accountId,
            "currency"   : arguments.currency,
            "direction"  : arguments.direction,
            "amount"     : arguments.amount,
            "date"       : dateFormat(now(), "yyyy-mm-dd"),
            "notes"      : arguments.notes,
            "status"     : "Active",
            "createdAt"  : now,
            "updatedAt"  : now
        };
        var result = variables.fb.setDocument("cashTransfers", id, doc, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message=result.error ?: "Failed to record cash transfer");
    }

    private function _getTransfers(string accountId = "") {
        var filters = [
            variables.fb.fieldFilter("userId", "EQUAL", variables.userId)
        ];
        if (len(arguments.accountId)) {
            arrayAppend(filters, variables.fb.fieldFilter("accountId", "EQUAL", arguments.accountId));
        }
        var result = variables.fb.queryCollection(
            collection = "cashTransfers",
            filters    = filters,
            idToken    = variables.idToken
        );
        if (!result.success) return [];
        return arrayFilter(result.data, function(t) { return t.status != "Deleted"; });
    }

}
