# RedCellNet --- Required UI/UX and Feature Changes

> **Design direction:** Modern Healthcare + Emergency (Hybrid)\
> **Scope:** Entire application\
> **Focus:** UI/UX improvements and functional enhancements\
> **Source basis:** Existing RedCellNet application documentation
> (`APP_DOCUMENTATION.md`) and the requested hybrid redesign direction.

------------------------------------------------------------------------

## 1. Overall Product Direction

RedCellNet should feel like a trustworthy healthcare and blood-donation
platform, while making urgent blood requests immediately visible and
easy to act on.

The experience should have two visual modes:

-   **Everyday use:** calm, clean, professional healthcare interface.
-   **Emergency use:** clear, high-contrast urgency indicators and
    prominent emergency actions.

The redesign must cover the complete application, not only the home
dashboard. Existing working functionality should be retained unless a
change is explicitly required below.

## 2. Color System

Replace the current use of vivid red as a broad visual treatment with a
more controlled palette. Red should communicate the brand or an actual
emergency---not be used for every card, icon, or action.

### Brand and surface colors

  Purpose                  Color           Hex
  ------------------------ --------------- -----------
  Primary brand            Deep burgundy   `#A41235`
  Emergency accent         Crimson         `#E11D48`
  Soft rose surface        Pale rose       `#FFF1F2`
  Dark text                Slate           `#0F172A`
  Secondary text           Slate grey      `#64748B`
  Main background          Off-white       `#F8FAFC`
  Card surface             White           `#FFFFFF`
  Healthcare information   Medical blue    `#0284C7`
  Success / available      Green           `#059669`
  Critical                 Red             `#DC2626`
  High priority            Orange          `#EA580C`
  Moderate priority        Amber           `#D97706`

### Color usage rules

-   Use deep burgundy for primary branding and primary actions.
-   Reserve bright crimson/red for emergency actions and critical
    states.
-   Use pale rose for subtle blood-related highlights and selected
    states.
-   Use blue for hospital, blood-bank, and healthcare information.
-   Use green for successful verification and availability states.
-   Use amber/orange for warning and moderate/high urgency states.
-   Do not communicate status by color alone; include text labels or
    icons.
-   Maintain readable text contrast on all surfaces.
-   Add a complete dark theme using the same semantic color roles.

## 3. Global UI and Design-System Changes

Apply a consistent design system across every screen.

  Element                 Required standard
  ----------------------- -------------------------------------------
  UI framework            Flutter Material 3
  English font            Inter
  Bengali font            Noto Sans Bengali
  Main screen padding     16--20 px
  Card corner radius      14--16 px
  Dialog corner radius    Around 20 px
  Primary button height   52--56 px
  Input height            52--56 px
  Main heading            24--28 px, semibold
  Section heading         18--20 px, semibold
  Body text               14--16 px
  Supporting text         12--13 px
  Standard icon size      20--24 px
  Card shadows            Subtle; prefer borders over heavy shadows

### Reusable components

Create or standardize reusable components for:

-   Primary and secondary buttons
-   Emergency action button
-   Blood-group badge
-   Urgency badge
-   Verification badge
-   Donor availability control
-   Blood-request card
-   Donor card
-   Hospital / blood-bank card
-   Statistics card
-   Section header
-   Empty, loading, and error states
-   Confirmation dialog
-   Bottom navigation

Keep colors, typography, spacing, radii, and component variants
centralized in the existing theme system. Avoid screen-specific styling
that causes the application to look inconsistent.

### General interaction requirements

-   Use consistent loading, success, empty, and error states.
-   Provide clear confirmation for destructive or consequential actions.
-   Prevent accidental repeated submissions.
-   Use accessible touch targets.
-   Keep animations subtle and purposeful.
-   Respect system font scaling and smaller device sizes.
-   Support English and Bengali text without clipping or overflow.
-   Make all screens work in light and dark themes.

## 4. Screen-by-Screen UI Changes

### 4.1 Splash, Onboarding, and Authentication

Redesign:

-   Splash screen
-   Onboarding
-   Login
-   Registration
-   Forgot password
-   Password reset
-   Google sign-in flow

Required changes:

-   Use a clean white/light background with the RedCellNet brand
    identity.
-   Keep onboarding short and explain the service in up to three slides.
-   Use consistent form fields and validation messages.
-   Include password visibility controls.
-   Make authentication errors understandable and actionable.
-   Add phone-number verification where required.
-   Show a clear registration/profile-completion status.
-   Request location and other permissions when the feature needs them,
    with an explanation of why they are needed.

### 4.2 Home Dashboard

Reorganize the dashboard in this order:

1.  Greeting, user identity, and notification shortcut.
2.  Donor availability card.
3.  Prominent emergency blood-request action.
4.  Quick-access shortcuts.
5.  Nearby and compatible emergency requests.
6.  Donation statistics or donor progress.
7.  Relevant learning and awareness content.

Required changes:

-   Make donor availability easy to understand and change.
-   Clearly distinguish available, unavailable, and temporarily
    unavailable states.
-   Show nearby emergency requests with blood group, urgency, units,
    hospital, distance, and request age.
-   Prioritize relevant compatible requests without hiding the ability
    to browse all requests.
-   Provide quick access to Map, Requests, Donate/Offer, and Learn.
-   Show notification counts where applicable.
-   Avoid filling the dashboard with multiple competing red gradient
    cards.
-   Keep the emergency request action prominent without making the
    entire dashboard look like an emergency alert.

### 4.3 Blood Requests Center

Improve the current request tabs and request list.

Recommended tabs:

-   All Requests
-   Nearby
-   Critical
-   My Requests
-   My Offers

Each request card should show:

-   Blood group
-   Urgency
-   Required units
-   Accepted and remaining units, when applicable
-   Hospital name
-   Location/address
-   Distance, when available
-   Request creation time
-   Current request status
-   A clear action to view details

Add:

-   Search by hospital, location, blood group, or relevant request
    information.
-   Filters for blood group, urgency, status, and distance.
-   Sorting by urgency, distance, and newest.
-   Request expiry information.
-   Share request action.
-   Save/bookmark request action.
-   Report suspicious request action.
-   Clear empty and no-results states.

### 4.4 Create Blood Request

Retain the existing four-step wizard but improve clarity and usability.

**Step 1 --- Blood requirement**

-   Blood group
-   Required units
-   Blood component/type, if supported by the service

**Step 2 --- Urgency**

-   Critical
-   High
-   Moderate
-   Scheduled

Show a short explanation of each urgency option. Avoid implying that an
urgency label guarantees donor availability or medical response.

**Step 3 --- Hospital and location**

-   Hospital/facility name
-   Address
-   Map location
-   Current-location pinning
-   Hospital search/autocomplete, if available

**Step 4 --- Patient and contact**

-   Patient identifier or display name, using privacy-conscious wording
-   Attendant name
-   Contact number
-   Relevant request notes

Additional requirements:

-   Save draft.
-   Validate required fields and phone number.
-   Preview the request before broadcasting.
-   Confirm before publishing.
-   Show clear submission success/failure.
-   Allow the requester to manage or cancel their request.
-   Include an expiry setting or clearly defined expiry behavior.

### 4.5 Request Details and Donor Handshake

Improve both requester and donor views.

**Requester view**

-   Request summary and status
-   Required, accepted, and remaining units
-   Hospital and location
-   Donor offers
-   Donor verification status
-   Offered quantity
-   Accept/reject actions
-   Request cancellation
-   Request activity/timeline

**Donor view**

-   Blood compatibility result
-   Request urgency and quantity
-   Hospital and approximate distance
-   Relevant request information
-   Offer Blood action
-   Withdraw offer action
-   Contact details only when authorized by the workflow

Show clear status labels and explain what happens after an offer is
accepted.

### 4.6 OpenStreetMap Nearby View

Redesign the map interface while retaining the existing OpenStreetMap
functionality.

Required UI changes:

-   Floating search bar.
-   Map/List toggle.
-   Compact filter chips.
-   Clear emergency and healthcare-facility marker styles.
-   Recenter-on-user control.
-   Map-layer selector.
-   Zoom controls.
-   Draggable bottom-sheet preview for selected markers.

Add or improve:

-   Marker clustering for dense areas.
-   Distance filters (2 km, 5 km, 10 km, and 25 km).
-   Filters for emergencies, hospitals, and verified blood banks.
-   Blood-group filtering.
-   Navigation handoff to a supported maps application.
-   Last-updated information where location or facility data can become
    stale.
-   Compatible donor counts only where the underlying data is reliable
    and permissioned.

**Privacy requirement:** Do not expose an individual donor's exact live
location publicly. Use an appropriately approximate location or distance
and enforce access restrictions in backend rules.

### 4.7 Profile and Donor Dashboard

Organize the profile into clear sections.

**Donor identity**

-   Profile image
-   Name
-   Blood group
-   Verification status
-   Phone verification status
-   Availability status

**Donation information**

-   Completed donations
-   Donation history
-   Last donation date
-   Next eligible date, when safely determined
-   Verified donation records

**Achievements**

-   Donation milestones
-   Badges
-   Life Points
-   Donor tier

**Account and privacy**

-   Personal information
-   Language
-   Notification preferences
-   Location permissions
-   Privacy settings
-   Theme selection
-   Account deletion

Make completed and verified donations more prominent than points earned
for reading educational content.

### 4.8 Edit Profile and Blood-Report OCR

Improve the existing Google ML Kit OCR flow.

Required experience:

1.  Take a photo or select a report from the gallery.
2.  Scan the document.
3.  Display the extracted blood group.
4.  Ask the user to confirm the extracted value.
5.  Submit for verification if required.
6.  Display verification status and any rejection reason.

OCR must not automatically certify a blood group. Unclear or ambiguous
reports must not be treated as verified.

Also improve profile-field validation, image handling, and save
feedback.

### 4.9 Learn and Health Awareness

Redesign the educational area with:

-   Featured educational guides
-   Clear article categories
-   Search
-   Bengali/English content selection
-   Estimated reading time
-   Reading progress
-   Bookmarks
-   Consistent article typography
-   Clear source/review information for medical content

Recommended content categories:

-   Donor eligibility
-   Before donation
-   During donation
-   After donation
-   Health and safety
-   Myths and facts
-   Frequently asked questions

The existing 60-second eligibility quiz should be presented as
preliminary educational guidance, not medical clearance. Final donor
eligibility must be determined through the appropriate qualified medical
screening process.

### 4.10 Notifications Center

Create a dedicated notifications screen with categories for:

-   Emergency blood requests
-   Donor offers
-   Offer accepted or rejected
-   Request status changes
-   Donation reminders
-   Verification updates
-   System announcements

Required changes:

-   Unread/read states.
-   Clear timestamps.
-   Deep links to the relevant request or screen.
-   Notification preferences.
-   Mute or pause controls where appropriate.
-   Duplicate-notification prevention.
-   Clear distinction between emergency and nonessential notifications.

## 5. Functional Changes and New Features

### 5.1 Donor Verification

Add a verification workflow with:

-   Phone-number verification.
-   Blood-group report submission.
-   Verification status: unverified, pending, verified, rejected.
-   Review/rejection reason.
-   Ability to resubmit when appropriate.
-   Admin review for submitted evidence.

Do not display a verified badge until the verification process has
actually succeeded.

### 5.2 Multi-Donor and Partial Fulfillment

**Critical change to the existing request workflow.**

The current documented behavior marks a request fulfilled when a
requester accepts an offer. Change this so requests requiring multiple
units can be fulfilled by multiple donors.

Track:

-   `requiredUnits`
-   `acceptedUnits`
-   `remainingUnits`
-   Individual offer quantities
-   Individual offer statuses

Example:

-   Request requires 4 bags.
-   Donor A offers 1 bag and is accepted.
-   Donor B offers 2 bags and is accepted.
-   Remaining requirement is 1 bag.
-   Another donor can offer the remaining unit.
-   Mark the request fulfilled only when the required quantity has been
    satisfied.

Rules:

-   Accepted units must never exceed remaining units.
-   Concurrent acceptances must be handled safely.
-   Keep partially fulfilled requests open.
-   Stop or adjust new offer acceptance when the request is fully
    fulfilled.
-   Support offer rejection and withdrawal.
-   Define how cancellation affects already accepted offers.

### 5.3 Request Lifecycle and Expiry

Use clear request states:

-   Open
-   Partially Fulfilled
-   Fulfilled
-   Cancelled
-   Expired

Add:

-   Request expiry.
-   Expiry reminders where appropriate.
-   Automatic closure of expired requests.
-   Prevention of new offers on expired/cancelled requests.
-   Request activity history.
-   Requester confirmation when blood is no longer needed.

### 5.4 Donor Availability Scheduling

Extend the existing one-tap availability switch with:

-   Available now.
-   Temporarily unavailable.
-   Scheduled availability.
-   Pause notifications.
-   Automatic availability update after a donation, where appropriate.

Do not treat the availability switch as medical eligibility.

### 5.5 Smart Emergency Notifications

Improve emergency broadcasting by targeting relevant donors using:

-   Compatible blood group.
-   Donor availability.
-   Configurable distance/radius.
-   Verification and eligibility rules where applicable.
-   User notification preferences.

Include:

-   Delivery deduplication.
-   Notification delivery tracking.
-   Emergency-specific notification handling.
-   Notification throttling to prevent spam.
-   Appropriate fallback when no nearby compatible donors are found.

### 5.6 Donor Eligibility Safeguards

Improve the existing eligibility quiz and donation history workflow.

-   Record relevant donation dates.
-   Apply configurable cooldown checks.
-   Prevent clearly ineligible donors from being presented as ready to
    donate.
-   Explain that app-based checks are preliminary.
-   Require appropriate medical screening before donation.

Do not hard-code a universal cooldown or treat the current quiz as a
substitute for professional screening.

### 5.7 Hospital and Blood-Bank Directory

Improve the existing donation-center functionality.

Add or support:

-   Facility name
-   Facility type
-   Address
-   Coordinates
-   Contact information
-   Operating hours
-   Verification status
-   Last-updated information
-   Blood group availability, only if reliably maintained

Provide search, map display, and facility details.

### 5.8 Donation History and Certificates

Improve donation history with:

-   Donation date
-   Hospital/facility
-   Donation quantity
-   Related request, where applicable
-   Verification status

Add downloadable donation certificates only for records that have been
appropriately verified.

### 5.9 Trust, Safety, and Moderation

Add:

-   Report suspicious requests.
-   Report suspicious users.
-   Admin review queue.
-   Request moderation.
-   User suspension/restriction.
-   Verification review.
-   Administrative audit history.

## 6. Admin Dashboard Requirements

Add a separate administrative interface for managing the platform.

### Dashboard overview

Show:

-   Total registered users
-   Verified donors
-   Available donors
-   Active emergency requests
-   Partially fulfilled requests
-   Fulfilled requests
-   Pending verification submissions
-   Reported requests/users

### User management

-   Search and filter users.
-   View verification status.
-   Review submitted blood-group evidence.
-   Suspend or restore accounts.
-   Review reports.
-   View relevant account activity.

### Emergency request management

-   View all requests.
-   Filter by blood group, urgency, location, and status.
-   Review suspicious requests.
-   Close invalid requests.
-   Monitor fulfillment.
-   Review expired requests.

### Hospital and blood-bank management

-   Add and edit facilities.
-   Verify facility information.
-   Manage contact details.
-   Manage coordinates.
-   Update facility status.

### Analytics

-   Blood-group demand.
-   District/location-wise requests.
-   Request fulfillment rate.
-   Time to first donor offer.
-   Donor availability trends.
-   Verification coverage.

Use role-based access control and record sensitive administrative
actions in an audit log.

## 7. Backend, Firestore, and Security Changes

Retain the existing Flutter, Firebase, Firestore, Firebase
Authentication, FCM, and OpenStreetMap architecture where suitable.

Review and update the existing services rather than creating duplicate
service layers.

### Suggested data additions

``` text
users/
  {userId}
    verificationStatus
    availability
    lastDonationDate

bloodRequests/
  {requestId}
    requiredUnits
    acceptedUnits
    remainingUnits
    status
    expiryAt

  {requestId}/offers/
    {offerId}
      donorId
      offeredUnits
      status

donations/
  {donationId}

hospitals/
  {hospitalId}

notifications/
  {notificationId}

reports/
  {reportId}

verificationRequests/
  {verificationId}

adminLogs/
  {logId}
```

These are proposed data structures. Check the existing database before
introducing new collections or fields.

### Required backend safeguards

-   Use Firestore transactions or trusted backend operations for
    critical fulfillment changes.
-   Prevent accepted quantities from exceeding remaining quantities.
-   Validate user permissions on the backend.
-   Restrict access to sensitive contact details.
-   Prevent public exposure of exact donor coordinates.
-   Validate request ownership before edits/cancellation.
-   Protect verification status from unauthorized client-side
    modification.
-   Prevent duplicate donation records.
-   Record important moderation and administrative actions.
-   Use trusted scheduled backend processing for request expiry.
-   Use Firebase App Check and appropriate Firestore security rules.

## 8. Navigation Changes

Use a consistent bottom navigation structure across the mobile
application.

Recommended primary destinations:

1.  Home
2.  Requests
3.  Map
4.  Profile
5.  Learn

Notifications should be accessible from the top app bar.

Keep secondary functions within their relevant screens rather than
overcrowding the bottom navigation.

## 9. Accessibility, Localization, and Responsiveness

Required across the entire application:

-   Complete English and Bengali UI support.
-   Inter and Noto Sans Bengali typography.
-   Correct Bengali text rendering and line wrapping.
-   Light and dark themes.
-   Accessible text contrast.
-   Screen-reader-friendly labels.
-   Clear icons with text labels where needed.
-   Touch-friendly controls.
-   Support for small and large Android devices.
-   No clipped text or overflowing cards.
-   Clear feedback when permissions are denied.
-   Usable empty, loading, offline, and error states.

## 10. Quality and Performance Requirements

-   Use pagination for large request and user lists.
-   Optimize Firestore queries and indexes.
-   Cache appropriate images and static content.
-   Reduce unnecessary Firestore listeners.
-   Optimize map marker rendering.
-   Handle poor network connections gracefully.
-   Prevent duplicate form submissions.
-   Provide centralized error handling.
-   Add Firebase Crashlytics monitoring.
-   Test light/dark themes and both languages.
-   Test concurrent donor acceptance.
-   Test expired and cancelled requests.
-   Test authorization and privacy boundaries.

## 11. Acceptance Criteria

The changes should be considered complete only when:

-   All application screens follow the same design system.
-   The hybrid healthcare/emergency visual direction is consistent.
-   Red is reserved for appropriate brand and emergency use.
-   All existing working features remain functional.
-   Users can clearly understand donor availability and request status.
-   Multiple donors can contribute toward a single multi-unit request.
-   Fulfillment quantities cannot exceed the required quantity.
-   Request expiry and cancellation work correctly.
-   Verification status cannot be falsely assigned by a normal client.
-   Sensitive donor and patient information is access-controlled.
-   Emergency notifications are relevant and deduplicated.
-   Map views do not expose private donor locations.
-   Bengali and English layouts work correctly.
-   Dark mode works across all screens.
-   Critical workflows pass functional and security testing.

------------------------------------------------------------------------

## 12. Important Design and Product Principles

1.  **Emergency first, but not emergency everywhere.** Keep everyday
    screens calm and make urgent actions prominent.
2.  **Trust over gamification.** Verified donations and reliable donor
    information matter more than points and badges.
3.  **Privacy by design.** Donor and patient information must only be
    revealed when the workflow authorizes it.
4.  **Accurate fulfillment.** A request is not fulfilled just because
    one donor accepts an offer.
5.  **Medical safety.** The app supports donor discovery; it does not
    replace professional eligibility screening or medical decisions.
6.  **Consistency.** Every screen should use the same design tokens and
    reusable components.
7.  **Preserve working functionality.** Improve the current application
    instead of replacing working features with static UI.

**Final expected result:** A complete, consistent RedCellNet experience
that combines a professional healthcare interface with a fast,
trustworthy emergency blood-donation workflow.
