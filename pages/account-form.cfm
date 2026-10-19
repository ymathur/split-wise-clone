<cfinclude template="/includes/authCheck.cfm">
<cfinclude template="/includes/csrfCheck.cfm">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset accCFC = new components.account(fb, session.userId, session.idToken)>

<cfset isEdit     = isDefined("url.id") && len(url.id)>
<cfset pageTitle  = isEdit ? "Edit Account" : "New Account">
<cfset formData   = {accountName: "", currency: application.defaultCurrency, openingAmount: 0, startDate: dateFormat(now(), "yyyy-mm-dd"), notes: "", status: "Active"}>
<cfset formErrors = []>
<cfset cashInHand = accCFC.getCashInHand()>
<cfset cashAmount = "">
<cfset currencyLocked = false>

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
        <cfset currencyLocked = accCFC.hasCashTransfers(url.id)>
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
    <cfset cashAmount             = trim(form.cashAmount    ?: "")>
    <cfif currencyLocked><cfset formData.currency = existing.currency></cfif>

    <cfif !len(formData.accountName)>   <cfset arrayAppend(formErrors, "Account name is required")>   </cfif>
    <cfif !isNumeric(formData.openingAmount)><cfset arrayAppend(formErrors, "Opening amount must be a number")></cfif>
    <cfif !len(formData.startDate)>     <cfset arrayAppend(formErrors, "Start date is required")>      </cfif>
    <cfif len(cashAmount)>
        <cfset cashAvailable = cashInHand[formData.currency] ?: 0>
        <cfif !isNumeric(cashAmount) || val(cashAmount) lt 0>
            <cfset arrayAppend(formErrors, "Cash in hand amount must be a positive number")>
        <cfelseif val(cashAmount) gt cashAvailable>
            <cfset arrayAppend(formErrors, "Only #application.currencySymbol(formData.currency)##numberFormat(cashAvailable, '9,999.00')# is available in cash in hand for #formData.currency#")>
        </cfif>
    </cfif>

    <cfif !arrayLen(formErrors)>
        <cftry>
            <cfif isEdit>
                <cfset accCFC.updateAccount(url.id, formData)>
                <cfset targetId = url.id>
            <cfelse>
                <cfset targetId = accCFC.createAccount(formData)>
            </cfif>
            <cfif val(cashAmount) gt 0>
                <cfset accCFC.fundFromCash(targetId, val(cashAmount))>
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
            <select id="currency" name="currency" class="form-control" onchange="updateCashHint()" <cfif currencyLocked>disabled</cfif>>
                <cfloop array="#application.currencies#" index="c">
                    <option value="#c.code#" data-symbol="#htmlEditFormat(c.symbol)#" data-cash="#cashInHand[c.code] ?: 0#" <cfif formData.currency eq c.code>selected</cfif>>#c.symbol# &mdash; #c.name#</option>
                </cfloop>
            </select>
            <cfif currencyLocked><p class="form-hint">Currency can't be changed once cash has moved in or out of this account.</p></cfif>
        </div>
        <div class="form-group">
            <label class="form-label" for="openingAmount">Opening Amount</label>
            <input type="number" id="openingAmount" name="openingAmount" class="form-control"
                   value="#val(formData.openingAmount)#" min="0" step="0.01" <cfif formData.status eq "Closed">disabled</cfif>>
        </div>
    </div>

    <cfif formData.status neq "Closed">
    <div class="form-group">
        <label class="form-label" for="cashAmount">#isEdit ? "Add from Cash in Hand" : "Use from Cash in Hand"#</label>
        <input type="number" id="cashAmount" name="cashAmount" class="form-control"
               value="#htmlEditFormat(cashAmount)#" min="0" step="0.01" placeholder="0.00">
        <p class="form-hint" id="cashHint"></p>
    </div>
    </cfif>

    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="startDate">Start Date <span class="required">*</span></label>
            <input type="date" id="startDate" name="startDate" class="form-control"
                   value="#htmlEditFormat(formData.startDate)#" required>
        </div>
    </div>

    <cfif formData.status eq "Closed">
    <p class="form-hint">This account is closed. Its remaining balance was moved to cash in hand.</p>
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

<script>
function updateCashHint() {
    const hint = document.getElementById('cashHint');
    if (!hint) return;
    const opt  = document.getElementById('currency').selectedOptions[0];
    const cash = parseFloat(opt.dataset.cash) || 0;
    hint.textContent = 'Available: ' + opt.dataset.symbol + cash.toFixed(2);
}
updateCashHint();
</script>

</main>
<cfinclude template="/includes/footer.cfm">
