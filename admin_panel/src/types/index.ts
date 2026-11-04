// admin_panel/src/types/index.ts

export type BloodGroup = 'A+' | 'A-' | 'B+' | 'B-' | 'AB+' | 'AB-' | 'O+' | 'O-';

export type UrgencyLevel = 'Critical' | 'High' | 'Medium' | 'Low';

export type RequestStatus = 'Open' | 'Partially Fulfilled' | 'Fulfilled' | 'Cancelled' | 'Expired';

export type VerificationStatus = 'pending' | 'verified' | 'rejected';

export interface UserProfile {
  id: string;
  email: string;
  name: string;
  phone_number?: string;
  blood_type?: BloodGroup;
  location_city?: string;
  location_area?: string;
  is_available_to_donate?: boolean;
  is_verified_donor?: boolean;
  verification_status?: VerificationStatus;
  rejection_reason?: string;
  verified_at?: string;
  verification_lab?: string;
  verification_cert?: string;
  verification_notes?: string;
  verification_requested_at?: string;
  points?: number;
  total_donations?: number;
  badges?: string[];
  role?: 'admin' | 'moderator' | 'user';
  created_at?: string;
  updated_at?: string;
}

export interface BloodOffer {
  id: string;
  donorId: string;
  donorName: string;
  donorBloodType: string;
  offeredUnits: number;
  donorIsVerified?: boolean;
  status: 'pending' | 'accepted' | 'declined';
  offerTimestamp: string;
  acceptedAt?: string;
}

export interface TimelineEvent {
  action: string;
  by?: string;
  time: string;
  donorId?: string;
  units?: number;
  note?: string;
}

export interface BloodRequest {
  id: string;
  requester_user_id: string;
  patient_name: string;
  patient_identifier?: string;
  hospital_name: string;
  hospital_address?: string;
  city?: string;
  required_blood_type: BloodGroup;
  required_units: number;
  accepted_units: number;
  remaining_units: number;
  contact_phone: string;
  urgency_level: UrgencyLevel;
  reason?: string;
  is_emergency?: boolean;
  status: RequestStatus;
  cancellation_reason?: string;
  expiry_hours?: number;
  expiry_at?: string;
  component_type?: string;
  accepted_donor_ids?: string[];
  offers?: BloodOffer[];
  timeline?: TimelineEvent[];
  created_at?: string;
  updated_at?: string;
}

export interface DonationCenter {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  operating_hours?: string;
  contact_number?: string;
  created_at?: string;
}

export interface EducationalContent {
  id: string;
  title_en: string;
  title_bn: string;
  content_en: string;
  content_bn: string;
  category: string;
  order: number;
  image_url?: string;
  points: number;
  created_at?: string;
}

export interface NotificationItem {
  id: string;
  user_id: string;
  title: string;
  body: string;
  type?: string;
  screen?: string;
  resource_id?: string;
  is_read: boolean;
  created_at?: string;
}

export interface ReportItem {
  id: string;
  reporter_user_id: string;
  reported_type: 'request' | 'profile' | 'comment';
  target_id: string;
  reason: string;
  details?: string;
  status: 'pending' | 'dismissed' | 'action_taken';
  resolved_at?: string;
  created_at?: string;
}

export interface DashboardMetrics {
  totalUsers: number;
  verifiedDonors: number;
  pendingVerifications: number;
  availableDonors: number;
  totalRequests: number;
  activeRequests: number;
  criticalRequests: number;
  fulfilledRequests: number;
  totalFacilities: number;
  pendingReports: number;
  bloodGroupCounts: Record<BloodGroup, number>;
}
