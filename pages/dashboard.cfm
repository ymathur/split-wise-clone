<cfinclude template="/includes/authCheck.cfm">
<cfset pageTitle = "Dashboard">

<cfset fb      = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset accCFC  = new components.account(fb, session.userId, session.idToken)>
<cfset grpCFC  = new components.group(fb, session.userId, session.idToken)>
<cfset expCFC  = new components.expense(fb, session.userId, session.idToken)>
<cfset stlCFC  = new components.settlement(fb, session.userId, session.idToken)>

<cftry>
    <cfset accounts      = accCFC.getAccounts()>
    <cfset groups        = grpCFC.getGroups()>
    <cfset recentExp     = expCFC.getExpenses({})>
    <cfset pendingStls   = stlCFC.getSettlements("", "Pending")>

    <!--- Summary numbers --->
    <cfset totalPersonal = 0>
    <cfset totalGroup    = 0>
    <cfset totalBalance  = 0>
    <cfset amtPayable    = 0>
    <cfset amtReceivable = 0>

    <cfloop array="#recentExp#" index="e">
        <cfif e.expenseType eq "Personal">
            <cfset totalPersonal += val(e.amount)>
        <cfelse>
            <cfset totalGroup += val(e.amount)>
        </cfif>
    </cfloop>

    <cfloop array="#accounts#" index="acc">
        <cftry>
            <cfset bal = accCFC.getAccountBalance(acc._id)>
            <cfset totalBalance += bal.balance>
            <cfcatch type="any"></cfcatch>
        </cftry>
    </cfloop>

    <cfloop array="#pendingStls#" index="s">
        <cfif s.fromMemberId eq session.userId>
            <cfset amtPayable += val(s.amount)>
        <cfelse>
            <cfset amtReceivable += val(s.amount)>
        </cfif>
    </cfloop>

    <cfset recentExp5 = []>
    <cfif arrayLen(recentExp) gt 0>
        <cfset recentExp5 = arraySlice(recentExp, 1, min(5, arrayLen(recentExp)))>
    </cfif>

    <cfcatch type="any">
        <cfset dashError = cfcatch.message>
    </cfcatch>
</cftry>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Welcome, #htmlEditFormat(session.userName)#</h1>
    <p class="text-muted">#dateFormat(now(), "ddd, dd mmm yyyy")#</p>
</div>

<cfif isDefined("dashError")>
    <div class="alert alert-danger">#htmlEditFormat(dashError)#</div>
</cfif>

<div class="stats-grid">
    <div class="stat-card stat-blue">
        <div class="stat-icon">&##128179;</div>
        <div class="stat-value">#application.currency##numberFormat(totalBalance, "9,999.00")#</div>
        <div class="stat-label">Total Balance</div>
    </div>
    <div class="stat-card stat-red">
        <div class="stat-icon">&##128176;</div>
        <div class="stat-value">#application.currency##numberFormat(totalPersonal, "9,999.00")#</div>
        <div class="stat-label">Personal Expenses</div>
    </div>
    <div class="stat-card stat-orange">
        <div class="stat-icon">&##128101;</div>
        <div class="stat-value">#application.currency##numberFormat(totalGroup, "9,999.00")#</div>
        <div class="stat-label">Group Expenses</div>
    </div>
    <div class="stat-card stat-green">
        <div class="stat-icon">&##129534;</div>
        <div class="stat-value">#application.currency##numberFormat(amtReceivable, "9,999.00")#</div>
        <div class="stat-label">To Receive</div>
    </div>
    <div class="stat-card stat-purple">
        <div class="stat-icon">&##128197;</div>
        <div class="stat-value">#arrayLen(accounts)#</div>
        <div class="stat-label">Active Accounts</div>
    </div>
    <div class="stat-card stat-teal">
        <div class="stat-icon">&##128101;</div>
        <div class="stat-value">#arrayLen(groups)#</div>
        <div class="stat-label">Active Groups</div>
    </div>
</div>

<div class="quick-actions">
    <a href="/pages/expense-form.cfm"     class="btn btn-primary">+ Add Expense</a>
    <a href="/pages/account-form.cfm"     class="btn btn-secondary">+ New Account</a>
    <a href="/pages/group-form.cfm"       class="btn btn-secondary">+ New Group</a>
    <a href="/pages/reports.cfm"          class="btn btn-outline">Reports</a>
    <a href="/pages/settlements.cfm"      class="btn btn-outline">Settlements</a>
</div>

<div class="two-col">
    <div class="card">
        <div class="card-header">
            <h2>Recent Expenses</h2>
            <a href="/pages/expenses.cfm" class="card-link">View all</a>
        </div>
        <cfif arrayLen(recentExp5)>
        <table class="table">
            <thead>
                <tr><th>Date</th><th>Description</th><th>Category</th><th class="text-right">Amount</th></tr>
            </thead>
            <tbody>
            <cfloop array="#recentExp5#" index="e">
                <tr>
                    <td>#dateFormat(e.date, "dd/mm")#</td>
                    <td><a href="/pages/expense-detail.cfm?id=#urlEncodedFormat(e._id)#">#htmlEditFormat(e.description)#</a></td>
                    <td><span class="badge">#htmlEditFormat(e.category)#</span></td>
                    <td class="text-right">#application.currency##numberFormat(e.amount, "9,999.00")#</td>
                </tr>
            </cfloop>
            </tbody>
        </table>
        <cfelse>
        <p class="empty-state">No expenses yet. <a href="/pages/expense-form.cfm">Add one!</a></p>
        </cfif>
    </div>

    <div class="card">
        <div class="card-header">
            <h2>My Accounts</h2>
            <a href="/pages/accounts.cfm" class="card-link">View all</a>
        </div>
        <cfif arrayLen(accounts)>
        <table class="table">
            <thead>
                <tr><th>Account</th><th class="text-right">Balance</th></tr>
            </thead>
            <tbody>
            <cfloop array="#accounts#" index="acc">
                <cftry>
                <cfset bal = accCFC.getAccountBalance(acc._id)>
                <tr>
                    <td><a href="/pages/expenses.cfm?accountId=#urlEncodedFormat(acc._id)#">#htmlEditFormat(acc.accountName)#</a></td>
                    <td class="text-right <cfif bal.balance lt 0>text-danger<cfelse>text-success</cfif>">
                        #application.currency##numberFormat(bal.balance, "9,999.00")#
                    </td>
                </tr>
                <cfcatch type="any"><cfcontinue></cfcatch>
                </cftry>
            </cfloop>
            </tbody>
        </table>
        <cfelse>
        <p class="empty-state">No accounts. <a href="/pages/account-form.cfm">Create one!</a></p>
        </cfif>
    </div>
</div>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
