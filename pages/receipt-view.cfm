<cfinclude template="/includes/authCheck.cfm">

<cfset expId = url.id ?: "">
<cfif !len(expId)>
    <cfheader statuscode="404" statustext="Not Found">
    <cfabort>
</cfif>

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset expCFC = new components.expense(fb, session.userId, session.idToken)>

<cftry>
    <cfset expense    = expCFC.getExpense(expId)>
    <cfset receiptFile = expense.receiptFile ?: "">

    <cfif !len(receiptFile)>
        <cfheader statuscode="404" statustext="Not Found">
        <cfabort>
    </cfif>

    <cfset filePath = application.receiptsDir & receiptFile>

    <!--- Defense in depth: confirm the resolved path is actually inside receiptsDir,
          even though receiptFile is normally only ever set by our own upload code. --->
    <cfset jFile = createObject("java", "java.io.File").init(filePath)>
    <cfset canonicalPath = jFile.getCanonicalPath()>
    <cfset canonicalReceiptsDir = createObject("java", "java.io.File").init(application.receiptsDir).getCanonicalPath()>

    <cfif !len(canonicalPath) || left(canonicalPath, len(canonicalReceiptsDir)) neq canonicalReceiptsDir || !fileExists(canonicalPath)>
        <cfheader statuscode="404" statustext="Not Found">
        <cfabort>
    </cfif>

    <cfset ext = lCase(listLast(canonicalPath, "."))>
    <cfset mimeTypes = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "webp": "image/webp", "heic": "image/heic"}>
    <cfset mimeType = structKeyExists(mimeTypes, ext) ? mimeTypes[ext] : "application/octet-stream">

    <cfheader name="Content-Type" value="#mimeType#">
    <cfheader name="Cache-Control" value="private, max-age=3600">
    <cfcontent file="#canonicalPath#">

    <cfcatch type="any">
        <cfheader statuscode="404" statustext="Not Found">
    </cfcatch>
</cftry>
