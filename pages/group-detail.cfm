<cfinclude template="/includes/authCheck.cfm">

<cfset groupId = url.id ?: "">
<cfif !len(groupId)><cflocation url="/pages/groups.cfm" addtoken="false"></cfif>

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>
<cfset expCFC = new components.expense(fb, session.userId, session.idToken)>
<cfset stlCFC = new components.settlement(fb, session.userId, session.idToken)>

<cftry>
    <cfset grp        = grpCFC.getGroup(groupId)>
    <cfset members    = grpCFC.getMembers(groupId)>
    <cfset expenses   = expCFC.getExpenses({groupId: groupId})>
    <cfset settlements= stlCFC.getSettlements(groupId)>

    <!--- Collect splits --->
    <cfset allSplits = []>
    <cfloop array="#expenses#" index="e">
        <cfset splits = expCFC.getExpenseSplits(e._id)>
        <cfloop array="#splits#" index="s"><cfset arrayAppend(allSplits, s)></cfloop>
    </cfloop>

    <cfset balances    = stlCFC.calculateBalances(groupId, members, expenses, allSplits, settlements)>
    <cfset suggestions = stlCFC.suggestSettlements(balances)>

    <!--- Build member name lookup --->
    <cfset memberNames = {}>
    <cfloop array="#members#" index="m">
        <cfset memberNames[m.memberId] = m.name>
    </cfloop>

    <cfset totalSpend = 0>
    <cfloop array="#expenses#" index="e"><cfset totalSpend += val(e.amount)></cfloop>

    <cfset pageTitle = grp.groupName>

    <cfcatch type="any">
        <cflocation url="/pages/groups.cfm?error=1" addtoken="false">
    </cfcatch>
</cftry>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <div>
        <h1>#htmlEditFormat(grp.groupName)#</h1>
        <span class="badge badge-#lCase(grp.status)#">#grp.status#</span>
        <cfif len(grp.description)><p class="text-muted">#htmlEditFormat(grp.description)#</p></cfif>
    </div>
    <div class="header-actions">
        <a href="/pages/expense-form.cfm?groupId=#urlEncodedFormat(groupId)#" class="btn btn-primary">+ Add Expense</a>
        <a href="/pages/group-members.cfm?groupId=#urlEncodedFormat(groupId)#" class="btn btn-outline">Members</a>
        <a href="/pages/group-form.cfm?id=#urlEncodedFormat(groupId)#" class="btn btn-outline">Edit</a>
        <a href="/pages/export.cfm?type=group&groupId=#urlEncodedFormat(groupId)#" class="btn btn-outline">Export CSV</a>
    </div>
</div>

<div class="stats-grid stats-grid-3">
    <div class="stat-card stat-blue">
        <div class="stat-value">#application.currency##numberFormat(totalSpend, "9,999.00")#</div>
        <div class="stat-label">Total Spent</div>
    </div>
    <div class="stat-card stat-teal">
        <div class="stat-value">#arrayLen(members)#</div>
        <div class="stat-label">Members</div>
    </div>
    <div class="stat-card stat-orange">
        <div class="stat-value">#arrayLen(expenses)#</div>
        <div class="stat-label">Expenses</div>
    </div>
</div>

<!--- Member Balances --->
<div class="card">
    <div class="card-header">
        <h2>Member Balances</h2>
        <a href="/pages/settlements.cfm?groupId=#urlEncodedFormat(groupId)#" class="card-link">Settlements</a>
    </div>
    <cfif arrayLen(balances)>
    <table class="table">
        <thead>
            <tr>
                <th>Member</th>
                <th class="text-right">Paid</th>
                <th class="text-right">Share</th>
                <th class="text-right">Net</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
        <cfloop array="#balances#" index="b">
            <tr>
                <td><strong>#htmlEditFormat(b.name)#</strong></td>
                <td class="text-right">#application.currency##numberFormat(b.totalPaid, "9,999.00")#</td>
                <td class="text-right">#application.currency##numberFormat(b.totalShare, "9,999.00")#</td>
                <td class="text-right <cfif b.netBalance gt 0>text-success<cfelseif b.netBalance lt 0>text-danger<cfelse>text-muted</cfif>">
                    <cfif b.netBalance gt 0>+</cfif>#application.currency##numberFormat(abs(b.netBalance), "9,999.00")#
                </td>
                <td>
                    <cfif b.netBalance gt 0.01>
                        <span class="badge badge-success">to receive</span>
                    <cfelseif b.netBalance lt -0.01>
                        <span class="badge badge-danger">to pay</span>
                    <cfelse>
                        <span class="badge">settled</span>
                    </cfif>
                </td>
            </tr>
        </cfloop>
        </tbody>
    </table>
    <cfelse>
    <p class="empty-state">No members yet. <a href="/pages/group-members.cfm?groupId=#urlEncodedFormat(groupId)#">Add members</a></p>
    </cfif>
</div>

<!--- Suggested Settlements --->
<cfif arrayLen(suggestions)>
<div class="card">
    <div class="card-header">
        <h2>Suggested Settlements</h2>
    </div>
    <table class="table">
        <thead>
            <tr><th>From</th><th>To</th><th class="text-right">Amount</th><th></th></tr>
        </thead>
        <tbody>
        <cfloop array="#suggestions#" index="sug">
            <tr>
                <td>#htmlEditFormat(sug.fromName)#</td>
                <td>#htmlEditFormat(sug.toName)#</td>
                <td class="text-right">#application.currency##numberFormat(sug.amount, "9,999.00")#</td>
                <td>
                    <a href="/pages/settlement-form.cfm?groupId=#urlEncodedFormat(groupId)#&fromId=#urlEncodedFormat(sug.fromMemberId)#&toId=#urlEncodedFormat(sug.toMemberId)#&amount=#urlEncodedFormat(sug.amount)#"
                       class="btn btn-sm btn-primary">Record</a>
                </td>
            </tr>
        </cfloop>
        </tbody>
    </table>
</div>
</cfif>

<!--- Expense List --->
<div class="card">
    <div class="card-header">
        <h2>Expenses</h2>
        <a href="/pages/expense-form.cfm?groupId=#urlEncodedFormat(groupId)#" class="card-link">+ Add</a>
    </div>
    <cfif arrayLen(expenses)>
    <table class="table">
        <thead>
            <tr><th>Date</th><th>Description</th><th>Category</th><th>Paid By</th><th class="text-right">Amount</th><th></th></tr>
        </thead>
        <tbody>
        <cfloop array="#expenses#" index="e">
            <tr>
                <td>#dateFormat(e.date, "dd/mm/yy")#</td>
                <td><a href="/pages/expense-detail.cfm?id=#urlEncodedFormat(e._id)#">#htmlEditFormat(e.description)#</a></td>
                <td><span class="badge">#e.category#</span></td>
                <td>#len(e.paidByMemberId) && structKeyExists(memberNames, e.paidByMemberId) ? htmlEditFormat(memberNames[e.paidByMemberId]) : "—"#</td>
                <td class="text-right">#application.currency##numberFormat(e.amount, "9,999.00")#</td>
                <td>
                    <a href="/pages/expense-form.cfm?id=#urlEncodedFormat(e._id)#" class="btn btn-xs btn-outline">Edit</a>
                </td>
            </tr>
        </cfloop>
        </tbody>
    </table>
    <cfelse>
    <p class="empty-state">No group expenses yet. <a href="/pages/expense-form.cfm?groupId=#urlEncodedFormat(groupId)#">Add one!</a></p>
    </cfif>
</div>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
