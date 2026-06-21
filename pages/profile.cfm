<cfinclude template="/includes/authCheck.cfm">
<cfset pageTitle = "Profile">
<cfset formErrors = []>
<cfset saveSuccess = false>

<cfset fb = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>

<cfif cgi.request_method eq "POST">
    <cfset newName = trim(form.name ?: "")>
    <cfif !len(newName)>
        <cfset arrayAppend(formErrors, "Name is required")>
    <cfelse>
        <cftry>
            <cfset fb.updateDocument("users", session.userId, {
                name      : newName,
                updatedAt : fb._now()
            }, session.idToken)>
            <cfset session.userName = newName>
            <cfset saveSuccess = true>
            <cfcatch type="any">
                <cfset arrayAppend(formErrors, "Failed to update profile: " & cfcatch.message)>
            </cfcatch>
        </cftry>
    </cfif>
</cfif>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Profile</h1>
</div>

<cfif saveSuccess><div class="alert alert-success">Profile updated successfully.</div></cfif>

<cfif arrayLen(formErrors)>
<div class="alert alert-danger">
    <ul class="mb-0"><cfloop array="#formErrors#" index="err"><li>#htmlEditFormat(err)#</li></cfloop></ul>
</div>
</cfif>

<div class="card form-card">
    <form method="post">
        <div class="form-group">
            <label class="form-label" for="name">Display Name <span class="required">*</span></label>
            <input type="text" id="name" name="name" class="form-control"
                   value="#htmlEditFormat(session.userName)#" required>
        </div>
        <div class="form-group">
            <label class="form-label">Email</label>
            <input type="text" class="form-control" value="#htmlEditFormat(session.userEmail)#" disabled>
            <small class="form-hint">Email cannot be changed here.</small>
        </div>
        <div class="form-actions">
            <button type="submit" class="btn btn-primary">Update Profile</button>
        </div>
    </form>
</div>

<div class="card">
    <div class="card-header"><h2>Account Actions</h2></div>
    <div class="profile-actions">
        <a href="/logout.cfm" class="btn btn-danger">Sign Out</a>
    </div>
</div>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
