<cfif !(session.keyExists("isLoggedIn") && session.isLoggedIn)>
    <cfset redirectUrl = "/login.cfm?msg=Please+log+in+to+continue&next=" & urlEncodedFormat(cgi.script_name)>
    <cflocation url="#redirectUrl#" addtoken="false">
</cfif>
<cfinclude template="/includes/tokenRefresh.cfm">
<cfif !tokenValid>
    <cfset sessionInvalidate()>
    <cflocation url="/login.cfm?msg=Your+session+expired.+Please+log+in+again&next=#urlEncodedFormat(cgi.script_name)#" addtoken="false">
</cfif>
