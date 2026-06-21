<cfinclude template="/includes/authCheck.cfm">
<cfinclude template="/includes/csrfCheck.cfm">
<cfset pageTitle = "Expenses">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset expCFC = new components.expense(fb, session.userId, session.idToken)>
<cfset accCFC = new components.account(fb, session.userId, session.idToken)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>

<cfset f = {
    accountId   : url.accountId   ?: "",
    groupId     : url.groupId     ?: "",
    expenseType : url.expenseType ?: "",
    category    : url.category    ?: "",
    paymentMode : url.paymentMode ?: "",
    dateFrom    : url.dateFrom    ?: "",
    dateTo      : url.dateTo      ?: ""
}>

<cftry>
    <cfset expenses  = expCFC.getExpenses(f)>
    <cfset accounts  = accCFC.getAccounts("All")>
    <cfset groups    = grpCFC.getGroups("All")>

    <cfset acctCurrency = {}>
    <cfloop array="#accounts#" index="a"><cfset acctCurrency[a._id] = a.currency></cfloop>
    <cfset groupCurrency = {}>
    <cfloop array="#groups#" index="g"><cfset groupCurrency[g._id] = g.currency></cfloop>

    <cfset totalByCur = {}>
    <cfloop array="#expenses#" index="e">
        <cfset eCur = e.expenseType eq "Personal" ? (acctCurrency[e.accountId] ?: application.defaultCurrency) : (groupCurrency[e.groupId] ?: application.defaultCurrency)>
        <cfset totalByCur[eCur] = (totalByCur[eCur] ?: 0) + val(e.amount)>
    </cfloop>

    <cfcatch type="any">
        <cfset loadError = cfcatch.message>
        <cfset expenses = []>
        <cfset accounts = []>
        <cfset groups   = []>
        <cfset acctCurrency = {}>
        <cfset groupCurrency = {}>
        <cfset totalByCur = {}>
    </cfcatch>
</cftry>

<!--- Handle delete --->
<cfif cgi.request_method eq "POST" && (form.action ?: "") eq "delete" && len(form.deleteId ?: "")>
    <cftry>
        <cfset expCFC.deleteExpense(form.deleteId)>
        <cflocation url="/pages/expenses.cfm?deleted=1" addtoken="false">
        <cfcatch type="any">
            <cfset deleteError = cfcatch.message>
        </cfcatch>
    </cftry>
</cfif>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Expenses</h1>
    <a href="/pages/expense-form.cfm" class="btn btn-primary">+ Add Expense</a>
</div>

<cfif isDefined("loadError")>   <div class="alert alert-danger">#htmlEditFormat(loadError)#</div>   </cfif>
<cfif isDefined("deleteError")> <div class="alert alert-danger">#htmlEditFormat(deleteError)#</div> </cfif>
<cfif isDefined("url.deleted") && url.deleted><div class="alert alert-success">Expense deleted.</div></cfif>

<!--- Filters --->
<div class="card filter-card">
    <form method="get" class="filter-form">
        <div class="filter-row">
            <div class="form-group form-group-sm">
                <label class="form-label">Account</label>
                <select name="accountId" class="form-control">
                    <option value="">All Accounts</option>
                    <cfloop array="#accounts#" index="a">
                        <option value="#htmlEditFormat(a._id)#" <cfif f.accountId eq a._id>selected</cfif>>#htmlEditFormat(a.accountName)#</option>
                    </cfloop>
                </select>
            </div>
            <div class="form-group form-group-sm">
                <label class="form-label">Group</label>
                <select name="groupId" class="form-control">
                    <option value="">All Groups</option>
                    <cfloop array="#groups#" index="g">
                        <option value="#htmlEditFormat(g._id)#" <cfif f.groupId eq g._id>selected</cfif>>#htmlEditFormat(g.groupName)#</option>
                    </cfloop>
                </select>
            </div>
            <div class="form-group form-group-sm">
                <label class="form-label">Type</label>
                <select name="expenseType" class="form-control">
                    <option value="">All Types</option>
                    <option value="Personal" <cfif f.expenseType eq "Personal">selected</cfif>>Personal</option>
                    <option value="Group"    <cfif f.expenseType eq "Group">selected</cfif>>Group</option>
                </select>
            </div>
            <div class="form-group form-group-sm">
                <label class="form-label">Category</label>
                <select name="category" class="form-control">
                    <option value="">All Categories</option>
                    <cfloop array="#expCFC.getCategories()#" index="cat">
                        <option value="#cat#" <cfif f.category eq cat>selected</cfif>>#cat#</option>
                    </cfloop>
                </select>
            </div>
            <div class="form-group form-group-sm">
                <label class="form-label">From Date</label>
                <input type="date" name="dateFrom" class="form-control" value="#htmlEditFormat(f.dateFrom)#">
            </div>
            <div class="form-group form-group-sm">
                <label class="form-label">To Date</label>
                <input type="date" name="dateTo" class="form-control" value="#htmlEditFormat(f.dateTo)#">
            </div>
        </div>
        <div class="filter-actions">
            <button type="submit" class="btn btn-primary btn-sm">Filter</button>
            <a href="/pages/expenses.cfm" class="btn btn-outline btn-sm">Clear</a>
        </div>
    </form>
</div>

<div class="summary-bar">
    <strong>#arrayLen(expenses)# expense(s)</strong> &bull; Total:
    <cfif !structCount(totalByCur)>
        <strong>#application.currencySymbol("")#0.00</strong>
    <cfelse>
        <cfloop collection="#totalByCur#" item="cur">
            <strong>#application.currencySymbol(cur)##numberFormat(totalByCur[cur], "9,999.00")#</strong>
        </cfloop>
    </cfif>
</div>

<cfif arrayLen(expenses)>
<div class="card">
<table class="table table-hover">
    <thead>
        <tr>
            <th>Date</th>
            <th>Description</th>
            <th>Category</th>
            <th>Type</th>
            <th>Mode</th>
            <th class="text-right">Amount</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
    <cfloop array="#expenses#" index="e">
        <cfset eCur = e.expenseType eq "Personal" ? (acctCurrency[e.accountId] ?: application.defaultCurrency) : (groupCurrency[e.groupId] ?: application.defaultCurrency)>
        <tr>
            <td>#dateFormat(e.date, "dd/mm/yy")#</td>
            <td><a href="/pages/expense-detail.cfm?id=#urlEncodedFormat(e._id)#">#htmlEditFormat(e.description)#</a><cfif len(e.receiptFile ?: "")> &##128206;</cfif></td>
            <td><span class="badge">#htmlEditFormat(e.category)#</span></td>
            <td><span class="badge badge-<cfif e.expenseType eq 'Group'>teal<cfelse>blue</cfif>">#htmlEditFormat(e.expenseType)#</span></td>
            <td>#htmlEditFormat(e.paymentMode)#</td>
            <td class="text-right">#application.currencySymbol(eCur)##numberFormat(e.amount, "9,999.00")#</td>
            <td class="actions">
                <a href="/pages/expense-form.cfm?id=#urlEncodedFormat(e._id)#"   class="btn btn-xs btn-outline">Edit</a>
                <form method="post" class="inline-form" onsubmit="return confirm('Delete this expense?')">
                    <input type="hidden" name="csrfToken" value="#htmlEditFormat(session.csrfToken)#">
                    <input type="hidden" name="action" value="delete">
                    <input type="hidden" name="deleteId" value="#htmlEditFormat(e._id)#">
                    <button type="submit" class="btn btn-xs btn-danger">Del</button>
                </form>
            </td>
        </tr>
    </cfloop>
    </tbody>
</table>
</div>
<cfelse>
<div class="empty-state-large">
    <div class="empty-icon">&##128176;</div>
    <h3>No expenses found</h3>
    <p>Try clearing the filters or add a new expense.</p>
    <a href="/pages/expense-form.cfm" class="btn btn-primary">+ Add Expense</a>
</div>
</cfif>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
