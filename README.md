# 🏦 Family Spend Tracker

[![Download APK](https://img.shields.io/badge/⚡_Download_Android_APK-v1.0.7-9184d9?style=for-the-badge&logo=android&logoColor=white)](https://github.com/apzscorpion/family-finance/raw/main/releases/FamilySpendTracker-latest.apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Cloud_Auth_%26_DB-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

A collaborative mobile & cloud finance tracker designed for families, couples, and shared households. Track expenses, balance budgets, manage event loans, split expenses, and share live notes—all wrapped in the **Nocturne Dark Theme** design system.

---

## 📲 Quick Download & Installation (No Play Store Needed)

### 📥 Direct Download (Always Latest Version):
👉 **[Download Latest APK (`FamilySpendTracker-latest.apk`)](https://github.com/apzscorpion/family-finance/raw/main/releases/FamilySpendTracker-latest.apk)**

### 📱 Installation Steps:
1. Tap the download link above on your Android device.
2. Open the downloaded `FamilySpendTracker-latest.apk` file.
3. If prompted, tap **"Allow from this source"** to enable APK installation.
4. Open **Family Spend Tracker**, log in or create a family workspace, and enjoy!

> 🔄 **In-App Auto-Updates:** The app automatically checks GitHub on startup. When an update is published, a pop-up appears in-app to install the new version with 1 tap—no Play Store needed!

---

## 🌟 Key Features

### 👨‍👩‍👧‍👦 Collaborative Family Management
- **Role & Authority Hierarchy:** Family Owner can assign member roles (`Owner`, `Admin`, `Member`, `Viewer`) with granular authorities (`canEditSettings`, `canApproveExpenses`, `canManageMembers`).
- **Approval Workflows:** Track expenses added on behalf of family members with interactive diff reviews (`[Reject]` / `[Approve]`).

### 💸 Shared Expenses, Splits & Loan Pools
- **Google Splitwise Style:** Tag who paid for an entry and split costs equally, by percentage, or custom amount.
- **Payback Tracking:** Track who owes money to whom with built-in payback requirements.
- **Event & Loan Pools:** Manage dedicated loan budgets (e.g. *Wedding Loan ₹2,00,000*) and track drawdowns across sub-categories (*Venue*, *Makeup*, *Hair Setting*, *Clothing*, *Cash in Hand*).

### 📝 Live Shared Family Notes
- Collaborative shared scratchpad for family planning, shopping wishlists, and event budget notes.
- Real-time indicator badges showing who last edited the note (e.g. `"Edited by Sara · 15m ago"`).

### 🤖 Bank SMS Auto-Parser (On-Device Privacy)
- Automatically detects debit/credit messages from **HDFC**, **ICICI**, **SBI**, and other major banks.
- Parses amount, merchant, and category locally on your device—raw messages and OTPs are never uploaded.

### 📊 Time Filtering & Insights
- Filter spending and income by **7 Days**, **30 Days**, **This Month**, **This Year**, or **All Time**.
- Category breakdown progress bars and weekly cash flow charts.

---

## 🛠️ Developer Support & Error Reporting

Encountered a bug, missed an SMS parsing pattern, or have a feature request?

### 1. In-App Developer Support
Open the app $\rightarrow$ **Settings** $\rightarrow$ **Developer Support & Feedback** $\rightarrow$ Tap **"Report Error / Send Feedback"**.

### 2. GitHub Issues & Support
- Developer Profile: [@apzscorpion](https://github.com/apzscorpion)
- Report Issues: [GitHub Issues Page](https://github.com/apzscorpion/family-finance/issues)

---

## 🏗️ Local Development Setup

```bash
# 1. Clone Repository
git clone https://github.com/apzscorpion/family-finance.git
cd family-finance/mobile

# 2. Install Flutter Dependencies
flutter pub get

# 3. Setup Supabase Database
# Run `supabase_schema.sql` in your Supabase SQL Editor and insert keys into:
# lib/services/supabase_service.dart

# 4. Run Application
flutter run
```
