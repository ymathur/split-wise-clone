<cfinclude template="/includes/authCheck.cfm">

<cfset groupId = url.groupId ?: "">
<cfif !len(groupId)><cflocation url="/pages/groups.cfm" addtoken="false"></cfif>

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>
<cfset formErrors = []>

<cftry>
    <cfset grp     = grpCFC.getGroup(groupId)>
    <cfset members = grpCFC.getMembers(groupId)>
    <cfcatch type="any">
        <cflocation url="/pages/groups.cfm" addtoken="false">
    </cfcatch>
</cftry>

<!--- Handle add member --->
<cfif cgi.request_method eq "POST" && (form.action ?: "") eq "add">
    <cfset mName   = trim(form.memberName   ?: "")>
    <cfset mEmail  = trim(form.memberEmail  ?: "")>
    <cfset mMobile = trim(form.memberMobile ?: "")>
    <cfif !len(mName)>
        <cfset arrayAppend(formErrors, "Member name is required")>
    <cfelse>
        <cftry>
            <cfset grpCFC.addMember(groupId, {name: mName, email: mEmail, mobile: mMobile})>
            <cflocation url="/pages/group-members.cfm?groupId=#urlEncodedFormat(groupId)#&added=1" addtoken="false">
            <cfcatch type="any">
                <cfset arrayAppend(formErrors, cfcatch.message)>
            </cfcatch>
        </cftry>
    </cfif>
</cfif>

<!--- Handle remove member --->
<cfif isDefined("url.remove") && len(url.remove)>
    <cftry>
        <cfset grpCFC.removeMember(url.remove)>
        <cflocation url="/pages/group-members.cfm?groupId=#urlEncodedFormat(groupId)#&removed=1" addtoken="false">
        <cfcatch type="any">
            <cfset removeError = cfcatch.message>
        </cfcatch>
    </cftry>
    <!--- Reload members after remove --->
    <cfset members = grpCFC.getMembers(groupId)>
</cfif>

<cfset pageTitle = grp.groupName & " - Members">
<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <div>
        <h1>Members</h1>
        <p class="text-muted">#htmlEditFormat(grp.groupName)#</p>
    </div>
    <a href="/pages/group-detail.cfm?id=#urlEncodedFormat(groupId)#" class="btn btn-outline">Back to Group</a>
</div>

<cfif isDefined("url.added")   && url.added>  <div class="alert alert-success">Member added.</div>  </cfif>
<cfif isDefined("url.removed") && url.removed><div class="alert alert-success">Member removed.</div></cfif>
<cfif isDefined("removeError")><div class="alert alert-danger">#htmlEditFormat(removeError)#</div></cfif>

<div class="two-col">
    <!--- Member list --->
    <div class="card">
        <div class="card-header"><h2>Current Members (#arrayLen(members)#)</h2></div>
        <cfif arrayLen(members)>
        <table class="table">
            <thead>
                <tr><th>Name</th><th>Email</th><th>Mobile</th><th></th></tr>
            </thead>
            <tbody>
            <cfloop array="#members#" index="m">
                <tr>
                    <td><strong>#htmlEditFormat(m.name)#</strong></td>
                    <td>#len(m.email) ? htmlEditFormat(m.email) : "—"#</td>
                    <td>#len(m.mobile) ? htmlEditFormat(m.mobile) : "—"#</td>
                    <td>
                        <a href="?groupId=#urlEncodedFormat(groupId)#&remove=#urlEncodedFormat(m.memberId)#"
                           class="btn btn-xs btn-danger"
                           onclick="return confirm('Remove #htmlEditFormat(jsStringFormat(m.name))#?')">Remove</a>
                    </td>
                </tr>
            </cfloop>
            </tbody>
        </table>
        <cfelse>
        <p class="empty-state">No members yet. Add members using the form.</p>
        </cfif>
    </div>

    <!--- Add member form --->
    <div class="card">
        <div class="card-header"><h2>Add Member</h2></div>

        <cfif arrayLen(formErrors)>
        <div class="alert alert-danger">
            <ul class="mb-0"><cfloop array="#formErrors#" index="err"><li>#htmlEditFormat(err)#</li></cfloop></ul>
        </div>
        </cfif>

        <form method="post">
            <input type="hidden" name="action" value="add">
            <div class="form-group">
                <label class="form-label" for="memberName">Name <span class="required">*</span></label>
                <input type="text" id="memberName" name="memberName" class="form-control"
                       placeholder="Member name" required>
            </div>
            <div class="form-group">
                <label class="form-label" for="memberEmail">Email</label>
                <input type="email" id="memberEmail" name="memberEmail" class="form-control"
                       placeholder="Optional">
            </div>
            <div class="form-group">
                <label class="form-label" for="memberMobile">Mobile</label>
                <input type="tel" id="memberMobile" name="memberMobile" class="form-control"
                       placeholder="Optional">
            </div>
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Member</button>
            </div>
        </form>
    </div>
</div>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
