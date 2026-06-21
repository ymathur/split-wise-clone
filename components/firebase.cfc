component {

    variables.projectId = "";
    variables.apiKey    = "";
    variables.firestoreBase = "";
    variables.authBase      = "https://identitytoolkit.googleapis.com/v1";

    function init(required string projectId, required string apiKey) {
        variables.projectId     = arguments.projectId;
        variables.apiKey        = arguments.apiKey;
        variables.firestoreBase = "https://firestore.googleapis.com/v1/projects/" & arguments.projectId & "/databases/(default)/documents";
        return this;
    }

    // ── Auth ─────────────────────────────────────────────────────────────

    function verifyIdToken(required string idToken) {
        var result  = {"success": false, "user": {}};
        var reqUrl  = variables.authBase & "/accounts:lookup?key=" & variables.apiKey;
        var reqBody = serializeJSON({"idToken": arguments.idToken});

        var res = _post(reqUrl, reqBody);

        if (res.statusCode contains "200") {
            var parsed = deserializeJSON(res.fileContent);
            if (arrayLen(parsed.users)) {
                result["success"] = true;
                result["user"]    = parsed.users[1];
            }
        } else {
            result["error"] = _parseError(res.fileContent);
        }
        return result;
    }

    // ── Firestore CRUD ───────────────────────────────────────────────────

    function getDocument(required string collection, required string docId, required string idToken) {
        var result = {"success": false, "data": {}};
        var reqUrl = variables.firestoreBase & "/" & arguments.collection & "/" & arguments.docId;

        var res = _get(reqUrl, arguments.idToken);

        if (res.statusCode contains "200") {
            var doc = deserializeJSON(res.fileContent);
            result["success"]       = true;
            result["data"]          = firestoreToStruct(doc);
            result["data"]["_id"]   = listLast(doc.name, "/");
        } else {
            result["error"] = _parseError(res.fileContent);
        }
        return result;
    }

    // Uses commit (POST) to avoid PATCH, which Java 11 HttpURLConnection restricts.
    // NOTE: :batchWrite is NOT enforced by Firestore Security Rules the same way as
    // normal writes - it always returns 403 for end-user (Firebase Auth) tokens
    // regardless of rules content. :commit is the endpoint the official SDKs use
    // and is correctly rules-enforced, so it must be used instead.
    function setDocument(required string collection, required string docId, required struct data, required string idToken) {
        var result  = {"success": false};
        var docName = "projects/" & variables.projectId & "/databases/(default)/documents/" & arguments.collection & "/" & arguments.docId;
        var reqUrl  = variables.firestoreBase & ":commit";

        var writeOp = {
            "update": {
                "name"  : docName,
                "fields": structToFirestore(arguments.data)
            }
        };
        var payload = serializeJSON({"writes": [writeOp]});

        var res = _post(reqUrl, payload, arguments.idToken);

        if (res.statusCode contains "200") {
            result["success"]     = true;
            result["data"]        = duplicate(arguments.data);
            result["data"]["_id"] = arguments.docId;
        } else {
            result["error"] = _parseError(res.fileContent);
        }
        return result;
    }

    // Uses commit (POST) with updateMask for partial updates. See note on setDocument
    // re: why :commit is used instead of :batchWrite.
    function updateDocument(required string collection, required string docId, required struct data, required string idToken) {
        var result  = {"success": false};
        var docName = "projects/" & variables.projectId & "/databases/(default)/documents/" & arguments.collection & "/" & arguments.docId;
        var reqUrl  = variables.firestoreBase & ":commit";
        var fields  = structToFirestore(arguments.data);

        var fieldPaths = [];
        for (var key in arguments.data) {
            arrayAppend(fieldPaths, key);
        }

        var writeOp = {
            "update": {
                "name"  : docName,
                "fields": fields
            },
            "updateMask": {
                "fieldPaths": fieldPaths
            }
        };

        var payload = serializeJSON({"writes": [writeOp]});
        var res     = _post(reqUrl, payload, arguments.idToken);

        if (res.statusCode contains "200") {
            result["success"] = true;
        } else {
            result["error"] = _parseError(res.fileContent);
        }
        return result;
    }

    function softDelete(required string collection, required string docId, required string idToken) {
        return updateDocument(arguments.collection, arguments.docId, {
            "status"    : "Deleted",
            "updatedAt" : _now()
        }, arguments.idToken);
    }

    // ── Querying ─────────────────────────────────────────────────────────

    function queryCollection(
        required string collection,
        array   filters = [],
        array   orderBy = [],
        numeric limit   = 200,
        required string idToken
    ) {
        var result = {"success": false, "data": []};
        var reqUrl = variables.firestoreBase & ":runQuery";

        var query = {
            "structuredQuery": {
                "from"  : [{"collectionId": arguments.collection}],
                "limit" : arguments.limit
            }
        };

        if (arrayLen(arguments.filters) == 1) {
            query["structuredQuery"]["where"] = arguments.filters[1];
        } else if (arrayLen(arguments.filters) > 1) {
            query["structuredQuery"]["where"] = {
                "compositeFilter": {"op": "AND", "filters": arguments.filters}
            };
        }

        if (arrayLen(arguments.orderBy)) {
            query["structuredQuery"]["orderBy"] = arguments.orderBy;
        }

        var payload = serializeJSON(query);
        var res     = _post(reqUrl, payload, arguments.idToken);

        if (res.statusCode contains "200") {
            var rows = deserializeJSON(res.fileContent);
            result["success"] = true;
            for (var row in rows) {
                if (structKeyExists(row, "document")) {
                    var d = firestoreToStruct(row.document);
                    d["_id"] = listLast(row.document.name, "/");
                    arrayAppend(result["data"], d);
                }
            }
        } else {
            result["error"] = _parseError(res.fileContent);
        }
        return result;
    }

    function fieldFilter(required string field, required string op, required any value) {
        return {
            "fieldFilter": {
                "field": {"fieldPath": arguments.field},
                "op"   : arguments.op,
                "value": _typedValue(arguments.value)
            }
        };
    }

    function orderBy(required string field, string direction = "ASCENDING") {
        return {"field": {"fieldPath": arguments.field}, "direction": arguments.direction};
    }

    // ── Type helpers ─────────────────────────────────────────────────────

    // Uses a Java LinkedHashMap so keys survive serializeJSON with their original case.
    // Lucee's CFML struct is case-insensitive and serializeJSON may uppercase keys,
    // but Java Map keys are case-sensitive and serialized exactly as stored.
    // Callers MUST use quoted string keys in struct literals (e.g. {"userId": v})
    // so Lucee stores the camelCase name rather than the uppercase identifier form.
    function structToFirestore(required struct data) {
        var fields = createObject("java", "java.util.LinkedHashMap").init();
        for (var key in arguments.data) {
            var v = arguments.data[key];
            if (isNull(v)) {
                fields.put(key, {"nullValue": javacast("null", "")});
            } else if (isArray(v)) {
                var arrVals = [];
                for (var item in v) { arrayAppend(arrVals, _typedValue(item)); }
                fields.put(key, {"arrayValue": {"values": arrVals}});
            } else if (isStruct(v)) {
                fields.put(key, {"mapValue": {"fields": structToFirestore(v)}});
            } else {
                fields.put(key, _typedValue(v));
            }
        }
        return fields;
    }

    function firestoreToStruct(required struct doc) {
        var result = {};
        if (!structKeyExists(arguments.doc, "fields")) return result;
        for (var key in arguments.doc.fields) {
            result[key] = _extractValue(arguments.doc.fields[key]);
        }
        return result;
    }

    function generateId() {
        return lCase(replace(createUUID(), "-", "", "all"));
    }

    function _now() {
        return dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss") & "Z";
    }

    // ── Private HTTP helpers ──────────────────────────────────────────────
    // Uses java.net.URL.openConnection() to avoid Lucee cfhttp URL-encoding
    // colons in path segments (e.g. accounts:lookup, documents:runQuery).

    private function _get(required string reqUrl, string token = "") {
        return _javaRequest(arguments.reqUrl, "GET", "", arguments.token);
    }

    private function _post(required string reqUrl, required string body, string token = "") {
        return _javaRequest(arguments.reqUrl, "POST", arguments.body, arguments.token);
    }

    // All HTTP calls go through java.net.URL to preserve colons and parens in URL paths.
    private function _javaRequest(
        required string reqUrl,
        required string method,
        string body  = "",
        string token = ""
    ) {
        try {
            var jUrl = createObject("java", "java.net.URL").init(arguments.reqUrl);
            var conn = jUrl.openConnection();
            conn.setConnectTimeout(30000);
            conn.setReadTimeout(30000);
            conn.setDoInput(true);
            conn.setRequestProperty("Content-Type", "application/json");
            if (len(trim(arguments.token))) {
                conn.setRequestProperty("Authorization", "Bearer " & arguments.token);
            }

            conn.setRequestMethod(uCase(arguments.method));

            if (len(arguments.body)) {
                conn.setDoOutput(true);
                var bytes = arguments.body.getBytes("UTF-8");
                var oStream = conn.getOutputStream();
                oStream.write(bytes);
                oStream.close();
            }

            var sc = conn.getResponseCode();
            var iStream = (sc >= 200 && sc < 300) ? conn.getInputStream() : conn.getErrorStream();
            var responseText = "";
            if (!isNull(iStream)) {
                var scanner = createObject("java", "java.util.Scanner")
                    .init(iStream, "UTF-8")
                    .useDelimiter("\A");
                responseText = scanner.hasNext() ? scanner.next() : "";
                scanner.close();
            }
            conn.disconnect();
            return {statusCode: "#sc#", fileContent: responseText};
        } catch (any e) {
            return {statusCode: "500", fileContent: '{"error":{"message":"' & replace(e.message, '"', "'", "all") & '"}}'};
        }
    }

    private function _typedValue(required any v) {
        if (isNull(v))         return {"nullValue": javacast("null", "")};
        if (!isSimpleValue(v)) return {"stringValue": ""};
        var sv = "#v#";
        if (!len(trim(sv)))    return {"stringValue": ""};
        if (isNumeric(v)) {
            var n = val(v);
            if (n == int(n))   return {"integerValue": "#int(n)#"};
            else               return {"doubleValue": n};
        }
        if (sv == "true"  || sv == "YES") return {"booleanValue": true};
        if (sv == "false" || sv == "NO")  return {"booleanValue": false};
        return {"stringValue": sv};
    }

    private function _extractValue(required struct field) {
        if (structKeyExists(field, "stringValue"))    return field.stringValue;
        if (structKeyExists(field, "integerValue"))   return val(field.integerValue);
        if (structKeyExists(field, "doubleValue"))    return field.doubleValue;
        if (structKeyExists(field, "booleanValue"))   return field.booleanValue;
        if (structKeyExists(field, "timestampValue")) return field.timestampValue;
        if (structKeyExists(field, "nullValue"))      return "";
        if (structKeyExists(field, "arrayValue")) {
            var arr = [];
            if (structKeyExists(field.arrayValue, "values")) {
                for (var item in field.arrayValue.values) { arrayAppend(arr, _extractValue(item)); }
            }
            return arr;
        }
        if (structKeyExists(field, "mapValue")) return firestoreToStruct(field.mapValue);
        return "";
    }

    private function _parseError(required string body) {
        try {
            var parsed = deserializeJSON(body);
            if (structKeyExists(parsed, "error")) return parsed.error.message;
        } catch (any e) {}
        return body;
    }

}
