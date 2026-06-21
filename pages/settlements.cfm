<cfinclude template="/includes/authCheck.cfm">
<cfinclude template="/includes/csrfCheck.cfm">
<cfset pageTitle = "Settlements">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset stlCFC = new components.settlement(fb, session.userId, session.idToken)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>

<cfset groupFilter  = url.groupId ?: "">
<cfset statusFilter = url.status  ?: "">

<cftry>
    <cfset settlements = stlCFC.getSettlements(groupFilter, statusFilter)>
    <cfset groups      = grpCFC.getGroups("All")>

    <!--- Build group name lookup --->
    <cfset groupNames = {}>
    <cfloop array="#groups#" index="g">
        <cfset groupNames[g._id] = g.groupName>
    </cfloop>

    <!--- Build member name lookups per group --->
    <cfset memberNames = {}>
    <cfset loadedGroups = {}>
    <cfloop array="#settlements#" index="s">
        <cfif len(s.groupId) && !structKeyExists(loadedGroups, s.groupId)>
            <cfset loadedGroups[s.groupId] = true>
            <cfset gMembers = grpCFC.getMembers(s.groupId)>
            <cfloop array="#gMembers#" index="m">
                <cfset memberNames[m.memberId] = m.name>
            </cfloop>
        </cfif>
    </cfloop>

    <cfcatch type="any">
        <cfset loadError   = cfcatch.message>
        <cfset settlements = []>
        <cfset groups      = []>
        <cfset groupNames  = {}>
        <cfset memberNames = {}>
    </cfcatch>
</cftry>

<!--- Handle mark as paid --->
<cfif cgi.request_method eq "POST" && (form.action ?: "") eq "markPaid" && len(form.markPaidId ?: "")>
    <cftry>
        <cfset stlCFC.markAsPaid(form.markPaidId)>
        <cflocation url="/pages/settlements.cfm?paid=1" addtoken="false">
        <cfcatch type="any">
            <cfset paidError = cfcatch.message>
        </cfcatch>
    </cftry>
</cfif>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Settlements</h1>
    <a href="/pages/settlement-form.cfm" class="btn btn-primary">+ New Settlement</a>
</div>

<cfif isDefined("loadError")><div class="alert alert-danger">#htmlEditFormat(loadError)#</div></cfif>
<cfif isDefined("paidError")><div class="alert alert-danger">#htmlEditFormat(paidError)#</div></cfif>
<cfif isDefined("url.paid") && url.paid><div class="alert alert-success">Settlement marked as paid!</div></cfif>

<div class="filter-bar">
    <form method="get" class="inline-form">
        <select name="groupId" class="form-control form-control-sm" onchange="this.form.submit()">
            <option value="">All Groups</option>
            <cfloop array="#groups#" index="g">
                <option value="#htmlEditFormat(g._id)#" <cfif groupFilter eq g._id>selected</cfif>>#htmlEditFormat(g.groupName)#</option>
            </cfloop>
        </select>
        <select name="status" class="form-control form-control-sm" onchange="this.form.submit()">
            <option value="">All Statuses</option>
            <option value="Pending" <cfif statusFilter eq "Pending">selected</cfif>>Pending</option>
            <option value="Paid"    <cfif statusFilter eq "Paid">selected</cfif>>Paid</option>
        </select>
        <a href="/pages/settlements.cfm" class="btn btn-outline btn-sm">Clear</a>
    </form>
</div>

<cfif arrayLen(settlements)>
<div class="card">
<table class="table table-hover">
    <thead>
        <tr>
            <th>Date</th>
            <th>Group</th>
            <th>From</th>
            <th>To</th>
            <th>Mode</th>
            <th class="text-right">Amount</th>
            <th>Status</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
    <cfloop array="#settlements#" index="s">
        <tr>
            <td>#dateFormat(s.date, "dd/mm/yy")#</td>
            <td>#htmlEditFormat(groupNames[s.groupId] ?: s.groupId)#</td>
            <td>#htmlEditFormat(memberNames[s.fromMemberId] ?: s.fromMemberId)#</td>
            <td>#htmlEditFormat(memberNames[s.toMemberId]   ?: s.toMemberId)#</td>
            <td>#htmlEditFormat(s.paymentMode)#</td>
            <td class="text-right">#application.currency##numberFormat(s.amount, "9,999.00")#</td>
            <td>
                <span class="badge badge-<cfif s.status eq 'Paid'>success<cfelse>warning</cfif>">#htmlEditFormat(s.status)#</span>
            </td>
            <td class="actions">
                <cfif s.status eq "Pending">
                <form method="post" class="inline-form" onsubmit="return confirm('Mark as paid?')">
                    <input type="hidden" name="csrfToken" value="#htmlEditFormat(session.csrfToken)#">
                    <input type="hidden" name="action" value="markPaid">
                    <input type="hidden" name="markPaidId" value="#htmlEditFormat(s._id)#">
                    <button type="submit" class="btn btn-xs btn-success">Mark Paid</button>
                </form>
                </cfif>
            </td>
        </tr>
    </cfloop>
    </tbody>
</table>
</div>
<cfelse>
<div class="empty-state-large">
    <div class="empty-icon">&##129534;</div>
    <h3>No settlements found</h3>
    <p>Settlements are created from the Group Detail page or manually.</p>
    <a href="/pages/groups.cfm" class="btn btn-primary">Go to Groups</a>
</div>
</cfif>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
