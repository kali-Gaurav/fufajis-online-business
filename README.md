# Fufaji Online Business

A robust hyperlocal e-commerce platform for Customers, Shop Owners, and Delivery Agents.

## 🚀 Key Features
- **Triple-App Ecosystem:** Integrated flows for customers, owners, and riders.
- **Production-Ready Security:** Server-side RBAC, verified payments, and hardened Firestore rules.
- **Automated Infrastructure:** CI/CD via GitHub Actions and OTA updates via Shorebird.
- **Operational Excellence:** GST invoicing, inventory audit logs, and vendor communication.

## 🛠 Tech Stack
- **Frontend:** Flutter (Mobile/Web)
- **Backend:** Firebase (Firestore, Auth, Functions, Storage, Messaging, Remote Config)
- **Updates:** Shorebird (Over-The-Air)
- **Monitoring:** Sentry & Firebase Analytics
- **Payments:** Razorpay

## 📦 Getting Started

1. **Clone the repo:**
   ```bash
   git clone <your-repo-url>
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   cd functions && npm install
   ```

3. **Configure Environment:**
   Create a `.env` file in the root directory (see `.env.example`).

4. **Run the app:**
   ```bash
   flutter run
   ```

## 🚢 Deployment

### Automated (CI/CD)
Pushing to the `main` branch triggers:
- **GitHub Actions:** Deploys Firebase Functions/Rules and builds APKs.
- **Shorebird:** (Manual trigger) Push logic updates via `shorebird patch`.

### Manual Firebase Deploy
```bash
firebase deploy --only functions,firestore,storage
```

---
*Built with ❤️ for Local Commerce.*
