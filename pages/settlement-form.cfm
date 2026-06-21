<cfinclude template="/includes/authCheck.cfm">
<cfinclude template="/includes/csrfCheck.cfm">
<cfset pageTitle = "New Settlement">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset stlCFC = new components.settlement(fb, session.userId, session.idToken)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>

<cfset groups     = grpCFC.getGroups("All")>
<cfset formErrors = []>

<!--- Pre-fill from URL params (from group-detail suggestion) --->
<cfset formData = {
    groupId      : url.groupId  ?: "",
    fromMemberId : url.fromId   ?: "",
    toMemberId   : url.toId     ?: "",
    amount       : url.amount   ?: "",
    date         : dateFormat(now(), "yyyy-mm-dd"),
    paymentMode  : "Cash",
    notes        : ""
}>

<cfset groupMembers = []>
<cfif len(formData.groupId)>
    <cfset groupMembers = grpCFC.getMembers(formData.groupId)>
</cfif>

<cfif cgi.request_method eq "POST">
    <cfset formData.groupId      = trim(form.groupId      ?: "")>
    <cfset formData.fromMemberId = trim(form.fromMemberId ?: "")>
    <cfset formData.toMemberId   = trim(form.toMemberId   ?: "")>
    <cfset formData.amount       = trim(form.amount       ?: "")>
    <cfset formData.date         = trim(form.date         ?: "")>
    <cfset formData.paymentMode  = trim(form.paymentMode  ?: "Cash")>
    <cfset formData.notes        = trim(form.notes        ?: "")>

    <cfif !len(formData.groupId)>      <cfset arrayAppend(formErrors, "Group is required")>         </cfif>
    <cfif !len(formData.fromMemberId)> <cfset arrayAppend(formErrors, "Payer (from) is required")>  </cfif>
    <cfif !len(formData.toMemberId)>   <cfset arrayAppend(formErrors, "Receiver (to) is required")> </cfif>
    <cfif formData.fromMemberId eq formData.toMemberId && len(formData.fromMemberId)>
        <cfset arrayAppend(formErrors, "Payer and receiver cannot be the same member")>
    </cfif>
    <cfif !isNumeric(formData.amount) || val(formData.amount) <= 0>
        <cfset arrayAppend(formErrors, "Amount must be a positive number")>
    </cfif>
    <cfif !len(formData.date)> <cfset arrayAppend(formErrors, "Date is required")> </cfif>

    <cfif !arrayLen(formErrors)>
        <cftry>
            <cfset newId = stlCFC.createSettlement(formData)>
            <cflocation url="/pages/settlements.cfm?groupId=#urlEncodedFormat(formData.groupId)#&saved=1" addtoken="false">
            <cfcatch type="any">
                <cfset arrayAppend(formErrors, cfcatch.message)>
            </cfcatch>
        </cftry>
    </cfif>

    <cfif len(formData.groupId)>
        <cfset groupMembers = grpCFC.getMembers(formData.groupId)>
    </cfif>
</cfif>

<cfset expCFC = new components.expense(fb, session.userId, session.idToken)>

<cfset groupCurForm = {}>
<cfloop array="#groups#" index="g"><cfset groupCurForm[g._id] = g.currency></cfloop>
<cfset initialCurSym = application.currencySymbol(groupCurForm[formData.groupId] ?: "")>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Record Settlement</h1>
    <a href="/pages/settlements.cfm" class="btn btn-outline">Cancel</a>
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
        <label class="form-label" for="groupId">Group <span class="required">*</span></label>
        <select id="groupId" name="groupId" class="form-control" required
                onchange="loadSettlementMembers(this.value); updateAmountCurrency();">
            <option value="">-- Select Group --</option>
            <cfloop array="#groups#" index="g">
                <option value="#htmlEditFormat(g._id)#" data-currency="#htmlEditFormat(g.currency)#" <cfif formData.groupId eq g._id>selected</cfif>>#htmlEditFormat(g.groupName)#</option>
            </cfloop>
        </select>
    </div>

    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="fromMemberId">Payer (From) <span class="required">*</span></label>
            <select id="fromMemberId" name="fromMemberId" class="form-control" required>
                <option value="">-- Select --</option>
                <cfloop array="#groupMembers#" index="m">
                    <option value="#htmlEditFormat(m.memberId)#"
                            <cfif formData.fromMemberId eq m.memberId>selected</cfif>>#htmlEditFormat(m.name)#</option>
                </cfloop>
            </select>
        </div>
        <div class="form-group">
            <label class="form-label" for="toMemberId">Receiver (To) <span class="required">*</span></label>
            <select id="toMemberId" name="toMemberId" class="form-control" required>
                <option value="">-- Select --</option>
                <cfloop array="#groupMembers#" index="m">
                    <option value="#htmlEditFormat(m.memberId)#"
                            <cfif formData.toMemberId eq m.memberId>selected</cfif>>#htmlEditFormat(m.name)#</option>
                </cfloop>
            </select>
        </div>
    </div>

    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="amount">Amount (<span id="amountCurrencyLabel">#initialCurSym#</span>) <span class="required">*</span></label>
            <input type="number" id="amount" name="amount" class="form-control"
                   value="#htmlEditFormat(formData.amount)#" min="0.01" step="0.01" required>
        </div>
        <div class="form-group">
            <label class="form-label" for="date">Date <span class="required">*</span></label>
            <input type="date" id="date" name="date" class="form-control"
                   value="#htmlEditFormat(formData.date)#" required>
        </div>
    </div>

    <div class="form-group">
        <label class="form-label" for="paymentMode">Payment Mode</label>
        <select id="paymentMode" name="paymentMode" class="form-control">
            <cfloop array="#expCFC.getPaymentModes()#" index="pm">
                <option value="#pm#" <cfif formData.paymentMode eq pm>selected</cfif>>#pm#</option>
            </cfloop>
        </select>
    </div>

    <div class="form-group">
        <label class="form-label" for="notes">Notes</label>
        <textarea id="notes" name="notes" class="form-control" rows="2"
                  placeholder="Optional notes">#htmlEditFormat(formData.notes)#</textarea>
    </div>

    <div class="form-actions">
        <button type="submit" class="btn btn-primary">Record Settlement</button>
        <a href="/pages/settlements.cfm" class="btn btn-outline">Cancel</a>
    </div>
</form>
</div>

<script>
<cfoutput>
const currencySymbols = #serializeJSON(application.currencySymbols)#;
const defaultCurrency = '#jsStringFormat(application.defaultCurrency)#';
</cfoutput>

function updateAmountCurrency() {
    const select = document.getElementById('groupId');
    const opt    = select.options[select.selectedIndex];
    const code   = (opt && opt.dataset.currency) || defaultCurrency;
    document.getElementById('amountCurrencyLabel').textContent = currencySymbols[code] || currencySymbols[defaultCurrency];
}

async function loadSettlementMembers(groupId) {
    if (!groupId) return;
    try {
        const res     = await fetch('/api/get-members.cfm?groupId=' + encodeURIComponent(groupId));
        const data    = await res.json();
        if (!data.success) return;
        const members = data.data;
        const opts    = '<option value="">-- Select --</option>' +
                        members.map(m => `<option value="${m.memberId}">${escHtml(m.name)}</option>`).join('');
        document.getElementById('fromMemberId').innerHTML = opts;
        document.getElementById('toMemberId').innerHTML   = opts;
    } catch(e) { console.error(e); }
}

function escHtml(str) {
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
</script>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
