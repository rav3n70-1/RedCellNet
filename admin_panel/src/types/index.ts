// admin_panel/src/types/index.ts

export type BloodGroup = 'A+' | 'A-' | 'B+' | 'B-' | 'AB+' | 'AB-' | 'O+' | 'O-';

export type UrgencyLevel = 'Critical' | 'High' | 'Medium' | 'Low';

export type RequestStatus = 'Open' | 'Partially Fulfilled' | 'Fulfilled' | 'Cancelled' | 'Expired';

export type VerificationStatus = 'unverified' | 'pending' | 'verified' | 'rejected';

export interface DonationHistoryEntry {
  id?: string;
  request_id?: string;
  hospital?: string;
  hospital_name?: string;
  date?: string;
  units?: number;
  component_type?: string;
  verified?: boolean;
  certificate_id?: string;
}

export interface UserProfile {
  id: string;
  email: string;
  name: string;
  phone_number?: string;
  is_phone_verified?: boolean;
  blood_type?: BloodGroup | null;
  location_city?: string;
  location_area?: string;
  avatar_url?: string;
  is_available_to_donate?: boolean;
  availability_status?: string;
  last_donation_date?: string | null;
  next_eligible_date?: string | null;
  is_verified_donor?: boolean;
  verification_status?: VerificationStatus;
  rejection_reason?: string | null;
  verified_at?: string | null;
  verification_lab?: string | null;
  verification_cert?: string | null;
  verification_notes?: string | null;
  verification_doc_url?: string | null;
  extracted_blood_type?: string | null;
  verification_requested_at?: string | null;
  points?: number;
  total_donations?: number;
  badges?: string[];
  donation_history?: DonationHistoryEntry[];
  role?: 'admin' | 'moderator' | 'user';
  is_banned?: boolean;
  ban_reason?: string | null;
  staff_notes?: Array<Record<string, unknown>>;
  created_at?: string;
  updated_at?: string;
}

export interface BloodOffer {
  id: string;
  donorId: string;
  donorName: string;
  donorBloodType: string;
  donorPhone?: string;
  offeredUnits: number;
  donorIsVerified?: boolean;
  note?: string;
  status: 'pending' | 'accepted' | 'declined' | 'completed' | 'withdrawn' | 'released';
  offerTimestamp: string;
  acceptedAt?: string;
  completedAt?: string;
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
  ward_bed_info?: string;
  city?: string;
  latitude?: number | null;
  longitude?: number | null;
  required_blood_type: BloodGroup;
  required_units: number;
  accepted_units: number;
  remaining_units: number;
  contact_person?: string;
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
  is_verified_hospital_case?: boolean;
  staff_notes?: Array<Record<string, unknown>>;
  created_at?: string;
  updated_at?: string;
}

export interface DonationCenter {
  id: string;
  name: string;
  address: string;
  city?: string;
  latitude: number | null;
  longitude: number | null;
  operating_hours?: string;
  contact_info?: string;
  contact_number?: string;
  facility_type?: string;
  operational_status?: string;
  is_verified?: boolean;
  blood_inventory?: Record<string, number>;
  created_at?: string;
  updated_at?: string;
}

export interface EducationalContent {
  id: string;
  title_en: string;
  title_bn: string;
  content_en: string;
  content_bn: string;
  category: string;
  order: number;
  image_url?: string | null;
  points: number;
  points_value?: number;
  read_time_minutes?: number;
  source_attribution?: string | null;
  created_at?: string;
  updated_at?: string;
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
  resolved_by?: string | null;
  resolution_notes?: string | null;
  resolved_at?: string | null;
  created_at?: string;
}

export interface AdminLog {
  id: string;
  admin_user_id: string | null;
  action_type: string;
  target_type: string;
  target_id?: string | null;
  details?: Record<string, unknown> | null;
  created_at: string;
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
  expiredRequests: number;
  totalFacilities: number;
  pendingReports: number;
  bloodGroupCounts: Record<BloodGroup, number>;
}

export interface SystemBroadcast {
  id: string;
  title: string;
  message: string;
  broadcast_type: string;
  target_blood_type?: string | null;
  target_city?: string | null;
  created_at: string;
  is_active: boolean;
  expires_at?: string | null;
  updated_at?: string | null;
}
