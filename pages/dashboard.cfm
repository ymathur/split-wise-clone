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
    <cfset allAccounts   = accCFC.getAccounts("All")>
    <cfset allGroups     = grpCFC.getGroups("All")>
    <cfset recentExp     = expCFC.getExpenses({})>
    <cfset pendingStls   = stlCFC.getSettlements("", "Pending")>

    <cfset acctCurrency = {}>
    <cfloop array="#allAccounts#" index="a"><cfset acctCurrency[a._id] = a.currency></cfloop>
    <cfset groupCurrency = {}>
    <cfloop array="#allGroups#" index="g"><cfset groupCurrency[g._id] = g.currency></cfloop>

    <!--- Summary numbers, split per currency since accounts/groups can each use a different one --->
    <cfset totalPersonalByCur  = {}>
    <cfset totalGroupByCur     = {}>
    <cfset totalBalanceByCur   = {}>
    <cfset amtPayableByCur     = {}>
    <cfset amtReceivableByCur  = {}>

    <cfloop array="#recentExp#" index="e">
        <cfif e.expenseType eq "Personal">
            <cfset cur = acctCurrency[e.accountId] ?: application.defaultCurrency>
            <cfset totalPersonalByCur[cur] = (totalPersonalByCur[cur] ?: 0) + val(e.amount)>
        <cfelse>
            <cfset cur = groupCurrency[e.groupId] ?: application.defaultCurrency>
            <cfset totalGroupByCur[cur] = (totalGroupByCur[cur] ?: 0) + val(e.amount)>
        </cfif>
    </cfloop>

    <cfloop array="#accounts#" index="acc">
        <cftry>
            <cfset bal = accCFC.getAccountBalance(acc._id)>
            <cfset cur = acc.currency ?: application.defaultCurrency>
            <cfset totalBalanceByCur[cur] = (totalBalanceByCur[cur] ?: 0) + bal.balance>
            <cfcatch type="any"></cfcatch>
        </cftry>
    </cfloop>

    <cfloop array="#pendingStls#" index="s">
        <cfset cur = groupCurrency[s.groupId] ?: application.defaultCurrency>
        <cfif s.fromMemberId eq session.userId>
            <cfset amtPayableByCur[cur] = (amtPayableByCur[cur] ?: 0) + val(s.amount)>
        <cfelse>
            <cfset amtReceivableByCur[cur] = (amtReceivableByCur[cur] ?: 0) + val(s.amount)>
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
<cfif isDefined("url.error") && url.error eq "invalid_request">
    <div class="alert alert-danger">Your request could not be verified (it may have expired). Please try again.</div>
</cfif>

<div class="stats-grid">
    <div class="stat-card stat-blue">
        <div class="stat-icon">&##128179;</div>
        <div class="stat-value">
            <cfif !structCount(totalBalanceByCur)>#application.currencySymbol("")#0.00<cfelse>
                <cfloop collection="#totalBalanceByCur#" item="cur">
                    <div>#application.currencySymbol(cur)##numberFormat(totalBalanceByCur[cur], "9,999.00")#</div>
                </cfloop>
            </cfif>
        </div>
        <div class="stat-label">Total Balance</div>
    </div>
    <div class="stat-card stat-red">
        <div class="stat-icon">&##128176;</div>
        <div class="stat-value">
            <cfif !structCount(totalPersonalByCur)>#application.currencySymbol("")#0.00<cfelse>
                <cfloop collection="#totalPersonalByCur#" item="cur">
                    <div>#application.currencySymbol(cur)##numberFormat(totalPersonalByCur[cur], "9,999.00")#</div>
                </cfloop>
            </cfif>
        </div>
        <div class="stat-label">Personal Expenses</div>
    </div>
    <div class="stat-card stat-orange">
        <div class="stat-icon">&##128101;</div>
        <div class="stat-value">
            <cfif !structCount(totalGroupByCur)>#application.currencySymbol("")#0.00<cfelse>
                <cfloop collection="#totalGroupByCur#" item="cur">
                    <div>#application.currencySymbol(cur)##numberFormat(totalGroupByCur[cur], "9,999.00")#</div>
                </cfloop>
            </cfif>
        </div>
        <div class="stat-label">Group Expenses</div>
    </div>
    <div class="stat-card stat-green">
        <div class="stat-icon">&##129534;</div>
        <div class="stat-value">
            <cfif !structCount(amtReceivableByCur)>#application.currencySymbol("")#0.00<cfelse>
                <cfloop collection="#amtReceivableByCur#" item="cur">
                    <div>#application.currencySymbol(cur)##numberFormat(amtReceivableByCur[cur], "9,999.00")#</div>
                </cfloop>
            </cfif>
        </div>
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
                <cfset eCur = e.expenseType eq "Personal" ? (acctCurrency[e.accountId] ?: application.defaultCurrency) : (groupCurrency[e.groupId] ?: application.defaultCurrency)>
                <tr>
                    <td>#dateFormat(e.date, "dd/mm")#</td>
                    <td><a href="/pages/expense-detail.cfm?id=#urlEncodedFormat(e._id)#">#htmlEditFormat(e.description)#</a></td>
                    <td><span class="badge">#htmlEditFormat(e.category)#</span></td>
                    <td class="text-right">#application.currencySymbol(eCur)##numberFormat(e.amount, "9,999.00")#</td>
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
                        #application.currencySymbol(acc.currency)##numberFormat(bal.balance, "9,999.00")#
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
