<cfinclude template="/includes/authCheck.cfm">
<cfinclude template="/includes/csrfCheck.cfm">
<cfset pageTitle = "Accounts">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset accCFC = new components.account(fb, session.userId, session.idToken)>

<cftry>
    <cfset statusFilter = url.status ?: "Active">
    <cfset accounts = accCFC.getAccounts(statusFilter)>
    <cfcatch type="any">
        <cfset loadError = cfcatch.message>
        <cfset accounts  = []>
    </cfcatch>
</cftry>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Accounts</h1>
    <a href="/pages/account-form.cfm" class="btn btn-primary">+ New Account</a>
</div>

<cfif isDefined("loadError")>
    <div class="alert alert-danger">#htmlEditFormat(loadError)#</div>
</cfif>

<cfif isDefined("url.deleted") && url.deleted eq "1">
    <div class="alert alert-success">Account deleted.</div>
</cfif>
<cfif isDefined("url.saved") && url.saved eq "1">
    <div class="alert alert-success">Account saved.</div>
</cfif>

<div class="filter-bar">
    <a href="?status=Active"  class="btn <cfif statusFilter eq 'Active'>btn-primary<cfelse>btn-outline</cfif> btn-sm">Active</a>
    <a href="?status=Closed" class="btn <cfif statusFilter eq 'Closed'>btn-primary<cfelse>btn-outline</cfif> btn-sm">Closed</a>
    <a href="?status=All"    class="btn <cfif statusFilter eq 'All'>btn-primary<cfelse>btn-outline</cfif> btn-sm">All</a>
</div>

<cfif arrayLen(accounts)>
<div class="card-list">
<cfloop array="#accounts#" index="acc">
    <cftry>
    <cfset bal = accCFC.getAccountBalance(acc._id)>
    <div class="list-card">
        <div class="list-card-main">
            <div class="list-card-title">
                <a href="/pages/expenses.cfm?accountId=#urlEncodedFormat(acc._id)#">#htmlEditFormat(acc.accountName)#</a>
                <span class="badge badge-#htmlEditFormat(lCase(acc.status))#">#htmlEditFormat(acc.status)#</span>
            </div>
            <div class="list-card-meta">
                Started #dateFormat(acc.startDate, "dd mmm yyyy")#
                <cfif len(acc.notes)> &bull; #htmlEditFormat(acc.notes)#</cfif>
            </div>
            <div class="balance-row">
                <span>Opening: <strong>#application.currency##numberFormat(bal.openingAmount, "9,999.00")#</strong></span>
                <span>Spent: <strong class="text-danger">#application.currency##numberFormat(bal.totalExpenses, "9,999.00")#</strong></span>
                <span>Balance: <strong class="<cfif bal.balance lt 0>text-danger<cfelse>text-success</cfif>">#application.currency##numberFormat(bal.balance, "9,999.00")#</strong></span>
            </div>
        </div>
        <div class="list-card-actions">
            <a href="/pages/account-form.cfm?id=#urlEncodedFormat(acc._id)#" class="btn btn-sm btn-outline">Edit</a>
            <a href="/pages/expenses.cfm?accountId=#urlEncodedFormat(acc._id)#" class="btn btn-sm btn-outline">Expenses</a>
            <a href="/pages/export.cfm?type=personal&accountId=#urlEncodedFormat(acc._id)#" class="btn btn-sm btn-outline">Export CSV</a>
            <form method="post" class="inline-form" onsubmit="return confirm('Delete this account?')">
                <input type="hidden" name="csrfToken" value="#htmlEditFormat(session.csrfToken)#">
                <input type="hidden" name="action" value="delete">
                <input type="hidden" name="deleteId" value="#htmlEditFormat(acc._id)#">
                <button type="submit" class="btn btn-sm btn-danger" title="Delete">Delete</button>
            </form>
        </div>
    </div>
    <cfcatch type="any"><cfcontinue></cfcatch>
    </cftry>
</cfloop>
</div>
<cfelse>
<div class="empty-state-large">
    <div class="empty-icon">&##128179;</div>
    <h3>No accounts yet</h3>
    <p>Create an account to track your cash or trip expenses.</p>
    <a href="/pages/account-form.cfm" class="btn btn-primary">+ Create Account</a>
</div>
</cfif>
</cfoutput>

<!--- Handle delete --->
<cfif cgi.request_method eq "POST" && (form.action ?: "") eq "delete" && len(form.deleteId ?: "")>
    <cftry>
        <cfset accCFC.deleteAccount(form.deleteId)>
        <cflocation url="/pages/accounts.cfm?deleted=1" addtoken="false">
        <cfcatch type="any">
            <cfoutput><div class="alert alert-danger">#htmlEditFormat(cfcatch.message)#</div></cfoutput>
        </cfcatch>
    </cftry>
</cfif>

</main>
<cfinclude template="/includes/footer.cfm">
