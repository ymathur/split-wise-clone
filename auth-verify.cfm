<cfheader name="Content-Type" value="application/json">

<cfscript>
// Build lowercase-key JSON; serializeJSON() uppercases CFML struct keys
function jsonResp(boolean success, string message, string redirect = "") {
    var redir = len(arguments.redirect)
              ? ',"redirect":"' & jsStringFormat(arguments.redirect) & '"'
              : "";
    return '{"success":' & (arguments.success ? "true" : "false")
         & ',"message":"' & jsStringFormat(arguments.message) & '"'
         & redir & "}";
}
</cfscript>

<cftry>
    <cfif uCase(cgi.request_method) neq "POST">
        <cfoutput>#jsonResp(false, "Method not allowed")#</cfoutput>
        <cfabort>
    </cfif>

    <cfset rawBody = toString(getHttpRequestData().content)>
    <cfif !isJSON(rawBody)>
        <cfoutput>#jsonResp(false, "Invalid JSON")#</cfoutput>
        <cfabort>
    </cfif>

    <cfset body    = deserializeJSON(rawBody)>
    <cfset idToken = body.idToken ?: "">
    <cfset action  = body.action  ?: "login">

    <cfif !len(idToken)>
        <cfoutput>#jsonResp(false, "Token required")#</cfoutput>
        <cfabort>
    </cfif>

    <cfset fb           = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
    <cfset verification = fb.verifyIdToken(idToken)>

    <cfif !verification.success>
        <cfoutput>#jsonResp(false, "Invalid or expired token")#</cfoutput>
        <cfabort>
    </cfif>

    <cfset firebaseUser = verification.user>
    <cfset userId       = firebaseUser.localId>
    <cfset userEmail    = firebaseUser.email>
    <cfset userName     = body.name ?: (firebaseUser.displayName ?: listFirst(userEmail, "@"))>

    <cfif action eq "register">
        <cfset now = fb._now()>
        <cfset profileResult = fb.setDocument("users", userId, {
            "userId"    : userId,
            "name"      : userName,
            "email"     : userEmail,
            "createdAt" : now,
            "updatedAt" : now
        }, idToken)>
        <cfif !profileResult.success>
            <cfoutput>#jsonResp(false, "Failed to create user profile: " & (profileResult.error ?: "Unknown error"))#</cfoutput>
            <cfabort>
        </cfif>
    </cfif>

    <cfset session.isLoggedIn = true>
    <cfset session.userId     = userId>
    <cfset session.userName   = userName>
    <cfset session.userEmail  = userEmail>
    <cfset session.idToken    = idToken>

    <cfoutput>#jsonResp(true, "Authentication successful", "/pages/dashboard.cfm")#</cfoutput>

    <cfcatch type="any">
        <cfoutput>#jsonResp(false, "Server error: " & cfcatch.message)#</cfoutput>
    </cfcatch>
</cftry>
