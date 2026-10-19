<!---
    Keeps session.idToken valid. Firebase ID tokens last 1 hour, so when the current one is
    within 5 minutes of expiry it is swapped for a new one using the stored refresh token.
    Sets tokenValid = false when the token is expired and cannot be renewed.
--->
<cfset tokenValid = true>
<cfset tokenFb    = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfif tokenFb.tokenSecondsLeft(session.idToken ?: "") lt 300>
    <cfset tokenValid = false>
    <cfif len(session.refreshToken ?: "")>
        <cflock scope="session" type="exclusive" timeout="30">
            <!--- Another request may have refreshed it while this one waited for the lock --->
            <cfif tokenFb.tokenSecondsLeft(session.idToken ?: "") gte 300>
                <cfset tokenValid = true>
            <cfelse>
                <cfset refreshed = tokenFb.refreshIdToken(session.refreshToken)>
                <cfif refreshed.success>
                    <cfset session.idToken      = refreshed.idToken>
                    <cfset session.refreshToken = refreshed.refreshToken>
                    <cfset tokenValid = true>
                </cfif>
            </cfif>
        </cflock>
    </cfif>
</cfif>
