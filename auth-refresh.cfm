<cfheader name="Content-Type" value="application/json">
<cfif !(session.keyExists("isLoggedIn") && session.isLoggedIn)>
    <cfoutput>#serializeJSON({success: false, message: "Not logged in"})#</cfoutput>
    <cfabort>
</cfif>
<cftry>
    <cfset body    = deserializeJSON(toString(getHttpRequestData().content))>
    <cfset idToken = body.idToken ?: "">
    <cfif len(idToken)>
        <cfset session.idToken = idToken>
        <cfoutput>#serializeJSON({success: true})#</cfoutput>
    <cfelse>
        <cfoutput>#serializeJSON({success: false, message: "No token"})#</cfoutput>
    </cfif>
    <cfcatch type="any">
        <cfoutput>#serializeJSON({success: false, message: cfcatch.message})#</cfoutput>
    </cfcatch>
</cftry>
