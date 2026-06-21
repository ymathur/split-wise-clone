<cfif !(session.keyExists("isLoggedIn") && session.isLoggedIn)>
    <cfset redirectUrl = "/login.cfm?msg=Please+log+in+to+continue&next=" & urlEncodedFormat(cgi.script_name)>
    <cflocation url="#redirectUrl#" addtoken="false">
</cfif>
