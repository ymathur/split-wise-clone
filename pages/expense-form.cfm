<cfinclude template="/includes/authCheck.cfm">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset expCFC = new components.expense(fb, session.userId, session.idToken)>
<cfset accCFC = new components.account(fb, session.userId, session.idToken)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>

<cfset isEdit     = isDefined("url.id") && len(url.id)>
<cfset pageTitle  = isEdit ? "Edit Expense" : "Add Expense">
<cfset formErrors = []>

<cfset accounts = accCFC.getAccounts("All")>
<cfset groups   = grpCFC.getGroups("All")>

<cfset formData = {
    accountId      : url.accountId ?: "",
    groupId        : url.groupId   ?: "",
    expenseType    : "Personal",
    date           : dateFormat(now(), "yyyy-mm-dd"),
    description    : "",
    category       : "Miscellaneous",
    amount         : "",
    paidByMemberId : "",
    paymentMode    : "Cash",
    splitType      : "Equal",
    notes          : ""
}>
<cfset existingSplits = []>

<cfif isEdit>
    <cftry>
        <cfset existing = expCFC.getExpense(url.id)>
        <cfset formData = {
            accountId      : existing.accountId,
            groupId        : existing.groupId,
            expenseType    : existing.expenseType,
            date           : existing.date,
            description    : existing.description,
            category       : existing.category,
            amount         : existing.amount,
            paidByMemberId : existing.paidByMemberId,
            paymentMode    : existing.paymentMode,
            splitType      : existing.splitType ?: "Equal",
            notes          : existing.notes
        }>
        <cfset existingSplits = expCFC.getExpenseSplits(url.id)>
        <cfcatch type="any">
            <cflocation url="/pages/expenses.cfm" addtoken="false">
        </cfcatch>
    </cftry>
</cfif>

<!--- Pre-load members if groupId known --->
<cfset groupMembers = []>
<cfif len(formData.groupId)>
    <cfset groupMembers = grpCFC.getMembers(formData.groupId)>
</cfif>

<cfif cgi.request_method eq "POST">
    <cfset formData.accountId      = trim(form.accountId      ?: "")>
    <cfset formData.groupId        = trim(form.groupId        ?: "")>
    <cfset formData.expenseType    = trim(form.expenseType    ?: "Personal")>
    <cfset formData.date           = trim(form.date           ?: "")>
    <cfset formData.description    = trim(form.description    ?: "")>
    <cfset formData.category       = trim(form.category       ?: "Miscellaneous")>
    <cfset formData.amount         = trim(form.amount         ?: "")>
    <cfset formData.paidByMemberId = trim(form.paidByMemberId ?: "")>
    <cfset formData.paymentMode    = trim(form.paymentMode    ?: "Cash")>
    <cfset formData.splitType      = trim(form.splitType      ?: "Equal")>
    <cfset formData.notes          = trim(form.notes          ?: "")>

    <!--- Validation --->
    <cfif !len(formData.description)>  <cfset arrayAppend(formErrors, "Description is required")>       </cfif>
    <cfif !isNumeric(formData.amount) || val(formData.amount) <= 0>
        <cfset arrayAppend(formErrors, "Amount must be a positive number")>
    </cfif>
    <cfif !len(formData.date)>         <cfset arrayAppend(formErrors, "Date is required")>              </cfif>
    <cfif formData.expenseType eq "Group" && !len(formData.groupId)>
        <cfset arrayAppend(formErrors, "Please select a group for group expenses")>
    </cfif>
    <cfif formData.expenseType eq "Personal" && !len(formData.accountId)>
        <cfset arrayAppend(formErrors, "Please select an account for personal expenses")>
    </cfif>

    <!--- Parse splits from form --->
    <cfset splits = []>
    <cfif formData.expenseType eq "Group" && len(formData.groupId) && !arrayLen(formErrors)>
        <cfset amount = val(formData.amount)>
        <cfif formData.splitType eq "Equal">
            <!--- Get selected member IDs --->
            <cfset selectedIds = isDefined("form.splitMembers") ? listToArray(form.splitMembers) : []>
            <cfif arrayLen(selectedIds)>
                <cfset share = amount / arrayLen(selectedIds)>
                <cfloop array="#selectedIds#" index="mid">
                    <cfset arrayAppend(splits, {memberId: mid, shareAmount: share})>
                </cfloop>
            </cfif>
        <cfelse>
            <!--- Custom split: read custom_share_<memberId> fields --->
            <cfset splitTotal = 0>
            <cfloop array="#grpCFC.getMembers(formData.groupId)#" index="m">
                <cfset fieldName = "custom_share_" & m.memberId>
                <cfif structKeyExists(form, fieldName) && isNumeric(form[fieldName])>
                    <cfset shareAmt = val(form[fieldName])>
                    <cfif shareAmt gt 0>
                        <cfset arrayAppend(splits, {memberId: m.memberId, shareAmount: shareAmt})>
                        <cfset splitTotal += shareAmt>
                    </cfif>
                </cfif>
            </cfloop>
            <cfif abs(splitTotal - amount) gt 0.01>
                <cfset arrayAppend(formErrors, "Custom split total (#application.currency##numberFormat(splitTotal,'9,999.00')#) must equal expense amount (#application.currency##numberFormat(amount,'9,999.00')#)")>
            </cfif>
        </cfif>
    </cfif>

    <cfif !arrayLen(formErrors)>
        <cftry>
            <cfif isEdit>
                <cfset expCFC.updateExpense(url.id, formData, splits)>
            <cfelse>
                <cfset newId = expCFC.createExpense(formData, splits)>
            </cfif>
            <cfif len(formData.groupId)>
                <cflocation url="/pages/group-detail.cfm?id=#urlEncodedFormat(formData.groupId)#&saved=1" addtoken="false">
            <cfelse>
                <cflocation url="/pages/expenses.cfm?saved=1" addtoken="false">
            </cfif>
            <cfcatch type="any">
                <cfset arrayAppend(formErrors, cfcatch.message)>
            </cfcatch>
        </cftry>
    </cfif>

    <!--- Reload group members if group changed --->
    <cfif len(formData.groupId)>
        <cfset groupMembers = grpCFC.getMembers(formData.groupId)>
    </cfif>
</cfif>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>#isEdit ? "Edit Expense" : "Add Expense"#</h1>
    <a href="/pages/expenses.cfm" class="btn btn-outline">Cancel</a>
</div>

<cfif arrayLen(formErrors)>
<div class="alert alert-danger">
    <ul class="mb-0"><cfloop array="#formErrors#" index="err"><li>#htmlEditFormat(err)#</li></cfloop></ul>
</div>
</cfif>

<div class="card form-card">
<form method="post" id="expenseForm">

    <!--- Expense Type Toggle --->
    <div class="form-group">
        <label class="form-label">Expense Type <span class="required">*</span></label>
        <div class="btn-group-toggle">
            <label class="toggle-label <cfif formData.expenseType eq 'Personal'>active</cfif>">
                <input type="radio" name="expenseType" value="Personal" id="typePersonal"
                       <cfif formData.expenseType eq "Personal">checked</cfif>> Personal
            </label>
            <label class="toggle-label <cfif formData.expenseType eq 'Group'>active</cfif>">
                <input type="radio" name="expenseType" value="Group" id="typeGroup"
                       <cfif formData.expenseType eq "Group">checked</cfif>> Group
            </label>
        </div>
    </div>

    <!--- Personal: Account select --->
    <div id="personalSection" <cfif formData.expenseType eq "Group">style="display:none"</cfif>>
        <div class="form-group">
            <label class="form-label" for="accountId">Account</label>
            <select id="accountId" name="accountId" class="form-control">
                <option value="">-- Select Account --</option>
                <cfloop array="#accounts#" index="a">
                    <option value="#htmlEditFormat(a._id)#" <cfif formData.accountId eq a._id>selected</cfif>>#htmlEditFormat(a.accountName)#</option>
                </cfloop>
            </select>
        </div>
    </div>

    <!--- Group: Group select --->
    <div id="groupSection" <cfif formData.expenseType eq "Personal">style="display:none"</cfif>>
        <div class="form-group">
            <label class="form-label" for="groupId">Group</label>
            <select id="groupId" name="groupId" class="form-control" onchange="loadGroupMembers(this.value)">
                <option value="">-- Select Group --</option>
                <cfloop array="#groups#" index="g">
                    <option value="#htmlEditFormat(g._id)#" <cfif formData.groupId eq g._id>selected</cfif>>#htmlEditFormat(g.groupName)#</option>
                </cfloop>
            </select>
        </div>
    </div>

    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="date">Date <span class="required">*</span></label>
            <input type="date" id="date" name="date" class="form-control"
                   value="#htmlEditFormat(formData.date)#" required>
        </div>
        <div class="form-group">
            <label class="form-label" for="amount">Amount (#application.currency#) <span class="required">*</span></label>
            <input type="number" id="amount" name="amount" class="form-control"
                   value="#htmlEditFormat(formData.amount)#" min="0.01" step="0.01" required
                   oninput="updateEqualShares()">
        </div>
    </div>

    <div class="form-group">
        <label class="form-label" for="description">Description <span class="required">*</span></label>
        <input type="text" id="description" name="description" class="form-control"
               value="#htmlEditFormat(formData.description)#" placeholder="What was this for?" required>
    </div>

    <div class="form-row">
        <div class="form-group">
            <label class="form-label" for="category">Category</label>
            <select id="category" name="category" class="form-control">
                <cfloop array="#expCFC.getCategories()#" index="cat">
                    <option value="#cat#" <cfif formData.category eq cat>selected</cfif>>#cat#</option>
                </cfloop>
            </select>
        </div>
        <div class="form-group">
            <label class="form-label" for="paymentMode">Payment Mode</label>
            <select id="paymentMode" name="paymentMode" class="form-control">
                <cfloop array="#expCFC.getPaymentModes()#" index="pm">
                    <option value="#pm#" <cfif formData.paymentMode eq pm>selected</cfif>>#pm#</option>
                </cfloop>
            </select>
        </div>
    </div>

    <!--- Group Split Section --->
    <div id="splitSection" <cfif formData.expenseType eq "Personal">style="display:none"</cfif>>
        <hr class="form-divider">
        <h3 class="section-title">Split Details</h3>

        <div class="form-row">
            <div class="form-group">
                <label class="form-label" for="paidByMemberId">Paid By</label>
                <select id="paidByMemberId" name="paidByMemberId" class="form-control">
                    <option value="">-- Select Member --</option>
                    <cfloop array="#groupMembers#" index="m">
                        <option value="#htmlEditFormat(m.memberId)#"
                                <cfif formData.paidByMemberId eq m.memberId>selected</cfif>>#htmlEditFormat(m.name)#</option>
                    </cfloop>
                </select>
            </div>
            <div class="form-group">
                <label class="form-label">Split Type</label>
                <div class="btn-group-toggle">
                    <label class="toggle-label <cfif formData.splitType eq 'Equal'>active</cfif>">
                        <input type="radio" name="splitType" value="Equal"
                               <cfif formData.splitType eq "Equal">checked</cfif>
                               onchange="toggleSplitType('Equal')"> Equal
                    </label>
                    <label class="toggle-label <cfif formData.splitType eq 'Custom'>active</cfif>">
                        <input type="radio" name="splitType" value="Custom"
                               <cfif formData.splitType eq "Custom">checked</cfif>
                               onchange="toggleSplitType('Custom')"> Custom
                    </label>
                </div>
            </div>
        </div>

        <!--- Equal split: checkboxes --->
        <div id="equalSplitSection" <cfif formData.splitType eq "Custom">style="display:none"</cfif>>
            <label class="form-label">Include in Split</label>
            <div id="equalMemberList" class="member-checklist">
                <cfif arrayLen(groupMembers)>
                <cfloop array="#groupMembers#" index="m">
                    <label class="member-check-item">
                        <input type="checkbox" name="splitMembers" value="#htmlEditFormat(m.memberId)#" checked>
                        <span>#htmlEditFormat(m.name)#</span>
                        <span class="member-share" id="share_#htmlEditFormat(m.memberId)#">—</span>
                    </label>
                </cfloop>
                <cfelse>
                <p class="text-muted">Select a group above to see members.</p>
                </cfif>
            </div>
        </div>

        <!--- Custom split: amount per member --->
        <div id="customSplitSection" <cfif formData.splitType eq "Equal">style="display:none"</cfif>>
            <label class="form-label">Custom Amounts</label>
            <div id="customMemberList" class="member-checklist">
                <cfif arrayLen(groupMembers)>
                <cfloop array="#groupMembers#" index="m">
                    <cfset existingShare = 0>
                    <cfloop array="#existingSplits#" index="sp">
                        <cfif sp.memberId eq m.memberId><cfset existingShare = sp.shareAmount></cfif>
                    </cfloop>
                    <div class="member-custom-item">
                        <span class="member-custom-name">#htmlEditFormat(m.name)#</span>
                        <input type="number" name="custom_share_#htmlEditFormat(m.memberId)#"
                               class="form-control custom-share" min="0" step="0.01"
                               value="#val(existingShare)#" oninput="checkCustomTotal()">
                    </div>
                </cfloop>
                <div id="customTotalRow" class="custom-total">
                    Total: <span id="customTotal">0.00</span> / <span id="customTarget">0.00</span>
                </div>
                <cfelse>
                <p class="text-muted">Select a group above to see members.</p>
                </cfif>
            </div>
        </div>
    </div>

    <div class="form-group">
        <label class="form-label" for="notes">Notes</label>
        <textarea id="notes" name="notes" class="form-control" rows="2"
                  placeholder="Optional notes">#htmlEditFormat(formData.notes)#</textarea>
    </div>

    <div class="form-actions">
        <button type="submit" class="btn btn-primary">#isEdit ? "Update Expense" : "Save Expense"#</button>
        <a href="/pages/expenses.cfm" class="btn btn-outline">Cancel</a>
    </div>
</form>
</div>
</cfoutput>

<script>
<cfoutput>
const initialGroupId   = '#jsStringFormat(formData.groupId)#';
const initialSplitType = '#jsStringFormat(formData.splitType)#';
</cfoutput>

// Show/hide sections based on expense type
document.querySelectorAll('input[name="expenseType"]').forEach(r => {
    r.addEventListener('change', () => {
        const isGroup = r.value === 'Group';
        document.getElementById('personalSection').style.display = isGroup ? 'none' : '';
        document.getElementById('groupSection').style.display    = isGroup ? '' : 'none';
        document.getElementById('splitSection').style.display    = isGroup ? '' : 'none';
        if (!isGroup) {
            document.getElementById('groupId').value = '';
        }
    });
});

// Toggle label active state for btn-group-toggle
document.querySelectorAll('.btn-group-toggle input').forEach(inp => {
    inp.addEventListener('change', () => {
        inp.closest('.btn-group-toggle').querySelectorAll('.toggle-label').forEach(l => l.classList.remove('active'));
        inp.closest('.toggle-label').classList.add('active');
    });
});

function toggleSplitType(type) {
    document.getElementById('equalSplitSection').style.display  = type === 'Equal'  ? '' : 'none';
    document.getElementById('customSplitSection').style.display = type === 'Custom' ? '' : 'none';
    updateEqualShares();
}

function updateEqualShares() {
    const amount    = parseFloat(document.getElementById('amount').value) || 0;
    const checkboxes = document.querySelectorAll('#equalMemberList input[type="checkbox"]:checked');
    const count     = checkboxes.length;
    const share     = count > 0 ? (amount / count).toFixed(2) : '0.00';
    document.querySelectorAll('.member-share').forEach(el => el.textContent = count > 0 ? '₹' + share : '—');
    const ctEl = document.getElementById('customTarget');
    if (ctEl) ctEl.textContent = amount.toFixed(2);
}

function checkCustomTotal() {
    const amount = parseFloat(document.getElementById('amount').value) || 0;
    let   total  = 0;
    document.querySelectorAll('.custom-share').forEach(inp => { total += parseFloat(inp.value) || 0; });
    const totalEl = document.getElementById('customTotal');
    if (!totalEl) return;
    totalEl.textContent = total.toFixed(2);
    totalEl.style.color = Math.abs(total - amount) < 0.01 ? 'green' : 'red';
}

async function loadGroupMembers(groupId) {
    if (!groupId) return;
    try {
        const res     = await fetch('/api/get-members.cfm?groupId=' + encodeURIComponent(groupId));
        const data    = await res.json();
        if (!data.success) return;
        const members = data.data;

        // Rebuild equal member list
        const eqList = document.getElementById('equalMemberList');
        eqList.innerHTML = members.map(m => `
            <label class="member-check-item">
                <input type="checkbox" name="splitMembers" value="${m.memberId}" checked onchange="updateEqualShares()">
                <span>${escHtml(m.name)}</span>
                <span class="member-share">—</span>
            </label>`).join('');

        // Rebuild custom member list
        const cuList = document.getElementById('customMemberList');
        cuList.innerHTML = members.map(m => `
            <div class="member-custom-item">
                <span class="member-custom-name">${escHtml(m.name)}</span>
                <input type="number" name="custom_share_${m.memberId}"
                       class="form-control custom-share" min="0" step="0.01" value="0"
                       oninput="checkCustomTotal()">
            </div>`).join('') + '<div id="customTotalRow" class="custom-total">Total: <span id="customTotal">0.00</span> / <span id="customTarget">0.00</span></div>';

        // Rebuild paid-by select
        const paidBy = document.getElementById('paidByMemberId');
        paidBy.innerHTML = '<option value="">-- Select Member --</option>' +
            members.map(m => `<option value="${m.memberId}">${escHtml(m.name)}</option>`).join('');

        updateEqualShares();
    } catch (e) { console.error(e); }
}

function escHtml(str) {
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// Init on load
updateEqualShares();
checkCustomTotal();
</script>

</main>
<cfinclude template="/includes/footer.cfm">
