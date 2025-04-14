# RedCellNet - Blood Donation Network App

<p align="center">
    </p>

<p align="center">
  <strong>Connecting blood donors and recipients quickly and efficiently.</strong>
</p>

---

## Overview

RedCellNet is a mobile application built with Flutter and Firebase designed to streamline the process of blood donation. It allows users to request blood in emergencies, view nearby requests and donation centers, and enables potential donors to offer help, fostering a connected community focused on saving lives.

## ✨ Features

* **User Authentication:** Secure login and registration using Email/Password and Google Sign-In.
* **User Profiles:** Manage personal details, blood type, contact information, and donation availability status.
* **Profile Editing:** Update profile information easily.
* **Blood Report OCR:** Scan blood reports using ML Kit Text Recognition to automatically detect and suggest blood types during profile editing.
* **Blood Requests:**
    * Create detailed blood requests (patient info, required type, units, urgency, hospital, contact).
    * View a list of all open requests.
    * View a filtered list of requests created by the logged-in user ("My Requests").
    * Filter open requests by Blood Group and Urgency Level.
    * View request details.
    * Delete own blood requests.
* **Donation Offers & Connection:**
    * Compatible donors can "Offer Help" on requests.
    * Requesters can view pending offers on their requests.
    * Requesters can **Accept** or **Reject** offers. Accepting fulfills the request and rejects other offers.
    * Requesters can view the accepted donor's contact information after accepting an offer.
    * _(TODO: Donor view of their offer status and requester contact info)_
* **Nearby Map:** Visualize locations of open blood requests and registered donation centers (Google Maps integration - requires API key setup).
* **Donation Centers:** View registered donation centers on the map.
* **Educational Content:** Browse articles and tips related to blood donation ("Learn & Aware" section).
* **Rewards System:**
    * Earn points for actions like completing profile and reading content.
    * Earn badges (e.g., "Profile Complete") based on achievements.
    * View points and earned badges on the profile page.
* **Push Notifications (FCM):**
    * Receive notifications (setup for foreground, background, terminated states).
    * Tap notifications to navigate directly to relevant request details.
    * _(TODO: Cloud Function required for server-side sending of notifications)._

## 🚀 Technology Stack

* **Framework:** Flutter (Cross-platform UI)
* **Language:** Dart
* **Backend & Database:** Firebase
    * Firebase Authentication (Email/Password, Google Sign-In)
    * Cloud Firestore (NoSQL Database)
    * Firebase Cloud Messaging (Push Notifications - Client setup)
    * _(Firebase Storage originally planned, replaced with ImgBB due to user constraints)_
* **Mapping & Geocoding:** Google Maps Platform
    * `Maps_flutter` (Android/iOS Map Display)
    * `Maps_apis` (Geocoding - requires billing/API key setup)
* **Image Handling:**
    * `image_picker` (Select images from gallery/camera)
    * `google_mlkit_text_recognition` (On-device OCR)
    * `http` & `http_parser` (For uploading to ImgBB)
    * ImgBB (Third-party image hosting for profile pictures)
* **State Management:** Implicit (`StatefulWidget`, `StreamBuilder`, `FutureBuilder`)
* **Other:**
    * `intl` (Date/Time formatting)
    * `flutter_local_notifications` (Displaying foreground FCM messages)
    * `permission_handler` (Requesting location permissions)
    * `geolocator` (Getting device location)

## 🛠️ Setup & Installation (for Developers)

1.  **Prerequisites:**
    * Flutter SDK (Latest stable recommended)
    * Git
    * An IDE (like VS Code or Android Studio)
    * Java Development Kit (JDK) (for Android signing key generation)

2.  **Clone Repository:**
    ```bash
    git clone [https://github.com/YourUsername/YourRepositoryName.git](https://github.com/YourUsername/YourRepositoryName.git) # Replace with your repo URL
    cd YourRepositoryName
    ```

3.  **Firebase Project Setup:**
    * Create a new Firebase project at [https://console.firebase.google.com/](https://console.firebase.google.com/).
    * **Register Apps:** Add an Android app (using package name `com.example.red_cell_net`), an iOS app (if needed), and a Web app to the project.
    * **Download Config Files:**
        * Download `google-services.json` and place it in `android/app/`.
        * Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
        * Configure web initialization if needed (often handled by FlutterFire).
        * **Important:** Ensure these files are listed in your `.gitignore` and not committed.
    * **Enable Services:** In the Firebase console, enable:
        * **Authentication:** Enable Email/Password and Google Sign-In providers. Add your Android SHA-1 keys (debug and release) and configure Web OAuth Client ID for Google Sign-In.
        * **Cloud Firestore:** Create a Firestore database (start in test mode for development, secure rules later).
        * **Storage:** Enable Cloud Storage (required for ImgBB alternative setup, though not directly used if sticking to ImgBB). Apply the security rules provided earlier (or stricter ones). *Note: If you resolve billing issues, you can switch back to Firebase Storage.*
    * **Publish Firestore Rules:** Copy the final version of the Firestore security rules (allowing reads, specific creates/updates/deletes) provided in our conversation and publish them in the Firestore Rules tab.
    * **Create Firestore Indexes:** Run the app and check the debug console for errors related to missing indexes (especially for request filtering and urgent requests). Click the links provided in the logs to create the necessary composite indexes in Firestore.

4.  **API Keys & Configuration:**
    * **Google Maps Platform:**
        * Go to [https://console.cloud.google.com/](https://console.cloud.google.com/).
        * Select your Firebase project.
        * Enable **Maps SDK for Android**, **Maps SDK for iOS**, **Geocoding API**, and **Maps JavaScript API** (for web).
        * **Enable Billing** for the project (required for Maps/Geocoding to work reliably).
        * Create an API Key restricted for these APIs and your specific app (Android package name + SHA-1, iOS bundle ID, Web HTTP referrers).
        * Add the key to:
            * `android/app/src/main/AndroidManifest.xml`
            * `ios/Runner/AppDelegate.swift`
            * `web/index.html`
    * **ImgBB API Key:**
        * Sign up at [https://imgbb.com/](https://imgbb.com/) and get your API key.
        * **Crucially: Store this key securely.** Use the `flutter_dotenv` package:
            * Add `flutter_dotenv` to `pubspec.yaml`.
            * Create a `.env` file in the project root (add it to `.gitignore`!).
            * Add `IMGBB_API_KEY=YOUR_ACTUAL_KEY` to `.env`.
            * Load it in `main.dart`: `await dotenv.load(fileName: ".env");`
            * Access it in `edit_profile_page.dart`: `final String imgbbApiKey = dotenv.env['IMGBB_API_KEY'] ?? 'MISSING';`
    * **Android Signing Key:**
        * Generate your upload keystore (`.jks` file) using `keytool` (follow previous instructions). **Backup this file and its passwords securely!**
        * Create the `android/key.properties` file with the correct paths and passwords (ensure it's in `.gitignore`).
        * Ensure `android/app/build.gradle.kts` is configured to read `key.properties` for release signing.

5.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

6.  **Run the App:**
    ```bash
    flutter run # Debug mode
    # OR for release testing (after signing setup)
    flutter run --release
    ```

## 🚀 Usage

1.  **Register/Login:** Create an account using email/password or sign in with Google.
2.  **Home Screen:** View your points, request blood, or navigate to learn about donation. See urgent requests (requires index).
3.  **Requests Tab:** View all open requests or filter to see only your own requests. Apply filters for blood type or urgency. Tap a request to see details.
4.  **Map Tab:** View nearby requests and donation centers visually (requires Maps API key setup).
5.  **Profile Tab:** View your profile details, points, badges, donation history (TBD). Toggle your availability to donate. Edit your profile or log out.
6.  **Edit Profile:** Update your name, contact info, blood type. Use the Scan button to try detecting blood type via OCR from a report image. Upload a profile picture. Saving a complete profile awards points/badge.
7.  **Learn Tab:** Browse and read educational articles. Earn points for reading each article once.
8.  **Request Details:**
    * View full details of a blood request.
    * If you are the requester, you can delete the request or view/accept/reject offers from donors.
    * If you are *not* the requester, you can contact the requester (TBD) or offer help (if compatible and available).
    * If an offer is accepted (by the requester), the requester sees the donor's contact details.

## ⚠️ Known Issues & TODOs

* **Google Maps Billing/API Key:** Geocoding requests currently fail (`REQUEST_DENIED`) and the map shows a watermark because a billing account needs to be properly linked and configured in the Google Cloud Console for the API key being used.
* **Donor "Connect" View:** Donors currently cannot see the status of their offers or the requester's contact info after acceptance. A "My Offers" section is needed.
* **Notifications (Sending):** The client-side setup for receiving notifications is done, but the backend Cloud Function to *send* notifications (e.g., for new requests, accepted offers) needs to be deployed.
* **Donation History:** The UI displays history, but the logic for recording actual donations needs implementation.
* **Badge Awarding Logic:** Only the "Profile Complete" badge is awarded automatically. Logic for other badges (based on donations, points, etc.) needs to be added.
* **OCR Robustness:** The current OCR text parsing for blood type works for some formats but may fail on others. It relies on user confirmation or manual entry if detection fails.
* **Contact Requester:** The "Contact" button currently shows placeholder text; needs `url_launcher` implementation to initiate a phone call.
* **Localization:** Basic structure might be present, but full English/Bangla localization across all UI elements needs review and completion.
* **Error Handling:** Improve user-facing error messages and handling for edge cases.
* **Testing:** More comprehensive unit, widget, and integration tests are needed.
* **Security:** Revisit Firestore/Storage rules for potential tightening (e.g., field-level read access for profiles). Ensure API keys are stored securely using `flutter_dotenv` or similar, not hardcoded. Clean Git history if secrets were exposed.

## Contributing

_(Optional: Add guidelines here if you plan to accept contributions from others)_
This project is currently under personal development.

## License

_(Optional: Choose and add a license file, e.g., MIT)_
This project is currently unlicensed.
