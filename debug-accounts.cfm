<cfinclude template="/includes/authCheck.cfm">
<cfheader name="Content-Type" value="application/json">
<cfset fb = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>

<cfset result = {}>
<cfset result["userId"] = session.userId>

<!--- Test 1: Write to accounts (requires userId == auth.uid) --->
<cfset testId = "debug-test-" & session.userId>
<cfset writeResult = fb.setDocument("accounts", testId, {
    "userId"      : session.userId,
    "accountName" : "Debug Test"
}, session.idToken)>
<cfset result["accountWriteSuccess"] = writeResult.success>
<cfset result["accountWriteError"]   = writeResult.success ? "" : (writeResult.error ?: "")>

<!--- Test 2: Write to groupMembers (only requires auth, no userId check) --->
<cfset gmId     = "debug-gm-" & session.userId>
<cfset gmResult = fb.setDocument("groupMembers", gmId, {
    "groupId"  : "test-group-123",
    "name"     : "Test Member",
    "status"   : "Active"
}, session.idToken)>
<cfset result["gmWriteSuccess"] = gmResult.success>
<cfset result["gmWriteError"]   = gmResult.success ? "" : (gmResult.error ?: "")>

<!--- Test 3: Write to users/{userId} (requires auth.uid == userId) --->
<cfset userResult = fb.setDocument("users", session.userId, {
    "userId" : session.userId,
    "name"   : "Test User"
}, session.idToken)>
<cfset result["userWriteSuccess"] = userResult.success>
<cfset result["userWriteError"]   = userResult.success ? "" : (userResult.error ?: "")>

<!--- Query accounts --->
<cfset filters = [fb.fieldFilter("userId", "EQUAL", session.userId)]>
<cfset qResult = fb.queryCollection(collection="accounts", filters=filters, idToken=session.idToken)>
<cfset result["querySuccess"] = qResult.success>
<cfset result["queryCount"]   = qResult.success ? arrayLen(qResult.data) : -1>

<cfoutput>#serializeJSON(result)#</cfoutput>
