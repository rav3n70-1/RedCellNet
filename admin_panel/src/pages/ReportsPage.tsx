// admin_panel/src/pages/ReportsPage.tsx
import React, { useState } from 'react';
import {
  ShieldAlert,
  Search,
  AlertTriangle,
  Clock,
  Trash2,
  Eye,
  CheckCircle2,
} from 'lucide-react';
import type { BloodRequest, ReportItem, UserProfile } from '../types';
import { BloodGroupBadge, StatusBadge } from '../components/common/Badge';
import { ConfirmDialog } from '../components/common/ConfirmDialog';
import { Modal } from '../components/common/Modal';
import { EmptyState } from '../components/common/EmptyState';
import { supabase } from '../lib/supabase';

interface ReportsPageProps {
  reports: ReportItem[];
  requests?: BloodRequest[];
  donors?: UserProfile[];
  onRefresh: () => void;
}

export const ReportsPage: React.FC<ReportsPageProps> = ({
  reports,
  requests = [],
  donors = [],
  onRefresh,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [inspectingReport, setInspectingReport] = useState<ReportItem | null>(null);
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

  const handleResolveReport = async (reportId: string, action: 'dismiss' | 'action_taken') => {
    const defaultNote =
      action === 'action_taken'
        ? 'Verified violation; corrective moderation action executed.'
        : 'Reviewed by moderation team; no policy violation found.';
    const notes = window.prompt('Enter moderation resolution note:', defaultNote);
    if (notes === null) return;

    setIsProcessing(true);
    try {
      const { error } = await supabase.rpc('resolve_moderation_report', {
        p_report_id: reportId,
        p_action: action,
        p_notes: notes.trim() || defaultNote,
      });
      if (error) throw error;

      if (inspectingReport?.id === reportId) {
        setInspectingReport(null);
      }
      onRefresh();
    } catch (err: unknown) {
      console.error('Error resolving report:', err);
      alert(err instanceof Error ? err.message : 'Failed to resolve moderation report.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDeleteReport = async () => {
    if (!deletingReport) return;
    setIsProcessing(true);
    try {
      const targetId = deletingReport.id;
      const { error } = await supabase.from('reports').delete().eq('id', targetId);
      if (error) throw error;

      await supabase.rpc('record_admin_log', {
        p_action_type: 'delete_moderation_report',
        p_target_type: 'report',
        p_target_id: targetId,
        p_details: { reason: deletingReport.reason },
      });

      setDeletingReport(null);
      onRefresh();
    } catch (err: unknown) {
      console.error('Error deleting report:', err);
      alert(err instanceof Error ? err.message : 'Failed to delete report.');
    } finally {
      setIsProcessing(false);
    }
  };

  const getTargetSummary = (report: ReportItem) => {
    if (report.reported_type === 'request') {
      const req = requests.find((r) => r.id === report.target_id);
      if (req) {
        return `Request: ${req.patient_name} @ ${req.hospital_name} (${req.status})`;
      }
    } else if (report.reported_type === 'profile') {
      const profile = donors.find((d) => d.id === report.target_id);
      if (profile) {
        return `Profile: ${profile.name || profile.email} (${profile.is_banned ? 'Suspended' : 'Active'})`;
      }
    }
    return `Target ID: ${report.target_id}`;
  };

  const inspectedRequest =
    inspectingReport?.reported_type === 'request'
      ? requests.find((r) => r.id === inspectingReport.target_id) || null
      : null;

  const inspectedProfile =
    inspectingReport?.reported_type === 'profile'
      ? donors.find((d) => d.id === inspectingReport.target_id) || null
      : null;

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
          title="No Safety Reports"
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
                      <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-md bg-amber-100 text-amber-800">
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

                  <div className="text-xs text-slate-700 font-semibold">
                    {getTargetSummary(report)}
                  </div>

                  {report.details && (
                    <p className="text-xs text-slate-600 bg-slate-50 p-2.5 rounded-xl border border-slate-100 mt-2 max-w-xl leading-relaxed">
                      "{report.details}"
                    </p>
                  )}

                  {report.resolution_notes && (
                    <div className="text-xs text-emerald-800 bg-emerald-50/70 p-2.5 rounded-xl border border-emerald-200 mt-2 max-w-xl flex items-start gap-1.5">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 shrink-0 mt-0.5" />
                      <span>
                        <strong>Staff Resolution:</strong> {report.resolution_notes}
                      </span>
                    </div>
                  )}

                  {report.created_at && (
                    <div className="text-[11px] text-slate-400 flex items-center gap-1 pt-1">
                      <Clock className="w-3 h-3" />
                      Reported on {new Date(report.created_at).toLocaleString()}
                      {report.resolved_at
                        ? ` • Resolved ${new Date(report.resolved_at).toLocaleString()}`
                        : ''}
                    </div>
                  )}
                </div>
              </div>

              {/* Actions */}
              <div className="flex flex-wrap items-center gap-2 self-end md:self-center shrink-0">
                <button
                  onClick={() => setInspectingReport(report)}
                  className="px-2.5 py-1.5 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors flex items-center gap-1"
                >
                  <Eye className="w-3.5 h-3.5" />
                  Inspect
                </button>

                {report.status === 'pending' && (
                  <>
                    <button
                      onClick={() => handleResolveReport(report.id, 'dismiss')}
                      disabled={isProcessing}
                      className="px-3 py-1.5 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
                    >
                      Dismiss
                    </button>
                    <button
                      onClick={() => handleResolveReport(report.id, 'action_taken')}
                      disabled={isProcessing}
                      className="px-3.5 py-1.5 text-xs font-semibold text-white bg-rose-600 hover:bg-rose-700 rounded-xl shadow-xs transition-colors flex items-center gap-1"
                    >
                      <AlertTriangle className="w-3.5 h-3.5" />
                      Take Action
                    </button>
                  </>
                )}

                <button
                  onClick={() => setDeletingReport(report)}
                  className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                  title="Delete Report"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Inspect Reported Target Modal */}
      {inspectingReport && (
        <Modal
          isOpen={true}
          onClose={() => setInspectingReport(null)}
          title={`Moderation Case: ${inspectingReport.reason}`}
          subtitle={`Reported ${inspectingReport.reported_type.toUpperCase()} • ID: ${inspectingReport.target_id}`}
          maxWidth="lg"
        >
          <div className="space-y-4 text-xs">
            <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 space-y-1.5">
              <div>
                <span className="text-slate-400 font-semibold">Reporter ID: </span>
                <span className="font-mono text-slate-700">{inspectingReport.reporter_user_id}</span>
              </div>
              {inspectingReport.details && (
                <div>
                  <span className="text-slate-400 font-semibold">Reporter Statement: </span>
                  <p className="text-slate-800 mt-1">{inspectingReport.details}</p>
                </div>
              )}
            </div>

            {inspectedRequest && (
              <div className="p-4 bg-white rounded-xl border border-slate-200 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-slate-900 text-sm">
                    {inspectedRequest.patient_name} — {inspectedRequest.hospital_name}
                  </span>
                  <StatusBadge status={inspectedRequest.status} />
                </div>
                <div className="flex items-center gap-2">
                  <BloodGroupBadge bloodType={inspectedRequest.required_blood_type} size="sm" />
                  <span className="text-slate-600">
                    {inspectedRequest.remaining_units}/{inspectedRequest.required_units} units •
                    Phone: {inspectedRequest.contact_phone}
                  </span>
                </div>
                {inspectedRequest.reason && (
                  <p className="text-slate-600 italic">Clinical Note: {inspectedRequest.reason}</p>
                )}
              </div>
            )}

            {inspectedProfile && (
              <div className="p-4 bg-white rounded-xl border border-slate-200 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-slate-900 text-sm">
                    {inspectedProfile.name || 'Unnamed User'} ({inspectedProfile.email})
                  </span>
                  <BloodGroupBadge bloodType={inspectedProfile.blood_type} size="sm" />
                </div>
                <div className="text-slate-600">
                  Role: <strong>{inspectedProfile.role || 'user'}</strong> • Status:{' '}
                  <strong>{inspectedProfile.is_banned ? 'Suspended' : 'Active'}</strong>
                </div>
              </div>
            )}

            {!inspectedRequest && !inspectedProfile && (
              <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 text-slate-500 italic">
                Target record is no longer present or is an external reference ({inspectingReport.target_id}).
              </div>
            )}

            {inspectingReport.status === 'pending' && (
              <div className="pt-3 border-t border-slate-100 flex justify-end gap-2">
                <button
                  onClick={() => handleResolveReport(inspectingReport.id, 'dismiss')}
                  disabled={isProcessing}
                  className="px-4 py-2 font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl"
                >
                  Dismiss Report
                </button>
                <button
                  onClick={() => handleResolveReport(inspectingReport.id, 'action_taken')}
                  disabled={isProcessing}
                  className="px-4 py-2 font-semibold text-white bg-rose-600 hover:bg-rose-700 rounded-xl"
                >
                  Enforce Action (Cancel / Suspend)
                </button>
              </div>
            )}
          </div>
        </Modal>
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
