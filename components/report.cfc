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

    function getPersonalReport(struct filters = {}) {
        var expCFC = new components.expense(variables.fb, variables.userId, variables.idToken);
        var accCFC = new components.account(variables.fb, variables.userId, variables.idToken);
        var expenses = expCFC.getExpenses({
            expenseType : "Personal",
            accountId   : filters.accountId   ?: "",
            dateFrom    : filters.dateFrom     ?: "",
            dateTo      : filters.dateTo       ?: "",
            category    : filters.category     ?: "",
            paymentMode : filters.paymentMode  ?: ""
        });

        // accountId -> currency, used to split totals by currency since accounts can differ
        var acctCurrency = {};
        for (var acct in accCFC.getAccounts("All")) acctCurrency[acct._id] = acct.currency;

        var total        = 0;
        var categoryTotals = {};
        var totalByCur      = {};
        for (var e in expenses) {
            total += val(e.amount);
            var cat = e.category ?: "Miscellaneous";
            if (!structKeyExists(categoryTotals, cat)) categoryTotals[cat] = 0;
            categoryTotals[cat] += val(e.amount);

            var cur = acctCurrency[e.accountId] ?: application.defaultCurrency;
            if (!structKeyExists(totalByCur, cur)) totalByCur[cur] = 0;
            totalByCur[cur] += val(e.amount);
        }

        var openingAmount = 0;
        var currency       = "";
        if (structKeyExists(filters, "accountId") && len(filters.accountId)) {
            try {
                var acc = accCFC.getAccount(filters.accountId);
                openingAmount = val(acc.openingAmount);
                currency      = acc.currency;
            } catch (any e) {}
        }

        return {
            expenses       : expenses,
            totalExpenses  : total,
            totalByCur     : totalByCur,
            openingAmount  : openingAmount,
            balance        : openingAmount - total,
            categoryTotals : categoryTotals,
            currency       : currency,
            acctCurrency   : acctCurrency
        };
    }

    function getGroupReport(required string groupId, struct filters = {}) {
        var expCFC  = new components.expense(variables.fb, variables.userId, variables.idToken);
        var grpCFC  = new components.group(variables.fb, variables.userId, variables.idToken);
        var stlCFC  = new components.settlement(variables.fb, variables.userId, variables.idToken);

        var grp       = grpCFC.getGroup(arguments.groupId);
        var members   = grpCFC.getMembers(arguments.groupId);
        var expenses  = expCFC.getExpenses({groupId: arguments.groupId});
        var stls      = stlCFC.getSettlements(arguments.groupId);

        // Collect all splits for group expenses
        var allSplits = [];
        for (var e in expenses) {
            var splits = expCFC.getExpenseSplits(e._id);
            for (var s in splits) { arrayAppend(allSplits, s); }
        }

        // Member lookup
        var memberMap = {};
        for (var m in members) { memberMap[m.memberId] = m.name; }

        // Apply filters
        // NOTE: .filter() member syntax on arrays is buggy in Lucee 5.4 - use arrayFilter().
        // Also capture into locals before the closures: closures get their OWN arguments
        // scope, so a bare reference to a function parameter inside one is unreliable.
        if (structKeyExists(filters, "dateFrom") && len(filters.dateFrom)) {
            var dateFrom = filters.dateFrom;
            expenses = arrayFilter(expenses, function(e) { return e.date >= dateFrom; });
        }
        if (structKeyExists(filters, "dateTo") && len(filters.dateTo)) {
            var dateTo = filters.dateTo;
            expenses = arrayFilter(expenses, function(e) { return e.date <= dateTo; });
        }

        var totalSpend  = 0;
        var memberPaid  = {};
        var memberShare = {};
        for (var m in members) {
            memberPaid[m.memberId]  = 0;
            memberShare[m.memberId] = 0;
        }

        for (var e in expenses) {
            totalSpend += val(e.amount);
            if (len(e.paidByMemberId) && structKeyExists(memberPaid, e.paidByMemberId)) {
                memberPaid[e.paidByMemberId] += val(e.amount);
            }
        }
        for (var s in allSplits) {
            if (structKeyExists(memberShare, s.memberId)) {
                memberShare[s.memberId] += val(s.shareAmount);
            }
        }

        var balances = stlCFC.calculateBalances(arguments.groupId, members, expenses, allSplits, stls);

        return {
            group       : grp,
            members     : members,
            memberMap   : memberMap,
            expenses    : expenses,
            settlements : stls,
            totalSpend  : totalSpend,
            memberPaid  : memberPaid,
            memberShare : memberShare,
            balances    : balances
        };
    }

}
