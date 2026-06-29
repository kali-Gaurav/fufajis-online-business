# ✅ FUFAJI ONLINE - FINAL INTEGRATION & DEPLOYMENT CHECKLIST

Use this checklist to ensure all parts of the app (Frontend, Backend, Database, Firebase) are fully synchronized and ready for production.

---

## 1. 📂 Codebase Status
- [x] **Hybrid Architecture**: Enabled (Firestore + Supabase).
- [x] **Dual-Write Logic**: Implemented in `user_service.dart`, `product_service.dart`, and Backend `orders.js`.
- [x] **Supabase Init**: Fixed. Now uses Runtime Configuration from the backend.
- [x] **Phone Auth**: Fully integrated and fixed.

---

## 2. 🔧 Backend Setup (Render.com / AWS Lambda)
The primary backend is currently hosted on **Render.com**.

### **Secrets to Set on Backend:**
Ensure these are in your Render.com Environment Variables or AWS SSM:
- `FIREBASE_SERVICE_ACCOUNT`: (Paste the entire JSON)
- `SUPABASE_URL`: `https://mxjtgpunctckovtuyfmz.supabase.co`
- `SUPABASE_SECRET_KEY`: (Your Service Role Key)
- `RAZORPAY_KEY_ID`: `rzp_live_T72SdW8PsZ2Nhj`
- `RAZORPAY_KEY_SECRET`: (From .env)
- `TWILIO_ACCOUNT_SID`: (From .env)
- `TWILIO_AUTH_TOKEN`: (From .env)

---

## 3. 🗄️ Database Setup (Supabase)
### **Link & Push Migrations:**
Run these in your local terminal:
1. `cd supabase`
2. `npx supabase login` (If not already logged in)
3. `npx supabase link --project-ref mxjtgpunctckovtuyfmz`
4. `npx supabase db push`

---

## 4. 📱 Mobile App Build (APK)
### **Local Build Command:**
```bash
flutter build apk --release `
  --dart-define=API_BASE_URL=https://fufaji-api.render.com `
  --dart-define=GOOGLE_MAPS_KEY=AIzaSyAcxtNxcPCuqoJNkPzg71PLF97mU-2d6Uk
```

### **Google Play Store (AAB):**
```bash
flutter build appbundle --release `
  --dart-define=API_BASE_URL=https://fufaji-api.render.com `
  --dart-define=GOOGLE_MAPS_KEY=AIzaSyAcxtNxcPCuqoJNkPzg71PLF97mU-2d6Uk
```

---

## 5. 🐙 GitHub & CI/CD
### **GitHub Secrets Checklist:**
Set these in your GitHub Repo Settings > Secrets > Actions:
- `API_BASE_URL`: `https://fufaji-api.render.com`
- `GOOGLE_MAPS_KEY`: `AIzaSyAcxtNxcPCuqoJNkPzg71PLF97mU-2d6Uk`
- `FIREBASE_APP_ID`: (From Firebase Console)
- `FIREBASE_TOKEN`: (From `firebase login:ci`)
- `KEYSTORE_BASE64`: (Base64 of your `.jks` file)
- `STORE_PASSWORD` / `KEY_PASSWORD` / `KEY_ALIAS`

### **Pushing Updates:**
```bash
git add .
git commit -m "feat: complete production-ready integration with hybrid sync"
git push origin main
```

---

## 🚀 Verification Commands
### **Check Backend Health:**
`curl https://fufaji-api.render.com/health`

### **Check Runtime Config:**
`curl https://fufaji-api.render.com/config/app-config`
*(Verify that `supabase` keys are returned correctly).*

### **Test OTP Send:**
`curl -X POST https://fufaji-api.render.com/auth/send-otp -H "Content-Type: application/json" -d "{\"phoneNumber\": \"+91XXXXXXXXXX\"}"`

---

**Everything is now wired for a full build. Run the build command above to generate your production APK!** 📦
