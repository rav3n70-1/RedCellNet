// admin_panel/src/pages/DashboardPage.tsx
import React, { useState } from 'react';
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

interface DashboardPageProps {
  donors: UserProfile[];
  requests: BloodRequest[];
  facilities: DonationCenter[];
  reports: ReportItem[];
  onNavigate: (tab: NavigationTab) => void;
  onRefresh: () => void;
}

export const DashboardPage: React.FC<DashboardPageProps> = ({
  donors,
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

  // Derived Section 6 KPI metrics
  const totalUsers = donors.length;
  const verifiedDonors = donors.filter((d) => d.verification_status === 'verified').length;
  const availableDonors = donors.filter(
    (d) => Boolean(d.is_available_to_donate) && !d.is_banned
  ).length;
  const pendingVerifications = donors.filter((d) => d.verification_status === 'pending').length;

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

      {seedSuccess && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600" />
          Sample emergency blood requests successfully created!
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
          title="Total Users"
          value={totalUsers}
          subtitle="Registered community"
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
