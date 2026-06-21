<cfsetting enablecfoutputonly="true">
<cfinclude template="/includes/authCheck.cfm">

<cfset templateType = url.type ?: "personal">

<cfif templateType eq "group">
    <cfset csvBody = "date,amount,description,category,paymentMode,paidByName,splitType,splitMembers,customShares,notes" & chr(10)
        & "2026-07-02,600,Hotel Booking,Accommodation,Card,Alice,Equal,Alice;Bob,,Booked online" & chr(10)
        & "2026-07-03,500,Dinner,Food,Cash,Bob,Custom,,""Alice=200;Bob=300"",Custom split example" & chr(10)>
    <cfset fileName = "group-expense-import-template.csv">
<cfelse>
    <cfset csvBody = "date,amount,description,category,paymentMode,notes" & chr(10)
        & "2026-06-01,250,Groceries,Food,Cash,Weekly groceries" & chr(10)
        & "2026-06-03,1200,Electricity Bill,Miscellaneous,UPI," & chr(10)>
    <cfset fileName = "personal-expense-import-template.csv">
</cfif>

<cfheader name="Content-Type" value="text/csv">
<cfheader name="Content-Disposition" value="attachment; filename=#fileName#">
<cfoutput>#csvBody#</cfoutput>
