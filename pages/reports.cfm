<cfinclude template="/includes/authCheck.cfm">
<cfset pageTitle = "Reports">

<cfset fb      = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset rptCFC  = new components.report(fb, session.userId, session.idToken)>
<cfset accCFC  = new components.account(fb, session.userId, session.idToken)>
<cfset grpCFC  = new components.group(fb, session.userId, session.idToken)>

<cfset reportType = url.reportType ?: "personal">
<cfset accounts   = accCFC.getAccounts("All")>
<cfset groups     = grpCFC.getGroups("All")>

<cfset f = {
    accountId   : url.accountId  ?: "",
    groupId     : url.groupId    ?: "",
    dateFrom    : url.dateFrom   ?: "",
    dateTo      : url.dateTo     ?: "",
    category    : url.category   ?: "",
    paymentMode : url.paymentMode ?: ""
}>

<cfset reportData    = {}>
<cfset reportGenerated = false>
<cfset expCFC = new components.expense(fb, session.userId, session.idToken)>

<cfif isDefined("url.generate")>
    <cftry>
        <cfif reportType eq "group" && len(f.groupId)>
            <cfset reportData = rptCFC.getGroupReport(f.groupId, f)>
        <cfelse>
            <cfset reportData = rptCFC.getPersonalReport(f)>
            <cfset reportType = "personal">
        </cfif>
        <cfset reportGenerated = true>
        <cfcatch type="any">
            <cfset reportError = cfcatch.message>
        </cfcatch>
    </cftry>
</cfif>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Reports</h1>
</div>

<cfif isDefined("reportError")>
    <div class="alert alert-danger">#htmlEditFormat(reportError)#</div>
</cfif>

<!--- Report Type Tabs --->
<div class="tabs">
    <a href="?reportType=personal" class="tab <cfif reportType eq 'personal'>tab-active</cfif>">Personal Expenses</a>
    <a href="?reportType=group"    class="tab <cfif reportType eq 'group'>tab-active</cfif>">Group Expenses</a>
</div>

<!--- Filter Form --->
<div class="card filter-card">
    <form method="get" class="filter-form">
        <input type="hidden" name="reportType" value="#htmlEditFormat(reportType)#">
        <input type="hidden" name="generate"   value="1">
        <div class="filter-row">
            <cfif reportType eq "personal">
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
                <label class="form-label">Category</label>
                <select name="category" class="form-control">
                    <option value="">All</option>
                    <cfloop array="#expCFC.getCategories()#" index="cat">
                        <option value="#cat#" <cfif f.category eq cat>selected</cfif>>#cat#</option>
                    </cfloop>
                </select>
            </div>
            <div class="form-group form-group-sm">
                <label class="form-label">Payment Mode</label>
                <select name="paymentMode" class="form-control">
                    <option value="">All</option>
                    <cfloop array="#expCFC.getPaymentModes()#" index="pm">
                        <option value="#pm#" <cfif f.paymentMode eq pm>selected</cfif>>#pm#</option>
                    </cfloop>
                </select>
            </div>
            <cfelseif reportType eq "group">
            <div class="form-group form-group-sm">
                <label class="form-label">Group <span class="required">*</span></label>
                <select name="groupId" class="form-control" required>
                    <option value="">-- Select Group --</option>
                    <cfloop array="#groups#" index="g">
                        <option value="#htmlEditFormat(g._id)#" <cfif f.groupId eq g._id>selected</cfif>>#htmlEditFormat(g.groupName)#</option>
                    </cfloop>
                </select>
            </div>
            </cfif>
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
            <button type="submit" class="btn btn-primary">Generate Report</button>
            <a href="?reportType=#urlEncodedFormat(reportType)#" class="btn btn-outline">Clear</a>
        </div>
    </form>
</div>

<!--- Report Output --->
<cfif reportGenerated>
    <cfset reportCurSym = len(reportData.currency ?: "") ? application.currencySymbol(reportData.currency) : application.currencySymbol("")>
    <cfif reportType eq "personal">
        <!--- Personal Report --->
        <div class="stats-grid stats-grid-3">
            <div class="stat-card stat-blue">
                <div class="stat-value">#reportCurSym##numberFormat(reportData.openingAmount, "9,999.00")#</div>
                <div class="stat-label">Opening Amount</div>
            </div>
            <div class="stat-card stat-red">
                <div class="stat-value">
                    <cfif !structCount(reportData.totalByCur)>#reportCurSym#0.00<cfelse>
                        <cfloop collection="#reportData.totalByCur#" item="cur">
                            <div>#application.currencySymbol(cur)##numberFormat(reportData.totalByCur[cur], "9,999.00")#</div>
                        </cfloop>
                    </cfif>
                </div>
                <div class="stat-label">Total Spent</div>
            </div>
            <div class="stat-card stat-<cfif reportData.balance lt 0>red<cfelse>green</cfif>">
                <div class="stat-value">#reportCurSym##numberFormat(reportData.balance, "9,999.00")#</div>
                <div class="stat-label">Balance</div>
            </div>
        </div>

        <cfif structCount(reportData.categoryTotals)>
        <div class="card">
            <div class="card-header"><h2>Category-wise Total</h2></div>
            <table class="table">
                <thead><tr><th>Category</th><th class="text-right">Amount</th><th class="text-right">%</th></tr></thead>
                <tbody>
                <cfset catKeys = structKeyArray(reportData.categoryTotals)>
                <cfset arraySort(catKeys, function(a,b) { return reportData.categoryTotals[b] - reportData.categoryTotals[a]; })>
                <cfloop array="#catKeys#" index="cat">
                    <cfset pct = reportData.totalExpenses gt 0 ? (reportData.categoryTotals[cat] / reportData.totalExpenses * 100) : 0>
                    <tr>
                        <td>#cat#</td>
                        <td class="text-right">#reportCurSym##numberFormat(reportData.categoryTotals[cat], "9,999.00")#</td>
                        <td class="text-right">#numberFormat(pct, "9.0")#%</td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </div>
        </cfif>

        <div class="card">
            <div class="card-header"><h2>Expense List (#arrayLen(reportData.expenses)#)</h2></div>
            <cfif arrayLen(reportData.expenses)>
            <table class="table">
                <thead><tr><th>Date</th><th>Description</th><th>Category</th><th>Mode</th><th class="text-right">Amount</th></tr></thead>
                <tbody>
                <cfloop array="#reportData.expenses#" index="e">
                    <tr>
                        <td>#dateFormat(e.date, "dd mmm yyyy")#</td>
                        <td>#htmlEditFormat(e.description)#</td>
                        <td><span class="badge">#htmlEditFormat(e.category)#</span></td>
                        <td>#htmlEditFormat(e.paymentMode)#</td>
                        <td class="text-right">#application.currencySymbol(reportData.acctCurrency[e.accountId] ?: "")##numberFormat(e.amount, "9,999.00")#</td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
            <cfelse>
            <p class="empty-state">No expenses match the selected filters.</p>
            </cfif>
        </div>

    <cfelseif reportType eq "group">
        <!--- Group Report --->
        <cfset groupCurSym = application.currencySymbol(reportData.group.currency)>
        <div class="card">
            <div class="card-header">
                <h2>#htmlEditFormat(reportData.group.groupName)#</h2>
                <span class="badge badge-#htmlEditFormat(lCase(reportData.group.status))#">#htmlEditFormat(reportData.group.status)#</span>
            </div>
            <div class="stats-grid stats-grid-3">
                <div class="stat-card stat-blue">
                    <div class="stat-value">#groupCurSym##numberFormat(reportData.totalSpend, "9,999.00")#</div>
                    <div class="stat-label">Total Spent</div>
                </div>
                <div class="stat-card stat-teal">
                    <div class="stat-value">#arrayLen(reportData.members)#</div>
                    <div class="stat-label">Members</div>
                </div>
                <div class="stat-card stat-orange">
                    <div class="stat-value">#arrayLen(reportData.expenses)#</div>
                    <div class="stat-label">Expenses</div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-header"><h2>Member Summary</h2></div>
            <table class="table">
                <thead>
                    <tr><th>Member</th><th class="text-right">Paid</th><th class="text-right">Share</th><th class="text-right">Net Balance</th></tr>
                </thead>
                <tbody>
                <cfloop array="#reportData.balances#" index="b">
                    <tr>
                        <td><strong>#htmlEditFormat(b.name)#</strong></td>
                        <td class="text-right">#groupCurSym##numberFormat(b.totalPaid, "9,999.00")#</td>
                        <td class="text-right">#groupCurSym##numberFormat(b.totalShare, "9,999.00")#</td>
                        <td class="text-right <cfif b.netBalance gt 0>text-success<cfelseif b.netBalance lt 0>text-danger<cfelse>text-muted</cfif>">
                            <cfif b.netBalance gt 0>+</cfif>#groupCurSym##numberFormat(b.netBalance, "9,999.00")#
                        </td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </div>

        <div class="card">
            <div class="card-header"><h2>Expense List</h2></div>
            <cfif arrayLen(reportData.expenses)>
            <table class="table">
                <thead><tr><th>Date</th><th>Description</th><th>Category</th><th>Paid By</th><th class="text-right">Amount</th></tr></thead>
                <tbody>
                <cfloop array="#reportData.expenses#" index="e">
                    <tr>
                        <td>#dateFormat(e.date, "dd mmm yyyy")#</td>
                        <td>#htmlEditFormat(e.description)#</td>
                        <td><span class="badge">#htmlEditFormat(e.category)#</span></td>
                        <td>#htmlEditFormat(reportData.memberMap[e.paidByMemberId] ?: "—")#</td>
                        <td class="text-right">#groupCurSym##numberFormat(e.amount, "9,999.00")#</td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
            <cfelse>
            <p class="empty-state">No expenses match the selected filters.</p>
            </cfif>
        </div>
    </cfif>
</cfif>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
