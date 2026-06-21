<cfinclude template="/includes/authCheck.cfm">

<cfset expId = url.id ?: "">
<cfif !len(expId)><cflocation url="/pages/expenses.cfm" addtoken="false"></cfif>

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset expCFC = new components.expense(fb, session.userId, session.idToken)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>
<cfset accCFC = new components.account(fb, session.userId, session.idToken)>

<cftry>
    <cfset expense = expCFC.getExpense(expId)>
    <cfset splits  = expCFC.getExpenseSplits(expId)>
    <cfset memberNames = {}>
    <cfif expense.expenseType eq "Group" && len(expense.groupId)>
        <cfset members = grpCFC.getMembers(expense.groupId)>
        <cfloop array="#members#" index="m">
            <cfset memberNames[m.memberId] = m.name>
        </cfloop>
        <cfset eCur = grpCFC.getGroup(expense.groupId).currency>
    <cfelse>
        <cfset eCur = accCFC.getAccount(expense.accountId).currency>
    </cfif>
    <cfset curSym = application.currencySymbol(eCur)>
    <cfset pageTitle = expense.description>
    <cfcatch type="any">
        <cflocation url="/pages/expenses.cfm" addtoken="false">
    </cfcatch>
</cftry>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <div>
        <h1>#htmlEditFormat(expense.description)#</h1>
        <span class="badge badge-<cfif expense.expenseType eq 'Group'>teal<cfelse>blue</cfif>">#htmlEditFormat(expense.expenseType)#</span>
        <span class="badge">#htmlEditFormat(expense.category)#</span>
    </div>
    <div class="header-actions">
        <a href="/pages/expense-form.cfm?id=#urlEncodedFormat(expId)#" class="btn btn-outline">Edit</a>
        <a href="/pages/expenses.cfm" class="btn btn-outline">Back</a>
    </div>
</div>

<div class="card">
    <table class="detail-table">
        <tr><th>Date</th>         <td>#dateFormat(expense.date, "dd mmm yyyy")#</td></tr>
        <tr><th>Amount</th>       <td><strong>#curSym##numberFormat(expense.amount, "9,999.00")#</strong></td></tr>
        <tr><th>Category</th>     <td>#htmlEditFormat(expense.category)#</td></tr>
        <tr><th>Payment Mode</th> <td>#htmlEditFormat(expense.paymentMode)#</td></tr>
        <tr><th>Type</th>         <td>#htmlEditFormat(expense.expenseType)#</td></tr>
        <cfif expense.expenseType eq "Group" && len(expense.paidByMemberId)>
        <tr><th>Paid By</th>      <td>#htmlEditFormat(memberNames[expense.paidByMemberId] ?: "Unknown")#</td></tr>
        <tr><th>Split Type</th>   <td>#htmlEditFormat(expense.splitType ?: "Equal")#</td></tr>
        </cfif>
        <cfif len(expense.notes)>
        <tr><th>Notes</th>        <td>#htmlEditFormat(expense.notes)#</td></tr>
        </cfif>
        <tr><th>Created</th>      <td>#dateTimeFormat(expense.createdAt, "dd mmm yyyy HH:nn")#</td></tr>
    </table>
</div>

<cfif arrayLen(splits)>
<div class="card">
    <div class="card-header"><h2>Split Details</h2></div>
    <table class="table">
        <thead>
            <tr><th>Member</th><th class="text-right">Share</th></tr>
        </thead>
        <tbody>
        <cfloop array="#splits#" index="s">
            <tr>
                <td>#htmlEditFormat(memberNames[s.memberId] ?: s.memberId)#</td>
                <td class="text-right">#curSym##numberFormat(s.shareAmount, "9,999.00")#</td>
            </tr>
        </cfloop>
        <tr class="total-row">
            <td><strong>Total</strong></td>
            <td class="text-right"><strong>#curSym##numberFormat(expense.amount, "9,999.00")#</strong></td>
        </tr>
        </tbody>
    </table>
</div>
</cfif>

<div class="page-actions">
    <a href="/pages/expense-form.cfm?id=#urlEncodedFormat(expId)#" class="btn btn-primary">Edit Expense</a>
    <form method="post" action="/pages/expenses.cfm" class="inline-form" onsubmit="return confirm('Delete this expense?')">
        <input type="hidden" name="csrfToken" value="#htmlEditFormat(session.csrfToken)#">
        <input type="hidden" name="action" value="delete">
        <input type="hidden" name="deleteId" value="#htmlEditFormat(expId)#">
        <button type="submit" class="btn btn-danger">Delete Expense</button>
    </form>
    <cfif expense.expenseType eq "Group" && len(expense.groupId)>
    <a href="/pages/group-detail.cfm?id=#urlEncodedFormat(expense.groupId)#" class="btn btn-outline">Back to Group</a>
    </cfif>
</div>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
