    <footer class="app-footer">
        <cfoutput><p>&copy; #year(now())# #application.appName# &mdash; v#application.appVersion#</p></cfoutput>
    </footer>
    <script src="/assets/js/app.js"></script>
    <cfif isDefined("extraJS")><cfoutput>#extraJS#</cfoutput></cfif>
</body>
</html>
