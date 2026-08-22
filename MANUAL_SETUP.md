# Setu Production Manual Setup Guide

This guide covers the necessary steps to deploy the Setu production architecture. Since the codebase contains no hardcoded secrets or infrastructure state, you must manually perform these steps in the Google Cloud / Firebase console.

## 1. Firebase Project & Authentication
1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project `Setu-Prod`.
2. Upgrade the project to the **Blaze (Pay as you go)** plan. Cloud Functions v2 and Vertex AI require this.
3. Enable **Authentication**. Under Sign-in methods, enable **Phone Number** and set up reCAPTCHA verification.

## 2. App Check & Security
1. Navigate to **App Check** in Firebase.
2. Register your iOS app with **DeviceCheck/App Attest**.
3. Register your Android app with **Play Integrity**.
4. Enforce App Check on Firebase Authentication, Cloud Firestore, Storage, and Cloud Functions.

## 3. Google Cloud APIs Enablement
1. Open the [Google Cloud Console](https://console.cloud.google.com/) for your project.
2. Navigate to **APIs & Services > Library**.
3. Enable the following APIs:
   - **Cloud Speech-to-Text API**
   - **Vertex AI API** (for Gemini)
   - **Cloud Scheduler API** (for missed check-ins)
   - **Secret Manager API**

## 4. Secret Management (Zero-Credential Policy)
Never commit `.env` files. We use Google Cloud Secret Manager.
1. In Google Cloud Console, navigate to **Security > Secret Manager**.
2. Create the following secrets:
   - `GEMINI_API_KEY`: Generate this from Google AI Studio or use Vertex AI default credentials if deploying directly.
   - `WHATSAPP_WEBHOOK_SECRET`: A cryptographic string provided by Twilio/Gupshup for webhook validation.
3. Grant the `Secret Manager Secret Accessor` role to the default compute service account (`PROJECT_NUMBER-compute@developer.gserviceaccount.com`).

## 5. Storage Lifecycle Policy
We must enforce a 7-day retention policy on raw audio files for privacy compliance.
1. Install `gsutil` (Google Cloud SDK).
2. Create a file `lifecycle.json`:
   ```json
   {
     "rule": [
       {
         "action": {"type": "Delete"},
         "condition": {"age": 7}
       }
     ]
   }
   ```
3. Apply it to the storage bucket: `gsutil lifecycle set lifecycle.json gs://setu-prod.appspot.com`

## 6. Deployment
1. Run `flutterfire configure` to generate `firebase_options.dart`.
2. Connect your Flutter app to the project.
3. Deploy the backend rules and functions:
   ```bash
   firebase deploy --only firestore:rules,storage
   firebase deploy --only functions
   ```

## 7. WhatsApp Integration (Phase 4)
1. Complete Meta's WhatsApp Business API verification.
2. Configure your provider (Twilio/Gupshup) to point the webhook URL to the deployed `whatsappWebhook` function.
3. Add the Webhook Secret to Secret Manager.

## 8. Rollback & Incident Runbook
- **If LLM begins hallucinating:** Downgrade the model version in `functions/index.js` (e.g., to `gemini-1.5-flash-001`) and redeploy functions.
- **If malicious traffic hits the webhook:** Rotate `WHATSAPP_WEBHOOK_SECRET` in Secret Manager immediately and restart functions.
- **To rollback rules:** Run `firebase deploy --only firestore:rules --version <previous_version>` or revert the git commit and deploy.
