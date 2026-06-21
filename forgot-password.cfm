<cfset includeFirebaseJS = true>
<cfset pageTitle = "Forgot Password">
<cfinclude template="/includes/header.cfm">

<div class="auth-wrapper">
    <div class="auth-card">
        <div class="auth-logo">&#128272;</div>
        <h1 class="auth-title">Reset Password</h1>
        <p class="auth-subtitle">Enter your email and we will send a reset link.</p>

        <div id="fpError"   class="alert alert-danger"  style="display:none"></div>
        <div id="fpSuccess" class="alert alert-success" style="display:none"></div>

        <form id="fpForm" novalidate>
            <div class="form-group">
                <label class="form-label" for="email">Email</label>
                <input type="email" id="email" name="email" class="form-control" placeholder="you@example.com" required autofocus>
            </div>
            <button type="submit" class="btn btn-primary btn-full" id="fpBtn">Send Reset Link</button>
        </form>

        <div class="auth-links">
            <a href="/login.cfm">Back to login</a>
        </div>
    </div>
</div>

<script>
document.getElementById('fpForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const errBox  = document.getElementById('fpError');
    const succBox = document.getElementById('fpSuccess');
    const btn     = document.getElementById('fpBtn');
    const email   = document.getElementById('email').value.trim();

    errBox.style.display  = 'none';
    succBox.style.display = 'none';
    btn.disabled    = true;
    btn.textContent = 'Sending…';

    const genericSuccess = 'If an account exists for that email, a reset link has been sent. Check your inbox.';

    try {
        await firebase.auth().sendPasswordResetEmail(email);
        succBox.textContent   = genericSuccess;
        succBox.style.display = 'block';
    } catch (err) {
        if (err.code === 'auth/user-not-found') {
            // Don't reveal whether the email is registered - avoids user enumeration.
            succBox.textContent   = genericSuccess;
            succBox.style.display = 'block';
        } else {
            const map = {
                'auth/invalid-email' : 'Invalid email address.'
            };
            errBox.textContent   = map[err.code] || err.message;
            errBox.style.display = 'block';
        }
    } finally {
        btn.disabled    = false;
        btn.textContent = 'Send Reset Link';
    }
});
</script>

<cfinclude template="/includes/footer.cfm">
