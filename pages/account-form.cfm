<cfinclude template="/includes/authCheck.cfm">
<cfinclude template="/includes/csrfCheck.cfm">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset accCFC = new components.account(fb, session.userId, session.idToken)>

<cfset isEdit     = isDefined("url.id") && len(url.id)>
<cfset pageTitle  = isEdit ? "Edit Account" : "New Account">
<cfset formData   = {accountName: "", currency: application.defaultCurrency, openingAmount: 0, startDate: dateFormat(now(), "yyyy-mm-dd"), notes: "", status: "Active"}>
<cfset formErrors = []>

<cfif isEdit>
    <cftry>
        <cfset existing = accCFC.getAccount(url.id)>
        <cfset formData = {
            accountName   : existing.accountName,
            currency      : len(existing.currency ?: "") ? existing.currency : application.defaultCurrency,
            openingAmount : existing.openingAmount,
            startDate     : existing.startDate,
            notes         : existing.notes,
            status        : existing.status
        }>
        <cfcatch type="any">
            <cflocation url="/pages/accounts.cfm" addtoken="false">
        </cfcatch>
    </cftry>
</cfif>

<cfif cgi.request_method eq "POST">
    <cfset formData.accountName   = trim(form.accountName   ?: "")>
    <cfset formData.currency      = trim(form.currency      ?: application.defaultCurrency)>
    <cfset formData.openingAmount = trim(form.openingAmount ?: 0)>
    <cfset formData.startDate     = trim(form.startDate     ?: "")>
    <cfset formData.notes         = trim(form.notes         ?: "")>
    <cfset formData.status        = trim(form.status        ?: "Active")>

    <cfif !len(formData.accountName)>   <cfset arrayAppend(formErrors, "Account name is required")>   </cfif>
    <cfif !isNumeric(formData.openingAmount)><cfset arrayAppend(formErrors, "Opening amount must be a number")></cfif>
    <cfif !len(formData.startDate)>     <cfset arrayAppend(formErrors, "Start date is required")>      </cfif>

    <cfif !arrayLen(formErrors)>
        <cftry>
            <cfif isEdit>
                <cfset accCFC.updateAccount(url.id, formData)>
            <cfelse>
                <cfset newId = accCFC.createAccount(formData)>
            </cfif>
            <cflocation url="/pages/accounts.cfm?saved=1" addtoken="false">
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
    <h1>#isEdit ? "Edit Account" : "New Account"#</h1>
    <a href="/pages/accounts.cfm" class="btn btn-outline">Cancel</a>
</div>

<cfif arrayLen(formErrors)>
<div class="alert alert-danger">
    <ul class="mb-0">
    <cfloop array="#formErrors#" index="err">
        <li>#htmlEditFormat(err)#</li>
    </cfloop>
    </ul>
</div>
</cfif>

<div class="card form-card">
<form method="post">
    <input type="hidden" name="csrfToken" value="#htmlEditFormat(session.csrfToken)#">
    <div class="form-group">
        <label class="form-label" for="accountName">Account Name <span class="required">*</span></label>
        <input type="text" id="accountName" name="accountName" class="form-control"
               value="#htmlEditFormat(formData.accountName)#"
               placeholder="e.g. Daily Cash, USA Trip 2026" required>
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
            <label class="form-label" for="openingAmount">Opening Amount</label>
            <input type="number" id="openingAmount" name="openingAmount" class="form-control"
                   value="#val(formData.openingAmount)#" min="0" step="0.01">
        </div>
    </div>

    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="startDate">Start Date <span class="required">*</span></label>
            <input type="date" id="startDate" name="startDate" class="form-control"
                   value="#htmlEditFormat(formData.startDate)#" required>
        </div>
    </div>

    <cfif isEdit>
    <div class="form-group">
        <label class="form-label" for="status">Status</label>
        <select id="status" name="status" class="form-control">
            <option value="Active" <cfif formData.status eq "Active">selected</cfif>>Active</option>
            <option value="Closed" <cfif formData.status eq "Closed">selected</cfif>>Closed</option>
        </select>
    </div>
    </cfif>

    <div class="form-group">
        <label class="form-label" for="notes">Notes</label>
        <textarea id="notes" name="notes" class="form-control" rows="3"
                  placeholder="Optional notes">#htmlEditFormat(formData.notes)#</textarea>
    </div>

    <div class="form-actions">
        <button type="submit" class="btn btn-primary">#isEdit ? "Update Account" : "Create Account"#</button>
        <a href="/pages/accounts.cfm" class="btn btn-outline">Cancel</a>
    </div>
</form>
</div>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
