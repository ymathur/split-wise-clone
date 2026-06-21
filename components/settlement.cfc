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

    function createSettlement(required struct data) {
        var id  = variables.fb.generateId();
        var now = variables.fb._now();
        var doc = {
            "settlementId" : id,
            "userId"       : variables.userId,
            "groupId"      : arguments.data.groupId,
            "fromMemberId" : arguments.data.fromMemberId,
            "toMemberId"   : arguments.data.toMemberId,
            "amount"       : val(arguments.data.amount),
            "date"         : arguments.data.date        ?: dateFormat(now(), "yyyy-mm-dd"),
            "paymentMode"  : arguments.data.paymentMode ?: "Cash",
            "notes"        : arguments.data.notes       ?: "",
            "status"       : "Paid",
            "createdAt"    : now,
            "updatedAt"    : now
        };
        var result = variables.fb.setDocument("settlements", id, doc, variables.idToken);
        if (result.success) return id;
        throw(type="FirestoreError", message=result.error ?: "Failed to create settlement");
    }

    function getSettlements(string groupId = "", string status = "") {
        var filters = [variables.fb.fieldFilter("userId", "EQUAL", variables.userId)];
        if (len(arguments.groupId)) {
            arrayAppend(filters, variables.fb.fieldFilter("groupId", "EQUAL", arguments.groupId));
        }
        var result = variables.fb.queryCollection(
            collection = "settlements",
            filters    = filters,
            idToken    = variables.idToken
        );
        if (!result.success) return [];
        var list = arrayFilter(result.data, function(s) { return s.status != "Deleted"; });
        if (len(arguments.status)) {
            var statusArg = arguments.status;
            list = arrayFilter(list, function(s) { return s.status == statusArg; });
        }
        arraySort(list, function(a, b) { return compare(b.date, a.date); });
        return list;
    }

    function getSettlement(required string settlementId) {
        var result = variables.fb.getDocument("settlements", arguments.settlementId, variables.idToken);
        if (result.success && result.data.userId == variables.userId) return result.data;
        throw(type="NotFoundError", message="Settlement not found");
    }

    function markAsPaid(required string settlementId) {
        getSettlement(arguments.settlementId);
        var result = variables.fb.updateDocument("settlements", arguments.settlementId, {
            "status"    : "Paid",
            "updatedAt" : variables.fb._now()
        }, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message="Failed to update settlement");
    }

    function deleteSettlement(required string settlementId) {
        getSettlement(arguments.settlementId);
        variables.fb.softDelete("settlements", arguments.settlementId, variables.idToken);
    }

    /**
     * Calculate net balances for all members in a group.
     * Returns array of {memberId, name, totalPaid, totalShare, settlementsOut, settlementsIn, netBalance}
     * Positive netBalance = member is owed money; negative = member owes money.
     */
    function calculateBalances(required string groupId, required array members, required array expenses, required array splits, required array settlements) {
        // Build member lookup
        var memberMap = {};
        for (var m in arguments.members) {
            memberMap[m.memberId] = {
                memberId        : m.memberId,
                name            : m.name,
                totalPaid       : 0,
                totalShare      : 0,
                settlementsOut  : 0,  // paid OUT to others
                settlementsIn   : 0,  // received from others
                netBalance      : 0
            };
        }

        // Sum what each member paid
        for (var e in arguments.expenses) {
            if (e.status == "Deleted") continue;
            var payer = e.paidByMemberId;
            if (structKeyExists(memberMap, payer)) {
                memberMap[payer].totalPaid += val(e.amount);
            }
        }

        // Sum each member's share
        for (var s in arguments.splits) {
            if (structKeyExists(memberMap, s.memberId)) {
                memberMap[s.memberId].totalShare += val(s.shareAmount);
            }
        }

        // Sum settlements
        for (var st in arguments.settlements) {
            if (st.status == "Deleted") continue;
            if (structKeyExists(memberMap, st.fromMemberId)) {
                memberMap[st.fromMemberId].settlementsOut += val(st.amount);
            }
            if (structKeyExists(memberMap, st.toMemberId)) {
                memberMap[st.toMemberId].settlementsIn += val(st.amount);
            }
        }

        // Calculate net: positive = should receive, negative = should pay
        var result = [];
        for (var mid in memberMap) {
            var m = memberMap[mid];
            m.netBalance = m.totalPaid - m.totalShare + m.settlementsOut - m.settlementsIn;
            arrayAppend(result, m);
        }

        // Sort: receivers first (positive balance)
        arraySort(result, function(a, b) { return b.netBalance - a.netBalance; });
        return result;
    }

    /**
     * Suggest minimum settlement transactions from balances array.
     * Returns array of {fromMemberId, fromName, toMemberId, toName, amount}
     */
    function suggestSettlements(required array balances) {
        var debtors   = []; // netBalance < 0 → must pay
        var creditors = []; // netBalance > 0 → should receive

        for (var b in arguments.balances) {
            var nb = val(b.netBalance);
            if (nb < -0.01)      arrayAppend(debtors,   {memberId: b.memberId, name: b.name, amount: abs(nb)});
            else if (nb > 0.01)  arrayAppend(creditors, {memberId: b.memberId, name: b.name, amount: nb});
        }

        var suggestions = [];
        var di = 1; var ci = 1;
        while (di <= arrayLen(debtors) && ci <= arrayLen(creditors)) {
            var d = debtors[di];
            var c = creditors[ci];
            var pay = min(d.amount, c.amount);
            if (pay > 0.01) {
                arrayAppend(suggestions, {
                    fromMemberId : d.memberId,
                    fromName     : d.name,
                    toMemberId   : c.memberId,
                    toName       : c.name,
                    amount       : numberFormat(pay, "9999.99")
                });
            }
            d.amount -= pay;
            c.amount -= pay;
            if (d.amount < 0.01) di++;
            if (c.amount < 0.01) ci++;
        }
        return suggestions;
    }

}
