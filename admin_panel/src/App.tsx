// admin_panel/src/App.tsx
import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from './lib/supabase';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { Layout } from './components/layout/Layout';
import type { NavigationTab } from './components/layout/Sidebar';
import { LoginPage } from './pages/LoginPage';
import { DashboardPage } from './pages/DashboardPage';
import { DonorsPage } from './pages/DonorsPage';
import { RequestsPage } from './pages/RequestsPage';
import { FacilitiesPage } from './pages/FacilitiesPage';
import { ContentPage } from './pages/ContentPage';
import { ReportsPage } from './pages/ReportsPage';
import { BroadcastPage } from './pages/BroadcastPage';
import { AnalyticsPage } from './pages/AnalyticsPage';
import { AuditLogsPage } from './pages/AuditLogsPage';
import type {
  AdminLog,
  BloodRequest,
  DonationCenter,
  EducationalContent,
  ReportItem,
  UserProfile,
} from './types';
import { Activity, ShieldAlert, LogOut, RefreshCw } from 'lucide-react';

const AdminApp: React.FC = () => {
  const { user, profile, isStaff, loading: authLoading, signOut, refreshProfile } = useAuth();
  const [currentTab, setCurrentTab] = useState<NavigationTab>('dashboard');

  // Database State
  const [donors, setDonors] = useState<UserProfile[]>([]);
  const [requests, setRequests] = useState<BloodRequest[]>([]);
  const [facilities, setFacilities] = useState<DonationCenter[]>([]);
  const [content, setContent] = useState<EducationalContent[]>([]);
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [auditLogs, setAuditLogs] = useState<AdminLog[]>([]);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Fetch all core data (only for authorized staff)
  const fetchData = useCallback(async () => {
    if (!isStaff) return;
    setIsRefreshing(true);
    try {
      const [donorsRes, requestsRes, centersRes, contentRes, reportsRes, logsRes] =
        await Promise.all([
          supabase.from('profiles').select('*').order('created_at', { ascending: false }),
          supabase.from('blood_requests').select('*').order('created_at', { ascending: false }),
          supabase.from('donation_centers').select('*').order('name', { ascending: true }),
          supabase.from('educational_content').select('*').order('order', { ascending: true }),
          supabase.from('reports').select('*').order('created_at', { ascending: false }),
          supabase
            .from('admin_logs')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(200),
        ]);

      if (!donorsRes.error && donorsRes.data) setDonors(donorsRes.data as UserProfile[]);
      if (!requestsRes.error && requestsRes.data) setRequests(requestsRes.data as BloodRequest[]);
      if (!centersRes.error && centersRes.data) setFacilities(centersRes.data as DonationCenter[]);
      if (!contentRes.error && contentRes.data) setContent(contentRes.data as EducationalContent[]);
      if (!reportsRes.error && reportsRes.data) setReports(reportsRes.data as ReportItem[]);
      if (!logsRes.error && logsRes.data) setAuditLogs(logsRes.data as AdminLog[]);
    } catch (err) {
      console.error('Error loading admin portal data:', err);
    } finally {
      setIsRefreshing(false);
    }
  }, [isStaff]);

  // Initial load and Realtime setup
  useEffect(() => {
    if (!user || !isStaff) return;

    fetchData();

    const channel = supabase
      .channel('schema-db-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'blood_requests' }, () =>
        fetchData()
      )
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => fetchData())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'donation_centers' }, () =>
        fetchData()
      )
      .on('postgres_changes', { event: '*', schema: 'public', table: 'educational_content' }, () =>
        fetchData()
      )
      .on('postgres_changes', { event: '*', schema: 'public', table: 'reports' }, () => fetchData())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'admin_logs' }, () =>
        fetchData()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user, isStaff, fetchData]);

  if (authLoading) {
    return (
      <div className="min-h-screen bg-slate-900 flex flex-col items-center justify-center text-white">
        <Activity className="w-10 h-10 text-red-500 animate-spin mb-4" />
        <p className="text-sm font-semibold text-slate-400">Verifying RedCellNet Staff Access...</p>
      </div>
    );
  }

  if (!user) {
    return <LoginPage />;
  }

  if (!isStaff) {
    return (
      <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-white rounded-3xl p-8 shadow-2xl border border-slate-100 text-center space-y-5">
          <div className="w-14 h-14 mx-auto rounded-2xl bg-rose-50 border border-rose-200 flex items-center justify-center text-rose-600">
            <ShieldAlert className="w-8 h-8" />
          </div>
          <div>
            <h2 className="text-xl font-black text-slate-900">
              {profile?.is_banned ? 'Account Restricted' : 'Staff Authorization Required'}
            </h2>
            <p className="text-xs text-slate-500 mt-2 leading-relaxed">
              {profile?.is_banned
                ? `This account has been suspended (${profile.ban_reason || 'Policy violation'}). Portal access is disabled.`
                : `Signed in as ${user.email} (role: ${profile?.role || 'user'}). Only verified Moderators and Super Administrators may access the RedCellNet Operations Portal.`}
            </p>
          </div>
          <div className="flex items-center justify-center gap-3 pt-2">
            <button
              type="button"
              onClick={refreshProfile}
              className="inline-flex items-center gap-1.5 px-4 py-2.5 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              Re-check Role
            </button>
            <button
              type="button"
              onClick={signOut}
              className="inline-flex items-center gap-1.5 px-4 py-2.5 text-xs font-bold text-white bg-red-600 hover:bg-red-700 rounded-xl shadow-xs transition-colors"
            >
              <LogOut className="w-3.5 h-3.5" />
              Sign Out
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Pending counters
  const pendingVerificationsCount = donors.filter((d) => d.verification_status === 'pending').length;
  const criticalRequestsCount = requests.filter(
    (r) =>
      (r.status === 'Open' || r.status === 'Partially Fulfilled') && r.urgency_level === 'Critical'
  ).length;
  const pendingReportsCount = reports.filter((r) => r.status === 'pending').length;

  return (
    <Layout
      currentTab={currentTab}
      onSelectTab={setCurrentTab}
      onRefresh={fetchData}
      isRefreshing={isRefreshing}
      pendingVerificationsCount={pendingVerificationsCount}
      criticalRequestsCount={criticalRequestsCount}
      pendingReportsCount={pendingReportsCount}
    >
      {currentTab === 'dashboard' && (
        <DashboardPage
          donors={donors}
          requests={requests}
          facilities={facilities}
          reports={reports}
          onNavigate={setCurrentTab}
          onRefresh={fetchData}
        />
      )}

      {currentTab === 'donors' && (
        <DonorsPage donors={donors} requests={requests} onRefresh={fetchData} />
      )}

      {currentTab === 'requests' && (
        <RequestsPage requests={requests} reports={reports} onRefresh={fetchData} />
      )}

      {currentTab === 'facilities' && (
        <FacilitiesPage facilities={facilities} onRefresh={fetchData} />
      )}

      {currentTab === 'content' && <ContentPage content={content} onRefresh={fetchData} />}

      {currentTab === 'reports' && (
        <ReportsPage
          reports={reports}
          requests={requests}
          donors={donors}
          onRefresh={fetchData}
        />
      )}

      {currentTab === 'broadcast' && <BroadcastPage donors={donors} onRefresh={fetchData} />}

      {currentTab === 'analytics' && (
        <AnalyticsPage donors={donors} requests={requests} facilities={facilities} />
      )}

      {currentTab === 'audit_logs' && (
        <AuditLogsPage logs={auditLogs} donors={donors} onRefresh={fetchData} />
      )}
    </Layout>
  );
};

export default function App() {
  return (
    <AuthProvider>
      <AdminApp />
    </AuthProvider>
  );
}
