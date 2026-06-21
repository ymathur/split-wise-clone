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

    /**
     * data struct fields: accountId, groupId, expenseType, date, description,
     *   category, amount, paidByMemberId, paymentMode, notes, splitType
     * splits: array of {memberId, shareAmount} for custom; or array of memberIds for equal split
     */
    function createExpense(required struct data, array splits = []) {
        var id  = variables.fb.generateId();
        var now = variables.fb._now();
        var amount = val(arguments.data.amount);

        var doc = {
            "expenseId"      : id,
            "userId"         : variables.userId,
            "accountId"      : arguments.data.accountId      ?: "",
            "groupId"        : arguments.data.groupId        ?: "",
            "expenseType"    : arguments.data.expenseType    ?: "Personal",
            "date"           : arguments.data.date           ?: dateFormat(now(), "yyyy-mm-dd"),
            "description"    : arguments.data.description    ?: "",
            "category"       : arguments.data.category       ?: "Miscellaneous",
            "amount"         : amount,
            "paidByMemberId" : arguments.data.paidByMemberId ?: "",
            "paymentMode"    : arguments.data.paymentMode    ?: "Cash",
            "splitType"      : arguments.data.splitType      ?: "Equal",
            "notes"          : arguments.data.notes          ?: "",
            "status"         : "Active",
            "createdAt"      : now,
            "updatedAt"      : now
        };

        var result = variables.fb.setDocument("expenses", id, doc, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message=result.error ?: "Failed to create expense");

        // Save splits
        if (arrayLen(arguments.splits) && doc["expenseType"] == "Group") {
            _saveSplits(id, doc["groupId"], arguments.splits);
        }

        return id;
    }

    function getExpenses(struct filters = {}) {
        var fsFilters = [
            variables.fb.fieldFilter("userId", "EQUAL", variables.userId)
        ];
        if (structKeyExists(arguments.filters, "accountId") && len(arguments.filters.accountId)) {
            arrayAppend(fsFilters, variables.fb.fieldFilter("accountId", "EQUAL", arguments.filters.accountId));
        }
        if (structKeyExists(arguments.filters, "groupId") && len(arguments.filters.groupId)) {
            arrayAppend(fsFilters, variables.fb.fieldFilter("groupId", "EQUAL", arguments.filters.groupId));
        }
        if (structKeyExists(arguments.filters, "expenseType") && len(arguments.filters.expenseType)) {
            arrayAppend(fsFilters, variables.fb.fieldFilter("expenseType", "EQUAL", arguments.filters.expenseType));
        }

        var result = variables.fb.queryCollection(
            collection = "expenses",
            filters    = fsFilters,
            idToken    = variables.idToken
        );
        if (!result.success) return [];
        var expenses = arrayFilter(result.data, function(e) { return e.status != "Deleted"; });
        arraySort(expenses, function(a, b) { return compare(b.date, a.date); });

        // Optional date range filter in CFML
        // NOTE: closures get their OWN arguments scope, so "arguments.filters" inside
        // the callback would refer to the callback's args (value/index/array), not
        // this function's. Capture into locals first so the closures can see them.
        if (structKeyExists(arguments.filters, "dateFrom") && len(arguments.filters.dateFrom)) {
            var dateFrom = arguments.filters.dateFrom;
            expenses = arrayFilter(expenses, function(e) { return e.date >= dateFrom; });
        }
        if (structKeyExists(arguments.filters, "dateTo") && len(arguments.filters.dateTo)) {
            var dateTo = arguments.filters.dateTo;
            expenses = arrayFilter(expenses, function(e) { return e.date <= dateTo; });
        }
        if (structKeyExists(arguments.filters, "category") && len(arguments.filters.category)) {
            var category = arguments.filters.category;
            expenses = arrayFilter(expenses, function(e) { return e.category == category; });
        }
        if (structKeyExists(arguments.filters, "paymentMode") && len(arguments.filters.paymentMode)) {
            var paymentMode = arguments.filters.paymentMode;
            expenses = arrayFilter(expenses, function(e) { return e.paymentMode == paymentMode; });
        }

        return expenses;
    }

    function getExpense(required string expenseId) {
        var result = variables.fb.getDocument("expenses", arguments.expenseId, variables.idToken);
        if (result.success && result.data.userId == variables.userId && result.data.status != "Deleted") {
            return result.data;
        }
        throw(type="NotFoundError", message="Expense not found");
    }

    function getExpenseSplits(required string expenseId) {
        var filters = [variables.fb.fieldFilter("expenseId", "EQUAL", arguments.expenseId)];
        var result  = variables.fb.queryCollection(
            collection = "expenseSplits",
            filters    = filters,
            idToken    = variables.idToken
        );
        if (!result.success) return [];
        return result.data;
    }

    function updateExpense(required string expenseId, required struct data, array splits = []) {
        var existing = getExpense(arguments.expenseId);
        var now = variables.fb._now();
        var updates = {
            "accountId"      : arguments.data.accountId      ?: existing.accountId,
            "groupId"        : arguments.data.groupId        ?: existing.groupId,
            "expenseType"    : arguments.data.expenseType    ?: existing.expenseType,
            "date"           : arguments.data.date           ?: existing.date,
            "description"    : arguments.data.description    ?: existing.description,
            "category"       : arguments.data.category       ?: existing.category,
            "amount"         : val(arguments.data.amount     ?: existing.amount),
            "paidByMemberId" : arguments.data.paidByMemberId ?: existing.paidByMemberId,
            "paymentMode"    : arguments.data.paymentMode    ?: existing.paymentMode,
            "splitType"      : arguments.data.splitType      ?: existing.splitType,
            "notes"          : arguments.data.notes          ?: existing.notes,
            "updatedAt"      : now
        };
        var result = variables.fb.updateDocument("expenses", arguments.expenseId, updates, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message=result.error ?: "Failed to update expense");

        // Re-save splits if provided
        if (arrayLen(arguments.splits) && updates["expenseType"] == "Group") {
            _deleteSplits(arguments.expenseId);
            _saveSplits(arguments.expenseId, updates["groupId"], arguments.splits);
        }
    }

    function deleteExpense(required string expenseId) {
        getExpense(arguments.expenseId);
        var result = variables.fb.softDelete("expenses", arguments.expenseId, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message="Failed to delete expense");
    }

    // Total expenses for a date range
    function getTotalExpenses(struct filters = {}) {
        var expenses = getExpenses(arguments.filters);
        var total = 0;
        for (var e in expenses) { total += val(e.amount); }
        return total;
    }

    // ── Split helpers ─────────────────────────────────────────────────────

    private function _saveSplits(required string expenseId, required string groupId, required array splits) {
        var now = variables.fb._now();
        for (var split in arguments.splits) {
            var splitId = variables.fb.generateId();
            var doc = {
                "splitId"     : splitId,
                "expenseId"   : arguments.expenseId,
                "groupId"     : arguments.groupId,
                "memberId"    : split.memberId,
                "shareAmount" : val(split.shareAmount),
                "createdAt"   : now
            };
            variables.fb.setDocument("expenseSplits", splitId, doc, variables.idToken);
        }
    }

    private function _deleteSplits(required string expenseId) {
        var splits = getExpenseSplits(arguments.expenseId);
        for (var split in splits) {
            variables.fb.softDelete("expenseSplits", split._id, variables.idToken);
        }
    }

    // ── Category / payment lists ──────────────────────────────────────────

    function getCategories() {
        return ["Food","Travel","Hotel","Taxi","Fuel","Shopping","Tickets","Entertainment","Miscellaneous"];
    }

    function getPaymentModes() {
        return ["Cash","UPI","Card","Bank","Other"];
    }

}
