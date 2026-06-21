<cfif cgi.request_method eq "POST">
    <cfif !structKeyExists(form, "csrfToken") || !structKeyExists(session, "csrfToken") || form.csrfToken neq session.csrfToken>
        <cflocation url="/pages/dashboard.cfm?error=invalid_request" addtoken="false">
    </cfif>
</cfif>
