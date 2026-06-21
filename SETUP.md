# Setup Guide

## Step 1 — Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project**
3. Enter a project name (e.g., `split-expense-app`)
4. Disable Google Analytics (optional)
5. Click **Create project**

---

## Step 2 — Enable Firebase Authentication

1. In your project, click **Authentication** in the left sidebar
2. Click **Get started**
3. Under **Sign-in method**, click **Email/Password**
4. Toggle **Enable** to ON
5. Click **Save**

---

## Step 3 — Create Firestore Database

1. Click **Firestore Database** in the left sidebar
2. Click **Create database**
3. Choose **Start in production mode**
4. Select a region (e.g., `asia-south1` for India)
5. Click **Enable**

---

## Step 4 — Add Firestore Security Rules

1. In Firestore, click the **Rules** tab
2. Replace the default rules with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can read/write only their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Accounts: only owner can access
    match /accounts/{docId} {
      allow read, write: if request.auth != null &&
        (resource == null || resource.data.userId == request.auth.uid);
      allow create: if request.auth != null &&
        request.resource.data.userId == request.auth.uid;
    }

    // Groups: only owner can access
    match /groups/{docId} {
      allow read, write: if request.auth != null &&
        (resource == null || resource.data.ownerUserId == request.auth.uid);
      allow create: if request.auth != null &&
        request.resource.data.ownerUserId == request.auth.uid;
    }

    // Group members: accessible if user owns the group
    match /groupMembers/{docId} {
      allow read, write: if request.auth != null;
    }

    // Expenses: only owner
    match /expenses/{docId} {
      allow read, write: if request.auth != null &&
        (resource == null || resource.data.userId == request.auth.uid);
      allow create: if request.auth != null &&
        request.resource.data.userId == request.auth.uid;
    }

    // Expense splits: authenticated users
    match /expenseSplits/{docId} {
      allow read, write: if request.auth != null;
    }

    // Settlements: only owner
    match /settlements/{docId} {
      allow read, write: if request.auth != null &&
        (resource == null || resource.data.userId == request.auth.uid);
      allow create: if request.auth != null &&
        request.resource.data.userId == request.auth.uid;
    }
  }
}
```

3. Click **Publish**

---

## Step 5 — Get Firebase Credentials

### Web API Key (for Authentication)

1. Go to **Project Settings** (gear icon)
2. Under **General** tab, scroll to **Your apps**
3. Click **Add app** → Web (`</>`)
4. Register the app (any nickname)
5. Note down `apiKey`, `authDomain`, and `projectId` from the config snippet

### Firebase Project ID

Found on the **General** tab under **Your project** section.

---

## Step 6 — Configure the Application

Copy `.env.example` to `.env` and fill in your Firebase project's values:

```bash
cp .env.example .env
```

```
FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID
FIREBASE_API_KEY=YOUR_FIREBASE_WEB_API_KEY
FIREBASE_AUTH_DOMAIN=YOUR_PROJECT_ID.firebaseapp.com
FIREBASE_DATABASE_ID=(default)
```

`Application.cfc` loads these at startup. `.env` is gitignored - never commit real
credentials to source control. If `.env` is missing or incomplete, the app will fail
to start with a clear error telling you which key is missing.

---

## Step 7 — Set Up Lucee Server

### Option A — CommandBox (recommended)

1. Install CommandBox: https://commandbox.ortusbooks.com/
2. Navigate to the project folder:
   ```bash
   cd /path/to/SplitWiseClone
   box
   ```
3. Start Lucee server:
   ```bash
   server start cfengine=lucee@5 port=8888 webroot=.
   ```

### Option B — Standalone Lucee

1. Download Lucee from https://download.lucee.org/
2. Install and configure Lucee with your webroot pointing to the project folder
3. Start Lucee server

---

## Step 8 — Place Project Files

Ensure the project root (`SplitWiseClone/`) is your Lucee webroot or is mapped as a virtual host.

---

## Step 9 — Run the Application

1. Open your browser: `http://localhost:8888`
2. You will be redirected to the login page

---

## Step 10 — Register Your First User

1. Click **Create account** on the login page
2. Enter your name, email, and password (min 6 characters)
3. Click **Create Account**
4. You will be redirected to the dashboard

---

## Step 11 — Create Your First Account

1. From the dashboard, click **+ New Account**
2. Fill in:
   - Account Name: `Daily Cash`
   - Opening Amount: `5000`
   - Start Date: today
3. Click **Create Account**

---

## Step 12 — Add a Personal Expense

1. Click **+ Add Expense** from the dashboard
2. Select:
   - Type: **Personal**
   - Account: the account you just created
   - Description: `Lunch`
   - Amount: `150`
   - Category: `Food`
3. Click **Save Expense**

---

## Step 13 — Create a Group

1. Go to **Groups** → **+ New Group**
2. Fill in:
   - Group Name: `Goa Trip`
   - Start Date: today
3. Click **Create Group**

---

## Step 14 — Add Group Members

1. Open the group → click **Members**
2. Add members one by one:
   - Amit
   - Rahul
   - Suresh
3. Click **Add Member** for each

---

## Step 15 — Add a Group Expense

1. From the group detail page, click **+ Add Expense**
2. Fill in:
   - Type: **Group**
   - Group: Goa Trip
   - Description: `Hotel`
   - Amount: `4000`
   - Paid By: your name (as a member)
   - Split Type: **Equal**
   - Check all 4 members
3. Click **Save Expense**

---

## Step 16 — Check the Dashboard

- View account balances
- See recent expenses
- Check group summaries

---

## Step 17 — Record a Settlement

1. Go to the group → review suggested settlements
2. Click **Record** next to a suggested settlement
3. Fill in payment mode and click **Record Settlement**
4. Once paid, mark it as **Paid**

---

## Step 18 — Generate a Report

1. Go to **Reports**
2. Select **Personal Expenses** or **Group Expenses**
3. Apply filters and click **Generate Report**

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Blank page after login | Check that FIREBASE_PROJECT_ID and FIREBASE_API_KEY in `.env` are correct |
| "Missing or insufficient permissions" | Check Firebase security rules are published |
| 401 errors from Firestore | ID token may have expired — log out and log back in |
| Session not persisting | Ensure Lucee session management is enabled and cookies are accepted |
| Members not loading in expense form | Check browser console and verify `/api/get-members.cfm` returns JSON |
