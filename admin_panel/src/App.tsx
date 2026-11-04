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
import type {
  BloodRequest,
  DonationCenter,
  EducationalContent,
  ReportItem,
  UserProfile,
} from './types';
import { Activity } from 'lucide-react';

const AdminApp: React.FC = () => {
  const { user, loading: authLoading } = useAuth();
  const [currentTab, setCurrentTab] = useState<NavigationTab>('dashboard');

  // Database State
  const [donors, setDonors] = useState<UserProfile[]>([]);
  const [requests, setRequests] = useState<BloodRequest[]>([]);
  const [facilities, setFacilities] = useState<DonationCenter[]>([]);
  const [content, setContent] = useState<EducationalContent[]>([]);
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Fetch all core data
  const fetchData = useCallback(async () => {
    setIsRefreshing(true);
    try {
      // 1. Fetch Donors
      const { data: donorsData, error: donorsErr } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });
      if (!donorsErr && donorsData) setDonors(donorsData as UserProfile[]);

      // 2. Fetch Blood Requests
      const { data: requestsData, error: requestsErr } = await supabase
        .from('blood_requests')
        .select('*')
        .order('created_at', { ascending: false });
      if (!requestsErr && requestsData) setRequests(requestsData as BloodRequest[]);

      // 3. Fetch Facilities
      const { data: centersData, error: centersErr } = await supabase
        .from('donation_centers')
        .select('*')
        .order('name', { ascending: true });
      if (!centersErr && centersData) setFacilities(centersData as DonationCenter[]);

      // 4. Fetch Content
      const { data: contentData, error: contentErr } = await supabase
        .from('educational_content')
        .select('*')
        .order('order', { ascending: true });
      if (!contentErr && contentData) setContent(contentData as EducationalContent[]);

      // 5. Fetch Reports
      const { data: reportsData, error: reportsErr } = await supabase
        .from('reports')
        .select('*')
        .order('created_at', { ascending: false });
      if (!reportsErr && reportsData) setReports(reportsData as ReportItem[]);
    } catch (err) {
      console.error('Error loading admin portal data:', err);
    } finally {
      setIsRefreshing(false);
    }
  }, []);

  // Initial load and Realtime setup
  useEffect(() => {
    if (!user) return;

    fetchData();

    // Subscribe to Supabase Realtime changes across tables
    const channel = supabase
      .channel('schema-db-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'blood_requests' },
        () => fetchData()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'profiles' },
        () => fetchData()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'donation_centers' },
        () => fetchData()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'reports' },
        () => fetchData()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user, fetchData]);

  if (authLoading) {
    return (
      <div className="min-h-screen bg-slate-900 flex flex-col items-center justify-center text-white">
        <Activity className="w-10 h-10 text-red-500 animate-spin mb-4" />
        <p className="text-sm font-semibold text-slate-400">Loading RedCellNet Operations...</p>
      </div>
    );
  }

  if (!user) {
    return <LoginPage />;
  }

  // Pending counters
  const pendingVerificationsCount = donors.filter((d) => d.verification_status === 'pending').length;
  const criticalRequestsCount = requests.filter(
    (r) => (r.status === 'Open' || r.status === 'Partially Fulfilled') && r.urgency_level === 'Critical'
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

      {currentTab === 'donors' && <DonorsPage donors={donors} onRefresh={fetchData} />}

      {currentTab === 'requests' && <RequestsPage requests={requests} onRefresh={fetchData} />}

      {currentTab === 'facilities' && (
        <FacilitiesPage facilities={facilities} onRefresh={fetchData} />
      )}

      {currentTab === 'content' && <ContentPage content={content} onRefresh={fetchData} />}

      {currentTab === 'reports' && <ReportsPage reports={reports} onRefresh={fetchData} />}

      {currentTab === 'broadcast' && <BroadcastPage donors={donors} onRefresh={fetchData} />}
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
