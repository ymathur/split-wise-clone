<cfif session.keyExists("isLoggedIn") && session.isLoggedIn>
    <cflocation url="/pages/dashboard.cfm" addtoken="false">
</cfif>
<cfset includeFirebaseJS = true>
<cfset pageTitle = "Register">
<cfinclude template="/includes/header.cfm">

<div class="auth-wrapper">
    <div class="auth-card">
        <div class="auth-logo">&#128176;</div>
        <h1 class="auth-title"><cfoutput>#application.appName#</cfoutput></h1>
        <p class="auth-subtitle">Create your account</p>

        <div id="regError" class="alert alert-danger"  style="display:none"></div>

        <form id="regForm" novalidate>
            <div class="form-group">
                <label class="form-label" for="name">Full Name</label>
                <input type="text" id="name" name="name" class="form-control" placeholder="Your Name" required autofocus>
            </div>
            <div class="form-group">
                <label class="form-label" for="email">Email</label>
                <input type="email" id="email" name="email" class="form-control" placeholder="you@example.com" required>
            </div>
            <div class="form-group">
                <label class="form-label" for="password">Password</label>
                <input type="password" id="password" name="password" class="form-control" placeholder="Min 6 characters" required minlength="6">
            </div>
            <div class="form-group">
                <label class="form-label" for="confirmPassword">Confirm Password</label>
                <input type="password" id="confirmPassword" name="confirmPassword" class="form-control" placeholder="Repeat password" required>
            </div>
            <button type="submit" class="btn btn-primary btn-full" id="regBtn">Create Account</button>
        </form>

        <div class="auth-links">
            Already have an account? <a href="/login.cfm">Sign in</a>
        </div>
    </div>
</div>

<script>
const regForm = document.getElementById('regForm');
const regBtn  = document.getElementById('regBtn');
const errBox  = document.getElementById('regError');

regForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    errBox.style.display = 'none';

    const name     = document.getElementById('name').value.trim();
    const email    = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    const confirm  = document.getElementById('confirmPassword').value;

    if (!name)              return showError('Please enter your name.');
    if (password !== confirm) return showError('Passwords do not match.');

    regBtn.disabled    = true;
    regBtn.textContent = 'Creating account…';

    try {
        const cred = await firebase.auth().createUserWithEmailAndPassword(email, password);
        await cred.user.updateProfile({displayName: name});
        const idToken = await cred.user.getIdToken();

        const res  = await fetch('/auth-verify.cfm', {
            method  : 'POST',
            headers : {'Content-Type': 'application/json'},
            body    : JSON.stringify({idToken, action: 'register', name})
        });
        const data = await res.json();

        if (data.success) {
            window.location.href = data.redirect || '/pages/dashboard.cfm';
        } else {
            showError(data.message || 'Registration failed');
        }
    } catch (err) {
        const map = {
            'auth/email-already-in-use' : 'This email is already registered.',
            'auth/weak-password'        : 'Password is too weak (min 6 characters).',
            'auth/invalid-email'        : 'Invalid email address.'
        };
        showError(map[err.code] || err.message);
    } finally {
        regBtn.disabled    = false;
        regBtn.textContent = 'Create Account';
    }
});

function showError(msg) {
    errBox.textContent   = msg;
    errBox.style.display = 'block';
}
</script>

<cfinclude template="/includes/footer.cfm">
