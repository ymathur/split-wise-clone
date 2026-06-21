<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <cfoutput>
    <title><cfif isDefined("pageTitle")>#pageTitle# - #application.appName#<cfelse>#application.appName#</cfif></title>
    </cfoutput>
    <link rel="stylesheet" href="/assets/css/style.css">
    <cfif isDefined("includeFirebaseJS") && includeFirebaseJS>
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-auth-compat.js"></script>
    <cfoutput>
    <script>
        const firebaseConfig = {
            apiKey     : "#application.firebase.apiKey#",
            authDomain : "#application.firebase.authDomain#",
            projectId  : "#application.firebase.projectId#"
        };
        firebase.initializeApp(firebaseConfig);
    </script>
    </cfoutput>
    </cfif>
</head>
<body>
