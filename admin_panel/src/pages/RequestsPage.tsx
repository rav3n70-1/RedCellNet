// admin_panel/src/pages/RequestsPage.tsx
import React, { useState } from 'react';
import {
  Search,
  Filter,
  Download,
  MapPin,
  Phone,
  Trash2,
  Eye,
  Droplets,
  Building,
  UserCheck,
} from 'lucide-react';
import type { BloodGroup, BloodRequest, RequestStatus, UrgencyLevel } from '../types';
import { BloodGroupBadge, StatusBadge, UrgencyBadge } from '../components/common/Badge';
import { Modal } from '../components/common/Modal';
import { ConfirmDialog } from '../components/common/ConfirmDialog';
import { EmptyState } from '../components/common/EmptyState';
import { supabase } from '../lib/supabase';

interface RequestsPageProps {
  requests: BloodRequest[];
  onRefresh: () => void;
}

const BLOOD_GROUPS: BloodGroup[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

export const RequestsPage: React.FC<RequestsPageProps> = ({ requests, onRefresh }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [bloodFilter, setBloodFilter] = useState<string>('all');
  const [urgencyFilter, setUrgencyFilter] = useState<string>('all');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  // Selected request for details modal
  const [activeRequest, setActiveRequest] = useState<BloodRequest | null>(null);
  const [deletingRequest, setDeletingRequest] = useState<BloodRequest | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  // Filtered list
  const filteredRequests = requests.filter((r) => {
    const query = searchQuery.toLowerCase();
    const matchesSearch =
      (r.patient_name || '').toLowerCase().includes(query) ||
      (r.hospital_name || '').toLowerCase().includes(query) ||
      (r.city || '').toLowerCase().includes(query) ||
      (r.contact_phone || '').includes(query);

    const matchesBlood = bloodFilter === 'all' || r.required_blood_type === bloodFilter;
    const matchesUrgency = urgencyFilter === 'all' || r.urgency_level === urgencyFilter;
    const matchesStatus = statusFilter === 'all' || r.status === statusFilter;

    return matchesSearch && matchesBlood && matchesUrgency && matchesStatus;
  });

  // Update Status directly
  const handleUpdateStatus = async (requestId: string, newStatus: RequestStatus, reason?: string) => {
    setIsProcessing(true);
    try {
      await supabase
        .from('blood_requests')
        .update({
          status: newStatus,
          if: reason ? { cancellation_reason: reason } : {},
          updated_at: new Date().toISOString(),
        })
        .eq('id', requestId);

      if (activeRequest && activeRequest.id === requestId) {
        setActiveRequest({ ...activeRequest, status: newStatus });
      }
      onRefresh();
    } catch (err) {
      console.error('Error updating request status:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  // Update Urgency Level
  const handleUpdateUrgency = async (requestId: string, newUrgency: UrgencyLevel) => {
    setIsProcessing(true);
    try {
      await supabase
        .from('blood_requests')
        .update({
          urgency_level: newUrgency,
          updated_at: new Date().toISOString(),
        })
        .eq('id', requestId);

      if (activeRequest && activeRequest.id === requestId) {
        setActiveRequest({ ...activeRequest, urgency_level: newUrgency });
      }
      onRefresh();
    } catch (err) {
      console.error('Error updating urgency level:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  // Accept Offer
  const handleAcceptOffer = async (requestId: string, offerId: string) => {
    if (!activeRequest) return;
    setIsProcessing(true);
    try {
      const currentOffers = activeRequest.offers || [];
      const updatedOffers = currentOffers.map((o) =>
        o.id === offerId ? { ...o, status: 'accepted' as const, acceptedAt: new Date().toISOString() } : o
      );

      const targetOffer = currentOffers.find((o) => o.id === offerId);
      const offeredUnits = targetOffer?.offeredUnits || 1;
      const newAccepted = (activeRequest.accepted_units || 0) + offeredUnits;
      const newRemaining = Math.max(0, (activeRequest.required_units || 1) - newAccepted);
      const newStatus: RequestStatus = newRemaining <= 0 ? 'Fulfilled' : 'Partially Fulfilled';

      await supabase
        .from('blood_requests')
        .update({
          offers: updatedOffers,
          accepted_units: newAccepted,
          remaining_units: newRemaining,
          status: newStatus,
          updated_at: new Date().toISOString(),
        })
        .eq('id', requestId);

      setActiveRequest({
        ...activeRequest,
        offers: updatedOffers,
        accepted_units: newAccepted,
        remaining_units: newRemaining,
        status: newStatus,
      });

      onRefresh();
    } catch (err) {
      console.error('Error accepting offer:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  // Decline Offer
  const handleDeclineOffer = async (requestId: string, offerId: string) => {
    if (!activeRequest) return;
    setIsProcessing(true);
    try {
      const currentOffers = activeRequest.offers || [];
      const updatedOffers = currentOffers.map((o) =>
        o.id === offerId ? { ...o, status: 'declined' as const } : o
      );

      await supabase
        .from('blood_requests')
        .update({
          offers: updatedOffers,
          updated_at: new Date().toISOString(),
        })
        .eq('id', requestId);

      setActiveRequest({
        ...activeRequest,
        offers: updatedOffers,
      });

      onRefresh();
    } catch (err) {
      console.error('Error declining offer:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  // Delete Request
  const handleDeleteRequest = async () => {
    if (!deletingRequest) return;
    setIsProcessing(true);
    try {
      await supabase.from('blood_requests').delete().eq('id', deletingRequest.id);
      if (activeRequest?.id === deletingRequest.id) setActiveRequest(null);
      setDeletingRequest(null);
      onRefresh();
    } catch (err) {
      console.error('Error deleting blood request:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  // Export to CSV
  const exportToCSV = () => {
    const headers = [
      'ID',
      'Patient Name',
      'Hospital',
      'City',
      'Blood Group',
      'Required Units',
      'Accepted Units',
      'Remaining Units',
      'Urgency',
      'Status',
      'Contact Phone',
      'Created At',
    ];

    const rows = filteredRequests.map((r) => [
      `"${r.id}"`,
      `"${r.patient_name}"`,
      `"${r.hospital_name}"`,
      `"${r.city || ''}"`,
      `"${r.required_blood_type}"`,
      r.required_units,
      r.accepted_units,
      r.remaining_units,
      `"${r.urgency_level}"`,
      `"${r.status}"`,
      `"${r.contact_phone}"`,
      `"${r.created_at || ''}"`,
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `redcellnet_requests_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      {/* Search & Filters */}
      <div className="bg-white p-4.5 rounded-2xl border border-slate-200 shadow-xs flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-4">
        {/* Search */}
        <div className="relative flex-1 min-w-[280px]">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by patient, hospital name, or city..."
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
              value={urgencyFilter}
              onChange={(e) => setUrgencyFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Urgencies</option>
              <option value="Critical">Critical</option>
              <option value="High">High Priority</option>
              <option value="Medium">Medium</option>
              <option value="Low">Low</option>
            </select>
          </div>

          <div className="bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 text-xs">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Statuses</option>
              <option value="Open">Open</option>
              <option value="Partially Fulfilled">Partially Fulfilled</option>
              <option value="Fulfilled">Fulfilled</option>
              <option value="Cancelled">Cancelled</option>
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

      {/* Requests Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        {filteredRequests.length === 0 ? (
          <EmptyState
            icon={Droplets}
            title="No Blood Requests"
            description={
              searchQuery || bloodFilter !== 'all' || urgencyFilter !== 'all' || statusFilter !== 'all'
                ? 'No requests match your current filters. Clear filters to see all requests.'
                : 'No blood transfusion requests recorded in the system yet.'
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-sm">
              <thead>
                <tr className="bg-slate-50/80 border-b border-slate-200 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                  <th className="py-3.5 px-5">Blood Group</th>
                  <th className="py-3.5 px-4">Patient / Hospital</th>
                  <th className="py-3.5 px-4">City</th>
                  <th className="py-3.5 px-4">Units Needed</th>
                  <th className="py-3.5 px-4">Urgency</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4">Offers</th>
                  <th className="py-3.5 px-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredRequests.map((req) => (
                  <tr key={req.id} className="hover:bg-slate-50/60 transition-colors">
                    {/* Blood Group */}
                    <td className="py-3.5 px-5">
                      <BloodGroupBadge bloodType={req.required_blood_type} size="md" />
                    </td>

                    {/* Patient / Hospital */}
                    <td className="py-3.5 px-4">
                      <div>
                        <div className="font-bold text-slate-900">{req.patient_name}</div>
                        <div className="text-xs text-slate-500 flex items-center gap-1 mt-0.5">
                          <Building className="w-3 h-3 text-slate-400" />
                          <span className="truncate max-w-[200px]">{req.hospital_name}</span>
                        </div>
                      </div>
                    </td>

                    {/* City */}
                    <td className="py-3.5 px-4 text-xs font-medium text-slate-700">
                      {req.city ? (
                        <span className="flex items-center gap-1">
                          <MapPin className="w-3 h-3 text-slate-400" />
                          {req.city}
                        </span>
                      ) : (
                        <span className="text-slate-400 italic">Dhaka</span>
                      )}
                    </td>

                    {/* Units */}
                    <td className="py-3.5 px-4 text-xs font-semibold">
                      <span className="text-slate-900 font-extrabold">{req.remaining_units}</span>
                      <span className="text-slate-400 font-normal"> / {req.required_units} needed</span>
                      {req.accepted_units > 0 && (
                        <div className="text-[10px] text-emerald-600 font-bold mt-0.5">
                          ({req.accepted_units} accepted)
                        </div>
                      )}
                    </td>

                    {/* Urgency */}
                    <td className="py-3.5 px-4">
                      <UrgencyBadge level={req.urgency_level} />
                    </td>

                    {/* Status */}
                    <td className="py-3.5 px-4">
                      <StatusBadge status={req.status} />
                    </td>

                    {/* Offers */}
                    <td className="py-3.5 px-4 text-xs">
                      {req.offers && req.offers.length > 0 ? (
                        <span className="inline-flex items-center gap-1 font-bold text-indigo-700 bg-indigo-50 px-2 py-0.5 rounded-md">
                          <UserCheck className="w-3.5 h-3.5" />
                          {req.offers.length} offer{req.offers.length > 1 ? 's' : ''}
                        </span>
                      ) : (
                        <span className="text-slate-400 italic">No offers</span>
                      )}
                    </td>

                    {/* Actions */}
                    <td className="py-3.5 px-5 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => setActiveRequest(req)}
                          className="px-2.5 py-1 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-lg transition-colors flex items-center gap-1"
                        >
                          <Eye className="w-3.5 h-3.5" />
                          Manage
                        </button>
                        <button
                          onClick={() => setDeletingRequest(req)}
                          className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                          title="Delete Request"
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

      {/* Comprehensive Request Details & Offers Modal */}
      {activeRequest && (
        <Modal
          isOpen={true}
          onClose={() => setActiveRequest(null)}
          title={`Blood Request: ${activeRequest.patient_name}`}
          subtitle={`ID: ${activeRequest.id}`}
          maxWidth="2xl"
        >
          <div className="space-y-6">
            {/* Header info */}
            <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-3">
                <BloodGroupBadge bloodType={activeRequest.required_blood_type} size="lg" />
                <div>
                  <div className="text-xs font-bold text-slate-400 uppercase tracking-wider">Required Component</div>
                  <div className="text-sm font-extrabold text-slate-900">
                    {activeRequest.component_type || 'Whole Blood'} • {activeRequest.required_units} Units
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-3">
                {/* Urgency Selector */}
                <div>
                  <label className="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">
                    Urgency
                  </label>
                  <select
                    value={activeRequest.urgency_level}
                    onChange={(e) => handleUpdateUrgency(activeRequest.id, e.target.value as UrgencyLevel)}
                    className="text-xs font-semibold bg-white border border-slate-200 rounded-lg px-2.5 py-1 focus:ring-2 focus:ring-red-500/20"
                  >
                    <option value="Critical">Critical</option>
                    <option value="High">High</option>
                    <option value="Medium">Medium</option>
                    <option value="Low">Low</option>
                  </select>
                </div>

                {/* Status Selector */}
                <div>
                  <label className="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">
                    Status
                  </label>
                  <select
                    value={activeRequest.status}
                    onChange={(e) => handleUpdateStatus(activeRequest.id, e.target.value as RequestStatus)}
                    className="text-xs font-semibold bg-white border border-slate-200 rounded-lg px-2.5 py-1 focus:ring-2 focus:ring-red-500/20"
                  >
                    <option value="Open">Open</option>
                    <option value="Partially Fulfilled">Partially Fulfilled</option>
                    <option value="Fulfilled">Fulfilled</option>
                    <option value="Cancelled">Cancelled</option>
                  </select>
                </div>
              </div>
            </div>

            {/* Hospital & Contact Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div className="p-3.5 bg-white border border-slate-200 rounded-xl">
                <span className="text-slate-400 font-semibold block">Hospital & Location</span>
                <span className="text-slate-900 font-bold block mt-1">{activeRequest.hospital_name}</span>
                <span className="text-slate-600 block mt-0.5">
                  {activeRequest.hospital_address || activeRequest.city || 'Address on record'}
                </span>
              </div>

              <div className="p-3.5 bg-white border border-slate-200 rounded-xl">
                <span className="text-slate-400 font-semibold block">Contact Number</span>
                <span className="text-slate-900 font-bold block mt-1 flex items-center gap-1.5">
                  <Phone className="w-3.5 h-3.5 text-slate-400" />
                  {activeRequest.contact_phone}
                </span>
                {activeRequest.reason && (
                  <span className="text-slate-500 block mt-1 italic">Reason: {activeRequest.reason}</span>
                )}
              </div>
            </div>

            {/* Offers Section */}
            <div>
              <div className="flex items-center justify-between mb-3">
                <h4 className="text-sm font-bold text-slate-900 flex items-center gap-2">
                  <UserCheck className="w-4 h-4 text-red-600" />
                  Donor Offers ({activeRequest.offers?.length || 0})
                </h4>
                <span className="text-xs text-slate-500">
                  {activeRequest.accepted_units} of {activeRequest.required_units} accepted
                </span>
              </div>

              {(!activeRequest.offers || activeRequest.offers.length === 0) ? (
                <div className="p-6 bg-slate-50 rounded-xl border border-slate-200 text-center text-xs text-slate-500">
                  No volunteer offers have been submitted for this request yet.
                </div>
              ) : (
                <div className="space-y-2.5">
                  {activeRequest.offers.map((offer) => (
                    <div
                      key={offer.id}
                      className="p-3.5 rounded-xl border border-slate-200 bg-white shadow-2xs flex items-center justify-between gap-3"
                    >
                      <div className="flex items-center gap-3">
                        <BloodGroupBadge bloodType={offer.donorBloodType} size="sm" />
                        <div>
                          <div className="font-bold text-xs text-slate-900 flex items-center gap-1.5">
                            {offer.donorName}
                            {offer.donorIsVerified && (
                              <span className="text-[10px] text-emerald-600 font-bold">🛡️ Verified</span>
                            )}
                          </div>
                          <div className="text-[11px] text-slate-500">
                            Offered: {offer.offeredUnits} unit(s) •{' '}
                            {new Date(offer.offerTimestamp).toLocaleDateString()}
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        {offer.status === 'accepted' ? (
                          <span className="text-xs font-bold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-lg border border-emerald-200">
                            ✓ Accepted
                          </span>
                        ) : offer.status === 'declined' ? (
                          <span className="text-xs font-bold text-slate-500 bg-slate-100 px-2.5 py-1 rounded-lg">
                            Declined
                          </span>
                        ) : (
                          <>
                            <button
                              onClick={() => handleDeclineOffer(activeRequest.id, offer.id)}
                              disabled={isProcessing}
                              className="px-2.5 py-1 text-xs font-semibold text-rose-600 bg-rose-50 hover:bg-rose-100 rounded-lg transition-colors"
                            >
                              Decline
                            </button>
                            <button
                              onClick={() => handleAcceptOffer(activeRequest.id, offer.id)}
                              disabled={isProcessing}
                              className="px-2.5 py-1 text-xs font-semibold text-white bg-emerald-600 hover:bg-emerald-700 rounded-lg transition-colors shadow-xs"
                            >
                              Accept Offer
                            </button>
                          </>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Modal Actions */}
            <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
              <button
                onClick={() => setDeletingRequest(activeRequest)}
                className="text-xs font-semibold text-rose-600 hover:text-rose-700 flex items-center gap-1"
              >
                <Trash2 className="w-3.5 h-3.5" />
                Delete Request
              </button>
              <button
                onClick={() => setActiveRequest(null)}
                className="px-4 py-2 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl"
              >
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Delete Confirmation */}
      <ConfirmDialog
        isOpen={!!deletingRequest}
        onClose={() => setDeletingRequest(null)}
        onConfirm={handleDeleteRequest}
        title="Delete Blood Request?"
        message={`Are you sure you want to permanently delete blood request for patient "${deletingRequest?.patient_name}" at ${deletingRequest?.hospital_name}?`}
        confirmText="Delete Request"
        isLoading={isProcessing}
      />
    </div>
  );
};
