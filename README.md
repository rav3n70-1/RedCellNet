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
* **User Profiles:** Manage personal details, blood type, contact information, and donation availability status. Points and badges earned are displayed.
* **Profile Editing:** Update profile information easily.
* **Blood Report OCR:** Scan blood reports using ML Kit Text Recognition to automatically detect and suggest blood types during profile editing.
* **Blood Requests:**
    * Create detailed blood requests (patient info, required type, units, urgency, hospital, contact). Geocoding for coordinates attempted.
    * View a list of all open requests ("All Open" tab).
    * View a filtered list of requests created by the logged-in user ("My Requests" tab).
    * Filter open requests by Blood Group and Urgency Level.
    * View request details.
    * Delete own blood requests.
* **Donation Offers & Connection:**
    * Compatible, available donors can "Offer Help" on requests.
    * Requesters can view pending offers on their requests.
    * Requesters can **Accept** or **Reject** offers. Accepting fulfills the request and auto-rejects other pending offers.
    * Requesters can view the accepted donor's name and contact information after accepting an offer.
    * _(TODO: Donor view of their offer status and requester contact info)_
* **Nearby Map:** Visualize locations of open blood requests and registered donation centers (requires Google Maps setup & API key).
* **Donation Centers:** View registered donation centers (fetched from Firestore) on the map.
* **Educational Content:** Browse articles and tips related to blood donation ("Learn & Aware" section).
* **Rewards System:** Gamification through points and achievement badges.
    * **Points:** Earn points for actions like completing profile and reading educational content. View total points on the profile.
    * **Badges:** Earn badges based on achievements. Current badges include:
        * **First Drop** (`Icons.water_drop_outlined`): Awarded after the user records their first successful blood donation. _(Logic TBD)_
        * **High Five** (`Icons.thumb_up_alt_outlined`): Awarded after completing 5 donations. _(Logic TBD)_
        * **Double Digits** (`Icons.filter_alt_outlined`): Awarded after completing 10 donations. _(Logic TBD)_
        * **Rare Hero** (`Icons.star_outline`): Awarded for donating a rare blood type (e.g., AB-, O-). _(Logic TBD)_
        * **Crisis Warrior** (`Icons.local_fire_department_outlined`): Awarded for donating during an emergency/disaster mode. _(Logic TBD)_
        * **Lifesaver Buddy** (`Icons.group_add_outlined`): Awarded for referring new donors. _(Logic TBD)_
        * **Health Aware** (`Icons.school_outlined`): Awarded after reading a certain number of educational articles. _(Points awarded, badge TBD)_
        * **Profile Complete** (`Icons.check_circle_outline`): Awarded when Name, Blood Type, City/Area are filled. **(Logic Implemented!)**
        * **Standby Guardian** (`Icons.shield_outlined`): Awarded for consistently being available to donate. _(Logic TBD)_
        * **Legend Donor** (`Icons.emoji_events_outlined`): Awarded after a significant number of donations. _(Logic TBD)_
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
* **Mapping & Geocoding:** Google Maps Platform
    * `Maps_flutter` (Android/iOS Map Display)
    * `Maps_apis` (Geocoding - requires billing/API key setup)
* **Image & Text Recognition:**
    * `image_picker` (Select images from gallery/camera for OCR)
    * `google_mlkit_text_recognition` (On-device OCR)
* **State Management:** Implicit (`StatefulWidget`, `StreamBuilder`, `FutureBuilder`)
* **Other:**
    * `intl` (Date/Time formatting)
    * `flutter_local_notifications` (Displaying foreground FCM messages)
    * `permission_handler` (Requesting location permissions)
    * `geolocator` (Getting device location)

## 🛠️ Setup & Installation (for Developers)

1.  **Prerequisites:** Flutter SDK, Git, IDE, JDK.
2.  **Clone Repository:** `git clone <your-repo-url>`
3.  **Firebase Project Setup:**
    * Create Firebase project.
    * Register Android, iOS, Web apps.
    * Download/place `google-services.json` (Android) & `GoogleService-Info.plist` (iOS). Ensure they are in `.gitignore`.
    * Enable Authentication (Email/Pass, Google - configure SHA-1s & Web Client ID), Firestore (create database), Cloud Messaging.
    * Publish Firestore Security Rules (use rules provided in conversation).
    * Create required Firestore Indexes by running the app and clicking console links when errors appear (for filtering/ordering requests).
4.  **API Keys & Configuration:**
    * **Google Maps Platform:** Enable Maps SDKs & Geocoding API. **Enable Billing**. Create restricted API Key. Add key to `AndroidManifest.xml`, `AppDelegate.swift`, `web/index.html`. (See earlier steps for details).
    * **(No ImgBB Key Needed)** - Profile pictures currently skipped.
    * **Android Signing Key:** Generate upload key (`.jks`) using `keytool`. Create `android/key.properties` with credentials and correct path (use `/`). Add `key.properties` to `.gitignore`. Ensure `build.gradle.kts` is configured for release signing.
5.  **Install Dependencies:** `flutter pub get`
6.  **Run the App:** `flutter run`

## 🚀 Usage

(Brief overview of how to use the main app features - Register/Login, View Home, Request Blood, View Requests/Map, Offer/Accept/Reject, View Profile/Badges, Learn Content etc.)

## ⚠️ Known Issues & TODOs

* **Google Maps Billing/API Key:** Geocoding API fails (`REQUEST_DENIED`) and map has watermark until billing/key setup is fully resolved in Google Cloud Console.
* **Donor "Connect" View:** Donors cannot currently see their offer statuses or accepted requester contact info. A "My Offers" section is needed.
* **Notifications (Sending):** Backend Cloud Function to send notifications is not yet deployed.
* **Badge Logic:** Most badges are only displayed; logic for awarding them based on donations, etc., needs implementation.
* **Donation History:** UI exists, but logic to record actual donations is needed.
* **OCR Robustness:** Parsing logic works for tested formats but may fail on others.
* **Contact Requester Button:** Placeholder, needs `url_launcher`.
* **Localization:** Needs full review and implementation.
* **Error Handling & Testing:** Needs improvement.
* **Security:** Revisit rules, ensure no keys are hardcoded (use `flutter_dotenv` if needed), clean Git history if secrets were exposed.

## Contributing

_(Optional: Add contribution guidelines)_
Currently under development.

## License

_(Optional: Add license like MIT)_
Unlicensed.
