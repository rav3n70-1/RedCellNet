# RedCellNet - Blood Donation Network App

<p align="center">
  <img src="https://i.ibb.co.com/svqD8VfY/icon.png" alt="icon" border="0">
</p>

<p align="center">
  <strong>Connecting blood donors and recipients quickly and efficiently.</strong>
</p>

---

## Overview

**RedCellNet** is a mobile application built with Flutter and Firebase designed to streamline the blood donation process. The app allows users to request blood during emergencies, view nearby blood requests and donation centers, and offer help as a donor—all aimed at building a connected community focused on saving lives.

---

## Features

- **User Authentication:**  
  Secure login and registration using Email/Password and Google Sign-In.

- **User Profiles:**  
  Manage personal details including blood type, contact information, donation availability status, and display earned points and badges.

- **Profile Editing:**  
  Easily update your profile information.

- **Blood Report OCR:**  
  Scan blood reports using ML Kit Text Recognition, which automatically detects and suggests blood types during profile editing.

- **Blood Requests:**
  - Create detailed requests including patient information, required blood type, units, urgency, hospital, and contact details.
  - View all active requests under the **All Open** tab.
  - Monitor your own requests via the **My Requests** tab.
  - Filter requests by Blood Group and Urgency Level.
  - View detailed request information.
  - Delete your own requests.

- **Donation Offers & Connection:**
  - Compatible and available donors can "Offer Help" on requests.
  - Requesters can review pending offers on their requests.
  - Option to **Accept** or **Reject** offers—accepting a donor auto-rejects the remaining pending offers.
  - Access accepted donor’s name and contact information after an offer is accepted.
  - _(TODO: Build view for donors to see the status of their offers and requesters' contact info)_

- **Nearby Map:**  
  Visualize open blood requests and registered donation centers (requires Google Maps setup & API key).

- **Donation Centers:**  
  Locate registered donation centers (data fetched from Firestore) on an interactive map.

- **Educational Content:**  
  Browse informative articles and tips related to blood donation in the **Learn & Aware** section.

- **Rewards System (Gamification):**
  - **Points:** Earn points for activities such as completing your profile and reading educational content.
  - **Badges:** Earn badges for various achievements. Current badges include:
    - **First Drop:** Awarded upon recording your first successful donation.
    - **High Five:** For completing five donations.
    - **Double Digits:** For completing ten donations.
    - **Rare Hero:** For donating a rare blood type (e.g., AB-, O-).
    - **Crisis Warrior:** For donating during an emergency or disaster.
    - **Lifesaver Buddy:** For referring new donors.
    - **Health Aware:** For reading a set number of educational articles.
    - **Profile Complete:** For filling in mandatory fields (Name, Blood Type, City/Area).
    - **Standby Guardian:** For consistently being available to donate.
    - **Legend Donor:** For a significant number of completed donations.  
    _Note: Several badge logics are still under development._

- **Push Notifications (FCM):**
  - Receive notifications during foreground, background, and terminated app states.
  - Tap notifications to navigate to relevant request details.
  - _(TODO: Implement backend Cloud Function for sending notifications)_

---

📸 Screenshots
A visual overview of RedCellNet's key features:

🔐 Authentication
<p align="center"> <img src="https://i.ibb.co.com/tpBpZCk2/Login-Page.jpg" alt="Login Page" width="250"/> <img src="https://i.ibb.co.com/CKxzP6F9/Register-Page.jpg" alt="Register Page" width="250"/> </p>&#8203;
🏠 Home & Blood Requests
<p align="center"> <img src="https://i.ibb.co.com/ksYkCJDL/Home-Page.jpg" alt="Home Page" width="250"/> <img src="https://i.ibb.co.com/m5MC3WkQ/Blood-Requests.jpg" alt="Blood Requests" width="250"/> </p>&#8203;
➕ Create Request & 🗺️ Map View
<p align="center"> <img src="https://i.ibb.co.com/FLKtcr4k/Create-Blood-Request-Form.jpg" alt="Create Blood Request Form" width="250"/> <img src="https://i.ibb.co.com/LdWYdFpx/Nearby-Map.jpg" alt="Nearby Map" width="250"/> </p>&#8203;
👤 Profile & ✏️ Edit Profile
<p align="center"> <img src="https://i.ibb.co.com/7tGMTdg3/Profile-Page.jpg" alt="Profile Page" width="250"/> <img src="https://i.ibb.co.com/C5NSKsdV/Edit-Profile.jpg" alt="Edit Profile" width="250"/> </p>&#8203;
📚 Learn & Aware
<p align="center"> <img src="https://i.ibb.co.com/mCF6rJW1/photo-2-2025-04-14-13-58-56.jpg" alt="Learn Aware Page" width="250"/> </p>&#8203;

## Technology Stack

- **Framework:** Flutter (Cross-platform UI)
- **Language:** Dart
- **Backend & Database:** Firebase
  - **Firebase Authentication:** Email/Password, Google Sign-In
  - **Cloud Firestore:** NoSQL Database
  - **Firebase Cloud Messaging:** Push notifications
- **Mapping & Geocoding:** Google Maps Platform
  - `maps_flutter` for map display
  - `maps_apis` for geocoding (requires billing/API key)
- **Image & Text Recognition:**
  - `image_picker` for selecting images (gallery/camera)
  - `google_mlkit_text_recognition` for on-device OCR
- **State Management:**  
  Using implicit state management techniques (e.g., `StatefulWidget`, `StreamBuilder`, `FutureBuilder`)
- **Other:**
  - `intl` for date/time formatting
  - `flutter_local_notifications` for foreground messages
  - `permission_handler` for location access
  - `geolocator` for obtaining device location

---

## Setup & Installation (Developers)

1. **Prerequisites:**  
   Install Flutter SDK, Git, IDE (e.g., VS Code or Android Studio), and JDK.

2. **Clone Repository:**  
   ```bash
   git clone <your-repo-url>
   ```

3. **Firebase Project Setup:**  
   - Create a Firebase project.
   - Register Android, iOS, and Web apps.
   - Download and place `google-services.json` (Android) & `GoogleService-Info.plist` (iOS) appropriately.  
   - Enable Firebase Authentication (Email/Password, Google Sign-In), Firestore, and Cloud Messaging.
   - Publish Firestore Security Rules and create required Firestore Indexes by following on-screen instructions.

4. **Configure API Keys & Settings:**
   - **Google Maps Platform:**  
     Enable Maps SDKs & Geocoding API, enable billing, and add your restricted API key in the necessary files (`AndroidManifest.xml`, `AppDelegate.swift`, `web/index.html`).
   - **Android Signing Key:**  
     Generate an upload key (`.jks`), set up `android/key.properties`, and configure release signing in `build.gradle.kts`.

5. **Install Dependencies:**  
   ```bash
   flutter pub get
   ```

6. **Run the App:**  
   ```bash
   flutter run
   ```

---

## Usage

Once the app is running, users can:

- **Register/Login:** Access the app through secure authentication.
- **Home Screen:** Navigate to see nearby blood requests and donation centers.
- **Create/View Blood Requests:** Submit new blood requests and check active ones.
- **Offer/Accept Donations:** Donors can offer help; requesters can review and accept offers.
- **Manage Profile & Earn Rewards:** Update profile details, view points and badges, and read educational articles.

---

## Known Issues & TODOs

- **Google Maps Billing/API Key:**  
  The Geocoding API may fail with `REQUEST_DENIED` until billing is enabled.
- **Donor “Connect” View:**  
  Donors currently cannot track their offer statuses or view accepted requester information.
- **Push Notifications:**  
  Server-side Cloud Function for notifications is pending deployment.
- **Badge Logic:**  
  Badge award logic needs further implementation.
- **Donation History:**  
  UI exists; logic for tracking donations is still under development.
- **OCR Robustness:**  
  Parsing works with tested formats but could be improved for wider compatibility.
- **Contact Requester Functionality:**  
  Requires integration with `url_launcher` for contacting requesters.
- **Localization:**  
  Full localization review and implementation is pending.
- **Error Handling & Testing:**  
  Improvements needed in error handling and overall testing.
- **Security:**  
  Revisit Firebase rules and ensure no API keys or secrets are hardcoded (recommend using `flutter_dotenv`).

---

## Contributing

Your contributions are welcome as we continue to develop the app. Please follow our contribution guidelines and submit pull requests for review.

---

## License

Copyright © 2025  
Mehedi Hasan Rohan

All rights reserved.  
This source code is proprietary and confidential. Unauthorized copying, modification, distribution, or use of this code is strictly prohibited.

---

This updated README now clearly outlines the project’s features, tech stack, setup instructions, and includes a dedicated section for screenshots to help users understand the app visually. Adjust the image paths as necessary, and feel free to further refine any sections to better fit your evolving project needs.
