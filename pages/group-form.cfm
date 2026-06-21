<cfinclude template="/includes/authCheck.cfm">
<cfinclude template="/includes/csrfCheck.cfm">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>

<cfset isEdit     = isDefined("url.id") && len(url.id)>
<cfset pageTitle  = isEdit ? "Edit Group" : "New Group">
<cfset formData   = {groupName: "", currency: application.defaultCurrency, description: "", startDate: dateFormat(now(), "yyyy-mm-dd"), endDate: "", openingAmount: 0, status: "Active"}>
<cfset formErrors = []>

<cfif isEdit>
    <cftry>
        <cfset existing = grpCFC.getGroup(url.id)>
        <cfset formData = {
            groupName     : existing.groupName,
            currency      : len(existing.currency ?: "") ? existing.currency : application.defaultCurrency,
            description   : existing.description,
            startDate     : existing.startDate,
            endDate       : existing.endDate,
            openingAmount : existing.openingAmount,
            status        : existing.status
        }>
        <cfcatch type="any">
            <cflocation url="/pages/groups.cfm" addtoken="false">
        </cfcatch>
    </cftry>
</cfif>

<cfif cgi.request_method eq "POST">
    <cfset formData.groupName     = trim(form.groupName     ?: "")>
    <cfset formData.currency      = trim(form.currency      ?: application.defaultCurrency)>
    <cfset formData.description   = trim(form.description   ?: "")>
    <cfset formData.startDate     = trim(form.startDate     ?: "")>
    <cfset formData.endDate       = trim(form.endDate       ?: "")>
    <cfset formData.openingAmount = trim(form.openingAmount ?: 0)>
    <cfset formData.status        = trim(form.status        ?: "Active")>

    <cfif !len(formData.groupName)> <cfset arrayAppend(formErrors, "Group name is required")> </cfif>
    <cfif !len(formData.startDate)> <cfset arrayAppend(formErrors, "Start date is required")> </cfif>

    <cfif !arrayLen(formErrors)>
        <cftry>
            <cfif isEdit>
                <cfset grpCFC.updateGroup(url.id, formData)>
            <cfelse>
                <cfset newId = grpCFC.createGroup(formData)>
            </cfif>
            <cflocation url="/pages/groups.cfm?saved=1" addtoken="false">
            <cfcatch type="any">
                <cfset arrayAppend(formErrors, cfcatch.message)>
            </cfcatch>
        </cftry>
    </cfif>
</cfif>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>#isEdit ? "Edit Group" : "New Group"#</h1>
    <a href="/pages/groups.cfm" class="btn btn-outline">Cancel</a>
</div>

<cfif arrayLen(formErrors)>
<div class="alert alert-danger">
    <ul class="mb-0"><cfloop array="#formErrors#" index="err"><li>#htmlEditFormat(err)#</li></cfloop></ul>
</div>
</cfif>

<div class="card form-card">
<form method="post">
    <input type="hidden" name="csrfToken" value="#htmlEditFormat(session.csrfToken)#">
    <div class="form-group">
        <label class="form-label" for="groupName">Group Name <span class="required">*</span></label>
        <input type="text" id="groupName" name="groupName" class="form-control"
               value="#htmlEditFormat(formData.groupName)#"
               placeholder="e.g. Goa Trip, Friends Outing" required>
    </div>

    <div class="form-group">
        <label class="form-label" for="description">Description</label>
        <textarea id="description" name="description" class="form-control" rows="2"
                  placeholder="Optional description">#htmlEditFormat(formData.description)#</textarea>
    </div>

    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="startDate">Start Date <span class="required">*</span></label>
            <input type="date" id="startDate" name="startDate" class="form-control"
                   value="#htmlEditFormat(formData.startDate)#" required>
        </div>
        <div class="form-group">
            <label class="form-label" for="endDate">End Date</label>
            <input type="date" id="endDate" name="endDate" class="form-control"
                   value="#htmlEditFormat(formData.endDate)#">
        </div>
    </div>

    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="currency">Currency</label>
            <select id="currency" name="currency" class="form-control">
                <cfloop array="#application.currencies#" index="c">
                    <option value="#c.code#" <cfif formData.currency eq c.code>selected</cfif>>#c.symbol# &mdash; #c.name#</option>
                </cfloop>
            </select>
        </div>
        <div class="form-group">
            <label class="form-label" for="openingAmount">Opening Pool Amount</label>
            <input type="number" id="openingAmount" name="openingAmount" class="form-control"
                   value="#val(formData.openingAmount)#" min="0" step="0.01">
        </div>
    </div>

    <cfif isEdit>
    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="status">Status</label>
            <select id="status" name="status" class="form-control">
                <option value="Active" <cfif formData.status eq "Active">selected</cfif>>Active</option>
                <option value="Closed" <cfif formData.status eq "Closed">selected</cfif>>Closed</option>
            </select>
        </div>
    </div>
    </cfif>

    <div class="form-actions">
        <button type="submit" class="btn btn-primary">#isEdit ? "Update Group" : "Create Group"#</button>
        <a href="/pages/groups.cfm" class="btn btn-outline">Cancel</a>
    </div>
</form>
</div>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
