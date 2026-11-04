# RedCellNet Web Admin Portal 🩸🛡️

A modern, high-performance web administration dashboard for the **RedCellNet** Emergency Blood Donation & Distribution Platform, powered by **React 19**, **TypeScript**, **Tailwind CSS**, and **Supabase (PostgreSQL & Realtime)**.

---

## 🌟 Key Features & Capabilities

### 1. Operations Dashboard (`/`)
- **Key Metrics & KPIs**: Total Donors, Verified Donors (with shield badge), Active Blood Requests, Critical Hospital Emergencies, Certified Facilities, and Pending Abuse Reports.
- **Supply & Demand Distribution Chart**: Visual real-time breakdown of available donors vs active requests across all 8 blood groups (`A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`).
- **Urgent Emergencies Feed**: Live ticker of critical blood requests requiring blood within 2 hours.
- **Moderation Queue**: Fast review of user-flagged content.
- **Sample Data Seeder**: One-click demo data generation for testing emergencies and reports.

### 2. Donors & Community Management (`/donors`)
- **Comprehensive Directory**: Browse all registered users with avatar, blood group badge, contact phone, email, and district/city.
- **Search & Multi-Filters**: Instant search by donor name, email, phone, city, blood group, verification status, and availability.
- **Verification Workflow**: Inspect donor laboratory documentation and approve with official Verified Shield badge or decline with custom reason.
- **Availability Toggle**: Realtime switch for donor active availability.
- **Profile Editor**: Edit contact info, city, blood group, and life points.
- **Data Export**: One-click **Export to CSV** for emergency hospital coordination.

### 3. Blood Requests & Emergency Dispatch (`/requests`)
- **Live Transfusion Requests**: Track all hospital requests across Bangladesh.
- **Urgency Classification**: Filter by `Critical`, `High`, `Medium`, and `Low`.
- **Status Tracking**: Transition requests between `Open`, `Partially Fulfilled`, `Fulfilled`, and `Cancelled`.
- **Offer Resolution**: Inspect volunteer donor offers and accept or decline on behalf of patients.
- **Data Export**: Export all hospital requests to CSV.

### 4. Certified Blood Banks & Centers (`/facilities`)
- **Facility Directory**: Manage verified hospital blood banks, hours, and contact numbers.
- **GPS Coordinates**: Exact Latitude & Longitude with direct Google Maps integration.
- **Facility CRUD**: Add new centers, edit existing details, and delete facilities.

### 5. Health Guides & Educational Content (`/content`)
- **Multilingual Support**: Publish articles in English and Bengali (বাংলা).
- **Categorization**: Eligibility criteria, donation process, health benefits, and myth busters.
- **Gamification Rewards**: Configure Life Point bonuses awarded to users for reading articles.
- **Full Article CRUD**: Add, edit, re-order, and delete articles.

### 6. Abuse Reports & Content Moderation (`/reports`)
- **Abuse Flag Review**: Investigate flags for duplicate requests, fraudulent posts, or misconduct.
- **One-Click Actions**: Dismiss flags or **Take Action** (automatically cancels reported request and penalizes bad actors).

### 7. Broadcast System Announcements (`/broadcast`)
- **Push & In-App Alerts**: Send emergency broadcasts to:
  1. All registered donors
  2. Donors of a specific blood group (e.g. urgent O- shortage alert)
  3. A specific user by ID
- **Preset Quick Templates**: Shortage warnings, disaster relief drives, and verification reminders.
- **Live Lock Screen Preview**: See exactly how the notification will look on donor smartphones.

### 8. Secure Admin Authentication
- **Supabase Auth**: Email & password authentication with persistent sessions.
- **Quick Demo Login**: Instant one-click authentication for development and rapid testing.
- **Supabase Realtime**: Live listening to changes on `blood_requests`, `profiles`, `donation_centers`, and `reports`.

---

## 🚀 Getting Started

### Prerequisites
- Node.js v18+ (Node v22+ recommended)
- npm or yarn

### Installation & Run

1. Open your terminal in the `admin_panel` directory:
   ```bash
   cd admin_panel
   ```

2. Install dependencies (if not already installed):
   ```bash
   npm install
   ```

3. Launch development server with Instant HMR:
   ```bash
   npm run dev
   ```
   Open [http://localhost:5173](http://localhost:5173) in your browser.

4. Build for Production:
   ```bash
   npm run build
   ```
   The production-ready bundle will be output to `admin_panel/dist`.

5. Preview Production Build locally:
   ```bash
   npm run preview
   ```

---

## 🌐 Deployment Options

The built admin panel (`dist/`) is a pure static single-page application and can be hosted on any static hosting provider:

- **Vercel**: Run `vercel` inside `admin_panel`
- **Netlify**: Run `netlify deploy --dir=dist --prod`
- **Cloudflare Pages**: Connect repo and set build output to `dist`
- **Supabase Storage**: Upload `dist/` files to a public Supabase Storage bucket
