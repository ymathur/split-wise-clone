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

    // ── CSV parsing ──────────────────────────────────────────────────────

    // Parses CSV text (with header row) into an array of structs keyed by
    // lowercased header name. Handles quoted fields with embedded commas
    // and escaped quotes ("").
    function parseCsv(required string csvText) {
        var lines = _splitLines(arguments.csvText);
        if (!arrayLen(lines)) return [];

        var headers = _parseCsvLine(lines[1]);
        for (var h = 1; h <= arrayLen(headers); h++) headers[h] = lCase(trim(headers[h]));

        var rows = [];
        for (var i = 2; i <= arrayLen(lines); i++) {
            if (!len(trim(lines[i]))) continue;
            var cells = _parseCsvLine(lines[i]);
            var row = {};
            for (var c = 1; c <= arrayLen(headers); c++) {
                row[headers[c]] = c <= arrayLen(cells) ? trim(cells[c]) : "";
            }
            arrayAppend(rows, row);
        }
        return rows;
    }

    private function _splitLines(required string text) {
        var normalized = replace(replace(arguments.text, chr(13) & chr(10), chr(10), "all"), chr(13), chr(10), "all");
        return listToArray(normalized, chr(10), false, true);
    }

    private function _parseCsvLine(required string line) {
        var result   = [];
        var field    = "";
        var inQuotes = false;
        var n        = len(arguments.line);
        var i        = 1;
        while (i <= n) {
            var ch = mid(arguments.line, i, 1);
            if (inQuotes) {
                if (ch == '"') {
                    if (i < n && mid(arguments.line, i + 1, 1) == '"') {
                        field &= '"';
                        i += 2;
                    } else {
                        inQuotes = false;
                        i += 1;
                    }
                } else {
                    field &= ch;
                    i += 1;
                }
            } else {
                if (ch == '"') {
                    inQuotes = true;
                    i += 1;
                } else if (ch == ",") {
                    arrayAppend(result, field);
                    field = "";
                    i += 1;
                } else {
                    field &= ch;
                    i += 1;
                }
            }
        }
        arrayAppend(result, field);
        return result;
    }

    // ── Row validation ───────────────────────────────────────────────────

    // row keys expected (lowercase): date, amount, description, category, paymentmode, notes
    function validatePersonalRow(required struct row) {
        var errors = [];
        var date   = _normalizeDate(arguments.row.date ?: "");
        var amount = val(arguments.row.amount ?: "");

        if (!len(date))                          arrayAppend(errors, "Invalid or missing date");
        if (!isNumeric(arguments.row.amount ?: "") || amount <= 0) arrayAppend(errors, "Amount must be a positive number");
        if (!len(trim(arguments.row.description ?: ""))) arrayAppend(errors, "Description is required");

        return {
            "valid"  : !arrayLen(errors),
            "errors" : errors,
            "data"   : {
                "date"        : date,
                "amount"      : amount,
                "description" : trim(arguments.row.description ?: ""),
                "category"    : len(trim(arguments.row.category ?: "")) ? trim(arguments.row.category) : "Miscellaneous",
                "paymentMode" : len(trim(arguments.row.paymentmode ?: "")) ? trim(arguments.row.paymentmode) : "Cash",
                "notes"       : trim(arguments.row.notes ?: "")
            }
        };
    }

    // row keys expected (lowercase): date, amount, description, category, paymentmode,
    //   paidbyname, splittype, splitmembers (";"-separated names), customshares
    //   (";"-separated "Name=Amount" pairs), notes
    // memberNameMap: lowercased member name -> memberId
    function validateGroupRow(required struct row, required struct memberNameMap) {
        var errors = [];
        var date   = _normalizeDate(arguments.row.date ?: "");
        var amount = val(arguments.row.amount ?: "");

        if (!len(date))                          arrayAppend(errors, "Invalid or missing date");
        if (!isNumeric(arguments.row.amount ?: "") || amount <= 0) arrayAppend(errors, "Amount must be a positive number");
        if (!len(trim(arguments.row.description ?: ""))) arrayAppend(errors, "Description is required");

        var paidByName = trim(arguments.row.paidbyname ?: "");
        var paidByMemberId = "";
        if (!len(paidByName)) {
            arrayAppend(errors, "Paid By is required");
        } else if (!structKeyExists(arguments.memberNameMap, lCase(paidByName))) {
            arrayAppend(errors, "Unknown member in Paid By: " & paidByName);
        } else {
            paidByMemberId = arguments.memberNameMap[lCase(paidByName)];
        }

        var splitType = len(trim(arguments.row.splittype ?: "")) ? trim(arguments.row.splittype) : "Equal";
        var splits    = [];

        if (splitType == "Custom") {
            var pairs = listToArray(arguments.row.customshares ?: "", ";", false, true);
            if (!arrayLen(pairs)) {
                arrayAppend(errors, "Custom split requires customShares (e.g. 'Alice=200;Bob=300')");
            } else {
                var total = 0;
                for (var pair in pairs) {
                    var name = trim(listFirst(pair, "="));
                    var amt  = val(trim(listRest(pair, "=")));
                    if (!structKeyExists(arguments.memberNameMap, lCase(name))) {
                        arrayAppend(errors, "Unknown member in customShares: " & name);
                    } else if (amt <= 0) {
                        arrayAppend(errors, "Invalid share amount for: " & name);
                    } else {
                        arrayAppend(splits, {"memberId": arguments.memberNameMap[lCase(name)], "shareAmount": amt});
                        total += amt;
                    }
                }
                if (!arrayLen(errors) && abs(total - amount) > 0.01) {
                    arrayAppend(errors, "Custom split total (" & numberFormat(total, "9,999.00") & ") does not equal amount (" & numberFormat(amount, "9,999.00") & ")");
                }
            }
        } else {
            splitType = "Equal";
            var names = listToArray(arguments.row.splitmembers ?: "", ";", false, true);
            if (!arrayLen(names)) {
                arrayAppend(errors, "Equal split requires splitMembers (e.g. 'Alice;Bob')");
            } else {
                var unknown = [];
                for (var name in names) {
                    if (!structKeyExists(arguments.memberNameMap, lCase(trim(name)))) {
                        arrayAppend(unknown, trim(name));
                    }
                }
                if (arrayLen(unknown)) {
                    arrayAppend(errors, "Unknown member(s) in splitMembers: " & arrayToList(unknown, ", "));
                } else {
                    var share = amount / arrayLen(names);
                    for (var name in names) {
                        arrayAppend(splits, {"memberId": arguments.memberNameMap[lCase(trim(name))], "shareAmount": share});
                    }
                }
            }
        }

        return {
            "valid"  : !arrayLen(errors),
            "errors" : errors,
            "data"   : {
                "date"           : date,
                "amount"         : amount,
                "description"    : trim(arguments.row.description ?: ""),
                "category"       : len(trim(arguments.row.category ?: "")) ? trim(arguments.row.category) : "Miscellaneous",
                "paymentMode"    : len(trim(arguments.row.paymentmode ?: "")) ? trim(arguments.row.paymentmode) : "Cash",
                "paidByMemberId" : paidByMemberId,
                "splitType"      : splitType,
                "notes"          : trim(arguments.row.notes ?: "")
            },
            "splits" : splits
        };
    }

    function buildMemberNameMap(required array members) {
        var map = {};
        for (var m in arguments.members) {
            map[lCase(trim(m.name))] = m.memberId;
        }
        return map;
    }

    // Signature used for duplicate detection: date|amount|lowercased description
    function rowSignature(required string date, required numeric amount, required string description) {
        return arguments.date & "|" & numberFormat(arguments.amount, "0.00") & "|" & lCase(trim(arguments.description));
    }

    function buildExistingSignatures(required array expenses) {
        var sigs = {};
        for (var e in arguments.expenses) {
            sigs[rowSignature(e.date, val(e.amount), e.description)] = true;
        }
        return sigs;
    }

    private function _normalizeDate(required string raw) {
        if (!len(trim(arguments.raw))) return "";
        try {
            return dateFormat(arguments.raw, "yyyy-mm-dd");
        } catch (any e) {
            return "";
        }
    }

}
