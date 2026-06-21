<cfinclude template="/includes/authCheck.cfm">
<cfset pageTitle = "Groups">

<cfset fb     = new components.firebase(application.firebase.projectId, application.firebase.apiKey)>
<cfset grpCFC = new components.group(fb, session.userId, session.idToken)>

<cftry>
    <cfset statusFilter = url.status ?: "Active">
    <cfset groups = grpCFC.getGroups(statusFilter)>
    <cfcatch type="any">
        <cfset loadError = cfcatch.message>
        <cfset groups    = []>
    </cfcatch>
</cftry>

<cfif isDefined("url.delete") && len(url.delete)>
    <cftry>
        <cfset grpCFC.deleteGroup(url.delete)>
        <cflocation url="/pages/groups.cfm?deleted=1" addtoken="false">
        <cfcatch type="any">
            <cfset deleteError = cfcatch.message>
        </cfcatch>
    </cftry>
</cfif>

<cfinclude template="/includes/header.cfm">
<cfinclude template="/includes/nav.cfm">

<cfoutput>
<div class="page-header">
    <h1>Groups</h1>
    <a href="/pages/group-form.cfm" class="btn btn-primary">+ New Group</a>
</div>

<cfif isDefined("loadError")>  <div class="alert alert-danger">#htmlEditFormat(loadError)#</div>  </cfif>
<cfif isDefined("deleteError")><div class="alert alert-danger">#htmlEditFormat(deleteError)#</div></cfif>
<cfif isDefined("url.deleted") && url.deleted><div class="alert alert-success">Group deleted.</div></cfif>
<cfif isDefined("url.saved")   && url.saved>  <div class="alert alert-success">Group saved.</div>  </cfif>

<div class="filter-bar">
    <a href="?status=Active" class="btn <cfif statusFilter eq 'Active'>btn-primary<cfelse>btn-outline</cfif> btn-sm">Active</a>
    <a href="?status=Closed" class="btn <cfif statusFilter eq 'Closed'>btn-primary<cfelse>btn-outline</cfif> btn-sm">Closed</a>
    <a href="?status=All"    class="btn <cfif statusFilter eq 'All'>btn-primary<cfelse>btn-outline</cfif> btn-sm">All</a>
</div>

<cfif arrayLen(groups)>
<div class="card-list">
<cfloop array="#groups#" index="grp">
    <cfset memberCount = grpCFC.getMemberCount(grp._id)>
    <div class="list-card">
        <div class="list-card-main">
            <div class="list-card-title">
                <a href="/pages/group-detail.cfm?id=#urlEncodedFormat(grp._id)#">#htmlEditFormat(grp.groupName)#</a>
                <span class="badge badge-#htmlEditFormat(lCase(grp.status))#">#htmlEditFormat(grp.status)#</span>
            </div>
            <div class="list-card-meta">
                #memberCount# member(s) &bull;
                Started #dateFormat(grp.startDate, "dd mmm yyyy")#
                <cfif len(grp.endDate)> &bull; Ends #dateFormat(grp.endDate, "dd mmm yyyy")#</cfif>
            </div>
            <cfif len(grp.description)>
            <div class="list-card-desc">#htmlEditFormat(grp.description)#</div>
            </cfif>
        </div>
        <div class="list-card-actions">
            <a href="/pages/group-detail.cfm?id=#urlEncodedFormat(grp._id)#"  class="btn btn-sm btn-primary">View</a>
            <a href="/pages/group-form.cfm?id=#urlEncodedFormat(grp._id)#"    class="btn btn-sm btn-outline">Edit</a>
            <a href="/pages/group-members.cfm?groupId=#urlEncodedFormat(grp._id)#" class="btn btn-sm btn-outline">Members</a>
            <a href="?delete=#urlEncodedFormat(grp._id)#" class="btn btn-sm btn-danger"
               onclick="return confirm('Delete this group?')">Delete</a>
        </div>
    </div>
</cfloop>
</div>
<cfelse>
<div class="empty-state-large">
    <div class="empty-icon">&##128101;</div>
    <h3>No groups yet</h3>
    <p>Create a group for trips, events, or shared expenses with friends.</p>
    <a href="/pages/group-form.cfm" class="btn btn-primary">+ Create Group</a>
</div>
</cfif>
</cfoutput>

</main>
<cfinclude template="/includes/footer.cfm">
