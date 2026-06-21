<cfoutput>
<nav class="navbar">
    <div class="nav-brand">
        <button class="nav-toggle" id="navToggle" aria-label="Toggle menu">&##9776;</button>
        <a href="/pages/dashboard.cfm" class="brand-name">#application.appName#</a>
    </div>
    <div class="nav-links" id="navLinks">
        <a href="/pages/dashboard.cfm"  class="nav-link<cfif cgi.script_name contains 'dashboard'> active</cfif>">&##127968; Dashboard</a>
        <a href="/pages/accounts.cfm"   class="nav-link<cfif cgi.script_name contains 'account'> active</cfif>">&##128179; Accounts</a>
        <a href="/pages/groups.cfm"     class="nav-link<cfif cgi.script_name contains 'group'> active</cfif>">&##128101; Groups</a>
        <a href="/pages/expenses.cfm"   class="nav-link<cfif cgi.script_name contains 'expense'> active</cfif>">&##128176; Expenses</a>
        <a href="/pages/import.cfm"     class="nav-link<cfif cgi.script_name contains 'import'> active</cfif>">&##128229; Import</a>
        <a href="/pages/settlements.cfm" class="nav-link<cfif cgi.script_name contains 'settlement'> active</cfif>">&##129534; Settlements</a>
        <a href="/pages/reports.cfm"    class="nav-link<cfif cgi.script_name contains 'report'> active</cfif>">&##128202; Reports</a>
        <div class="nav-divider"></div>
        <a href="/pages/profile.cfm"    class="nav-link<cfif cgi.script_name contains 'profile'> active</cfif>">&##128100; #session.userName#</a>
        <a href="/logout.cfm"           class="nav-link nav-logout">&##128682; Logout</a>
    </div>
</nav>
<div class="nav-overlay" id="navOverlay"></div>
<main class="main-content">
</cfoutput>
