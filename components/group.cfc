component {

    variables.fb      = "";
    variables.userId  = "";
    variables.idToken = "";

    function init(required fb, required string userId, required string idToken) {
        variables.fb      = arguments.fb;
        variables.userId  = arguments.userId;
        variables.idToken = arguments.idToken;
        return this;
    }

    // ── Groups ────────────────────────────────────────────────────────────

    function createGroup(required struct data) {
        var id  = variables.fb.generateId();
        var now = variables.fb._now();
        var doc = {
            "groupId"       : id,
            "ownerUserId"   : variables.userId,
            "groupName"     : arguments.data.groupName,
            "description"   : arguments.data.description   ?: "",
            "startDate"     : arguments.data.startDate     ?: dateFormat(now(), "yyyy-mm-dd"),
            "endDate"       : arguments.data.endDate       ?: "",
            "openingAmount" : val(arguments.data.openingAmount ?: 0),
            "status"        : "Active",
            "createdAt"     : now,
            "updatedAt"     : now
        };
        var result = variables.fb.setDocument("groups", id, doc, variables.idToken);
        if (result.success) return id;
        throw(type="FirestoreError", message=result.error ?: "Failed to create group");
    }

    function getGroups(string status = "Active") {
        var filters = [
            variables.fb.fieldFilter("ownerUserId", "EQUAL", variables.userId)
        ];
        if (len(arguments.status) && arguments.status != "All") {
            arrayAppend(filters, variables.fb.fieldFilter("status", "EQUAL", arguments.status));
        }
        var result = variables.fb.queryCollection(
            collection = "groups",
            filters    = filters,
            idToken    = variables.idToken
        );
        if (!result.success) return [];
        var list = arrayFilter(result.data, function(g) { return g.status != "Deleted"; });
        arraySort(list, function(a, b) { return compare(b.createdAt, a.createdAt); });
        return list;
    }

    function getGroup(required string groupId) {
        var result = variables.fb.getDocument("groups", arguments.groupId, variables.idToken);
        if (result.success && result.data.ownerUserId == variables.userId) return result.data;
        throw(type="NotFoundError", message="Group not found");
    }

    function updateGroup(required string groupId, required struct data) {
        var existing = getGroup(arguments.groupId);
        var updates = {
            "groupName"     : arguments.data.groupName     ?: existing.groupName,
            "description"   : arguments.data.description   ?: existing.description,
            "startDate"     : arguments.data.startDate     ?: existing.startDate,
            "endDate"       : arguments.data.endDate       ?: existing.endDate,
            "openingAmount" : val(arguments.data.openingAmount ?: existing.openingAmount),
            "status"        : arguments.data.status        ?: existing.status,
            "updatedAt"     : variables.fb._now()
        };
        var result = variables.fb.updateDocument("groups", arguments.groupId, updates, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message=result.error ?: "Failed to update group");
    }

    function deleteGroup(required string groupId) {
        getGroup(arguments.groupId);
        var result = variables.fb.softDelete("groups", arguments.groupId, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message="Failed to delete group");
    }

    // ── Members ───────────────────────────────────────────────────────────

    function addMember(required string groupId, required struct data) {
        getGroup(arguments.groupId); // verify ownership
        var id  = variables.fb.generateId();
        var now = variables.fb._now();
        var doc = {
            "memberId"     : id,
            "groupId"      : arguments.groupId,
            "name"         : arguments.data.name,
            "email"        : arguments.data.email        ?: "",
            "mobile"       : arguments.data.mobile       ?: "",
            "linkedUserId" : arguments.data.linkedUserId ?: "",
            "status"       : "Active",
            "createdAt"    : now
        };
        var result = variables.fb.setDocument("groupMembers", id, doc, variables.idToken);
        if (result.success) return id;
        throw(type="FirestoreError", message=result.error ?: "Failed to add member");
    }

    function getMembers(required string groupId) {
        var filters = [
            variables.fb.fieldFilter("groupId", "EQUAL", arguments.groupId)
        ];
        var result = variables.fb.queryCollection(
            collection = "groupMembers",
            filters    = filters,
            idToken    = variables.idToken
        );
        if (!result.success) return [];
        var list = arrayFilter(result.data, function(m) { return m.status != "Deleted"; });
        arraySort(list, function(a, b) { return compare(a.createdAt, b.createdAt); });
        return list;
    }

    function getMember(required string memberId) {
        var result = variables.fb.getDocument("groupMembers", arguments.memberId, variables.idToken);
        if (!result.success) throw(type="NotFoundError", message="Member not found");
        return result.data;
    }

    function updateMember(required string memberId, required struct data) {
        var updates = {
            "name"   : arguments.data.name   ?: "",
            "email"  : arguments.data.email  ?: "",
            "mobile" : arguments.data.mobile ?: ""
        };
        var result = variables.fb.updateDocument("groupMembers", arguments.memberId, updates, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message=result.error ?: "Failed to update member");
    }

    function removeMember(required string memberId) {
        var result = variables.fb.softDelete("groupMembers", arguments.memberId, variables.idToken);
        if (!result.success) throw(type="FirestoreError", message="Failed to remove member");
    }

    // ── Group stats ───────────────────────────────────────────────────────

    function getMemberCount(required string groupId) {
        return arrayLen(getMembers(arguments.groupId));
    }

}
