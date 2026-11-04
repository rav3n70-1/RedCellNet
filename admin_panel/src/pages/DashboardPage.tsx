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
  const [selectedRequest, setSelectedRequest] = useState<BloodRequest | null>(null);
  const [isSeeding, setIsSeeding] = useState(false);
  const [seedSuccess, setSeedSuccess] = useState(false);

  // Derived metrics
  const totalDonors = donors.length;
  const verifiedDonors = donors.filter((d) => d.verification_status === 'verified').length;
  const pendingVerifications = donors.filter((d) => d.verification_status === 'pending').length;
  const activeRequests = requests.filter((r) => r.status === 'Open' || r.status === 'Partially Fulfilled').length;
  const criticalRequests = requests.filter(
    (r) => (r.status === 'Open' || r.status === 'Partially Fulfilled') && r.urgency_level === 'Critical'
  ).length;
  const pendingReports = reports.filter((r) => r.status === 'pending').length;

  const handleResolveReport = async (
    reportId: string,
    action: 'dismiss' | 'action_taken',
    targetId: string
  ) => {
    try {
      if (action === 'action_taken') {
        // Cancel the reported request
        await supabase
          .from('blood_requests')
          .update({
            status: 'Cancelled',
            cancellation_reason: 'Removed following moderation report',
            updated_at: new Date().toISOString(),
          })
          .eq('id', targetId);
      }

      await supabase
        .from('reports')
        .update({
          status: action,
          resolved_at: new Date().toISOString(),
        })
        .eq('id', reportId);

      onRefresh();
    } catch (err) {
      console.error('Error resolving report:', err);
    }
  };

  // Seed sample data for testing and demonstration
  const handleSeedDemoData = async () => {
    setIsSeeding(true);
    try {
      // 1. Seed demo requests if empty
      if (requests.length === 0) {
        await supabase.from('blood_requests').insert([
          {
            patient_name: 'Tanvir Hossain',
            hospital_name: 'Dhaka Medical College Hospital',
            hospital_address: 'Secretariat Rd, Dhaka 1000',
            city: 'Dhaka',
            required_blood_type: 'O-',
            required_units: 3,
            accepted_units: 1,
            remaining_units: 2,
            contact_phone: '+8801711223344',
            urgency_level: 'Critical',
            reason: 'Emergency cardiovascular surgery',
            is_emergency: true,
            status: 'Open',
            expiry_hours: 24,
            expiry_at: new Date(Date.now() + 24 * 3600000).toISOString(),
            offers: [
              {
                id: 'offer-1',
                donorId: 'donor-1',
                donorName: 'Dr. Rafiqul Islam',
                donorBloodType: 'O-',
                offeredUnits: 1,
                status: 'pending',
                offerTimestamp: new Date().toISOString(),
              },
            ],
            created_at: new Date().toISOString(),
          },
          {
            patient_name: 'Sabrina Akter',
            hospital_name: 'Square Hospitals Ltd.',
            hospital_address: '18/F Bir Uttam Qazi Nuruzzaman Sarak, Dhaka',
            city: 'Dhaka',
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
          {
            patient_name: 'Fahim Ahmed',
            hospital_name: 'Chittagong Medical College',
            hospital_address: '57 K.B. Fazlul Kader Rd, Chattogram',
            city: 'Chattogram',
            required_blood_type: 'B+',
            required_units: 1,
            accepted_units: 1,
            remaining_units: 0,
            contact_phone: '+8801933445566',
            urgency_level: 'Medium',
            reason: 'Thalassemia scheduled transfusion',
            is_emergency: false,
            status: 'Fulfilled',
            expiry_hours: 72,
            created_at: new Date().toISOString(),
          },
        ]);
      }

      // 2. Seed demo reports if empty
      if (reports.length === 0) {
        await supabase.from('reports').insert([
          {
            reporter_user_id: 'user-demo-1',
            reported_type: 'request',
            target_id: 'test-target-id',
            reason: 'Duplicate or spam request',
            details: 'The same phone number was posted multiple times with different names.',
            status: 'pending',
            created_at: new Date().toISOString(),
          },
        ]);
      }

      setSeedSuccess(true);
      setTimeout(() => setSeedSuccess(false), 3000);
      onRefresh();
    } catch (err) {
      console.error('Error seeding demo data:', err);
    } finally {
      setIsSeeding(false);
    }
  };

  return (
    <div className="space-y-8">
      {/* Quick Action Banner */}
      <div className="bg-gradient-to-r from-red-600 via-rose-600 to-rose-700 rounded-3xl p-6 text-white shadow-xl shadow-red-900/10 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <span className="text-xs uppercase font-extrabold tracking-wider bg-white/20 px-2.5 py-1 rounded-md text-white">
            System Control Hub
          </span>
          <h2 className="text-2xl font-black tracking-tight mt-2 text-white">
            RedCellNet Unified Administration
          </h2>
          <p className="text-sm text-red-100 max-w-xl mt-1">
            Oversee blood distribution across hospitals, verify voluntary donors, monitor emergency
            dispatches, and send community alerts.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => onNavigate('broadcast')}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-white text-red-700 hover:bg-red-50 font-bold rounded-xl text-sm shadow-md transition-colors"
          >
            <Send className="w-4 h-4 text-red-600" />
            Send Broadcast Alert
          </button>
          <button
            onClick={() => onNavigate('facilities')}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-red-800/60 hover:bg-red-800/80 text-white font-semibold rounded-xl text-sm border border-red-400/30 transition-colors"
          >
            <PlusCircle className="w-4 h-4" />
            Add Blood Bank
          </button>
          {donors.length === 0 && requests.length === 0 && (
            <button
              onClick={handleSeedDemoData}
              disabled={isSeeding}
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-slate-900/70 hover:bg-slate-900 text-white font-semibold rounded-xl text-sm border border-slate-700/50 transition-colors"
            >
              <Database className="w-4 h-4 text-amber-400" />
              {isSeeding ? 'Seeding...' : 'Load Sample Data'}
            </button>
          )}
        </div>
      </div>

      {seedSuccess && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600" />
          Sample emergency blood requests and moderation reports successfully loaded into Supabase!
        </div>
      )}

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        <StatCard
          title="Active Requests"
          value={activeRequests}
          subtitle="Currently open in hospitals"
          icon={Droplets}
          color="red"
          onClick={() => onNavigate('requests')}
        />
        <StatCard
          title="Critical Emergencies"
          value={criticalRequests}
          subtitle="Needed within 2 hours"
          icon={AlertTriangle}
          color="purple"
          trend={criticalRequests > 0 ? { value: 'Urgent', isPositive: false } : undefined}
          onClick={() => onNavigate('requests')}
        />
        <StatCard
          title="Total Donors"
          value={totalDonors}
          subtitle={pendingVerifications > 0 ? `${pendingVerifications} awaiting review` : "Registered donor base"}
          icon={Users}
          color="blue"
          onClick={() => onNavigate('donors')}
        />
        <StatCard
          title="Verified Donors"
          value={verifiedDonors}
          subtitle="Shield badge certified"
          icon={ShieldCheck}
          color="emerald"
          onClick={() => onNavigate('donors')}
        />
        <StatCard
          title="Certified Centers"
          value={facilities.length}
          subtitle="Registered blood banks"
          icon={Building2}
          color="slate"
          onClick={() => onNavigate('facilities')}
        />
        <StatCard
          title="Pending Reports"
          value={pendingReports}
          subtitle="Requires moderation"
          icon={ShieldAlert}
          color="amber"
          trend={pendingReports > 0 ? { value: `${pendingReports} flags`, isPositive: false } : undefined}
          onClick={() => onNavigate('reports')}
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
          subtitle={`${selectedRequest.hospital_name} • ${selectedRequest.city || 'Dhaka'}`}
          maxWidth="lg"
        >
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 bg-slate-50 rounded-xl border border-slate-200">
              <div className="flex items-center gap-3">
                <BloodGroupBadge bloodType={selectedRequest.required_blood_type} size="lg" />
                <div>
                  <div className="text-xs font-bold text-slate-500 uppercase">Requirement</div>
                  <div className="text-sm font-extrabold text-slate-900">
                    {selectedRequest.remaining_units} of {selectedRequest.required_units} Units Needed
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
