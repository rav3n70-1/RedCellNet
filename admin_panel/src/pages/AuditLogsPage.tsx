// admin_panel/src/pages/AuditLogsPage.tsx
import React, { useState, useMemo } from 'react';
import {
  ClipboardList,
  Search,
  Filter,
  Download,
  RefreshCw,
  Clock,
  Shield,
} from 'lucide-react';
import type { AdminLog, UserProfile } from '../types';
import { EmptyState } from '../components/common/EmptyState';

interface AuditLogsPageProps {
  logs: AdminLog[];
  donors: UserProfile[];
  onRefresh: () => void;
}

export const AuditLogsPage: React.FC<AuditLogsPageProps> = ({ logs, donors, onRefresh }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [targetFilter, setTargetFilter] = useState<string>('all');

  const actorLookup = useMemo(() => {
    const map = new Map<string, UserProfile>();
    for (const d of donors) {
      map.set(d.id, d);
    }
    return map;
  }, [donors]);

  const targetTypes = useMemo(() => {
    const set = new Set<string>();
    for (const l of logs) {
      if (l.target_type) set.add(l.target_type);
    }
    return Array.from(set).sort();
  }, [logs]);

  const filteredLogs = logs.filter((log) => {
    const actor = log.admin_user_id ? actorLookup.get(log.admin_user_id) : undefined;
    const q = searchQuery.toLowerCase();
    const matchesSearch =
      (log.action_type || '').toLowerCase().includes(q) ||
      (log.target_type || '').toLowerCase().includes(q) ||
      (log.target_id || '').toLowerCase().includes(q) ||
      (actor?.name || '').toLowerCase().includes(q) ||
      (actor?.email || '').toLowerCase().includes(q) ||
      JSON.stringify(log.details || {}).toLowerCase().includes(q);

    const matchesTarget = targetFilter === 'all' || log.target_type === targetFilter;

    return matchesSearch && matchesTarget;
  });

  const exportToCSV = () => {
    const headers = ['Timestamp', 'Staff Actor', 'Action Type', 'Target Type', 'Target ID', 'Details'];
    const rows = filteredLogs.map((l) => {
      const actor = l.admin_user_id ? actorLookup.get(l.admin_user_id) : undefined;
      const actorLabel = actor ? `${actor.name || ''} <${actor.email}>` : l.admin_user_id || 'System';
      return [
        `"${l.created_at}"`,
        `"${actorLabel.replace(/"/g, '""')}"`,
        `"${l.action_type}"`,
        `"${l.target_type}"`,
        `"${l.target_id || ''}"`,
        `"${JSON.stringify(l.details || {}).replace(/"/g, '""')}"`,
      ];
    });

    const csvContent =
      'data:text/csv;charset=utf-8,' +
      [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute(
      'download',
      `redcellnet_audit_logs_${new Date().toISOString().slice(0, 10)}.csv`
    );
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      {/* Toolbar */}
      <div className="bg-white p-4.5 rounded-2xl border border-slate-200 shadow-xs flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search audit trail by action, staff email, or target ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-hidden focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <div className="flex items-center gap-1.5 bg-slate-50 border border-slate-200 rounded-xl px-3 py-1.5 text-xs">
            <Filter className="w-3.5 h-3.5 text-slate-500" />
            <select
              value={targetFilter}
              onChange={(e) => setTargetFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Target Types</option>
              {targetTypes.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
          </div>

          <button
            onClick={onRefresh}
            className="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            Refresh
          </button>

          <button
            onClick={exportToCSV}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            <Download className="w-3.5 h-3.5" />
            Export CSV
          </button>
        </div>
      </div>

      {/* Audit Logs Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        {filteredLogs.length === 0 ? (
          <EmptyState
            icon={ClipboardList}
            title="No Audit Records Found"
            description={
              searchQuery || targetFilter !== 'all'
                ? 'No governance logs match your current filters.'
                : 'Staff actions (verifications, role updates, broadcasts, moderation) will appear here.'
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-slate-50/80 border-b border-slate-200 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                  <th className="py-3.5 px-5">Timestamp</th>
                  <th className="py-3.5 px-4">Staff Actor</th>
                  <th className="py-3.5 px-4">Action</th>
                  <th className="py-3.5 px-4">Target</th>
                  <th className="py-3.5 px-5">Context / Metadata</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredLogs.map((log) => {
                  const actor = log.admin_user_id ? actorLookup.get(log.admin_user_id) : undefined;
                  return (
                    <tr key={log.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-3.5 px-5 text-slate-500 whitespace-nowrap">
                        <span className="inline-flex items-center gap-1.5">
                          <Clock className="w-3.5 h-3.5 text-slate-400" />
                          {new Date(log.created_at).toLocaleString()}
                        </span>
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="font-bold text-slate-900 flex items-center gap-1.5">
                          <Shield className="w-3.5 h-3.5 text-red-600 shrink-0" />
                          <span>{actor?.name || actor?.email || 'Staff / System'}</span>
                        </div>
                        {actor?.email && (
                          <div className="text-[11px] text-slate-400">{actor.email}</div>
                        )}
                      </td>

                      <td className="py-3.5 px-4">
                        <span className="px-2.5 py-1 rounded-md bg-slate-100 text-slate-800 font-mono font-bold text-[11px] border border-slate-200">
                          {log.action_type}
                        </span>
                      </td>

                      <td className="py-3.5 px-4">
                        <div className="font-semibold text-slate-700 uppercase text-[10px]">
                          {log.target_type}
                        </div>
                        {log.target_id && (
                          <div className="font-mono text-slate-500 text-[11px] truncate max-w-[160px]">
                            {log.target_id}
                          </div>
                        )}
                      </td>

                      <td className="py-3.5 px-5 font-mono text-[11px] text-slate-600 max-w-md truncate">
                        {log.details && Object.keys(log.details).length > 0
                          ? JSON.stringify(log.details)
                          : '—'}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

