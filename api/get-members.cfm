<cfheader name="Content-Type" value="application/json">
<cfif !(session.keyExists("isLoggedIn") && session.isLoggedIn)>
    <cfoutput>{"success":false,"data":[]}</cfoutput>
    <cfabort>
</cfif>
<cftry>
    <cfset groupId = url.groupId ?: "">
    <cfif !len(groupId)>
        <cfoutput>{"success":false,"data":[]}</cfoutput>
        <cfabort>
    </cfif>
    <cfset fb      = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
    <cfset grpCFC  = new components.group(fb, session.userId, session.idToken)>
    <cfset members = grpCFC.getMembers(groupId)>
    <cfoutput>{"success":true,"data":#serializeJSON(members)#}</cfoutput>
    <cfcatch type="any">
        <cfoutput>{"success":false,"data":[],"error":"#jsStringFormat(cfcatch.message)#"}</cfoutput>
    </cfcatch>
</cftry>
