// admin_panel/src/pages/DonorsPage.tsx
import React, { useState, useEffect } from 'react';
import {
  Search,
  Filter,
  Download,
  CheckCircle,
  Edit2,
  Trash2,
  Users,
  Phone,
  Mail,
  MapPin,
  Award,
  Shield,
  Ban,
  UserCheck,
  FileText,
  ExternalLink,
  AlertTriangle,
  History,
  CheckCircle2,
  UserX,
} from 'lucide-react';
import type { BloodGroup, BloodRequest, UserProfile } from '../types';
import { BloodGroupBadge, StatusBadge, VerificationBadge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { EmptyState } from '../components/common/EmptyState';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface DonorsPageProps {
  donors: UserProfile[];
  staffMembers?: UserProfile[];
  requests?: BloodRequest[];
  onRefresh: () => void;
}

const BLOOD_GROUPS: BloodGroup[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

const ACCREDITED_LAB_KEYWORDS = [
  'POPULAR',
  'IBN SINA',
  'LABAID',
  'SQUARE',
  'EVERCARE',
  'UNITED HOSPITAL',
  'BSMMU',
  'PG HOSPITAL',
  'DHAKA MEDICAL',
  'DMCH',
  'RED CRESCENT',
  'BDRCS',
  'SANDHANI',
  'BADHAN',
  'QUANTUM',
  'BIRDEM',
  'ICDDR',
  'MEDINOVA',
  'PADMA DIAGNOSTIC',
  'CHEVRON',
  'EPIC HEALTH',
  'ASGAR ALI',
  'BRB',
  'KURMITOLA',
  'SUHRAWARDY',
  'SALIMULLAH',
  'MITFORD',
  'CMCH',
  'RMCH',
  'CMH',
  'NICVD',
  'PRAAVA',
  'AALOK',
];

interface ZeroCostScoreSummary {
  score: number;
  tier: 'HIGH_TRUST' | 'MODERATE_TRUST' | 'LOW_TRUST' | 'MISMATCH_ALERT';
  accreditedLab: boolean;
  extractedBg: string | null;
  hasConflict: boolean;
  hb: string | null;
  screening: string | null;
  cleanNotes: string;
}

function evaluateZeroCostVerification(donor: UserProfile): ZeroCostScoreSummary {
  const rawNotes = donor.verification_notes || '';
  const tagMatch = rawNotes.match(/\[ZCV-SCORE:(\d+)%\|TIER:([^|]+)\|BG:([^|]+)\|MATCH:([^|]+)\|LAB:([^|]+)\|CERT:([^|]+)\|HB:([^|]+)\|SCREEN:([^\]]+)\]/);
  const cleanNotes = rawNotes.replace(/\[ZCV-SCORE:[^\]]+\]\s*/g, '').trim();

  const labUpper = (donor.verification_lab || '').toUpperCase();
  const accreditedLab = ACCREDITED_LAB_KEYWORDS.some((k) => labUpper.includes(k));
  const extractedBg = donor.extracted_blood_type || (tagMatch && tagMatch[3] !== 'NONE' ? tagMatch[3] : null);
  const declaredBg = donor.blood_type || null;
  const hasConflict = Boolean(
    extractedBg && declaredBg && extractedBg.toUpperCase() !== declaredBg.toUpperCase()
  );

  if (tagMatch) {
    const parsedScore = Math.min(100, Math.max(0, parseInt(tagMatch[1], 10) || 0));
    const tier = hasConflict
      ? 'MISMATCH_ALERT'
      : parsedScore >= 75
        ? 'HIGH_TRUST'
        : parsedScore >= 50
          ? 'MODERATE_TRUST'
          : 'LOW_TRUST';
    return {
      score: parsedScore,
      tier,
      accreditedLab,
      extractedBg,
      hasConflict,
      hb: tagMatch[7] !== 'NA' ? tagMatch[7] : null,
      screening: tagMatch[8] !== 'NONE' ? tagMatch[8] : null,
      cleanNotes,
    };
  }

  let score = 0;
  if (extractedBg) {
    score += 35;
    if (declaredBg && extractedBg.toUpperCase() === declaredBg.toUpperCase()) {
      score += 20;
    } else if (!declaredBg) {
      score += 10;
    } else if (hasConflict) {
      score -= 25;
    }
  } else if (declaredBg) {
    score += 15;
  }

  if (accreditedLab) {
    score += 25;
  } else if (donor.verification_lab?.trim()) {
    score += 12;
  }

  if (donor.verification_cert?.trim()) {
    score += 15;
  }
  if (donor.verification_doc_url?.trim()) {
    score += 10;
  }
  if (donor.is_phone_verified) {
    score += 5;
  }

  const finalScore = Math.min(100, Math.max(0, score));
  const tier = hasConflict
    ? 'MISMATCH_ALERT'
    : finalScore >= 75
      ? 'HIGH_TRUST'
      : finalScore >= 50
        ? 'MODERATE_TRUST'
        : 'LOW_TRUST';

  return {
    score: finalScore,
    tier,
    accreditedLab,
    extractedBg,
    hasConflict,
    hb: null,
    screening: null,
    cleanNotes,
  };
}

export const DonorsPage: React.FC<DonorsPageProps> = ({
  donors,
  staffMembers = [],
  requests = [],
  onRefresh,
}) => {
  const { user: currentUser, isSuperAdmin } = useAuth();

  const [activeDirectoryTab, setActiveDirectoryTab] = useState<'donors' | 'staff'>('donors');
  const [searchQuery, setSearchQuery] = useState('');
  const [bloodFilter, setBloodFilter] = useState<string>('all');
  const [verificationFilter, setVerificationFilter] = useState<string>('all');
  const [availabilityFilter, setAvailabilityFilter] = useState<string>('all');
  const [roleFilter, setRoleFilter] = useState<string>('all');

  // Modals state
  const [reviewingDonor, setReviewingDonor] = useState<UserProfile | null>(null);
  const [signedDocUrl, setSignedDocUrl] = useState<string | null>(null);
  const [loadingDocUrl, setLoadingDocUrl] = useState(false);
  const [viewingActivityDonor, setViewingActivityDonor] = useState<UserProfile | null>(null);
  const [editingDonor, setEditingDonor] = useState<UserProfile | null>(null);
  const [deletingDonor, setDeletingDonor] = useState<UserProfile | null>(null);
  const [reviewingDeletionDonor, setReviewingDeletionDonor] = useState<UserProfile | null>(null);
  const [deletionAdminNote, setDeletionAdminNote] = useState('Processed by staff');
  const [deleteMode, setDeleteMode] = useState<'archive' | 'hard_delete'>('hard_delete');
  const [deleteReason, setDeleteReason] = useState('Removed by administrator');
  const [rejectionReason, setRejectionReason] = useState('Inconclusive or illegible laboratory report');
  const [isProcessing, setIsProcessing] = useState(false);

  // Edit form state (supports '' for unset blood group — never defaults null to O+)
  const [editForm, setEditForm] = useState<{
    name: string;
    phone_number: string;
    blood_type: BloodGroup | '';
    location_city: string;
    points: number;
    is_available_to_donate: boolean;
  }>({
    name: '',
    phone_number: '',
    blood_type: '',
    location_city: '',
    points: 0,
    is_available_to_donate: false,
  });

  // Load private verification document signed URL whenever reviewingDonor opens
  useEffect(() => {
    let cancelled = false;
    const loadSignedUrl = async () => {
      if (!reviewingDonor?.verification_doc_url) {
        setSignedDocUrl(null);
        return;
      }
      const rawPath = reviewingDonor.verification_doc_url.trim();
      if (!rawPath) {
        setSignedDocUrl(null);
        return;
      }
      if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
        // Check if it embeds verification-docs bucket path
        const marker = '/verification-docs/';
        const idx = rawPath.indexOf(marker);
        if (idx === -1) {
          setSignedDocUrl(rawPath);
          return;
        }
        const extractedPath = decodeURIComponent(rawPath.slice(idx + marker.length).split('?')[0]);
        setLoadingDocUrl(true);
        const { data, error } = await supabase.storage
          .from('verification-docs')
          .createSignedUrl(extractedPath, 3600);
        if (!cancelled) {
          setSignedDocUrl(!error && data?.signedUrl ? data.signedUrl : rawPath);
          setLoadingDocUrl(false);
        }
        return;
      }

      setLoadingDocUrl(true);
      const { data, error } = await supabase.storage
        .from('verification-docs')
        .createSignedUrl(rawPath, 3600);
      if (!cancelled) {
        setSignedDocUrl(!error && data?.signedUrl ? data.signedUrl : null);
        setLoadingDocUrl(false);
      }
    };

    loadSignedUrl();
    return () => {
      cancelled = true;
    };
  }, [reviewingDonor]);

  // Filtered donors
  const filteredDonors = donors.filter((d) => {
    const query = searchQuery.toLowerCase();
    const matchesSearch =
      (d.name || '').toLowerCase().includes(query) ||
      (d.email || '').toLowerCase().includes(query) ||
      (d.phone_number || '').includes(searchQuery) ||
      (d.location_city || '').toLowerCase().includes(query);

    const matchesBlood =
      bloodFilter === 'all' ||
      (bloodFilter === 'unset' ? !d.blood_type : d.blood_type === bloodFilter);

    const normalizedVerification = d.verification_status || 'unverified';
    const matchesVerification =
      verificationFilter === 'all' || normalizedVerification === verificationFilter;

    const matchesAvailability =
      availabilityFilter === 'all' ||
      (availabilityFilter === 'available' && Boolean(d.is_available_to_donate)) ||
      (availabilityFilter === 'unavailable' && !d.is_available_to_donate);

    const matchesRole =
      roleFilter === 'all' ||
      (roleFilter === 'banned' && Boolean(d.is_banned)) ||
      (roleFilter === 'deletion_requested' &&
        (Boolean(d.deletion_requested) || d.deletion_request_status === 'pending')) ||
      (d.role || 'user') === roleFilter;

    return (
      matchesSearch &&
      matchesBlood &&
      matchesVerification &&
      matchesAvailability &&
      matchesRole
    );
  });

  const pendingDeletionDonors = donors.filter(
    (d) => Boolean(d.deletion_requested) || d.deletion_request_status === 'pending'
  );

  // Resolve Account Deletion Request (Approve Hard Delete / Archive / Reject)
  const handleResolveDeletionRequest = async (
    donor: UserProfile,
    decision: 'approve_hard_delete' | 'archive' | 'reject'
  ) => {
    setIsProcessing(true);
    try {
      const { error } = await supabase.rpc('admin_resolve_deletion_request', {
        target_user_id: donor.id,
        decision,
        admin_note: deletionAdminNote.trim() || 'Processed by staff',
      });
      if (error) throw error;
      setReviewingDeletionDonor(null);
      setDeletionAdminNote('Processed by staff');
      onRefresh();
    } catch (err: unknown) {
      console.error('Error resolving account deletion request:', err);
      alert(err instanceof Error ? err.message : 'Failed to resolve deletion request.');
    } finally {
      setIsProcessing(false);
    }
  };

  // Verification Decision (Approve / Reject, with optional OCR Blood Group Sync)
  const handleVerificationDecision = async (
    donor: UserProfile,
    approve: boolean,
    syncExtractedBloodGroup = false
  ) => {
    const targetBlood = syncExtractedBloodGroup
      ? donor.extracted_blood_type || donor.blood_type
      : donor.blood_type || donor.extracted_blood_type;

    if (approve && !targetBlood) {
      alert('Cannot approve donor verification while blood group is unset.');
      return;
    }
    setIsProcessing(true);
    try {
      if (approve && targetBlood && targetBlood !== donor.blood_type) {
        const { error: bgError } = await supabase
          .from('profiles')
          .update({ blood_type: targetBlood })
          .eq('id', donor.id);
        if (bgError) throw bgError;
      }

      const { error } = await supabase.rpc('verify_donor', {
        target_user_id: donor.id,
        should_approve: approve,
        admin_notes: approve ? 'Verified by RedCellNet' : rejectionReason.trim() || 'Rejected by clinical reviewer',
      });
      if (error) throw error;

      // Also purge stored document from verification-docs storage bucket if present
      if (donor.verification_doc_url?.trim()) {
        const rawPath = donor.verification_doc_url.trim();
        const marker = '/verification-docs/';
        const idx = rawPath.indexOf(marker);
        const cleanStoragePath = idx !== -1
          ? decodeURIComponent(rawPath.slice(idx + marker.length).split('?')[0])
          : rawPath;
        if (!cleanStoragePath.startsWith('http')) {
          await supabase.storage.from('verification-docs').remove([cleanStoragePath]);
        }
      }

      setReviewingDonor(null);
      onRefresh();
    } catch (err: unknown) {
      console.error('Error updating verification status:', err);
      alert(err instanceof Error ? err.message : 'Failed to update verification status.');
    } finally {
      setIsProcessing(false);
    }
  };

  // Batch Fast-Track High-Confidence Pending Verifications
  const pendingHighTrustDonors = donors.filter((d) => {
    if (d.verification_status !== 'pending') return false;
    const zcv = evaluateZeroCostVerification(d);
    return zcv.score >= 75 && !zcv.hasConflict && Boolean(d.blood_type || zcv.extractedBg);
  });

  const handleBatchFastTrackApprove = async () => {
    if (pendingHighTrustDonors.length === 0) return;
    setIsProcessing(true);
    try {
      for (const d of pendingHighTrustDonors) {
        const zcv = evaluateZeroCostVerification(d);
        if (!d.blood_type && zcv.extractedBg) {
          await supabase.from('profiles').update({ blood_type: zcv.extractedBg }).eq('id', d.id);
        }
        await supabase.rpc('verify_donor', {
          target_user_id: d.id,
          should_approve: true,
          admin_notes: `Fast-tracked via Zero-Cost Clinical Engine (${zcv.score}% confidence)`,
        });
      }
      onRefresh();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Batch verification failed.');
    } finally {
      setIsProcessing(false);
    }
  };

  // Manage Role (Super Admin only)
  const handleRoleChange = async (donor: UserProfile, newRole: 'user' | 'moderator' | 'admin') => {
    if (!isSuperAdmin) {
      alert('Only Super Administrators can change staff roles.');
      return;
    }
    if (donor.id === currentUser?.id) {
      alert('You cannot modify your own Super Admin role.');
      return;
    }
    if (
      !window.confirm(
        `Change ${donor.name || donor.email}'s system role to ${newRole.toUpperCase()}?`
      )
    ) {
      return;
    }
    setIsProcessing(true);
    try {
      const { error } = await supabase.rpc('manage_user_role', {
        target_user_id: donor.id,
        new_role: newRole,
      });
      if (error) throw error;
      onRefresh();
    } catch (err: unknown) {
      console.error('Error changing user role:', err);
      alert(err instanceof Error ? err.message : 'Failed to change user role.');
    } finally {
      setIsProcessing(false);
    }
  };

  // Toggle Account Suspension / Ban
  const handleBanToggle = async (donor: UserProfile, shouldBan: boolean) => {
    if (donor.id === currentUser?.id) {
      alert('You cannot suspend your own account.');
      return;
    }
    if (donor.role === 'admin' && !isSuperAdmin) {
      alert('Moderators cannot suspend Administrator accounts.');
      return;
    }

    let reason = 'Violation of community safety guidelines';
    if (shouldBan) {
      const input = window.prompt(`Enter reason for suspending ${donor.name || 'user'}:`, reason);
      if (input === null) return;
      reason = input.trim() || reason;
    }

    setIsProcessing(true);
    try {
      const { error } = await supabase.rpc('set_user_ban_status', {
        target_user_id: donor.id,
        should_ban: shouldBan,
        reason,
      });
      if (error) throw error;
      onRefresh();
    } catch (err: unknown) {
      console.error('Error updating account status:', err);
      alert(err instanceof Error ? err.message : 'Failed to update suspension status.');
    } finally {
      setIsProcessing(false);
    }
  };

  // Toggle Availability (respects 90-day WHO cooldown warning for staff)
  const handleToggleAvailability = async (donor: UserProfile) => {
    const nextAvailable = !donor.is_available_to_donate;
    if (nextAvailable && donor.next_eligible_date) {
      const eligibleDate = new Date(donor.next_eligible_date);
      if (eligibleDate.getTime() > Date.now()) {
        alert(
          `WHO 90-day recovery cooldown active until ${eligibleDate.toLocaleDateString()}. Donor cannot be marked available early.`
        );
        return;
      }
    }
    try {
      const { error } = await supabase
        .from('profiles')
        .update({
          is_available_to_donate: nextAvailable,
          availability_status: nextAvailable ? 'available' : 'unavailable',
          updated_at: new Date().toISOString(),
        })
        .eq('id', donor.id);
      if (error) throw error;
      await supabase.rpc('record_admin_log', {
        p_action_type: 'toggle_donor_availability',
        p_target_type: 'profile',
        p_target_id: donor.id,
        p_details: { available: nextAvailable },
      });
      onRefresh();
    } catch (err) {
      console.error('Error toggling availability:', err);
    }
  };

  // Open Edit Modal
  const openEditModal = (donor: UserProfile) => {
    setEditingDonor(donor);
    setEditForm({
      name: donor.name || '',
      phone_number: donor.phone_number || '',
      blood_type: donor.blood_type || '',
      location_city: donor.location_city || '',
      points: donor.points || 0,
      is_available_to_donate: donor.is_available_to_donate ?? false,
    });
  };

  // Save Edit Profile
  const handleSaveEdit = async () => {
    if (!editingDonor) return;
    const bloodChanged = (editingDonor.blood_type || '') !== editForm.blood_type;
    if (bloodChanged && editingDonor.is_verified_donor) {
      const proceed = window.confirm(
        'Changing a verified donor’s blood group will reset their Verified Shield status until a matching lab report is reviewed. Continue?'
      );
      if (!proceed) return;
    }

    setIsProcessing(true);
    try {
      const payload: Record<string, unknown> = {
        name: editForm.name.trim(),
        phone_number: editForm.phone_number.trim(),
        blood_type: editForm.blood_type || null,
        location_city: editForm.location_city.trim(),
        points: editForm.points,
        is_available_to_donate: editForm.is_available_to_donate,
        availability_status: editForm.is_available_to_donate ? 'available' : 'unavailable',
        updated_at: new Date().toISOString(),
      };

      if (bloodChanged && editingDonor.is_verified_donor) {
        payload.is_verified_donor = false;
        payload.verification_status = 'unverified';
      }

      const { error } = await supabase.from('profiles').update(payload).eq('id', editingDonor.id);
      if (error) throw error;

      await supabase.rpc('record_admin_log', {
        p_action_type: 'edit_user_profile',
        p_target_type: 'profile',
        p_target_id: editingDonor.id,
        p_details: { blood_type: editForm.blood_type || 'unset', blood_changed: bloodChanged },
      });

      setEditingDonor(null);
      onRefresh();
    } catch (err: unknown) {
      console.error('Error editing donor:', err);
      alert(err instanceof Error ? err.message : 'Failed to save profile changes.');
    } finally {
      setIsProcessing(false);
    }
  };

  // Archive (Soft Delete) or Permanently Hard Delete Donor Profile
  const handleDeleteDonor = async () => {
    if (!deletingDonor) return;
    setIsProcessing(true);
    try {
      const targetId = deletingDonor.id;
      const { error } = await supabase.rpc('admin_delete_or_archive_user', {
        target_user_id: targetId,
        delete_mode: deleteMode,
        reason: deleteReason.trim() || (deleteMode === 'hard_delete' ? 'Permanently deleted by admin' : 'Archived by staff'),
      });
      if (error) throw error;

      setDeletingDonor(null);
      onRefresh();
    } catch (err: unknown) {
      console.error('Error archiving/deleting donor profile:', err);
      alert(err instanceof Error ? err.message : 'Failed to process account deletion.');
    } finally {
      setIsProcessing(false);
    }
  };

  // Export Donors to CSV
  const exportToCSV = () => {
    const headers = [
      'Name',
      'Email',
      'Phone',
      'Phone Verified',
      'Blood Group',
      'City',
      'Role',
      'Verification Status',
      'Available to Donate',
      'Total Donations',
      'Life Points',
    ];

    const rows = filteredDonors.map((d) => [
      `"${(d.name || '').replace(/"/g, '""')}"`,
      `"${(d.email || '').replace(/"/g, '""')}"`,
      `"${(d.phone_number || '').replace(/"/g, '""')}"`,
      d.is_phone_verified ? 'Yes' : 'No',
      `"${d.blood_type || 'Unset'}"`,
      `"${(d.location_city || '').replace(/"/g, '""')}"`,
      `"${d.role || 'user'}"`,
      `"${d.verification_status || 'unverified'}"`,
      d.is_available_to_donate ? 'Yes' : 'No',
      d.total_donations || 0,
      d.points || 0,
    ]);

    const csvContent =
      'data:text/csv;charset=utf-8,' +
      [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `redcellnet_donors_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Activity calculations for viewingActivityDonor
  const donorCreatedRequests = viewingActivityDonor
    ? requests.filter((r) => r.requester_user_id === viewingActivityDonor.id)
    : [];
  const donorSubmittedOffers = viewingActivityDonor
    ? requests.flatMap((r) =>
      (r.offers || [])
        .filter((o) => o.donorId === viewingActivityDonor.id)
        .map((o) => ({ offer: o, request: r }))
    )
    : [];

  const reviewingZcv = reviewingDonor ? evaluateZeroCostVerification(reviewingDonor) : null;

  const filteredStaff = staffMembers.filter((s) => {
    const query = searchQuery.toLowerCase();
    return (
      (s.name || '').toLowerCase().includes(query) ||
      (s.email || '').toLowerCase().includes(query) ||
      (s.phone_number || '').includes(searchQuery)
    );
  });

  return (
    <div className="space-y-6">
      {/* Directory Separation Tabs: Registered Donors vs Admin & Staff Roster */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setActiveDirectoryTab('donors')}
            className={`px-4 py-2 rounded-xl text-xs font-black transition-all flex items-center gap-2 ${
              activeDirectoryTab === 'donors'
                ? 'bg-red-600 text-white shadow-xs'
                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
            }`}
          >
            <Users className="w-4 h-4" />
            Registered Donors ({donors.length})
          </button>
          <button
            type="button"
            onClick={() => setActiveDirectoryTab('staff')}
            className={`px-4 py-2 rounded-xl text-xs font-black transition-all flex items-center gap-2 ${
              activeDirectoryTab === 'staff'
                ? 'bg-slate-900 text-white shadow-xs'
                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
            }`}
          >
            <Shield className="w-4 h-4" />
            Admin & Staff Roster ({staffMembers.length})
          </button>
        </div>

        <div className="text-xs text-slate-500 font-medium">
          {activeDirectoryTab === 'donors'
            ? 'Strictly regular donors (Admin & Staff accounts are isolated from donor metrics & dispatches).'
            : 'Dedicated Governance & Medical Moderation Officers (excluded from donor pool).'}
        </div>
      </div>

      {/* Zero-Cost Clinical Engine Fast-Track Banner */}
      {activeDirectoryTab === 'donors' && pendingHighTrustDonors.length > 0 && (
        <div className="bg-emerald-50 border border-emerald-200 rounded-2xl p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-600 text-white flex items-center justify-center shrink-0 font-black text-xs">
              AI/OCR
            </div>
            <div>
              <h4 className="text-xs font-black text-emerald-950">
                {pendingHighTrustDonors.length} High-Confidence Verification(s) Ready for Fast-Track
              </h4>
              <p className="text-[11px] text-emerald-800">
                Donor Verification Engine confirmed Accredited Lab + Matching ABO/Rh with ≥75% trust score.
              </p>
            </div>
          </div>
          <button
            type="button"
            disabled={isProcessing}
            onClick={handleBatchFastTrackApprove}
            className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-black shadow-xs transition-colors shrink-0"
          >
            Approve All High-Trust ({pendingHighTrustDonors.length})
          </button>
        </div>
      )}

      {/* Pending Account Deletion Requests Banner */}
      {activeDirectoryTab === 'donors' && pendingDeletionDonors.length > 0 && (
        <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-rose-600 text-white flex items-center justify-center shrink-0">
              <UserX className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-xs font-black text-rose-950">
                {pendingDeletionDonors.length} Account Deletion Request(s) Require Staff Approval
              </h4>
              <p className="text-[11px] text-rose-800">
                Regular users cannot self-delete or archive accounts. Review requests to permanently delete, archive, or reject.
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={() =>
              setRoleFilter(roleFilter === 'deletion_requested' ? 'all' : 'deletion_requested')
            }
            className="px-4 py-2 rounded-xl bg-rose-600 hover:bg-rose-700 text-white text-xs font-black shadow-xs transition-colors shrink-0"
          >
            {roleFilter === 'deletion_requested'
              ? 'Show All Donors'
              : `Filter Deletion Queue (${pendingDeletionDonors.length})`}
          </button>
        </div>
      )}

      {/* Search & Filter Toolbar */}
      <div className="bg-white p-4.5 rounded-2xl border border-slate-200 shadow-xs flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-4">
        {/* Search */}
        <div className="relative flex-1 min-w-[240px]">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search donors by name, email, phone, or city..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-hidden focus:ring-2 focus:ring-red-500/20 focus:border-red-500 transition-all"
          />
        </div>

        {/* Dropdowns */}
        <div className="flex flex-wrap items-center gap-2.5">
          <div className="flex items-center gap-1.5 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 text-xs">
            <Filter className="w-3.5 h-3.5 text-slate-500" />
            <select
              value={bloodFilter}
              onChange={(e) => setBloodFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Blood Groups</option>
              {BLOOD_GROUPS.map((bg) => (
                <option key={bg} value={bg}>
                  {bg}
                </option>
              ))}
              <option value="unset">Unset Group</option>
            </select>
          </div>

          <div className="bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 text-xs">
            <select
              value={verificationFilter}
              onChange={(e) => setVerificationFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Verifications</option>
              <option value="verified">Verified Donors</option>
              <option value="pending">Pending Review</option>
              <option value="unverified">Unverified</option>
              <option value="rejected">Rejected</option>
            </select>
          </div>

          <div className="bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 text-xs">
            <select
              value={availabilityFilter}
              onChange={(e) => setAvailabilityFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Availability</option>
              <option value="available">Available Now</option>
              <option value="unavailable">Unavailable / Cooldown</option>
            </select>
          </div>

          <div className="bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 text-xs">
            <select
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Donor Statuses</option>
              <option value="user">Active Donor Accounts</option>
              <option value="banned">Suspended / Archived Accounts</option>
              <option value="deletion_requested">Deletion Requested (Pending Approval)</option>
            </select>
          </div>

          <button
            onClick={exportToCSV}
            title="Export Registered Donors CSV"
            className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            <Download className="w-3.5 h-3.5" />
            Export Donors CSV
          </button>
        </div>
      </div>

      {activeDirectoryTab === 'staff' ? (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
          {filteredStaff.length === 0 ? (
            <EmptyState
              icon={Shield}
              title="No Staff Members Found"
              description="Promote a trusted account from the Registered Donors tab to Moderator or Admin."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-sm">
                <thead>
                  <tr className="bg-slate-900 text-white text-[11px] font-bold uppercase tracking-wider">
                    <th className="py-3.5 px-5">Staff Officer</th>
                    <th className="py-3.5 px-4">RBAC Role</th>
                    <th className="py-3.5 px-4">Official Contact</th>
                    <th className="py-3.5 px-4">Donor Pool Isolation</th>
                    <th className="py-3.5 px-5 text-right">Governance Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredStaff.map((staff) => (
                    <tr key={staff.id} className="hover:bg-slate-50/70 transition-colors">
                      <td className="py-3.5 px-5">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-xl bg-slate-900 text-white font-black text-xs flex items-center justify-center shrink-0">
                            <Shield className="w-4 h-4 text-rose-400" />
                          </div>
                          <div>
                            <div className="font-bold text-slate-900">
                              {staff.name || 'Staff Officer'}
                            </div>
                            <div className="text-xs text-slate-400 font-mono">
                              {staff.id.slice(0, 12)}...
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="py-3.5 px-4">
                        {staff.role === 'admin' ? (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-black bg-purple-100 text-purple-800 border border-purple-200">
                            <Shield className="w-3.5 h-3.5" /> Super Admin
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-black bg-amber-100 text-amber-800 border border-amber-200">
                            <Shield className="w-3.5 h-3.5" /> Medical Moderator
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-xs text-slate-700">
                        <div>{staff.email}</div>
                        {staff.phone_number && (
                          <div className="text-slate-400">{staff.phone_number}</div>
                        )}
                      </td>
                      <td className="py-3.5 px-4">
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-[11px] font-bold bg-slate-100 text-slate-700">
                          Non-Donor Staff Account (Isolated)
                        </span>
                      </td>
                      <td className="py-3.5 px-5 text-right">
                        {isSuperAdmin && staff.id !== currentUser?.id ? (
                          <select
                            aria-label={`Role for ${staff.name || staff.email}`}
                            value={staff.role || 'moderator'}
                            onChange={(e) =>
                              handleRoleChange(
                                staff,
                                e.target.value as 'user' | 'moderator' | 'admin'
                              )
                            }
                            className="text-xs font-bold bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 text-slate-800"
                          >
                            <option value="admin">Super Admin</option>
                            <option value="moderator">Medical Moderator</option>
                            <option value="user">Move to Regular Donor Pool</option>
                          </select>
                        ) : (
                          <span className="text-xs text-slate-400 italic">Active Session</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      ) : (
      /* Donors Table */
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        {filteredDonors.length === 0 ? (
          <EmptyState
            icon={Users}
            title="No Donors Found"
            description={
              searchQuery ||
                bloodFilter !== 'all' ||
                verificationFilter !== 'all' ||
                availabilityFilter !== 'all' ||
                roleFilter !== 'all'
                ? 'No donors match your search filters. Try clearing some filters.'
                : 'No registered donors are in the database yet.'
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-sm">
              <thead>
                <tr className="bg-slate-50/80 border-b border-slate-200 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                  <th className="py-3.5 px-5">Donor Name</th>
                  <th className="py-3.5 px-4">Blood Group</th>
                  <th className="py-3.5 px-4">Contact Info</th>
                  <th className="py-3.5 px-4">City</th>
                  <th className="py-3.5 px-4">Available</th>
                  <th className="py-3.5 px-4">Verification</th>
                  <th className="py-3.5 px-4">Impact</th>
                  <th className="py-3.5 px-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredDonors.map((donor) => {
                  const canManageBan =
                    donor.id !== currentUser?.id && (donor.role !== 'admin' || isSuperAdmin);

                  return (
                    <tr key={donor.id} className="hover:bg-slate-50/60 transition-colors">
                      {/* Name & Avatar */}
                      <td className="py-3.5 px-5">
                        <div className="flex items-center gap-3">
                          {donor.avatar_url ? (
                            <img
                              src={donor.avatar_url}
                              alt={donor.name || 'User'}
                              className="w-9 h-9 rounded-full object-cover border border-slate-200 shrink-0"
                            />
                          ) : (
                            <div className="w-9 h-9 rounded-full bg-gradient-to-tr from-red-600 to-rose-400 text-white font-black text-xs flex items-center justify-center shrink-0 shadow-xs">
                              {(donor.name || 'U').charAt(0).toUpperCase()}
                            </div>
                          )}
                          <div>
                            <div className="font-bold text-slate-900 flex flex-wrap items-center gap-1.5">
                              {donor.name || 'Unnamed Donor'}
                              {donor.role === 'admin' && (
                                <span className="text-[10px] font-extrabold uppercase px-1.5 py-0.5 rounded-sm bg-purple-100 text-purple-700">
                                  Admin
                                </span>
                              )}
                              {donor.role === 'moderator' && (
                                <span className="text-[10px] font-extrabold uppercase px-1.5 py-0.5 rounded-sm bg-amber-100 text-amber-700 flex items-center gap-0.5">
                                  <Shield className="w-2.5 h-2.5" /> Moderator
                                </span>
                              )}
                              {donor.is_banned && (
                                <span className="text-[10px] font-extrabold uppercase px-1.5 py-0.5 rounded-sm bg-rose-100 text-rose-700 flex items-center gap-0.5">
                                  <Ban className="w-2.5 h-2.5" /> Suspended / Archived
                                </span>
                              )}
                              {(donor.deletion_requested ||
                                donor.deletion_request_status === 'pending') && (
                                <button
                                  type="button"
                                  onClick={() => setReviewingDeletionDonor(donor)}
                                  className="text-[10px] font-extrabold uppercase px-1.5 py-0.5 rounded-sm bg-rose-600 text-white flex items-center gap-1 hover:bg-rose-700 transition-colors"
                                >
                                  <UserX className="w-2.5 h-2.5" /> Deletion Requested
                                </button>
                              )}
                            </div>
                            <div className="text-xs text-slate-400 font-mono">
                              {donor.id.slice(0, 8)}...
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Blood Group */}
                      <td className="py-3.5 px-4">
                        <BloodGroupBadge bloodType={donor.blood_type} size="md" />
                      </td>

                      {/* Contact */}
                      <td className="py-3.5 px-4 text-xs">
                        <div className="flex items-center gap-1.5 text-slate-700">
                          <Mail className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                          <span className="truncate max-w-[160px]">{donor.email}</span>
                        </div>
                        {donor.phone_number && (
                          <div className="flex items-center gap-1.5 text-slate-500 mt-0.5">
                            <Phone className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                            <span>{donor.phone_number}</span>
                            {donor.is_phone_verified && (
                              <span title="Verified Phone">
                                <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                              </span>
                            )}
                          </div>
                        )}
                      </td>

                      {/* City */}
                      <td className="py-3.5 px-4 text-xs font-medium text-slate-700">
                        {donor.location_city ? (
                          <span className="flex items-center gap-1">
                            <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                            {donor.location_city}
                          </span>
                        ) : (
                          <span className="text-slate-400 italic">Not set</span>
                        )}
                      </td>

                      {/* Availability Switch */}
                      <td className="py-3.5 px-4">
                        <button
                          onClick={() => handleToggleAvailability(donor)}
                          title="Toggle availability"
                          className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-hidden ${donor.is_available_to_donate ? 'bg-emerald-500' : 'bg-slate-300'
                            }`}
                        >
                          <span
                            className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out ${donor.is_available_to_donate ? 'translate-x-4' : 'translate-x-0'
                              }`}
                          />
                        </button>
                      </td>

                      {/* Verification Status + Zero-Cost Clinical Score */}
                      <td className="py-3.5 px-4">
                        <div className="flex flex-col gap-1">
                          <div className="flex items-center gap-1.5">
                            <VerificationBadge status={donor.verification_status} />
                            {donor.verification_doc_url && donor.verification_status !== 'pending' && (
                              <button
                                type="button"
                                onClick={() => setReviewingDonor(donor)}
                                title="Inspect uploaded lab document"
                                className="p-1 text-slate-400 hover:text-blue-600 rounded"
                              >
                                <FileText className="w-3.5 h-3.5" />
                              </button>
                            )}
                          </div>
                          {donor.verification_status === 'pending' && (() => {
                            const zcv = evaluateZeroCostVerification(donor);
                            return (
                              <span
                                className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-black w-fit ${
                                  zcv.hasConflict
                                    ? 'bg-rose-100 text-rose-700'
                                    : zcv.score >= 75
                                      ? 'bg-emerald-100 text-emerald-800'
                                      : 'bg-amber-100 text-amber-800'
                                }`}
                              >
                                {zcv.score}% Trust{zcv.accreditedLab ? ' • Accredited Lab' : ''}
                              </span>
                            );
                          })()}
                        </div>
                      </td>

                      {/* Points & Donations */}
                      <td className="py-3.5 px-4 text-xs font-bold text-slate-800">
                        <div className="flex items-center gap-1">
                          <Award className="w-3.5 h-3.5 text-amber-500" />
                          {donor.points || 0} pts
                        </div>
                        <div className="text-[11px] font-medium text-slate-400">
                          {donor.total_donations || 0} verified donation(s)
                        </div>
                      </td>

                      {/* Actions */}
                      <td className="py-3.5 px-5 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          {(donor.deletion_requested ||
                            donor.deletion_request_status === 'pending') && (
                            <button
                              onClick={() => setReviewingDeletionDonor(donor)}
                              className="px-2.5 py-1 text-xs font-bold text-white bg-rose-600 hover:bg-rose-700 rounded-lg transition-colors flex items-center gap-1"
                            >
                              <UserX className="w-3.5 h-3.5" />
                              Review Deletion
                            </button>
                          )}

                          {donor.verification_status === 'pending' && (
                            <button
                              onClick={() => setReviewingDonor(donor)}
                              className="px-2.5 py-1 text-xs font-bold text-amber-800 bg-amber-100 hover:bg-amber-200 rounded-lg transition-colors"
                            >
                              Review
                            </button>
                          )}

                          <button
                            onClick={() => setViewingActivityDonor(donor)}
                            className="p-1.5 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                            title="Inspect User Activity & History"
                          >
                            <History className="w-4 h-4" />
                          </button>

                          {isSuperAdmin && donor.id !== currentUser?.id && (
                            <select
                              aria-label={`Role for ${donor.name || donor.email}`}
                              value={donor.role || 'user'}
                              onChange={(e) =>
                                handleRoleChange(
                                  donor,
                                  e.target.value as 'user' | 'moderator' | 'admin'
                                )
                              }
                              className="text-[11px] font-semibold bg-slate-50 border border-slate-200 rounded-lg px-2 py-1 text-slate-700 focus:outline-hidden"
                              title="Promote Donor to Staff Role (Super Admin only)"
                            >
                              <option value="user">Donor</option>
                              <option value="moderator">Promote: Moderator</option>
                              <option value="admin">Promote: Admin</option>
                            </select>
                          )}

                          {canManageBan && (
                            <button
                              onClick={() => handleBanToggle(donor, !donor.is_banned)}
                              className={`p-1.5 rounded-lg transition-colors ${donor.is_banned
                                ? 'text-emerald-600 hover:bg-emerald-50'
                                : 'text-slate-400 hover:text-rose-600 hover:bg-rose-50'
                                }`}
                              title={donor.is_banned ? 'Restore Account' : 'Suspend Account'}
                            >
                              {donor.is_banned ? (
                                <UserCheck className="w-4 h-4" />
                              ) : (
                                <Ban className="w-4 h-4" />
                              )}
                            </button>
                          )}

                          <button
                            onClick={() => openEditModal(donor)}
                            className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition-colors"
                            title="Edit Donor Profile"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>

                          {canManageBan && (
                            <button
                              onClick={() => {
                                setDeleteMode('archive');
                                setDeletingDonor(donor);
                              }}
                              className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                              title="Archive or Hard Delete Account (Staff Only)"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
      )}

      {/* Review Verification Modal */}
      {reviewingDonor && reviewingZcv && (
        <Modal
          isOpen={true}
          onClose={() => setReviewingDonor(null)}
          title={`Donor Verification: ${reviewingDonor.name || reviewingDonor.email}`}
          subtitle="Review laboratory blood report or donor card. Stored report file will be automatically purged after verification/rejection."
          maxWidth="lg"
        >
          <div className="space-y-4">
            {/* Donor Verification Confidence Banner */}
            <div
              className={`p-3.5 rounded-xl border text-xs flex items-center justify-between ${
                reviewingZcv.hasConflict
                  ? 'bg-rose-50 border-rose-300 text-rose-900'
                  : reviewingZcv.score >= 75
                    ? 'bg-emerald-50 border-emerald-300 text-emerald-900'
                    : 'bg-amber-50 border-amber-300 text-amber-900'
              }`}
            >
              <div>
                <div className="font-black text-sm">
                  Donor Verification Confidence: {reviewingZcv.score}% ({reviewingZcv.tier.replace('_', ' ')})
                </div>
                <p className="mt-0.5 text-[11px] opacity-90">
                  {reviewingZcv.accreditedLab
                    ? 'Recognized Accredited Bangladesh Diagnostic Center / Blood Bank.'
                    : 'Manual or custom laboratory name — verify image & certificate number.'}
                </p>
              </div>
              <span className="px-3 py-1 rounded-xl font-black text-xs bg-white/80 border border-current">
                {reviewingZcv.score}% Trust
              </span>
            </div>

            {reviewingZcv.hasConflict && (
              <div className="p-3.5 rounded-xl bg-amber-50 border border-amber-300 text-amber-900 text-xs flex items-start gap-2.5">
                <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold">OCR Blood Group Mismatch Detected</div>
                  <p className="mt-0.5">
                    Declared profile group is <strong>{reviewingDonor.blood_type}</strong>, while
                    automated OCR extracted <strong>{reviewingZcv.extractedBg}</strong>{' '}
                    from the uploaded lab report. You can sync their profile to{' '}
                    <strong>{reviewingZcv.extractedBg}</strong> on approval below.
                  </p>
                </div>
              </div>
            )}

            <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 space-y-2.5 text-xs">
              <div className="flex items-center justify-between">
                <span className="text-slate-500 font-semibold">Declared Blood Group:</span>
                <BloodGroupBadge bloodType={reviewingDonor.blood_type} size="sm" />
              </div>
              <div className="flex items-center justify-between">
                <span className="text-slate-500 font-semibold">OCR Extracted Group:</span>
                {reviewingZcv.extractedBg ? (
                  <BloodGroupBadge bloodType={reviewingZcv.extractedBg as BloodGroup} size="sm" />
                ) : (
                  <span className="text-slate-400 italic">Not scanned</span>
                )}
              </div>
              <div className="flex justify-between items-center">
                <span className="text-slate-500 font-semibold">Laboratory Name:</span>
                <span className="font-bold text-slate-800 flex items-center gap-1.5">
                  {reviewingDonor.verification_lab || 'Not provided'}
                  {reviewingZcv.accreditedLab && (
                    <span className="px-1.5 py-0.5 rounded bg-blue-100 text-blue-800 text-[10px] font-black">
                      ACCREDITED
                    </span>
                  )}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500 font-semibold">Certificate / Sample ID:</span>
                <span className="font-bold text-slate-800 font-mono">
                  {reviewingDonor.verification_cert || 'Not provided'}
                </span>
              </div>
              {(reviewingZcv.hb || reviewingZcv.screening) && (
                <div className="flex justify-between">
                  <span className="text-slate-500 font-semibold">Clinical Pathology Markers:</span>
                  <span className="font-bold text-emerald-700">
                    {reviewingZcv.hb ? `Hb: ${reviewingZcv.hb} ` : ''}
                    {reviewingZcv.screening ? `• TTI: ${reviewingZcv.screening}` : ''}
                  </span>
                </div>
              )}
              {reviewingZcv.cleanNotes && (
                <div className="pt-2 border-t border-slate-200">
                  <span className="text-slate-500 font-semibold block mb-1">Donor Notes:</span>
                  <p className="text-slate-700 italic">{reviewingZcv.cleanNotes}</p>
                </div>
              )}
            </div>

            {/* Private Lab Report Signed URL Preview + Download Before Auto-Purge */}
            <div className="p-4 bg-white rounded-xl border border-slate-200 space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
                  <FileText className="w-4 h-4 text-red-600" />
                  Uploaded Laboratory Evidence (Auto-Purged After Decision)
                </span>
                {signedDocUrl && (
                  <a
                    href={signedDocUrl}
                    target="_blank"
                    rel="noreferrer"
                    download
                    className="px-2.5 py-1 rounded-lg bg-red-50 text-xs font-bold text-red-600 hover:bg-red-100 inline-flex items-center gap-1"
                  >
                    <Download className="w-3.5 h-3.5" /> Download Report First <ExternalLink className="w-3 h-3" />
                  </a>
                )}
              </div>

              {loadingDocUrl ? (
                <div className="py-8 text-center text-xs text-slate-400">
                  Generating temporary signed URL from private bucket...
                </div>
              ) : signedDocUrl ? (
                <div className="rounded-lg overflow-hidden border border-slate-200 bg-slate-100 max-h-64 flex items-center justify-center">
                  <img
                    src={signedDocUrl}
                    alt="Uploaded laboratory blood group certificate"
                    className="max-h-64 w-auto object-contain"
                  />
                </div>
              ) : (
                <div className="py-6 text-center text-xs text-slate-400 bg-slate-50 rounded-lg border border-dashed border-slate-200">
                  Verified via Digital Portal Text / Certificate Reference ID.
                </div>
              )}
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-slate-700">
                Rejection Reason (sent to donor if declining):
              </label>
              <input
                type="text"
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-red-500/20"
              />
            </div>

            <div className="pt-4 border-t border-slate-100 flex flex-wrap justify-end gap-2.5">
              <button
                type="button"
                disabled={isProcessing}
                onClick={() => handleVerificationDecision(reviewingDonor, false)}
                className="px-4 py-2 text-xs font-semibold text-rose-700 bg-rose-50 hover:bg-rose-100 rounded-xl transition-colors"
              >
                Reject Submission
              </button>
              {reviewingZcv.extractedBg &&
                reviewingZcv.extractedBg !== reviewingDonor.blood_type && (
                  <button
                    type="button"
                    disabled={isProcessing}
                    onClick={() => handleVerificationDecision(reviewingDonor, true, true)}
                    className="px-4 py-2 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-xs transition-colors flex items-center gap-1.5"
                  >
                    <CheckCircle className="w-4 h-4" />
                    Approve & Sync Group ({reviewingZcv.extractedBg})
                  </button>
                )}
              <button
                type="button"
                disabled={isProcessing || (!reviewingDonor.blood_type && !reviewingZcv.extractedBg)}
                onClick={() => handleVerificationDecision(reviewingDonor, true, !reviewingDonor.blood_type)}
                className="px-4 py-2 text-xs font-semibold text-white bg-emerald-600 hover:bg-emerald-700 disabled:bg-slate-300 rounded-xl shadow-xs transition-colors flex items-center gap-1.5"
              >
                <CheckCircle className="w-4 h-4" />
                Approve & Grant Shield Badge
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Full Donor Profile & Activity Inspector Modal */}
      {viewingActivityDonor && (
        <Modal
          isOpen={true}
          onClose={() => setViewingActivityDonor(null)}
          title={`Full Donor Profile: ${viewingActivityDonor.name || viewingActivityDonor.email}`}
          subtitle={`Donor ID: RCN-${viewingActivityDonor.id.slice(0, 8).toUpperCase()} • UUID: ${viewingActivityDonor.id}`}
          maxWidth="2xl"
        >
          <div className="space-y-5 text-xs">
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl">
                <span className="text-slate-400 font-semibold block">Blood Group</span>
                <div className="mt-1">
                  <BloodGroupBadge bloodType={viewingActivityDonor.blood_type} size="sm" />
                </div>
              </div>
              <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl">
                <span className="text-slate-400 font-semibold block">Verification</span>
                <span className="text-xs font-black text-slate-900 mt-1 block">
                  {viewingActivityDonor.verification_status === 'verified'
                    ? 'Verified by RedCellNet'
                    : 'Verification Pending'}
                </span>
              </div>
              <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl">
                <span className="text-slate-400 font-semibold block">Verified Donations</span>
                <span className="text-sm font-black text-slate-900 mt-1 block">
                  {viewingActivityDonor.total_donations || 0} ({(viewingActivityDonor.total_donations || 0) * 3} lives)
                </span>
              </div>
              <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl">
                <span className="text-slate-400 font-semibold block">Next Eligible (90d)</span>
                <span className="text-slate-800 font-bold mt-1 block">
                  {viewingActivityDonor.next_eligible_date
                    ? new Date(viewingActivityDonor.next_eligible_date).toLocaleDateString()
                    : 'Eligible now'}
                </span>
              </div>
            </div>

            {/* Full Personal, ICE & Referral Details Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="p-3.5 bg-slate-50 border border-slate-200 rounded-xl space-y-1.5">
                <div className="font-black text-slate-800 uppercase tracking-wider text-[10px]">
                  Personal & Referral Details
                </div>
                <div><strong>Full Name:</strong> {viewingActivityDonor.name || 'Not set'}</div>
                <div><strong>Email:</strong> {viewingActivityDonor.email || 'Not set'}</div>
                <div><strong>Phone:</strong> {viewingActivityDonor.phone_number || 'Not set'}</div>
                <div><strong>City / Area:</strong> {viewingActivityDonor.location_city || 'Not set'}</div>
                <div><strong>Life Points:</strong> {viewingActivityDonor.points || 0} pts</div>
                <div><strong>Referral Code:</strong> {(viewingActivityDonor as unknown as Record<string, unknown>).referral_code as string || 'Auto-generated'}</div>
              </div>
              <div className="p-3.5 bg-rose-50/60 border border-rose-200 rounded-xl space-y-1.5">
                <div className="font-black text-rose-800 uppercase tracking-wider text-[10px]">
                  Emergency Medical ID (ICE) & Lab Record
                </div>
                <div><strong>ICE Contact Name:</strong> {viewingActivityDonor.emergency_contact_name || 'Not configured'}</div>
                <div><strong>ICE Contact Phone:</strong> {viewingActivityDonor.emergency_contact_phone || 'Not configured'}</div>
                <div><strong>Allergies / Medical Notes:</strong> {viewingActivityDonor.medical_notes || 'None reported'}</div>
                <div><strong>Accredited Lab:</strong> {viewingActivityDonor.verification_lab || 'N/A'}</div>
                <div><strong>Certificate / Sample #:</strong> {viewingActivityDonor.verification_cert || 'N/A'}</div>
              </div>
            </div>

            {/* Donation History */}
            <div>
              <h4 className="font-bold text-slate-900 mb-2">
                Recorded Donation Log ({viewingActivityDonor.donation_history?.length || 0})
              </h4>
              {!viewingActivityDonor.donation_history ||
                viewingActivityDonor.donation_history.length === 0 ? (
                <p className="text-slate-400 italic p-3 bg-slate-50 rounded-xl border border-slate-100">
                  No donation log entries on file.
                </p>
              ) : (
                <div className="space-y-2 max-h-40 overflow-y-auto">
                  {viewingActivityDonor.donation_history.map((entry, idx) => (
                    <div
                      key={entry.id || idx}
                      className="p-3 rounded-xl border border-slate-200 bg-white flex items-center justify-between"
                    >
                      <div>
                        <span className="font-bold text-slate-900">
                          {entry.hospital || entry.hospital_name || 'Hospital / Blood Bank'}
                        </span>
                        <span className="text-slate-500 ml-2">
                          • {entry.units || 1} unit(s) {entry.component_type || ''}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span
                          className={`px-2 py-0.5 rounded text-[10px] font-bold ${entry.verified
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : 'bg-slate-100 text-slate-600'
                            }`}
                        >
                          {entry.verified ? 'Hospital Verified' : 'Self-Logged'}
                        </span>
                        {entry.date && (
                          <span className="text-slate-400">
                            {new Date(entry.date).toLocaleDateString()}
                          </span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Requests Created */}
            <div>
              <h4 className="font-bold text-slate-900 mb-2">
                Blood Requests Posted ({donorCreatedRequests.length})
              </h4>
              {donorCreatedRequests.length === 0 ? (
                <p className="text-slate-400 italic p-3 bg-slate-50 rounded-xl border border-slate-100">
                  This user has not posted any blood requests.
                </p>
              ) : (
                <div className="space-y-2 max-h-40 overflow-y-auto">
                  {donorCreatedRequests.map((req) => (
                    <div
                      key={req.id}
                      className="p-3 rounded-xl border border-slate-200 bg-white flex items-center justify-between"
                    >
                      <div>
                        <span className="font-bold text-slate-900">{req.patient_name}</span>
                        <span className="text-slate-500 ml-2">@ {req.hospital_name}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <BloodGroupBadge bloodType={req.required_blood_type} size="sm" />
                        <StatusBadge status={req.status} />
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Donor Offers Submitted */}
            <div>
              <h4 className="font-bold text-slate-900 mb-2">
                Volunteer Offers Submitted ({donorSubmittedOffers.length})
              </h4>
              {donorSubmittedOffers.length === 0 ? (
                <p className="text-slate-400 italic p-3 bg-slate-50 rounded-xl border border-slate-100">
                  No volunteer offers submitted yet.
                </p>
              ) : (
                <div className="space-y-2 max-h-40 overflow-y-auto">
                  {donorSubmittedOffers.map(({ offer, request }) => (
                    <div
                      key={offer.id}
                      className="p-3 rounded-xl border border-slate-200 bg-white flex items-center justify-between"
                    >
                      <div>
                        <span className="font-bold text-slate-900">{request.hospital_name}</span>
                        <span className="text-slate-500 ml-2">
                          ({offer.offeredUnits} unit(s) for {request.patient_name})
                        </span>
                      </div>
                      <span className="uppercase font-bold text-[10px] px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                        {offer.status}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </Modal>
      )}

      {/* Edit Donor Modal */}
      {editingDonor && (
        <Modal
          isOpen={true}
          onClose={() => setEditingDonor(null)}
          title={`Edit Donor: ${editingDonor.name || editingDonor.email}`}
          maxWidth="md"
        >
          <div className="space-y-4">
            <div>
              <label className="text-xs font-semibold text-slate-700 block mb-1">Full Name</label>
              <input
                type="text"
                value={editForm.name}
                onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Blood Group</label>
                <select
                  value={editForm.blood_type}
                  onChange={(e) =>
                    setEditForm({ ...editForm, blood_type: e.target.value as BloodGroup | '' })
                  }
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                >
                  <option value="">Unset (Not Declared)</option>
                  {BLOOD_GROUPS.map((bg) => (
                    <option key={bg} value={bg}>
                      {bg}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">City</label>
                <input
                  type="text"
                  value={editForm.location_city}
                  onChange={(e) => setEditForm({ ...editForm, location_city: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Phone Number
                </label>
                <input
                  type="text"
                  value={editForm.phone_number}
                  onChange={(e) => setEditForm({ ...editForm, phone_number: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Life Points
                </label>
                <input
                  type="number"
                  value={editForm.points}
                  onChange={(e) =>
                    setEditForm({ ...editForm, points: parseInt(e.target.value, 10) || 0 })
                  }
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>
            </div>

            <div className="pt-2 flex items-center justify-between">
              <span className="text-xs font-semibold text-slate-700">Available to Donate</span>
              <button
                type="button"
                onClick={() =>
                  setEditForm({
                    ...editForm,
                    is_available_to_donate: !editForm.is_available_to_donate,
                  })
                }
                className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ${editForm.is_available_to_donate ? 'bg-emerald-500' : 'bg-slate-300'
                  }`}
              >
                <span
                  className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow-sm transition duration-200 ${editForm.is_available_to_donate ? 'translate-x-4' : 'translate-x-0'
                    }`}
                />
              </button>
            </div>

            <div className="pt-4 border-t border-slate-100 flex justify-end gap-2.5">
              <button
                type="button"
                onClick={() => setEditingDonor(null)}
                className="px-4 py-2 text-xs font-semibold text-slate-700 bg-slate-100 rounded-xl hover:bg-slate-200"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isProcessing}
                onClick={handleSaveEdit}
                className="px-4 py-2 text-xs font-semibold text-white bg-red-600 hover:bg-red-700 rounded-xl shadow-xs"
              >
                {isProcessing ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Archive (Soft Delete) or Hard Delete User Modal */}
      {deletingDonor && (
        <Modal
          isOpen={true}
          onClose={() => setDeletingDonor(null)}
          title={`Archive or Hard Delete: ${deletingDonor.name || deletingDonor.email}`}
          subtitle="Choose between archiving (soft deactivate) or permanently deleting from public.profiles and auth.users."
          maxWidth="md"
        >
          <div className="space-y-4 text-xs">
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setDeleteMode('archive')}
                className={`p-3 rounded-xl border text-left transition-all ${
                  deleteMode === 'archive'
                    ? 'border-amber-500 bg-amber-50 text-amber-950 font-bold'
                    : 'border-slate-200 bg-slate-50 text-slate-600'
                }`}
              >
                <div className="font-black text-sm">Archive (Soft Delete)</div>
                <p className="mt-1 text-[11px] opacity-80">
                  Suspends account, disables donor availability, and preserves historical audit logs.
                </p>
              </button>
              <button
                type="button"
                onClick={() => setDeleteMode('hard_delete')}
                className={`p-3 rounded-xl border text-left transition-all ${
                  deleteMode === 'hard_delete'
                    ? 'border-rose-600 bg-rose-50 text-rose-950 font-bold'
                    : 'border-slate-200 bg-slate-50 text-slate-600'
                }`}
              >
                <div className="font-black text-sm">Hard Delete (Permanent DB)</div>
                <p className="mt-1 text-[11px] opacity-80">
                  Permanently deletes user from public.profiles, auth.users, storage, and requests.
                </p>
              </button>
            </div>
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Audit Log Reason</label>
              <input
                type="text"
                value={deleteReason}
                onChange={(e) => setDeleteReason(e.target.value)}
                className="w-full px-3 py-2 border border-slate-200 rounded-xl"
              />
            </div>
            <div className="pt-3 border-t border-slate-100 flex justify-end gap-2.5">
              <button
                type="button"
                onClick={() => setDeletingDonor(null)}
                className="px-4 py-2 font-semibold text-slate-700 bg-slate-100 rounded-xl hover:bg-slate-200"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isProcessing}
                onClick={handleDeleteDonor}
                className={`px-4 py-2 font-bold text-white rounded-xl shadow-xs ${
                  deleteMode === 'hard_delete'
                    ? 'bg-rose-600 hover:bg-rose-700'
                    : 'bg-amber-600 hover:bg-amber-700'
                }`}
              >
                {isProcessing
                  ? 'Processing...'
                  : deleteMode === 'hard_delete'
                    ? 'Hard Delete Forever'
                    : 'Archive Account'}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Review User-Submitted Account Deletion Request Modal */}
      {reviewingDeletionDonor && (
        <Modal
          isOpen={true}
          onClose={() => setReviewingDeletionDonor(null)}
          title={`Account Deletion Approval: ${reviewingDeletionDonor.name || reviewingDeletionDonor.email}`}
          subtitle="Regular users cannot delete or archive their own accounts without Staff / Admin approval."
          maxWidth="md"
        >
          <div className="space-y-4 text-xs">
            <div className="p-4 rounded-xl bg-rose-50 border border-rose-200 space-y-2 text-rose-950">
              <div className="font-black text-sm flex items-center gap-1.5">
                <UserX className="w-4 h-4 text-rose-600" />
                User Requested Account Deletion
              </div>
              <div>
                <strong>Account:</strong> {reviewingDeletionDonor.name || 'Donor'} (
                {reviewingDeletionDonor.email})
              </div>
              <div>
                <strong>User’s Stated Reason:</strong>{' '}
                <span className="italic">
                  "{reviewingDeletionDonor.deletion_request_reason || 'User requested account deletion from Settings.'}"
                </span>
              </div>
              {reviewingDeletionDonor.deletion_requested_at && (
                <div className="text-[11px] text-rose-700">
                  Requested at: {new Date(reviewingDeletionDonor.deletion_requested_at).toLocaleString()}
                </div>
              )}
            </div>

            <div>
              <label className="font-semibold text-slate-700 block mb-1">
                Staff Governance Note (Recorded in Audit Log & Sent if Rejected/Archived)
              </label>
              <input
                type="text"
                value={deletionAdminNote}
                onChange={(e) => setDeletionAdminNote(e.target.value)}
                placeholder="Reason or clinical note..."
                className="w-full px-3 py-2 border border-slate-200 rounded-xl"
              />
            </div>

            <div className="pt-3 border-t border-slate-100 flex flex-wrap justify-end gap-2">
              <button
                type="button"
                disabled={isProcessing}
                onClick={() => handleResolveDeletionRequest(reviewingDeletionDonor, 'reject')}
                className="px-3.5 py-2 font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl"
              >
                Reject & Keep Active
              </button>
              <button
                type="button"
                disabled={isProcessing}
                onClick={() => handleResolveDeletionRequest(reviewingDeletionDonor, 'archive')}
                className="px-3.5 py-2 font-bold text-amber-950 bg-amber-100 hover:bg-amber-200 rounded-xl"
              >
                Archive Account Instead
              </button>
              <button
                type="button"
                disabled={isProcessing}
                onClick={() =>
                  handleResolveDeletionRequest(reviewingDeletionDonor, 'approve_hard_delete')
                }
                className="px-4 py-2 font-bold text-white bg-rose-600 hover:bg-rose-700 rounded-xl shadow-xs"
              >
                {isProcessing ? 'Processing...' : 'Approve & Hard Delete Forever'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
