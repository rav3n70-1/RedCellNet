// admin_panel/src/components/layout/Header.tsx
import React from 'react';
import { Bell, RefreshCw, Radio } from 'lucide-react';
import type { NavigationTab } from './Sidebar';

interface HeaderProps {
  currentTab: NavigationTab;
  onRefresh?: () => void;
  isRefreshing?: boolean;
  totalAlerts?: number;
}

export const Header: React.FC<HeaderProps> = ({
  currentTab,
  onRefresh,
  isRefreshing = false,
  totalAlerts = 0,
}) => {
  const titles: Record<NavigationTab, { title: string; desc: string }> = {
    dashboard: {
      title: 'Operations Dashboard',
      desc: 'Real-time overview of blood requests, donor availability, and system metrics.',
    },
    donors: {
      title: 'Donor & User Management',
      desc: 'Verify donor credentials, view blood groups, and manage community profiles.',
    },
    requests: {
      title: 'Blood Requests & Emergency Dispatch',
      desc: 'Track urgent transfusions, review donor offers, and update fulfillment states.',
    },
    facilities: {
      title: 'Certified Blood Banks & Centers',
      desc: 'Manage verified hospital collection facilities, opening hours, and coordinates.',
    },
    content: {
      title: 'Health Guides & Articles',
      desc: 'Publish and organize multilingual educational content for the community.',
    },
    reports: {
      title: 'Abuse Reports & Moderation Queue',
      desc: 'Investigate user flags, resolve reported requests, and maintain platform trust.',
    },
    broadcast: {
      title: 'Broadcast System Announcements',
      desc: 'Dispatch emergency blood shortage alerts and push notifications to donors.',
    },
  };

  const current = titles[currentTab];

  return (
    <header className="h-20 bg-white border-b border-slate-200 px-8 flex items-center justify-between shrink-0">
      <div>
        <h2 className="text-xl font-extrabold text-slate-900 tracking-tight">{current.title}</h2>
        <p className="text-xs text-slate-500 font-medium">{current.desc}</p>
      </div>

      <div className="flex items-center gap-4">
        {/* Supabase Realtime Active Status */}
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs font-semibold">
          <Radio className="w-3.5 h-3.5 animate-pulse text-emerald-500" />
          <span>Realtime Live</span>
        </div>

        {/* Refresh Button */}
        {onRefresh && (
          <button
            onClick={onRefresh}
            disabled={isRefreshing}
            title="Refresh Data"
            className="p-2.5 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-xl transition-all"
          >
            <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin text-red-600' : ''}`} />
          </button>
        )}

        {/* Alerts Bell */}
        <div className="relative">
          <div className="p-2.5 text-slate-600 rounded-xl bg-slate-50 border border-slate-200">
            <Bell className="w-4 h-4" />
          </div>
          {totalAlerts > 0 && (
            <span className="absolute -top-1 -right-1 w-5 h-5 bg-rose-600 text-white rounded-full text-[10px] font-bold flex items-center justify-center ring-2 ring-white">
              {totalAlerts > 9 ? '9+' : totalAlerts}
            </span>
          )}
        </div>
      </div>
    </header>
  );
};
