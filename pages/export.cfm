<cfsetting enablecfoutputonly="true">
<cfinclude template="/includes/authCheck.cfm">

<cfscript>
function csvEscape(required string value) {
    var v = arguments.value;
    if (find(",", v) || find('"', v) || find(chr(10), v) || find(chr(13), v)) {
        return '"' & replace(v, '"', '""', "all") & '"';
    }
    return v;
}

function safeFileName(required string name) {
    return reReplace(arguments.name, "[^a-zA-Z0-9_-]", "_", "all");
}
</cfscript>

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset accCFC = new components.account(fb, session.userId, session.idToken)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>
<cfset expCFC = new components.expense(fb, session.userId, session.idToken)>

<cfset exportType = url.type ?: "personal">

<cftry>
    <cfif exportType eq "group">
        <cfset groupId  = url.groupId ?: "">
        <cfif !len(groupId)><cflocation url="/pages/groups.cfm" addtoken="false"></cfif>

        <cfset grp     = grpCFC.getGroup(groupId)>
        <cfset members = grpCFC.getMembers(groupId)>
        <cfset memberNames = {}>
        <cfloop array="#members#" index="m"><cfset memberNames[m.memberId] = m.name></cfloop>

        <cfset expenses = expCFC.getExpenses({groupId: groupId, expenseType: "Group"})>
        <cfset arraySort(expenses, function(a, b) { return compare(a.date, b.date); })>

        <cfset lines = ["date,amount,description,category,paymentMode,paidByName,splitType,splitMembers,customShares,notes"]>
        <cfloop array="#expenses#" index="e">
            <cfset splits      = expCFC.getExpenseSplits(e._id)>
            <cfset paidByName  = memberNames[e.paidByMemberId] ?: "">
            <cfset splitMembersOut = "">
            <cfset customSharesOut = "">

            <cfif e.splitType eq "Custom">
                <cfset parts = []>
                <cfloop array="#splits#" index="s">
                    <cfset arrayAppend(parts, (memberNames[s.memberId] ?: "?") & "=" & numberFormat(val(s.shareAmount), "0.00"))>
                </cfloop>
                <cfset customSharesOut = arrayToList(parts, ";")>
            <cfelse>
                <cfset names = []>
                <cfloop array="#splits#" index="s">
                    <cfset arrayAppend(names, memberNames[s.memberId] ?: "?")>
                </cfloop>
                <cfset splitMembersOut = arrayToList(names, ";")>
            </cfif>

            <cfset arrayAppend(lines, csvEscape(e.date) & "," & numberFormat(val(e.amount), "0.00") & ","
                & csvEscape(e.description) & "," & csvEscape(e.category) & "," & csvEscape(e.paymentMode) & ","
                & csvEscape(paidByName) & "," & csvEscape(e.splitType) & ","
                & csvEscape(splitMembersOut) & "," & csvEscape(customSharesOut) & "," & csvEscape(e.notes))>
        </cfloop>

        <cfset fileName = "group-" & safeFileName(grp.groupName) & "-export.csv">

    <cfelse>
        <cfset accountId = url.accountId ?: "">
        <cfif !len(accountId)><cflocation url="/pages/accounts.cfm" addtoken="false"></cfif>

        <cfset acc = accCFC.getAccount(accountId)>
        <cfset expenses = expCFC.getExpenses({accountId: accountId, expenseType: "Personal"})>
        <cfset arraySort(expenses, function(a, b) { return compare(a.date, b.date); })>

        <cfset lines = ["date,amount,description,category,paymentMode,notes"]>
        <cfloop array="#expenses#" index="e">
            <cfset arrayAppend(lines, csvEscape(e.date) & "," & numberFormat(val(e.amount), "0.00") & ","
                & csvEscape(e.description) & "," & csvEscape(e.category) & "," & csvEscape(e.paymentMode) & ","
                & csvEscape(e.notes))>
        </cfloop>

        <cfset fileName = "personal-" & safeFileName(acc.accountName) & "-export.csv">
    </cfif>

    <cfset csvBody = arrayToList(lines, chr(10)) & chr(10)>

    <cfheader name="Content-Type" value="text/csv">
    <cfheader name="Content-Disposition" value="attachment; filename=#fileName#">
    <cfoutput>#csvBody#</cfoutput>

    <cfcatch type="any">
        <cflocation url="/pages/expenses.cfm?error=1" addtoken="false">
    </cfcatch>
</cftry>
