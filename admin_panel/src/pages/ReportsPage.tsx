// admin_panel/src/pages/ReportsPage.tsx
import React, { useState } from 'react';
import {
  ShieldAlert,
  Search,
  AlertTriangle,
  Clock,
  Trash2,
} from 'lucide-react';
import type { ReportItem } from '../types';
import { ConfirmDialog } from '../components/common/ConfirmDialog';
import { EmptyState } from '../components/common/EmptyState';
import { supabase } from '../lib/supabase';

interface ReportsPageProps {
  reports: ReportItem[];
  onRefresh: () => void;
}

export const ReportsPage: React.FC<ReportsPageProps> = ({ reports, onRefresh }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [deletingReport, setDeletingReport] = useState<ReportItem | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const filteredReports = reports.filter((r) => {
    const query = searchQuery.toLowerCase();
    const matchesSearch =
      (r.reason || '').toLowerCase().includes(query) ||
      (r.details || '').toLowerCase().includes(query) ||
      (r.target_id || '').toLowerCase().includes(query);

    const matchesStatus = statusFilter === 'all' || r.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  const handleResolveReport = async (
    reportId: string,
    action: 'dismiss' | 'action_taken',
    targetId: string,
    reportedType: string
  ) => {
    setIsProcessing(true);
    try {
      if (action === 'action_taken') {
        if (reportedType === 'request') {
          // Cancel the reported request
          await supabase
            .from('blood_requests')
            .update({
              status: 'Cancelled',
              cancellation_reason: 'Closed following community moderation review',
              updated_at: new Date().toISOString(),
            })
            .eq('id', targetId);
        } else if (reportedType === 'profile') {
          // Revoke donor verification
          await supabase
            .from('profiles')
            .update({
              is_verified_donor: false,
              verification_status: 'rejected',
              rejection_reason: 'Flagged for moderation violation',
              updated_at: new Date().toISOString(),
            })
            .eq('id', targetId);
        }
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
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDeleteReport = async () => {
    if (!deletingReport) return;
    setIsProcessing(true);
    try {
      await supabase.from('reports').delete().eq('id', deletingReport.id);
      setDeletingReport(null);
      onRefresh();
    } catch (err) {
      console.error('Error deleting report:', err);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Search & Filter Toolbar */}
      <div className="bg-white p-4.5 rounded-2xl border border-slate-200 shadow-xs flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search reports by reason, target ID, details..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-hidden focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
          />
        </div>

        <div className="flex items-center gap-2.5">
          <div className="bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-xs">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="bg-transparent font-medium text-slate-700 focus:outline-hidden"
            >
              <option value="all">All Moderation States</option>
              <option value="pending">Pending Review</option>
              <option value="dismissed">Dismissed</option>
              <option value="action_taken">Action Taken</option>
            </select>
          </div>
        </div>
      </div>

      {/* Reports List */}
      {filteredReports.length === 0 ? (
        <EmptyState
          icon={ShieldAlert}
          title="No Abuse Reports"
          description={
            statusFilter !== 'all' || searchQuery
              ? 'No reports match your current filter parameters.'
              : 'Zero reports flagged by users. Community integrity is high.'
          }
        />
      ) : (
        <div className="space-y-3.5">
          {filteredReports.map((report) => (
            <div
              key={report.id}
              className={`p-5 rounded-2xl border bg-white shadow-xs transition-all flex flex-col md:flex-row items-start md:items-center justify-between gap-4 ${
                report.status === 'pending'
                  ? 'border-amber-200 ring-1 ring-amber-100'
                  : 'border-slate-200'
              }`}
            >
              <div className="flex items-start gap-4 flex-1">
                <div
                  className={`p-3 rounded-2xl shrink-0 ${
                    report.status === 'pending'
                      ? 'bg-amber-100 text-amber-700'
                      : report.status === 'action_taken'
                      ? 'bg-rose-100 text-rose-700'
                      : 'bg-slate-100 text-slate-600'
                  }`}
                >
                  <ShieldAlert className="w-6 h-6" />
                </div>

                <div className="space-y-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-bold text-sm text-slate-900">{report.reason}</span>
                    <span className="text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-md bg-slate-100 text-slate-600 border border-slate-200">
                      Target: {report.reported_type}
                    </span>
                    {report.status === 'pending' ? (
                      <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md bg-amber-100 text-amber-800 animate-pulse">
                        Pending
                      </span>
                    ) : report.status === 'action_taken' ? (
                      <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md bg-rose-100 text-rose-800">
                        Action Taken
                      </span>
                    ) : (
                      <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md bg-slate-100 text-slate-600">
                        Dismissed
                      </span>
                    )}
                  </div>

                  <div className="text-xs text-slate-500 font-mono">
                    Target ID: <span className="text-slate-800 font-semibold">{report.target_id}</span>
                  </div>

                  {report.details && (
                    <p className="text-xs text-slate-600 bg-slate-50 p-2.5 rounded-xl border border-slate-100 mt-2 max-w-xl leading-relaxed">
                      "{report.details}"
                    </p>
                  )}

                  {report.created_at && (
                    <div className="text-[11px] text-slate-400 flex items-center gap-1 pt-1">
                      <Clock className="w-3 h-3" />
                      Reported on {new Date(report.created_at).toLocaleString()}
                    </div>
                  )}
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center gap-2 self-end md:self-center shrink-0">
                {report.status === 'pending' ? (
                  <>
                    <button
                      onClick={() =>
                        handleResolveReport(report.id, 'dismiss', report.target_id, report.reported_type)
                      }
                      disabled={isProcessing}
                      className="px-3 py-1.5 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
                    >
                      Dismiss Flag
                    </button>
                    <button
                      onClick={() =>
                        handleResolveReport(
                          report.id,
                          'action_taken',
                          report.target_id,
                          report.reported_type
                        )
                      }
                      disabled={isProcessing}
                      className="px-3.5 py-1.5 text-xs font-semibold text-white bg-rose-600 hover:bg-rose-700 rounded-xl shadow-xs transition-colors flex items-center gap-1"
                    >
                      <AlertTriangle className="w-3.5 h-3.5" />
                      Take Action
                    </button>
                  </>
                ) : (
                  <span className="text-xs font-semibold text-slate-400 italic">Resolved</span>
                )}

                <button
                  onClick={() => setDeletingReport(report)}
                  className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors ml-2"
                  title="Delete Report"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Delete Confirmation */}
      <ConfirmDialog
        isOpen={!!deletingReport}
        onClose={() => setDeletingReport(null)}
        onConfirm={handleDeleteReport}
        title="Delete Report Entry?"
        message="Are you sure you want to permanently delete this report record from the moderation archives?"
        confirmText="Delete Record"
        isLoading={isProcessing}
      />
    </div>
  );
};
