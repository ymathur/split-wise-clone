<cfif session.keyExists("isLoggedIn") && session.isLoggedIn>
    <cflocation url="/pages/dashboard.cfm" addtoken="false">
<cfelse>
    <cflocation url="/login.cfm" addtoken="false">
</cfif>
