// admin_panel/src/pages/DonorsPage.tsx
import React, { useState } from 'react';
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
} from 'lucide-react';
import type { BloodGroup, UserProfile } from '../types';
import { BloodGroupBadge, VerificationBadge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { ConfirmDialog } from '../components/common/ConfirmDialog';
import { EmptyState } from '../components/common/EmptyState';
import { supabase } from '../lib/supabase';

interface DonorsPageProps {
  donors: UserProfile[];
  onRefresh: () => void;
}

const BLOOD_GROUPS: BloodGroup[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

export const DonorsPage: React.FC<DonorsPageProps> = ({ donors, onRefresh }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [bloodFilter, setBloodFilter] = useState<string>('all');
  const [verificationFilter, setVerificationFilter] = useState<string>('all');
  const [availabilityFilter, setAvailabilityFilter] = useState<string>('all');

  // Modals state
  const [reviewingDonor, setReviewingDonor] = useState<UserProfile | null>(null);
  const [editingDonor, setEditingDonor] = useState<UserProfile | null>(null);
  const [deletingDonor, setDeletingDonor] = useState<UserProfile | null>(null);
  const [rejectionReason, setRejectionReason] = useState('Inconclusive or missing lab report');
  const [isProcessing, setIsProcessing] = useState(false);

  // Edit form state
  const [editForm, setEditForm] = useState<{
    name: string;
    phone_number: string;
    blood_type: BloodGroup;
    location_city: string;
    points: number;
    is_available_to_donate: boolean;
  }>({
    name: '',
    phone_number: '',
    blood_type: 'O+',
    location_city: '',
    points: 0,
    is_available_to_donate: true,
  });

  // Filtered donors
  const filteredDonors = donors.filter((d) => {
    const matchesSearch =
      (d.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (d.email || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (d.phone_number || '').includes(searchQuery) ||
      (d.location_city || '').toLowerCase().includes(searchQuery.toLowerCase());

    const matchesBlood = bloodFilter === 'all' || d.blood_type === bloodFilter;
    const matchesVerification =
      verificationFilter === 'all' || (d.verification_status || 'pending') === verificationFilter;
    const matchesAvailability =
      availabilityFilter === 'all' ||
      (availabilityFilter === 'available' && d.is_available_to_donate) ||
      (availabilityFilter === 'unavailable' && !d.is_available_to_donate);

    return matchesSearch && matchesBlood && matchesVerification && matchesAvailability;
  });

  // Verification Decision (Approve / Reject)
  const handleVerificationDecision = async (donor: UserProfile, approve: boolean) => {
    setIsProcessing(true);
    try {
      if (approve) {
        await supabase
          .from('profiles')
          .update({
            verification_status: 'verified',
            is_verified_donor: true,
            verified_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', donor.id);

        // Send Notification
        await supabase.from('notifications').insert({
          user_id: donor.id,
          title: 'Donor Verification Approved! 🛡️',
          body: `Congratulations ${donor.name}! Your donor profile is now officially verified with the Shield Badge.`,
          type: 'verification',
          is_read: false,
          created_at: new Date().toISOString(),
        });
      } else {
        await supabase
          .from('profiles')
          .update({
            verification_status: 'rejected',
            is_verified_donor: false,
            rejection_reason: rejectionReason,
            updated_at: new Date().toISOString(),
          })
          .eq('id', donor.id);

        // Send Notification
        await supabase.from('notifications').insert({
          user_id: donor.id,
          title: 'Verification Update',
          body: `Your verification submission was reviewed: ${rejectionReason}. You may re-submit updated documents.`,
          type: 'verification',
          is_read: false,
          created_at: new Date().toISOString(),
        });
      }

      setReviewingDonor(null);
      onRefresh();
    } catch (err) {
      console.error('Error updating verification status:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  // Toggle Availability
  const handleToggleAvailability = async (donor: UserProfile) => {
    try {
      await supabase
        .from('profiles')
        .update({
          is_available_to_donate: !donor.is_available_to_donate,
          updated_at: new Date().toISOString(),
        })
        .eq('id', donor.id);
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
      blood_type: donor.blood_type || 'O+',
      location_city: donor.location_city || '',
      points: donor.points || 0,
      is_available_to_donate: donor.is_available_to_donate ?? true,
    });
  };

  // Save Edit Profile
  const handleSaveEdit = async () => {
    if (!editingDonor) return;
    setIsProcessing(true);
    try {
      await supabase
        .from('profiles')
        .update({
          name: editForm.name,
          phone_number: editForm.phone_number,
          blood_type: editForm.blood_type,
          location_city: editForm.location_city,
          points: editForm.points,
          is_available_to_donate: editForm.is_available_to_donate,
          updated_at: new Date().toISOString(),
        })
        .eq('id', editingDonor.id);

      setEditingDonor(null);
      onRefresh();
    } catch (err) {
      console.error('Error editing donor:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  // Delete Donor Profile
  const handleDeleteDonor = async () => {
    if (!deletingDonor) return;
    setIsProcessing(true);
    try {
      await supabase.from('profiles').delete().eq('id', deletingDonor.id);
      setDeletingDonor(null);
      onRefresh();
    } catch (err) {
      console.error('Error deleting donor profile:', err);
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
      'Blood Group',
      'City',
      'Verification Status',
      'Available to Donate',
      'Life Points',
    ];

    const rows = filteredDonors.map((d) => [
      `"${d.name || ''}"`,
      `"${d.email || ''}"`,
      `"${d.phone_number || ''}"`,
      `"${d.blood_type || ''}"`,
      `"${d.location_city || ''}"`,
      `"${d.verification_status || 'pending'}"`,
      d.is_available_to_donate ? 'Yes' : 'No',
      d.points || 0,
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `redcellnet_donors_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      {/* Search & Filter Toolbar */}
      <div className="bg-white p-4.5 rounded-2xl border border-slate-200 shadow-xs flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-4">
        {/* Search */}
        <div className="relative flex-1 min-w-[280px]">
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
              <option value="unavailable">Unavailable</option>
            </select>
          </div>

          <button
            onClick={exportToCSV}
            title="Export CSV"
            className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            <Download className="w-3.5 h-3.5" />
            Export CSV
          </button>
        </div>
      </div>

      {/* Donors Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        {filteredDonors.length === 0 ? (
          <EmptyState
            icon={Users}
            title="No Donors Found"
            description={
              searchQuery || bloodFilter !== 'all' || verificationFilter !== 'all'
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
                  <th className="py-3.5 px-4">Life Points</th>
                  <th className="py-3.5 px-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredDonors.map((donor) => (
                  <tr key={donor.id} className="hover:bg-slate-50/60 transition-colors">
                    {/* Name & Avatar */}
                    <td className="py-3.5 px-5">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-full bg-gradient-to-tr from-red-600 to-rose-400 text-white font-black text-xs flex items-center justify-center shrink-0 shadow-xs">
                          {(donor.name || 'U').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div className="font-bold text-slate-900 flex items-center gap-1.5">
                            {donor.name || 'Unnamed Donor'}
                            {donor.role === 'admin' && (
                              <span className="text-[10px] font-extrabold uppercase px-1.5 py-0.2 rounded-sm bg-purple-100 text-purple-700">
                                Admin
                              </span>
                            )}
                          </div>
                          <div className="text-xs text-slate-400">{donor.id.slice(0, 8)}...</div>
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
                        <span className="truncate max-w-[150px]">{donor.email}</span>
                      </div>
                      {donor.phone_number && (
                        <div className="flex items-center gap-1.5 text-slate-500 mt-0.5">
                          <Phone className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                          <span>{donor.phone_number}</span>
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
                        className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-hidden ${
                          donor.is_available_to_donate ? 'bg-emerald-500' : 'bg-slate-300'
                        }`}
                      >
                        <span
                          className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow-sm ring-0 transition duration-200 ease-in-out ${
                            donor.is_available_to_donate ? 'translate-x-4' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </td>

                    {/* Verification Status */}
                    <td className="py-3.5 px-4">
                      <VerificationBadge status={donor.verification_status} />
                    </td>

                    {/* Points */}
                    <td className="py-3.5 px-4 text-xs font-bold text-slate-800">
                      <span className="flex items-center gap-1">
                        <Award className="w-3.5 h-3.5 text-amber-500" />
                        {donor.points || 0} pts
                      </span>
                    </td>

                    {/* Actions */}
                    <td className="py-3.5 px-5 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        {donor.verification_status === 'pending' && (
                          <button
                            onClick={() => setReviewingDonor(donor)}
                            className="px-2.5 py-1 text-xs font-bold text-amber-800 bg-amber-100 hover:bg-amber-200 rounded-lg transition-colors"
                          >
                            Review
                          </button>
                        )}
                        <button
                          onClick={() => openEditModal(donor)}
                          className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition-colors"
                          title="Edit Donor Profile"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => setDeletingDonor(donor)}
                          className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                          title="Delete User"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Review Verification Modal */}
      {reviewingDonor && (
        <Modal
          isOpen={true}
          onClose={() => setReviewingDonor(null)}
          title={`Review Verification: ${reviewingDonor.name}`}
          subtitle="Inspect laboratory confirmation documents and grant verified donor badge."
          maxWidth="md"
        >
          <div className="space-y-4">
            <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-slate-500 font-semibold">Blood Group:</span>
                <BloodGroupBadge bloodType={reviewingDonor.blood_type} size="sm" />
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500 font-semibold">Laboratory Name:</span>
                <span className="font-bold text-slate-800">
                  {reviewingDonor.verification_lab || 'Diagnostic Lab Dhaka'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500 font-semibold">Certificate / Ref ID:</span>
                <span className="font-bold text-slate-800 font-mono">
                  {reviewingDonor.verification_cert || 'LAB-2026-X899'}
                </span>
              </div>
              {reviewingDonor.verification_notes && (
                <div className="pt-2 border-t border-slate-200">
                  <span className="text-slate-500 font-semibold block mb-1">Donor Notes:</span>
                  <p className="text-slate-700 italic">{reviewingDonor.verification_notes}</p>
                </div>
              )}
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-slate-700">Rejection Reason (if declining):</label>
              <input
                type="text"
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-red-500/20"
              />
            </div>

            <div className="pt-4 border-t border-slate-100 flex justify-end gap-2.5">
              <button
                type="button"
                disabled={isProcessing}
                onClick={() => handleVerificationDecision(reviewingDonor, false)}
                className="px-4 py-2 text-xs font-semibold text-rose-700 bg-rose-50 hover:bg-rose-100 rounded-xl transition-colors"
              >
                Reject Submission
              </button>
              <button
                type="button"
                disabled={isProcessing}
                onClick={() => handleVerificationDecision(reviewingDonor, true)}
                className="px-4 py-2 text-xs font-semibold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl shadow-xs transition-colors flex items-center gap-1.5"
              >
                <CheckCircle className="w-4 h-4" />
                Approve & Grant Shield Badge
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Edit Donor Modal */}
      {editingDonor && (
        <Modal
          isOpen={true}
          onClose={() => setEditingDonor(null)}
          title={`Edit Donor: ${editingDonor.name}`}
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
                  onChange={(e) => setEditForm({ ...editForm, blood_type: e.target.value as BloodGroup })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                >
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
                <label className="text-xs font-semibold text-slate-700 block mb-1">Phone Number</label>
                <input
                  type="text"
                  value={editForm.phone_number}
                  onChange={(e) => setEditForm({ ...editForm, phone_number: e.target.value })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">Life Points</label>
                <input
                  type="number"
                  value={editForm.points}
                  onChange={(e) => setEditForm({ ...editForm, points: parseInt(e.target.value) || 0 })}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl"
                />
              </div>
            </div>

            <div className="pt-2 flex items-center justify-between">
              <span className="text-xs font-semibold text-slate-700">Available to Donate</span>
              <button
                type="button"
                onClick={() => setEditForm({ ...editForm, is_available_to_donate: !editForm.is_available_to_donate })}
                className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ${
                  editForm.is_available_to_donate ? 'bg-emerald-500' : 'bg-slate-300'
                }`}
              >
                <span
                  className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow-sm transition duration-200 ${
                    editForm.is_available_to_donate ? 'translate-x-4' : 'translate-x-0'
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

      {/* Delete Confirmation */}
      <ConfirmDialog
        isOpen={!!deletingDonor}
        onClose={() => setDeletingDonor(null)}
        onConfirm={handleDeleteDonor}
        title="Delete Donor Account?"
        message={`Are you sure you want to permanently delete profile for "${deletingDonor?.name}"? All donation history associated with this ID will be removed.`}
        confirmText="Delete Profile"
        isLoading={isProcessing}
      />
    </div>
  );
};
