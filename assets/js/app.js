// ── Mobile nav toggle ─────────────────────────────────────────────────
const navToggle  = document.getElementById('navToggle');
const navLinks   = document.getElementById('navLinks');
const navOverlay = document.getElementById('navOverlay');

if (navToggle) {
    navToggle.addEventListener('click', () => {
        const isOpen = navLinks.classList.toggle('open');
        navOverlay.classList.toggle('open', isOpen);
        navToggle.setAttribute('aria-expanded', String(isOpen));
    });
    navOverlay.addEventListener('click', closeNav);
    document.addEventListener('keydown', e => { if (e.key === 'Escape') closeNav(); });
}

function closeNav() {
    navLinks && navLinks.classList.remove('open');
    navOverlay && navOverlay.classList.remove('open');
    navToggle && navToggle.setAttribute('aria-expanded', 'false');
}

// ── Firebase token refresh ────────────────────────────────────────────
// Only runs on pages that loaded Firebase SDK
if (typeof firebase !== 'undefined') {
    firebase.auth().onIdTokenChanged(async (user) => {
        if (user) {
            try {
                const idToken = await user.getIdToken();
                await fetch('/auth-refresh.cfm', {
                    method  : 'POST',
                    headers : {'Content-Type': 'application/json'},
                    body    : JSON.stringify({idToken})
                });
            } catch (e) {
                // Silent — token refresh is best-effort
            }
        }
    });
}

// ── Auto-dismiss alerts ───────────────────────────────────────────────
document.querySelectorAll('.alert-success').forEach(el => {
    setTimeout(() => { el.style.opacity = '0'; el.style.transition = 'opacity .5s'; }, 4000);
    setTimeout(() => { el.remove(); }, 4500);
});

// ── Confirm delete links ──────────────────────────────────────────────
document.querySelectorAll('[data-confirm]').forEach(el => {
    el.addEventListener('click', e => {
        if (!confirm(el.dataset.confirm || 'Are you sure?')) e.preventDefault();
    });
});
