<cfif session.keyExists("isLoggedIn") && session.isLoggedIn>
    <cflocation url="/pages/dashboard.cfm" addtoken="false">
</cfif>
<cfset includeFirebaseJS = true>
<cfset pageTitle = "Login">
<cfinclude template="/includes/header.cfm">

<div class="auth-wrapper">
    <div class="auth-card">
        <div class="auth-logo">&#128176;</div>
        <h1 class="auth-title"><cfoutput>#application.appName#</cfoutput></h1>
        <p class="auth-subtitle">Track expenses. Split fairly.</p>

        <cfif structKeyExists(url, "msg") && len(url.msg)>
            <div class="alert alert-info"><cfoutput>#htmlEditFormat(url.msg)#</cfoutput></div>
        </cfif>

        <div id="loginError" class="alert alert-danger" style="display:none"></div>

        <form id="loginForm" novalidate>
            <div class="form-group">
                <label class="form-label" for="email">Email</label>
                <input type="email" id="email" name="email" class="form-control" placeholder="you@example.com" required autofocus>
            </div>
            <div class="form-group">
                <label class="form-label" for="password">Password</label>
                <input type="password" id="password" name="password" class="form-control" placeholder="Password" required>
            </div>
            <button type="submit" class="btn btn-primary btn-full" id="loginBtn">
                Sign In
            </button>
        </form>

        <div class="auth-links">
            <a href="/forgot-password.cfm">Forgot password?</a>
            &nbsp;&bull;&nbsp;
            <a href="/register.cfm">Create account</a>
        </div>
    </div>
</div>

<script>
const loginForm = document.getElementById('loginForm');
const loginBtn  = document.getElementById('loginBtn');
const errorBox  = document.getElementById('loginError');

loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorBox.style.display = 'none';
    loginBtn.disabled = true;
    loginBtn.textContent = 'Signing in…';

    const email    = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;

    try {
        const credential = await firebase.auth().signInWithEmailAndPassword(email, password);
        const idToken    = await credential.user.getIdToken();

        const res  = await fetch('/auth-verify.cfm', {
            method  : 'POST',
            headers : {'Content-Type': 'application/json'},
            body    : JSON.stringify({idToken, action: 'login'})
        });
        const data = await res.json();

        if (data.success) {
            window.location.href = data.redirect || '/pages/dashboard.cfm';
        } else {
            showError(data.message || 'Login failed');
        }
    } catch (err) {
        showError(friendlyError(err));
    } finally {
        loginBtn.disabled    = false;
        loginBtn.textContent = 'Sign In';
    }
});

function showError(msg) {
    errorBox.textContent     = msg;
    errorBox.style.display   = 'block';
}

function friendlyError(err) {
    const map = {
        'auth/user-not-found'   : 'No account found with this email.',
        'auth/wrong-password'   : 'Incorrect password.',
        'auth/invalid-email'    : 'Invalid email address.',
        'auth/too-many-requests': 'Too many attempts. Please try again later.',
        'auth/invalid-credential': 'Invalid email or password.'
    };
    return map[err.code] || err.message;
}
</script>

<cfinclude template="/includes/footer.cfm">
