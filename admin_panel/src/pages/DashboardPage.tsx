// admin_panel/src/pages/DashboardPage.tsx
import React, { useState, useEffect } from 'react';
import {
  Users,
  Droplets,
  ShieldCheck,
  AlertTriangle,
  Building2,
  ShieldAlert,
  Send,
  PlusCircle,
  Database,
  CheckCircle2,
  UserCheck,
  Clock,
  BarChart3,
  Calendar,
  Sparkles,
  Trash2,
  UserX,
  Navigation,
} from 'lucide-react';
import type { BloodRequest, DonationCenter, ReportItem, UserProfile } from '../types';
import { StatCard } from '../components/common/StatCard';
import { BloodGroupSupplyChart } from '../components/dashboard/BloodGroupSupplyChart';
import { UrgentRequestsWidget } from '../components/dashboard/UrgentRequestsWidget';
import { PendingReportsWidget } from '../components/dashboard/PendingReportsWidget';
import type { NavigationTab } from '../components/layout/Sidebar';
import { Modal } from '../components/common/Modal';
import { BloodGroupBadge, StatusBadge, UrgencyBadge } from '../components/common/Badge';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface BloodCampRow {
  id: string;
  title: string;
  organizer: string;
  venue: string;
  city: string;
  event_date: string;
  contact_phone?: string;
  is_active?: boolean;
}

interface DashboardPageProps {
  donors: UserProfile[];
  staffMembers?: UserProfile[];
  requests: BloodRequest[];
  facilities: DonationCenter[];
  reports: ReportItem[];
  onNavigate: (tab: NavigationTab) => void;
  onRefresh: () => void;
}

export const DashboardPage: React.FC<DashboardPageProps> = ({
  donors,
  staffMembers = [],
  requests,
  facilities,
  reports,
  onNavigate,
  onRefresh,
}) => {
  const { user, isSuperAdmin } = useAuth();
  const [selectedRequest, setSelectedRequest] = useState<BloodRequest | null>(null);
  const [isSeeding, setIsSeeding] = useState(false);
  const [seedSuccess, setSeedSuccess] = useState(false);
  const [cleanupNotice, setCleanupNotice] = useState<string | null>(null);
  const [isCleaning, setIsCleaning] = useState(false);

  // Blood Camps Management State
  const [camps, setCamps] = useState<BloodCampRow[]>([]);
  const [showCampModal, setShowCampModal] = useState(false);
  const [campForm, setCampForm] = useState({
    title: '',
    organizer: 'Bangladesh Red Crescent / Sandhani',
    venue: '',
    city: 'Dhaka',
    event_date: new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10),
    contact_phone: '',
  });

  const loadCamps = async () => {
    const { data, error } = await supabase
      .from('blood_camps')
      .select('*')
      .order('event_date', { ascending: true });
    if (!error && data) {
      setCamps(data as BloodCampRow[]);
    }
  };

  useEffect(() => {
    loadCamps();
  }, []);

  const handleRunCleanup = async () => {
    setIsCleaning(true);
    try {
      const { data, error } = await supabase.rpc('cleanup_and_archive_stale_data');
      if (error) throw error;
      const summary = data as {
        expired_requests_closed?: number;
        expired_broadcasts_deactivated?: number;
      } | null;
      setCleanupNotice(
        `Database hygiene complete: ${summary?.expired_requests_closed ?? 0} stale request(s) archived, ${summary?.expired_broadcasts_deactivated ?? 0} expired broadcast(s) closed.`
      );
      setTimeout(() => setCleanupNotice(null), 5000);
      onRefresh();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Database cleanup failed.');
    } finally {
      setIsCleaning(false);
    }
  };

  const handleCreateCamp = async () => {
    if (!campForm.title.trim() || !campForm.venue.trim()) return;
    const { error } = await supabase.from('blood_camps').insert({
      title: campForm.title.trim(),
      organizer: campForm.organizer.trim(),
      venue: campForm.venue.trim(),
      city: campForm.city.trim(),
      event_date: campForm.event_date,
      contact_phone: campForm.contact_phone.trim(),
      is_active: true,
    });
    if (!error) {
      setShowCampModal(false);
      setCampForm({
        title: '',
        organizer: 'Bangladesh Red Crescent / Sandhani',
        venue: '',
        city: 'Dhaka',
        event_date: new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10),
        contact_phone: '',
      });
      loadCamps();
    } else {
      alert(error.message);
    }
  };

  const handleDeleteCamp = async (id: string) => {
    await supabase.from('blood_camps').delete().eq('id', id);
    loadCamps();
  };

  // Derived Section 6 KPI metrics
  const totalUsers = donors.length;
  const verifiedDonors = donors.filter((d) => d.verification_status === 'verified').length;
  const availableDonors = donors.filter(
    (d) => Boolean(d.is_available_to_donate) && !d.is_banned
  ).length;
  const pendingVerifications = donors.filter((d) => d.verification_status === 'pending').length;
  const pendingDeletionDonors = donors.filter(
    (d) => Boolean(d.deletion_requested) || d.deletion_request_status === 'pending'
  );

  const activeTrackedOffers = requests.flatMap((req) =>
    (req.offers || [])
      .filter(
        (o) =>
          o.locationTrackingStatus === 'active' || o.locationTrackingStatus === 'requested'
      )
      .map((offer) => ({ offer, request: req }))
  );

  const handleQuickDeletionDecision = async (
    targetUserId: string,
    decision: 'approve_hard_delete' | 'archive' | 'reject'
  ) => {
    try {
      const { error } = await supabase.rpc('admin_resolve_deletion_request', {
        target_user_id: targetUserId,
        decision,
        admin_note: `Processed from Operations Dashboard (${decision})`,
      });
      if (error) throw error;
      onRefresh();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Failed to process deletion request.');
    }
  };

  const activeRequests = requests.filter(
    (r) => r.status === 'Open' || r.status === 'Partially Fulfilled'
  ).length;
  const criticalRequests = requests.filter(
    (r) =>
      (r.status === 'Open' || r.status === 'Partially Fulfilled') && r.urgency_level === 'Critical'
  ).length;
  const fulfilledRequests = requests.filter((r) => r.status === 'Fulfilled').length;
  const expiredRequests = requests.filter((r) => r.status === 'Expired').length;
  const pendingReports = reports.filter((r) => r.status === 'pending').length;

  const handleResolveReport = async (
    reportId: string,
    action: 'dismiss' | 'action_taken',
    _targetId: string
  ) => {
    try {
      const { error } = await supabase.rpc('resolve_moderation_report', {
        p_report_id: reportId,
        p_action: action,
        p_notes:
          action === 'action_taken'
            ? 'Action enforced from Operations Dashboard.'
            : 'Dismissed from Operations Dashboard.',
      });
      if (error) throw error;
      onRefresh();
    } catch (err: unknown) {
      console.error('Error resolving report:', err);
      alert(err instanceof Error ? err.message : 'Failed to resolve report.');
    }
  };

  // Seed sample data (Super Admin only, passing valid requester_user_id & checking errors)
  const handleSeedDemoData = async () => {
    if (!user || !isSuperAdmin) return;
    setIsSeeding(true);
    try {
      if (requests.length === 0) {
        const { error: reqErr } = await supabase.from('blood_requests').insert([
          {
            requester_user_id: user.id,
            patient_name: 'Tanvir Hossain',
            hospital_name: 'Dhaka Medical College Hospital',
            hospital_address: 'Secretariat Rd, Dhaka 1000',
            city: 'Dhaka',
            latitude: 23.7258,
            longitude: 90.3976,
            required_blood_type: 'O-',
            required_units: 3,
            accepted_units: 0,
            remaining_units: 3,
            contact_phone: '+8801711223344',
            urgency_level: 'Critical',
            reason: 'Emergency cardiovascular surgery',
            is_emergency: true,
            status: 'Open',
            expiry_hours: 24,
            expiry_at: new Date(Date.now() + 24 * 3600000).toISOString(),
            created_at: new Date().toISOString(),
          },
          {
            requester_user_id: user.id,
            patient_name: 'Sabrina Akter',
            hospital_name: 'Square Hospitals Ltd.',
            hospital_address: '18/F Bir Uttam Qazi Nuruzzaman Sarak, Dhaka',
            city: 'Dhaka',
            latitude: 23.7528,
            longitude: 90.3816,
            required_blood_type: 'A+',
            required_units: 2,
            accepted_units: 0,
            remaining_units: 2,
            contact_phone: '+8801822334455',
            urgency_level: 'High',
            reason: 'Post-delivery maternal hemorrhage',
            is_emergency: true,
            status: 'Open',
            expiry_hours: 48,
            expiry_at: new Date(Date.now() + 48 * 3600000).toISOString(),
            created_at: new Date().toISOString(),
          },
        ]);
        if (reqErr) throw reqErr;
      }

      await supabase.rpc('record_admin_log', {
        p_action_type: 'seed_demo_requests',
        p_target_type: 'system',
        p_target_id: user.id,
        p_details: {},
      });

      setSeedSuccess(true);
      setTimeout(() => setSeedSuccess(false), 3000);
      onRefresh();
    } catch (err: unknown) {
      console.error('Error seeding demo data:', err);
      alert(err instanceof Error ? err.message : 'Failed to load sample data.');
    } finally {
      setIsSeeding(false);
    }
  };

  return (
    <div className="space-y-8">
      {/* Quick Action Banner */}
      <div className="bg-gradient-to-r from-red-700 via-red-600 to-rose-700 rounded-3xl p-6 text-white shadow-xl shadow-red-900/10 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <span className="text-xs uppercase font-extrabold tracking-wider bg-white/20 px-2.5 py-1 rounded-md text-white">
            Clinical Operations Hub
          </span>
          <h2 className="text-2xl font-black tracking-tight mt-2 text-white">
            RedCellNet Unified Administration
          </h2>
          <p className="text-sm text-red-100 max-w-xl mt-1">
            Oversee hospital blood dispatches, verify laboratory donor certificates, monitor
            regional availability, and enforce community safety.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => onNavigate('broadcast')}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-white text-red-700 hover:bg-red-50 font-bold rounded-xl text-sm shadow-md transition-colors"
          >
            <Send className="w-4 h-4 text-red-600" />
            Send Alert
          </button>
          <button
            onClick={() => onNavigate('analytics')}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-red-800/60 hover:bg-red-800/80 text-white font-semibold rounded-xl text-sm border border-red-400/30 transition-colors"
          >
            <BarChart3 className="w-4 h-4" />
            Analytics
          </button>
          <button
            onClick={() => onNavigate('facilities')}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-red-800/60 hover:bg-red-800/80 text-white font-semibold rounded-xl text-sm border border-red-400/30 transition-colors"
          >
            <PlusCircle className="w-4 h-4" />
            Blood Banks
          </button>
          <button
            onClick={() => setShowCampModal(true)}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-red-800/60 hover:bg-red-800/80 text-white font-semibold rounded-xl text-sm border border-red-400/30 transition-colors"
          >
            <Calendar className="w-4 h-4" />
            Schedule Camp
          </button>
          <button
            onClick={handleRunCleanup}
            disabled={isCleaning}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-slate-900/75 hover:bg-slate-900 text-white font-semibold rounded-xl text-sm border border-slate-700/50 transition-colors"
          >
            <Sparkles className="w-4 h-4 text-emerald-400" />
            {isCleaning ? 'Cleaning...' : 'DB Hygiene'}
          </button>
          {isSuperAdmin && requests.length === 0 && (
            <button
              onClick={handleSeedDemoData}
              disabled={isSeeding}
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-slate-900/70 hover:bg-slate-900 text-white font-semibold rounded-xl text-sm border border-slate-700/50 transition-colors"
            >
              <Database className="w-4 h-4 text-amber-400" />
              {isSeeding ? 'Seeding...' : 'Load Sample Requests'}
            </button>
          )}
        </div>
      </div>

      {cleanupNotice && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600" />
          {cleanupNotice}
        </div>
      )}

      {seedSuccess && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600" />
          Sample emergency blood requests successfully created!
        </div>
      )}

      {/* Pending Account Deletion Requests Queue Banner */}
      {pendingDeletionDonors.length > 0 && (
        <div className="bg-rose-50 border border-rose-200 rounded-2xl p-5 space-y-3 shadow-xs">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-xl bg-rose-600 text-white flex items-center justify-center shrink-0">
                <UserX className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-sm font-black text-rose-950">
                  {pendingDeletionDonors.length} Account Deletion Request(s) Awaiting Staff Approval
                </h3>
                <p className="text-xs text-rose-800">
                  Users cannot self-delete without staff review. Approve permanent hard-delete, archive (soft-deactivate), or reject.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => onNavigate('donors')}
              className="px-3.5 py-2 rounded-xl bg-white border border-rose-200 text-rose-700 hover:bg-rose-100 text-xs font-bold shrink-0"
            >
              Open Full Queue
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-1">
            {pendingDeletionDonors.slice(0, 4).map((d) => (
              <div
                key={d.id}
                className="p-3.5 rounded-xl bg-white border border-rose-200/80 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
              >
                <div className="min-w-0 text-xs">
                  <div className="font-bold text-slate-900 truncate">
                    {d.name || 'Donor'} ({d.blood_type || 'Unset'})
                  </div>
                  <div className="text-slate-500 truncate">{d.email}</div>
                  {d.deletion_request_reason && (
                    <div className="text-[11px] text-rose-700 font-medium mt-0.5 italic">
                      Reason: "{d.deletion_request_reason}"
                    </div>
                  )}
                </div>
                <div className="flex items-center gap-1.5 shrink-0">
                  <button
                    type="button"
                    onClick={() => handleQuickDeletionDecision(d.id, 'approve_hard_delete')}
                    className="px-2.5 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-700 text-white text-[11px] font-bold"
                  >
                    Approve Delete
                  </button>
                  <button
                    type="button"
                    onClick={() => handleQuickDeletionDecision(d.id, 'archive')}
                    className="px-2.5 py-1.5 rounded-lg bg-amber-100 hover:bg-amber-200 text-amber-900 text-[11px] font-bold"
                  >
                    Archive
                  </button>
                  <button
                    type="button"
                    onClick={() => handleQuickDeletionDecision(d.id, 'reject')}
                    className="px-2.5 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 text-[11px] font-semibold"
                  >
                    Reject
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Active Live Donor Location Tracking Monitor */}
      {activeTrackedOffers.length > 0 && (
        <div className="bg-blue-50/80 border border-blue-200 rounded-2xl p-5 space-y-3 shadow-xs">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-xl bg-blue-600 text-white flex items-center justify-center shrink-0">
                <Navigation className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-sm font-black text-blue-950">
                  Live Donor Route Tracking ({activeTrackedOffers.length} Active Dispatch)
                </h3>
                <p className="text-xs text-blue-800">
                  Mutual-consent GPS telemetry between confirmed donors and hospital requesters.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => onNavigate('requests')}
              className="px-3 py-1.5 rounded-xl bg-white border border-blue-200 text-blue-700 text-xs font-bold"
            >
              Inspect Dispatches
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            {activeTrackedOffers.map(({ offer, request }) => (
              <div
                key={`${request.id}-${offer.id}`}
                className="p-3.5 rounded-xl bg-white border border-blue-200 text-xs space-y-1.5"
              >
                <div className="flex items-center justify-between">
                  <span className="font-black text-slate-900">{offer.donorName}</span>
                  <span
                    className={`px-2 py-0.5 rounded-full text-[10px] font-black uppercase ${
                      offer.locationTrackingStatus === 'active'
                        ? 'bg-emerald-100 text-emerald-800'
                        : 'bg-amber-100 text-amber-800'
                    }`}
                  >
                    {offer.locationTrackingStatus === 'active' ? 'GPS LIVE' : 'AWAITING CONSENT'}
                  </span>
                </div>
                <div className="text-slate-600">
                  Destination: <strong>{request.hospital_name}</strong> ({request.patient_name})
                </div>
                {offer.locationTrackingStatus === 'active' && (
                  <div className="text-[11px] font-bold text-blue-700">
                    {offer.donorDistanceKm != null ? `${offer.donorDistanceKm.toFixed(1)} km away` : 'Calculating distance'}
                    {offer.donorEtaMinutes != null ? ` • ETA ~${offer.donorEtaMinutes} min` : ''}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Primary KPI Stats Grid (10 Operational Indicators across 2 clean rows) */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
        <StatCard
          title="Active Requests"
          value={activeRequests}
          subtitle="Open or partially fulfilled"
          icon={Droplets}
          color="red"
          onClick={() => onNavigate('requests')}
        />
        <StatCard
          title="Critical Cases"
          value={criticalRequests}
          subtitle="Immediate hospital need"
          icon={AlertTriangle}
          color="purple"
          trend={criticalRequests > 0 ? { value: 'Urgent', isPositive: false } : undefined}
          onClick={() => onNavigate('requests')}
        />
        <StatCard
          title="Fulfilled Cases"
          value={fulfilledRequests}
          subtitle="Completed transfusions"
          icon={CheckCircle2}
          color="emerald"
          onClick={() => onNavigate('requests')}
        />
        <StatCard
          title="Expired Cases"
          value={expiredRequests}
          subtitle="Past deadline window"
          icon={Clock}
          color="slate"
          onClick={() => onNavigate('requests')}
        />
        <StatCard
          title="Open Reports"
          value={pendingReports}
          subtitle="Awaiting moderation"
          icon={ShieldAlert}
          color="amber"
          trend={
            pendingReports > 0 ? { value: `${pendingReports} open`, isPositive: false } : undefined
          }
          onClick={() => onNavigate('reports')}
        />

        <StatCard
          title="Registered Donors"
          value={totalUsers}
          subtitle={`${staffMembers.length} staff isolated`}
          icon={Users}
          color="blue"
          onClick={() => onNavigate('donors')}
        />
        <StatCard
          title="Verified Donors"
          value={verifiedDonors}
          subtitle="Lab-verified shield badge"
          icon={ShieldCheck}
          color="emerald"
          onClick={() => onNavigate('donors')}
        />
        <StatCard
          title="Available Donors"
          value={availableDonors}
          subtitle="Eligible & ready now"
          icon={UserCheck}
          color="blue"
          onClick={() => onNavigate('donors')}
        />
        <StatCard
          title="Pending Reviews"
          value={pendingVerifications}
          subtitle="Lab certificates in queue"
          icon={ShieldCheck}
          color="amber"
          trend={
            pendingVerifications > 0
              ? { value: `${pendingVerifications} queued`, isPositive: false }
              : undefined
          }
          onClick={() => onNavigate('donors')}
        />
        <StatCard
          title="Blood Centers"
          value={facilities.length}
          subtitle="Certified collection hubs"
          icon={Building2}
          color="slate"
          onClick={() => onNavigate('facilities')}
        />
      </div>

      {/* Blood Group Distribution Graph */}
      <BloodGroupSupplyChart donors={donors} requests={requests} />

      {/* Lower Dashboard Grid: Urgent Requests + Moderation Reports */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <UrgentRequestsWidget
          requests={requests}
          onViewAll={() => onNavigate('requests')}
          onSelectRequest={(req) => setSelectedRequest(req)}
        />
        <PendingReportsWidget
          reports={reports}
          onViewAll={() => onNavigate('reports')}
          onResolve={handleResolveReport}
        />
      </div>

      {/* Community Blood Camps Manager */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-5 space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-sm font-black text-slate-900 flex items-center gap-2">
              <Calendar className="w-4 h-4 text-red-600" />
              Scheduled Blood Donation Camps ({camps.length})
            </h3>
            <p className="text-xs text-slate-500">
              Drives synced to the Donor App calendar (.ics export & RSVP).
            </p>
          </div>
          <button
            type="button"
            onClick={() => setShowCampModal(true)}
            className="px-3.5 py-2 rounded-xl bg-red-600 hover:bg-red-700 text-white text-xs font-bold transition-colors"
          >
            + Schedule Camp
          </button>
        </div>

        {camps.length === 0 ? (
          <div className="p-6 text-center text-xs text-slate-400 bg-slate-50 rounded-xl border border-dashed border-slate-200">
            No upcoming blood donation camps scheduled.
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            {camps.map((c) => (
              <div
                key={c.id}
                className="p-3.5 rounded-xl border border-slate-200 bg-slate-50/60 flex items-start justify-between gap-2"
              >
                <div className="text-xs space-y-1">
                  <div className="font-bold text-slate-900">{c.title}</div>
                  <div className="text-slate-600">
                    {c.organizer} • {c.venue}, {c.city}
                  </div>
                  <div className="text-[11px] font-bold text-red-600">
                    Date: {c.event_date} {c.contact_phone ? `• ${c.contact_phone}` : ''}
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => handleDeleteCamp(c.id)}
                  className="p-1.5 text-slate-400 hover:text-rose-600 rounded-lg"
                  title="Remove Camp"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Schedule Blood Camp Modal */}
      {showCampModal && (
        <Modal
          isOpen={true}
          onClose={() => setShowCampModal(false)}
          title="Schedule Community Blood Donation Camp"
          subtitle="Published immediately to the Donor App Blood Camp Calendar."
          maxWidth="md"
        >
          <div className="space-y-3 text-xs">
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Camp Title *</label>
              <input
                type="text"
                value={campForm.title}
                onChange={(e) => setCampForm({ ...campForm, title: e.target.value })}
                placeholder="e.g. DU TSC Annual Lifesaver Blood Drive"
                className="w-full px-3 py-2 border border-slate-200 rounded-xl"
              />
            </div>
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Organizer *</label>
              <input
                type="text"
                value={campForm.organizer}
                onChange={(e) => setCampForm({ ...campForm, organizer: e.target.value })}
                className="w-full px-3 py-2 border border-slate-200 rounded-xl"
              />
            </div>
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Venue / Campus *</label>
              <input
                type="text"
                value={campForm.venue}
                onChange={(e) => setCampForm({ ...campForm, venue: e.target.value })}
                placeholder="e.g. TSC Auditorium, University of Dhaka"
                className="w-full px-3 py-2 border border-slate-200 rounded-xl"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="font-semibold text-slate-700 block mb-1">City *</label>
                <input
                  type="text"
                  value={campForm.city}
                  onChange={(e) => setCampForm({ ...campForm, city: e.target.value })}
                  className="w-full px-3 py-2 border border-slate-200 rounded-xl"
                />
              </div>
              <div>
                <label className="font-semibold text-slate-700 block mb-1">Event Date *</label>
                <input
                  type="date"
                  value={campForm.event_date}
                  onChange={(e) => setCampForm({ ...campForm, event_date: e.target.value })}
                  className="w-full px-3 py-2 border border-slate-200 rounded-xl"
                />
              </div>
            </div>
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Coordinator Phone</label>
              <input
                type="text"
                value={campForm.contact_phone}
                onChange={(e) => setCampForm({ ...campForm, contact_phone: e.target.value })}
                placeholder="+88017..."
                className="w-full px-3 py-2 border border-slate-200 rounded-xl"
              />
            </div>
            <div className="pt-3 flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setShowCampModal(false)}
                className="px-4 py-2 rounded-xl bg-slate-100 text-slate-700 font-semibold"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleCreateCamp}
                className="px-4 py-2 rounded-xl bg-red-600 text-white font-bold"
              >
                Publish Camp
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Quick Request Details Modal */}
      {selectedRequest && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedRequest(null)}
          title={`Blood Request: ${selectedRequest.patient_name}`}
          subtitle={`${selectedRequest.hospital_name} • ${selectedRequest.city || 'Location on file'}`}
          maxWidth="lg"
        >
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 bg-slate-50 rounded-xl border border-slate-200">
              <div className="flex items-center gap-3">
                <BloodGroupBadge bloodType={selectedRequest.required_blood_type} size="lg" />
                <div>
                  <div className="text-xs font-bold text-slate-500 uppercase">Requirement</div>
                  <div className="text-sm font-extrabold text-slate-900">
                    {selectedRequest.remaining_units} of {selectedRequest.required_units} Units
                    Needed
                  </div>
                </div>
              </div>
              <div className="flex flex-col items-end gap-1.5">
                <UrgencyBadge level={selectedRequest.urgency_level} />
                <StatusBadge status={selectedRequest.status} />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 text-xs">
              <div className="p-3 bg-white border border-slate-200 rounded-xl">
                <span className="text-slate-400 font-semibold block">Hospital Address</span>
                <span className="text-slate-800 font-bold mt-1 block">
                  {selectedRequest.hospital_address || 'Address on file'}
                </span>
              </div>
              <div className="p-3 bg-white border border-slate-200 rounded-xl">
                <span className="text-slate-400 font-semibold block">Contact Phone</span>
                <span className="text-slate-800 font-bold mt-1 block">
                  {selectedRequest.contact_phone}
                </span>
              </div>
            </div>

            {selectedRequest.reason && (
              <div className="p-3 bg-white border border-slate-200 rounded-xl text-xs">
                <span className="text-slate-400 font-semibold block">Clinical Reason</span>
                <p className="text-slate-700 mt-1">{selectedRequest.reason}</p>
              </div>
            )}

            <div className="pt-3 border-t border-slate-100 flex justify-end gap-2">
              <button
                onClick={() => {
                  setSelectedRequest(null);
                  onNavigate('requests');
                }}
                className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-semibold text-xs rounded-xl shadow-xs transition-colors"
              >
                Open Full Request Manager
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
};
