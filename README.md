# Split Expense App

A lightweight personal accounting and group expense splitting application built with ColdFusion (Lucee) and Firebase Firestore.

---

## Features

- **Personal Accounts** — Track cash, travel, or any spending category with opening balance and remaining balance
- **Group Expenses** — Create groups for trips or events, add members, and log shared expenses
- **Smart Split** — Equal split across all or selected members, or fully custom amounts per member
- **Settlement Tracking** — Auto-calculates who owes whom; record payments and mark as paid
- **Dashboard** — Summary view of balances, recent expenses, receivables, and payables
- **Reports** — Filter personal or group expenses by date, category, and payment mode
- **Mobile-Friendly** — Responsive UI works well on phones while travelling

---

## Technology Stack

| Layer | Technology |
|---|---|
| Backend | Lucee CFML (plain `.cfm` / `.cfc`, no framework) |
| Database | Firebase Firestore (REST API) |
| Authentication | Firebase Auth JS SDK + ColdFusion session |
| Frontend | Plain HTML, CSS, minimal vanilla JS |

---

## Folder Structure

```
SplitWiseClone/
├── Application.cfc           # Session + app config
├── index.cfm                 # Redirect to login or dashboard
├── login.cfm                 # Login page (Firebase Auth JS SDK)
├── register.cfm              # Registration
├── forgot-password.cfm       # Password reset
├── logout.cfm                # Clear session
├── auth-verify.cfm           # AJAX: verify Firebase ID token → CF session
├── auth-refresh.cfm          # AJAX: refresh token in CF session
│
├── components/
│   ├── firebase.cfc          # Firestore REST API wrapper
│   ├── account.cfc           # Personal account CRUD
│   ├── group.cfc             # Group + member CRUD
│   ├── expense.cfc           # Expense CRUD + split management
│   ├── settlement.cfc        # Settlement CRUD + balance calculation
│   └── report.cfc            # Report generation
│
├── includes/
│   ├── config.cfm            # Firebase config overrides
│   ├── authCheck.cfm         # Redirect to login if not authenticated
│   ├── header.cfm            # HTML head + Firebase JS SDK
│   ├── nav.cfm               # Top navbar
│   └── footer.cfm            # HTML close + JS includes
│
├── pages/
│   ├── dashboard.cfm
│   ├── accounts.cfm / account-form.cfm
│   ├── groups.cfm / group-form.cfm / group-detail.cfm / group-members.cfm
│   ├── expenses.cfm / expense-form.cfm / expense-detail.cfm
│   ├── settlements.cfm / settlement-form.cfm
│   ├── reports.cfm
│   └── profile.cfm
│
├── api/
│   └── get-members.cfm       # AJAX: return group members as JSON
│
└── assets/
    ├── css/style.css
    └── js/app.js
```

---

## Authentication Flow

```
Browser                    ColdFusion              Firebase
  │                            │                       │
  ├─ login.cfm loads ─────────►│                       │
  │                            │                       │
  ├─ email/password ──────────────────────────────────►│
  │◄─ ID Token ───────────────────────────────────────┤
  │                            │                       │
  ├─ POST /auth-verify.cfm ───►│                       │
  │  {idToken}                 ├─ accounts:lookup ─────►│
  │                            │◄─ user data ──────────┤
  │                            ├─ session.isLoggedIn=true
  │◄─ {success, redirect} ─────┤                       │
  │                            │                       │
  ├─ All Firestore calls: Authorization: Bearer {idToken}
```

---

## How to Run Locally

See [SETUP.md](SETUP.md) for the complete step-by-step guide.

**Quick start with CommandBox:**

```bash
cd SplitWiseClone
box
server start cfengine=lucee@5 port=8888 webroot=.
```

Open: `http://localhost:8888`

---

## Firebase Firestore Collections

| Collection | Description |
|---|---|
| `users` | User profile (uid, name, email) |
| `accounts` | Personal accounts (Daily Cash, USA Trip, etc.) |
| `groups` | Groups (Goa Trip, Family Tour, etc.) |
| `groupMembers` | Members of each group |
| `expenses` | Personal and group expenses |
| `expenseSplits` | Per-member share of each group expense |
| `settlements` | Recorded payments between members |

---

## Currency

Default currency: **INR (₹)**. All amounts stored as numbers in Firestore.

---

## Known Limitations (v1)

- ID token expires after 1 hour; token auto-refreshes via JS SDK (silent background refresh)
- Group members cannot log in — all data is managed by the main user
- No receipt image upload
- No PDF/Excel export
- Single currency only (INR)
- No offline support

---

## Future Enhancements

- Multi-currency support
- Receipt image upload to Firebase Storage
- PDF report export
- Invite group members to sign in
- Budget limits with alerts
- Category-wise charts and graphs
- PWA / offline support
- WhatsApp sharing of expense summaries
- Recurring expenses
