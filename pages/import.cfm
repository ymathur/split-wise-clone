<cfinclude template="/includes/authCheck.cfm">
<cfset pageTitle = "Import Expenses">

<cfset fb        = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset accCFC     = new components.account(fb, session.userId, session.idToken)>
<cfset grpCFC     = new components.group(fb, session.userId, session.idToken)>
<cfset expCFC     = new components.expense(fb, session.userId, session.idToken)>
<cfset importCFC  = new components.import(fb, session.userId, session.idToken)>

<cfset accounts   = accCFC.getAccounts("All")>
<cfset groups     = grpCFC.getGroups("All")>

<cfset stage        = "form">
<cfset pageErrors   = []>
<cfset preview      = []>
<cfset expenseType  = isDefined("form.expenseType") ? form.expenseType : "Personal">
<cfset targetId     = isDefined("form.targetId") ? form.targetId : "">
<cfset targetName   = "">
<cfset importedCount = 0>
<cfset failedCount   = 0>
<cfset failMessages  = []>

<cfif cgi.request_method eq "POST" && (form.stage ?: "") eq "preview">
    <cftry>
        <cfset expenseType = form.expenseType ?: "Personal">
        <cfset targetId    = expenseType eq "Group" ? (form.groupId ?: "") : (form.accountId ?: "")>

        <cfif !len(targetId)>
            <cfset arrayAppend(pageErrors, "Please select " & (expenseType eq "Group" ? "a group" : "an account") & ".")>
        </cfif>

        <cfif !arrayLen(pageErrors)>
            <cfset uploadDir = getTempDirectory()>
            <cfset uploadResult = "">
            <cffile action="upload" filefield="csvFile" destination="#uploadDir#" nameconflict="makeunique" accept="text/csv,application/vnd.ms-excel,text/plain" result="uploadResult">

            <cfif uploadResult.fileSize gt 2097152>
                <cfset arrayAppend(pageErrors, "File is too large (max 2MB).")>
                <cffile action="delete" file="#uploadResult.serverDirectory#/#uploadResult.serverFile#">
            <cfelseif listFindNoCase("csv,txt", uploadResult.clientFileExt) eq 0>
                <cfset arrayAppend(pageErrors, "Please upload a .csv file.")>
                <cffile action="delete" file="#uploadResult.serverDirectory#/#uploadResult.serverFile#">
            <cfelse>
                <cfset csvText = fileRead("#uploadResult.serverDirectory#/#uploadResult.serverFile#")>
                <cffile action="delete" file="#uploadResult.serverDirectory#/#uploadResult.serverFile#">

                <cfset rows = importCFC.parseCsv(csvText)>

                <cfif !arrayLen(rows)>
                    <cfset arrayAppend(pageErrors, "The CSV file has no data rows.")>
                <cfelseif arrayLen(rows) gt 1000>
                    <cfset arrayAppend(pageErrors, "Too many rows (" & arrayLen(rows) & "). Maximum is 1000 per import.")>
                <cfelse>
                    <cfif expenseType eq "Group">
                        <cfset targetGroup  = grpCFC.getGroup(targetId)>
                        <cfset targetName   = targetGroup.groupName>
                        <cfset members      = grpCFC.getMembers(targetId)>
                        <cfif !arrayLen(members)>
                            <cfset arrayAppend(pageErrors, "This group has no members yet. Add members before importing.")>
                        <cfelse>
                            <cfset memberMap      = importCFC.buildMemberNameMap(members)>
                            <cfset memberNameById = {}>
                            <cfloop array="#members#" index="mm"><cfset memberNameById[mm.memberId] = mm.name></cfloop>
                            <cfset existingExp    = expCFC.getExpenses({groupId: targetId, expenseType: "Group"})>
                            <cfset existingSigs   = importCFC.buildExistingSignatures(existingExp)>

                            <cfloop array="#rows#" index="i" item="r">
                                <cfset validated = importCFC.validateGroupRow(r, memberMap)>
                                <cfset isDup = false>
                                <cfif validated.valid>
                                    <cfset sig = importCFC.rowSignature(validated.data.date, validated.data.amount, validated.data.description)>
                                    <cfset isDup = structKeyExists(existingSigs, sig)>
                                </cfif>
                                <cfset arrayAppend(preview, {
                                    "rowNum"      : i,
                                    "valid"       : validated.valid,
                                    "errors"      : validated.errors,
                                    "data"        : validated.data,
                                    "splits"      : validated.splits,
                                    "isDuplicate" : isDup
                                })>
                            </cfloop>
                        </cfif>
                    <cfelse>
                        <cfset targetAccount = accCFC.getAccount(targetId)>
                        <cfset targetName    = targetAccount.accountName>
                        <cfset existingExp   = expCFC.getExpenses({accountId: targetId, expenseType: "Personal"})>
                        <cfset existingSigs  = importCFC.buildExistingSignatures(existingExp)>

                        <cfloop array="#rows#" index="i" item="r">
                            <cfset validated = importCFC.validatePersonalRow(r)>
                            <cfset isDup = false>
                            <cfif validated.valid>
                                <cfset sig = importCFC.rowSignature(validated.data.date, validated.data.amount, validated.data.description)>
                                <cfset isDup = structKeyExists(existingSigs, sig)>
                            </cfif>
                            <cfset arrayAppend(preview, {
                                "rowNum"      : i,
                                "valid"       : validated.valid,
                                "errors"      : validated.errors,
                                "data"        : validated.data,
                                "splits"      : [],
                                "isDuplicate" : isDup
                            })>
                        </cfloop>
                    </cfif>

                    <cfif !arrayLen(pageErrors)><cfset stage = "preview"></cfif>
                </cfif>
            </cfif>
        </cfif>

        <cfcatch type="any">
            <cfset arrayAppend(pageErrors, cfcatch.message)>
        </cfcatch>
    </cftry>
</cfif>

<cfif cgi.request_method eq "POST" && (form.stage ?: "") eq "commit">
    <cftry>
        <cfset expenseType = form.expenseType ?: "Personal">
        <cfset targetId    = form.targetId ?: "">
        <cfset stagedRows   = deserializeJSON(form.stagedData ?: "[]")>
        <cfset selectedRows = listToArray(form.selected ?: "")>
        <cfset selectedSet  = {}>
        <cfloop array="#selectedRows#" index="s"><cfset selectedSet[s] = true></cfloop>

        <cfloop array="#stagedRows#" index="item">
            <cfif structKeyExists(selectedSet, item.rowNum) && item.valid>
                <cftry>
                    <cfset expData = item.data>
                    <cfset expData.expenseType = expenseType>
                    <cfif expenseType eq "Group">
                        <cfset expData.groupId = targetId>
                    <cfelse>
                        <cfset expData.accountId = targetId>
                    </cfif>
                    <cfset expCFC.createExpense(expData, item.splits ?: [])>
                    <cfset importedCount++>
                    <cfcatch type="any">
                        <cfset failedCount++>
                        <cfset arrayAppend(failMessages, "Row " & item.rowNum & ": " & cfcatch.message)>
                    </cfcatch>
                </cftry>
            </cfif>
        </cfloop>

        <cfset stage = "done">

        <cfcatch type="any">
            <cfset arrayAppend(pageErrors, cfcatch.message)>
        </cfcatch>
    </cftry>
</cfif>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Import Expenses</h1>
    <a href="/pages/expenses.cfm" class="btn btn-outline">Cancel</a>
</div>

<cfif arrayLen(pageErrors)>
<div class="alert alert-danger">
    <ul class="mb-0">
    <cfloop array="#pageErrors#" index="err">
        <li>#htmlEditFormat(err)#</li>
    </cfloop>
    </ul>
</div>
</cfif>

<cfif stage eq "form">
<div class="card form-card">
    <p class="text-muted">Upload a CSV of past expenses. You'll get a chance to review and pick which rows to import before anything is saved.</p>

    <form method="post" enctype="multipart/form-data">
        <input type="hidden" name="stage" value="preview">

        <div class="form-group">
            <label class="form-label">Import Into</label>
            <div class="btn-group-toggle">
                <label class="toggle-label <cfif expenseType eq 'Personal'>active</cfif>">
                    <input type="radio" name="expenseType" value="Personal" id="typePersonal"
                           <cfif expenseType eq "Personal">checked</cfif>
                           onchange="togglePersonalGroup('Personal')"> Personal Account
                </label>
                <label class="toggle-label <cfif expenseType eq 'Group'>active</cfif>">
                    <input type="radio" name="expenseType" value="Group" id="typeGroup"
                           <cfif expenseType eq "Group">checked</cfif>
                           onchange="togglePersonalGroup('Group')"> Group
                </label>
            </div>
        </div>

        <div id="personalTargetSection" <cfif expenseType eq "Group">style="display:none"</cfif>>
            <div class="form-group">
                <label class="form-label" for="accountId">Account</label>
                <select id="accountId" name="accountId" class="form-control">
                    <option value="">-- Select Account --</option>
                    <cfloop array="#accounts#" index="a">
                        <option value="#htmlEditFormat(a._id)#">#htmlEditFormat(a.accountName)#</option>
                    </cfloop>
                </select>
            </div>
            <p class="text-muted">CSV columns: <code>date, amount, description, category, paymentMode, notes</code>
                &mdash; <a href="/pages/import-template.cfm?type=personal">download template</a></p>
        </div>

        <div id="groupTargetSection" <cfif expenseType eq "Personal">style="display:none"</cfif>>
            <div class="form-group">
                <label class="form-label" for="groupId">Group</label>
                <select id="groupId" name="groupId" class="form-control">
                    <option value="">-- Select Group --</option>
                    <cfloop array="#groups#" index="g">
                        <option value="#htmlEditFormat(g._id)#">#htmlEditFormat(g.groupName)#</option>
                    </cfloop>
                </select>
            </div>
            <p class="text-muted">CSV columns: <code>date, amount, description, category, paymentMode, paidByName, splitType, splitMembers, customShares, notes</code>
                &mdash; member names must match existing group members exactly &mdash;
                <a href="/pages/import-template.cfm?type=group">download template</a></p>
        </div>

        <div class="form-group">
            <label class="form-label" for="csvFile">CSV File</label>
            <input type="file" id="csvFile" name="csvFile" class="form-control" accept=".csv,text/csv" required>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn btn-primary">Preview Import</button>
            <a href="/pages/expenses.cfm" class="btn btn-outline">Cancel</a>
        </div>
    </form>
</div>

<script>
function togglePersonalGroup(type) {
    document.getElementById('personalTargetSection').style.display = type === 'Personal' ? '' : 'none';
    document.getElementById('groupTargetSection').style.display    = type === 'Group'    ? '' : 'none';
}
</script>
</cfif>

<cfif stage eq "preview">
<div class="card form-card">
    <h2>Review &mdash; #htmlEditFormat(targetName)#</h2>
    <p class="text-muted">
        #arrayLen(preview)# row(s) found.
        Rows with errors are disabled. Likely duplicates (same date, amount &amp; description as an existing expense) are unchecked by default &mdash; check them if you still want to import.
    </p>

    <form method="post">
        <input type="hidden" name="stage" value="commit">
        <input type="hidden" name="expenseType" value="#htmlEditFormat(expenseType)#">
        <input type="hidden" name="targetId" value="#htmlEditFormat(targetId)#">
        <input type="hidden" name="stagedData" value="#encodeForHTMLAttribute(serializeJSON(preview))#">

        <table class="table">
            <thead>
                <tr>
                    <th></th>
                    <th>Date</th>
                    <th>Description</th>
                    <th class="text-right">Amount</th>
                    <th>Category</th>
                    <cfif expenseType eq "Group"><th>Paid By</th></cfif>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
            <cfloop array="#preview#" index="item">
                <tr class="<cfif !item.valid>row-disabled<cfelseif item.isDuplicate>row-warning</cfif>">
                    <td>
                        <input type="checkbox" name="selected" value="#item.rowNum#"
                               <cfif !item.valid>disabled<cfelseif !item.isDuplicate>checked</cfif>>
                    </td>
                    <td>#htmlEditFormat(item.data.date)#</td>
                    <td>#htmlEditFormat(item.data.description)#</td>
                    <td class="text-right">#application.currency##numberFormat(val(item.data.amount), "9,999.00")#</td>
                    <td>#htmlEditFormat(item.data.category)#</td>
                    <cfif expenseType eq "Group">
                        <td>#htmlEditFormat(memberNameById[item.data.paidByMemberId] ?: "")#</td>
                    </cfif>
                    <td>
                        <cfif !item.valid>
                            <span class="badge badge-danger" title="#htmlEditFormat(arrayToList(item.errors, '; '))#">Error: #htmlEditFormat(arrayToList(item.errors, '; '))#</span>
                        <cfelseif item.isDuplicate>
                            <span class="badge badge-warning">Possible duplicate</span>
                        <cfelse>
                            <span class="badge badge-success">OK</span>
                        </cfif>
                    </td>
                </tr>
            </cfloop>
            </tbody>
        </table>

        <div class="form-actions">
            <button type="submit" class="btn btn-primary">Import Selected</button>
            <a href="/pages/import.cfm" class="btn btn-outline">Start Over</a>
        </div>
    </form>
</div>
</cfif>

<cfif stage eq "done">
<div class="card form-card">
    <h2>Import Complete</h2>
    <div class="alert alert-success">Imported #importedCount# expense(s).</div>
    <cfif failedCount gt 0>
        <div class="alert alert-danger">
            #failedCount# row(s) failed:
            <ul class="mb-0">
            <cfloop array="#failMessages#" index="fm"><li>#htmlEditFormat(fm)#</li></cfloop>
            </ul>
        </div>
    </cfif>
    <div class="form-actions">
        <a href="/pages/expenses.cfm" class="btn btn-primary">View Expenses</a>
        <a href="/pages/import.cfm" class="btn btn-outline">Import More</a>
    </div>
</div>
</cfif>

</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
