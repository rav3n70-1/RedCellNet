// admin_panel/src/pages/BroadcastPage.tsx
import React, { useState, useEffect } from 'react';
import {
  Send,
  Users,
  AlertTriangle,
  Smartphone,
  CheckCircle2,
  Sparkles,
  Radio,
  Clock,
  RefreshCw,
  Trash2,
  Pencil,
  X,
  Hourglass,
  Calendar,
  SlidersHorizontal,
} from 'lucide-react';
import type { BloodGroup, UserProfile, SystemBroadcast } from '../types';
import { supabase } from '../lib/supabase';

interface BroadcastPageProps {
  donors: UserProfile[];
  onRefresh: () => void;
}

const BLOOD_GROUPS: BloodGroup[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

const DURATION_PRESETS = [
  { id: '1h', label: '1 Hour', durationMs: 1 * 60 * 60 * 1000 },
  { id: '6h', label: '6 Hours', durationMs: 6 * 60 * 60 * 1000 },
  { id: '12h', label: '12 Hours', durationMs: 12 * 60 * 60 * 1000 },
  { id: '24h', label: '24 Hours (1 Day)', durationMs: 24 * 60 * 60 * 1000 },
  { id: '3d', label: '3 Days', durationMs: 3 * 24 * 60 * 60 * 1000 },
  { id: '7d', label: '7 Days', durationMs: 7 * 24 * 60 * 60 * 1000 },
  { id: 'indefinite', label: 'Permanent / Indefinite', durationMs: 0 },
  { id: 'custom', label: 'Custom Date & Time', durationMs: 0 },
];

export const BroadcastPage: React.FC<BroadcastPageProps> = ({ donors, onRefresh }) => {
  const [targetAudience, setTargetAudience] = useState<'all' | 'blood_group' | 'single_user'>('all');
  const [selectedBloodGroup, setSelectedBloodGroup] = useState<BloodGroup>('O-');
  const [targetCity, setTargetCity] = useState('');
  const [specificUserId, setSpecificUserId] = useState('');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [notificationType, setNotificationType] = useState('emergency');
  const [durationPreset, setDurationPreset] = useState<string>('24h');
  const [customExpiry, setCustomExpiry] = useState<string>('');
  const [isSending, setIsSending] = useState(false);
  const [sentSuccessCount, setSentSuccessCount] = useState<number | null>(null);
  const [broadcasts, setBroadcasts] = useState<SystemBroadcast[]>([]);
  const [loadingBroadcasts, setLoadingBroadcasts] = useState(false);

  // Edit Broadcast Modal state
  const [editingBroadcast, setEditingBroadcast] = useState<SystemBroadcast | null>(null);
  const [editTitle, setEditTitle] = useState('');
  const [editBody, setEditBody] = useState('');
  const [editType, setEditType] = useState('emergency');
  const [editTargetAudience, setEditTargetAudience] = useState<'all' | 'blood_group'>('all');
  const [editSelectedBloodGroup, setEditSelectedBloodGroup] = useState<BloodGroup>('O-');
  const [editTargetCity, setEditTargetCity] = useState('');
  const [editIsActive, setEditIsActive] = useState(true);
  const [editDurationPreset, setEditDurationPreset] = useState<string>('keep');
  const [editCustomExpiry, setEditCustomExpiry] = useState<string>('');
  const [isSavingEdit, setIsSavingEdit] = useState(false);

  const computeExpiresAt = (preset: string, customVal: string): string | null => {
    const now = new Date();
    switch (preset) {
      case '1h':
        return new Date(now.getTime() + 1 * 60 * 60 * 1000).toISOString();
      case '6h':
        return new Date(now.getTime() + 6 * 60 * 60 * 1000).toISOString();
      case '12h':
        return new Date(now.getTime() + 12 * 60 * 60 * 1000).toISOString();
      case '24h':
        return new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString();
      case '3d':
        return new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000).toISOString();
      case '7d':
        return new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString();
      case 'custom':
        return customVal ? new Date(customVal).toISOString() : null;
      case 'indefinite':
      default:
        return null;
    }
  };

  const formatExpiryRemaining = (expiresAt?: string | null, isActive?: boolean) => {
    if (isActive === false) {
      return {
        text: 'Deactivated',
        status: 'inactive',
        className: 'bg-slate-100 text-slate-500 border border-slate-200',
      };
    }
    if (!expiresAt) {
      return {
        text: 'Permanent (No Expiry)',
        status: 'indefinite',
        className: 'bg-slate-100 text-slate-600 border border-slate-200',
      };
    }
    const diffMs = new Date(expiresAt).getTime() - Date.now();
    if (diffMs <= 0) {
      return {
        text: 'Expired',
        status: 'expired',
        className: 'bg-rose-50 text-rose-700 border border-rose-200 font-bold',
      };
    }
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
    if (diffHours >= 24) {
      const days = Math.floor(diffHours / 24);
      return {
        text: `Ends in ${days}d ${diffHours % 24}h`,
        status: 'active',
        className: 'bg-emerald-50 text-emerald-800 border border-emerald-200 font-semibold',
      };
    }
    return {
      text: `Ends in ${diffHours}h ${diffMins}m`,
      status: 'active',
      className: 'bg-amber-50 text-amber-800 border border-amber-200 font-semibold',
    };
  };

  // Fetch recent broadcasts
  const fetchBroadcasts = async () => {
    setLoadingBroadcasts(true);
    try {
      const { data, error } = await supabase
        .from('system_broadcasts')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(30);

      if (error) throw error;
      setBroadcasts((data as SystemBroadcast[]) || []);
    } catch (err) {
      console.warn('Could not fetch past system broadcasts:', err);
    } finally {
      setLoadingBroadcasts(false);
    }
  };

  const handleToggleActiveBroadcast = async (broadcast: SystemBroadcast) => {
    try {
      const { error } = await supabase.rpc('update_system_broadcast', {
        p_id: broadcast.id,
        p_title: broadcast.title,
        p_message: broadcast.message,
        p_broadcast_type: broadcast.broadcast_type || 'emergency',
        p_target_blood_type: broadcast.target_blood_type || null,
        p_target_city: broadcast.target_city || null,
        p_is_active: !broadcast.is_active,
        p_expires_at: broadcast.expires_at || null,
      });
      if (error) throw error;
      fetchBroadcasts();
      onRefresh();
    } catch (err) {
      console.error('Error toggling broadcast:', err);
    }
  };

  const handleDeleteBroadcast = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this broadcast?')) return;
    try {
      const { error } = await supabase
        .from('system_broadcasts')
        .delete()
        .eq('id', id);
      if (error) throw error;
      await supabase.rpc('record_admin_log', {
        p_action_type: 'delete_system_broadcast',
        p_target_type: 'broadcast',
        p_target_id: id,
        p_details: {},
      });
      fetchBroadcasts();
      onRefresh();
    } catch (err) {
      console.error('Error deleting broadcast:', err);
    }
  };

  const openEditModal = (b: SystemBroadcast) => {
    setEditingBroadcast(b);
    setEditTitle(b.title || '');
    setEditBody(b.message || '');
    setEditType(b.broadcast_type || 'emergency');
    setEditTargetAudience(b.target_blood_type ? 'blood_group' : 'all');
    setEditSelectedBloodGroup((b.target_blood_type as BloodGroup) || 'O-');
    setEditTargetCity(b.target_city || '');
    setEditIsActive(b.is_active);
    setEditDurationPreset('keep');
    setEditCustomExpiry('');
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingBroadcast) return;
    if (!editTitle.trim() || !editBody.trim()) {
      alert('Title and Message Body are required.');
      return;
    }

    setIsSavingEdit(true);
    try {
      let finalExpiresAt: string | null = editingBroadcast.expires_at || null;
      if (editDurationPreset !== 'keep') {
        finalExpiresAt = computeExpiresAt(editDurationPreset, editCustomExpiry);
      }

      const { error } = await supabase.rpc('update_system_broadcast', {
        p_id: editingBroadcast.id,
        p_title: editTitle.trim(),
        p_message: editBody.trim(),
        p_broadcast_type: editType,
        p_target_blood_type: editTargetAudience === 'blood_group' ? editSelectedBloodGroup : null,
        p_target_city: editTargetCity.trim() || null,
        p_is_active: editIsActive,
        p_expires_at: finalExpiresAt,
      });

      if (error) throw error;
      setEditingBroadcast(null);
      fetchBroadcasts();
      onRefresh();
    } catch (err: unknown) {
      console.error('Error saving broadcast:', err);
      alert(`Failed to update broadcast: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsSavingEdit(false);
    }
  };

  useEffect(() => {
    fetchBroadcasts();
  }, []);

  // Quick Preset Templates
  const templates = [
    {
      label: '🚨 Critical O- Blood Shortage',
      title: 'URGENT: Critical O- Shortage in Dhaka',
      body: 'Dhaka Medical College & NICVD urgently require 4 units of O- Negative blood for emergency surgeries. Please respond if you are nearby!',
      type: 'emergency',
      audience: 'blood_group' as const,
      group: 'O-' as BloodGroup,
      preset: '6h',
    },
    {
      label: '🩸 Monsoon Blood Drive Notice',
      title: 'Monsoon Voluntary Blood Donation Drive',
      body: 'Certified donation centers across Bangladesh are open today. Every donation saves up to 3 lives. Find your nearest verified blood bank on the map.',
      type: 'general',
      audience: 'all' as const,
      group: 'A+' as BloodGroup,
      preset: '3d',
    },
    {
      label: '⭐ Verification Badge Reminder',
      title: 'Verify Your Donor Profile Today',
      body: 'Upload your laboratory blood grouping certificate to earn the official RedCellNet Verified Donor Shield Badge and help patients faster.',
      type: 'verification',
      audience: 'all' as const,
      group: 'B+' as BloodGroup,
      preset: '7d',
    },
  ];

  const applyTemplate = (t: typeof templates[0]) => {
    setTitle(t.title);
    setBody(t.body);
    setNotificationType(t.type);
    setTargetAudience(t.audience);
    if (t.group) setSelectedBloodGroup(t.group);
    if (t.preset) setDurationPreset(t.preset);
  };

  // Compute recipient target count
  let targetCount = donors.length;
  if (targetAudience === 'blood_group') {
    targetCount = donors.filter((d) => d.blood_type === selectedBloodGroup).length;
  } else if (targetAudience === 'single_user') {
    targetCount = specificUserId.trim() ? 1 : 0;
  }

  const handleSendBroadcast = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !body.trim()) {
      alert('Please fill out both notification title and message.');
      return;
    }

    if (targetAudience === 'single_user' && !specificUserId.trim()) {
      alert('Please select or enter a target User ID for direct notification.');
      return;
    }

    setIsSending(true);
    setSentSuccessCount(null);

    try {
      if (targetAudience === 'single_user') {
        const { error } = await supabase.rpc('send_direct_admin_notification', {
          p_target_user_id: specificUserId.trim(),
          p_title: title.trim(),
          p_message: body.trim(),
          p_type: notificationType,
        });
        if (error) throw error;

        setSentSuccessCount(1);
        setTitle('');
        setBody('');
        onRefresh();
      } else {
        const expiresAt = computeExpiresAt(durationPreset, customExpiry);

        const { error } = await supabase.rpc('create_emergency_broadcast', {
          broadcast_title: title.trim(),
          broadcast_message: body.trim(),
          b_type: notificationType,
          target_blood: targetAudience === 'blood_group' ? selectedBloodGroup : null,
          target_city: targetCity.trim() || null,
          broadcast_expires_at: expiresAt,
        });
        if (error) throw error;

        setSentSuccessCount(targetCount || 1);
        setTitle('');
        setBody('');
        setTargetCity('');
        onRefresh();
        fetchBroadcasts();
      }
    } catch (err: unknown) {
      console.error('Error sending broadcast notification:', err);
      alert(`Error sending notification: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsSending(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Banner */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-xs">
        <h3 className="text-base font-bold text-slate-900 mb-1">
          Broadcast Announcements & Push Alerts
        </h3>
        <p className="text-xs text-slate-500">
          Create, edit, schedule display durations, and target urgent shortage notices or platform announcements across mobile devices.
        </p>

        {/* Quick Templates */}
        <div className="mt-4 pt-4 border-t border-slate-100 flex flex-wrap items-center gap-2">
          <span className="text-xs font-semibold text-slate-400 flex items-center gap-1 mr-2">
            <Sparkles className="w-3.5 h-3.5 text-amber-500" /> Quick Templates:
          </span>
          {templates.map((tpl, i) => (
            <button
              key={i}
              type="button"
              onClick={() => applyTemplate(tpl)}
              className="px-3 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold rounded-lg transition-colors"
            >
              {tpl.label}
            </button>
          ))}
        </div>
      </div>

      {sentSuccessCount !== null && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          Broadcast alert successfully dispatched and published to mobile devices!
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Composer Form (Left 7 cols) */}
        <div className="lg:col-span-7 bg-white p-6 rounded-2xl border border-slate-200 shadow-xs">
          <form onSubmit={handleSendBroadcast} className="space-y-5">
            {/* Target Audience selection */}
            <div>
              <label className="text-xs font-bold uppercase tracking-wider text-slate-500 block mb-2">
                1. Select Target Recipients & Scope
              </label>

              <div className="grid grid-cols-3 gap-3">
                <button
                  type="button"
                  onClick={() => setTargetAudience('all')}
                  className={`p-3 rounded-xl border text-left transition-all ${
                    targetAudience === 'all'
                      ? 'border-red-600 bg-red-50/50 text-red-900 ring-2 ring-red-500/20'
                      : 'border-slate-200 text-slate-600 hover:border-slate-300'
                  }`}
                >
                  <Users className="w-4 h-4 mb-1.5 text-red-600" />
                  <div className="text-xs font-bold">All Users</div>
                  <div className="text-[10px] text-slate-400 mt-0.5">{donors.length} registered</div>
                </button>

                <button
                  type="button"
                  onClick={() => setTargetAudience('blood_group')}
                  className={`p-3 rounded-xl border text-left transition-all ${
                    targetAudience === 'blood_group'
                      ? 'border-red-600 bg-red-50/50 text-red-900 ring-2 ring-red-500/20'
                      : 'border-slate-200 text-slate-600 hover:border-slate-300'
                  }`}
                >
                  <AlertTriangle className="w-4 h-4 mb-1.5 text-amber-600" />
                  <div className="text-xs font-bold">By Blood Group</div>
                  <div className="text-[10px] text-slate-400 mt-0.5">Targeted Shortage</div>
                </button>

                <button
                  type="button"
                  onClick={() => setTargetAudience('single_user')}
                  className={`p-3 rounded-xl border text-left transition-all ${
                    targetAudience === 'single_user'
                      ? 'border-red-600 bg-red-50/50 text-red-900 ring-2 ring-red-500/20'
                      : 'border-slate-200 text-slate-600 hover:border-slate-300'
                  }`}
                >
                  <Send className="w-4 h-4 mb-1.5 text-blue-600" />
                  <div className="text-xs font-bold">Single User</div>
                  <div className="text-[10px] text-slate-400 mt-0.5">Direct Message</div>
                </button>
              </div>

              {/* Conditional parameters */}
              {targetAudience === 'blood_group' && (
                <div className="mt-3.5 p-3.5 bg-slate-50 rounded-xl border border-slate-200 flex items-center gap-3">
                  <span className="text-xs font-semibold text-slate-600 shrink-0">Select Blood Group:</span>
                  <div className="flex flex-wrap gap-1.5">
                    {BLOOD_GROUPS.map((bg) => (
                      <button
                        key={bg}
                        type="button"
                        onClick={() => setSelectedBloodGroup(bg)}
                        className={`px-2.5 py-1 text-xs font-extrabold rounded-lg transition-all ${
                          selectedBloodGroup === bg
                            ? 'bg-red-600 text-white shadow-xs'
                            : 'bg-white text-slate-700 border border-slate-200 hover:bg-slate-100'
                        }`}
                      >
                        {bg}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {targetAudience === 'single_user' && (
                <div className="mt-3.5 space-y-2">
                  <label className="text-xs font-semibold text-slate-700 block">
                    Select Recipient or Enter Profile UUID:
                  </label>
                  <select
                    value={specificUserId}
                    onChange={(e) => setSpecificUserId(e.target.value)}
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                  >
                    <option value="">-- Choose a registered user ({donors.length}) --</option>
                    {donors.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name || 'Unnamed'} ({d.email}) {d.blood_type ? `[${d.blood_type}]` : ''}
                      </option>
                    ))}
                  </select>
                  <input
                    type="text"
                    required
                    placeholder="Or paste target User UUID..."
                    value={specificUserId}
                    onChange={(e) => setSpecificUserId(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl font-mono focus:ring-2 focus:ring-red-500/20"
                  />
                </div>
              )}

              <div className="mt-3.5">
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Target City / Region (Optional)
                </label>
                <input
                  type="text"
                  placeholder="e.g. Dhaka, Chittagong, Sylhet (Leave blank for nationwide)"
                  value={targetCity}
                  onChange={(e) => setTargetCity(e.target.value)}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                />
              </div>
            </div>

            {/* Notification content */}
            <div>
              <label className="text-xs font-bold uppercase tracking-wider text-slate-500 block mb-2">
                2. Notification Content & Type
              </label>

              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-semibold text-slate-700 block mb-1">
                      Notification Type
                    </label>
                    <select
                      value={notificationType}
                      onChange={(e) => setNotificationType(e.target.value)}
                      className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                    >
                      <option value="emergency">🚨 Emergency Alert</option>
                      <option value="shortage">🩸 Blood Group Shortage</option>
                      <option value="general">📢 General Announcement</option>
                      <option value="verification">⭐ Donor Verification Drive</option>
                    </select>
                  </div>
                  <div>
                    <label className="text-xs font-semibold text-slate-700 block mb-1">
                      Target Label Preview
                    </label>
                    <div className="px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-700 truncate">
                      {targetAudience === 'blood_group'
                        ? `Blood Group: ${selectedBloodGroup}`
                        : targetAudience === 'all'
                        ? 'All Registered Donors'
                        : `User: ${specificUserId || 'Unspecified'}`}
                    </div>
                  </div>
                </div>

                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Notification Title *
                  </label>
                  <input
                    type="text"
                    required
                    maxLength={100}
                    placeholder="e.g. Critical Blood Shortage in Mirpur Area"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20 font-medium"
                  />
                </div>

                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Message Body *
                  </label>
                  <textarea
                    rows={4}
                    required
                    maxLength={300}
                    placeholder="Write your announcement or instructions for donors..."
                    value={body}
                    onChange={(e) => setBody(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20 leading-relaxed font-sans"
                  />
                  <div className="text-[11px] text-slate-400 text-right mt-1">
                    {body.length} / 300 characters
                  </div>
                </div>
              </div>
            </div>

            {/* Visible Duration & Expiration */}
            <div>
              <label className="text-xs font-bold uppercase tracking-wider text-slate-500 block mb-2 flex items-center gap-1.5">
                <Clock className="w-3.5 h-3.5 text-red-600" />
                3. Display Duration (How long it will show on Mobile)
              </label>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                {DURATION_PRESETS.map((dp) => (
                  <button
                    key={dp.id}
                    type="button"
                    onClick={() => setDurationPreset(dp.id)}
                    className={`px-3 py-2 rounded-xl text-xs font-semibold text-center border transition-all ${
                      durationPreset === dp.id
                        ? 'border-red-600 bg-red-50 text-red-800 ring-2 ring-red-500/20'
                        : 'border-slate-200 text-slate-600 hover:border-slate-300 bg-slate-50'
                    }`}
                  >
                    {dp.label}
                  </button>
                ))}
              </div>

              {durationPreset === 'custom' && (
                <div className="mt-3 p-3 bg-amber-50 rounded-xl border border-amber-200 flex items-center gap-3">
                  <Calendar className="w-4 h-4 text-amber-700 shrink-0" />
                  <div className="flex-1">
                    <label className="text-xs font-semibold text-amber-900 block mb-1">
                      Set Custom Expiration Date & Time:
                    </label>
                    <input
                      type="datetime-local"
                      required
                      value={customExpiry}
                      onChange={(e) => setCustomExpiry(e.target.value)}
                      className="w-full px-3 py-1.5 text-xs bg-white border border-amber-300 rounded-lg text-slate-800"
                    />
                  </div>
                </div>
              )}
            </div>

            {/* Submit */}
            <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
              <span className="text-xs text-slate-500">
                Estimated Recipients: <strong className="text-slate-900">{targetCount} device(s)</strong>
              </span>

              <button
                type="submit"
                disabled={isSending || !title.trim() || !body.trim()}
                className="inline-flex items-center gap-2 px-5 py-2.5 bg-red-600 hover:bg-red-700 disabled:bg-slate-300 text-white font-bold text-xs rounded-xl shadow-md transition-colors"
              >
                <Send className="w-4 h-4" />
                {isSending ? 'Sending Broadcast...' : 'Dispatch Notification'}
              </button>
            </div>
          </form>
        </div>

        {/* Mobile Device Live Preview (Right 5 cols) */}
        <div className="lg:col-span-5 flex flex-col items-center justify-center p-6 bg-slate-100 rounded-2xl border border-slate-200">
          <div className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-1.5">
            <Smartphone className="w-4 h-4" /> Device In-App & Lock Screen Preview
          </div>

          {/* Smartphone Mockup */}
          <div className="w-72 bg-slate-900 rounded-[36px] p-3 shadow-2xl border-4 border-slate-800">
            {/* Phone Speaker & Notch */}
            <div className="w-24 h-4 bg-slate-800 rounded-full mx-auto mb-3" />

            {/* Screen Display */}
            <div className="bg-slate-950 rounded-[28px] p-4 min-h-[380px] flex flex-col justify-start">
              {/* Clock */}
              <div className="text-center my-2">
                <div className="text-2xl font-extralight text-white tracking-wider">
                  {new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </div>
                <div className="text-[10px] text-slate-400">
                  {new Date().toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}
                </div>
              </div>

              {/* Push Notification Card */}
              <div className="bg-slate-900/95 border border-slate-800 rounded-2xl p-3 shadow-lg backdrop-blur-md mt-2">
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-1.5">
                    <div className="w-4 h-4 rounded-full bg-red-600 flex items-center justify-center text-[8px] font-black text-white">
                      R
                    </div>
                    <span className="text-[10px] font-bold text-slate-300">RedCellNet Push</span>
                  </div>
                  <span className="text-[9px] text-slate-500">now</span>
                </div>

                <div className="text-xs font-bold text-white leading-tight">
                  {title || 'Broadcast Title Appears Here'}
                </div>
                <div className="text-[11px] text-slate-300 mt-1 leading-snug line-clamp-3">
                  {body || 'Your message will appear in real-time on donor smartphones like this.'}
                </div>
              </div>

              {/* In-App In-Banner Preview with Dismiss button */}
              <div className="mt-4 p-3 rounded-xl bg-gradient-to-br from-rose-950 to-red-950 border border-rose-500/40 shadow-sm relative">
                <div className="flex items-start justify-between gap-1">
                  <div className="flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-rose-500 animate-ping" />
                    <span className="text-[10px] font-extrabold uppercase text-rose-300">In-App Banner</span>
                  </div>
                  <span className="text-[9px] text-rose-200/80 px-1.5 py-0.5 rounded bg-black/30 border border-rose-500/30">
                    ✕ Dismissible
                  </span>
                </div>
                <div className="text-[11px] font-bold text-white mt-1 leading-tight">
                  {title || 'Urgent Blood Notice'}
                </div>
                <div className="text-[9.5px] text-rose-100/90 mt-0.5 line-clamp-2">
                  {body || 'Banner notice displayed at top of donor home page.'}
                </div>
                <div className="mt-2 flex items-center justify-between text-[9px] text-rose-300 font-medium pt-1 border-t border-rose-800/60">
                  <span className="flex items-center gap-1">
                    <Clock className="w-2.5 h-2.5" />
                    {durationPreset === 'indefinite' ? 'Always on' : `Showing: ${durationPreset}`}
                  </span>
                  <span>Can be closed by user</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Broadcast History Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-4 border-b border-slate-100 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Radio className="w-4 h-4 text-red-600 animate-pulse" />
            <h4 className="text-sm font-bold text-slate-900">Broadcast Audit & History Log</h4>
            <span className="text-xs font-semibold px-2 py-0.5 bg-slate-100 text-slate-600 rounded-full">
              {broadcasts.length}
            </span>
          </div>
          <button
            type="button"
            onClick={fetchBroadcasts}
            className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition-colors"
            title="Refresh broadcast history"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loadingBroadcasts ? 'animate-spin' : ''}`} />
          </button>
        </div>

        {broadcasts.length === 0 ? (
          <div className="p-8 text-center text-xs text-slate-400">
            No system broadcasts dispatched yet.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50/70 border-b border-slate-100 text-slate-400 font-semibold uppercase tracking-wider text-[10px]">
                <tr>
                  <th className="py-2.5 px-4">Title & Message</th>
                  <th className="py-2.5 px-4">Type</th>
                  <th className="py-2.5 px-4">Target Group / City</th>
                  <th className="py-2.5 px-4">Display Duration</th>
                  <th className="py-2.5 px-4">Status</th>
                  <th className="py-2.5 px-4">Dispatched At</th>
                  <th className="py-2.5 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {broadcasts.map((b) => {
                  const expiryInfo = formatExpiryRemaining(b.expires_at, b.is_active);
                  const isPastExpiry = b.expires_at ? new Date(b.expires_at).getTime() < Date.now() : false;

                  return (
                    <tr key={b.id} className="hover:bg-slate-50/50 transition-colors">
                      <td className="py-3 px-4 max-w-xs">
                        <div className="font-bold text-slate-900 text-xs">{b.title}</div>
                        <div className="text-slate-500 text-[11px] mt-0.5 line-clamp-1">{b.message}</div>
                      </td>
                      <td className="py-3 px-4">
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase bg-amber-50 text-amber-700 border border-amber-200">
                          {b.broadcast_type || 'emergency'}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <div className="flex flex-col gap-1 items-start">
                          {b.target_blood_type ? (
                            <span className="px-2 py-0.5 rounded-md text-[10px] font-black bg-red-100 text-red-800">
                              {b.target_blood_type}
                            </span>
                          ) : (
                            <span className="text-slate-500 text-[10px] font-medium">All Donors</span>
                          )}
                          {b.target_city && (
                            <span className="text-[10px] text-slate-400">📍 {b.target_city}</span>
                          )}
                        </div>
                      </td>
                      <td className="py-3 px-4">
                        <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] ${expiryInfo.className}`}>
                          <Hourglass className="w-3 h-3" />
                          {expiryInfo.text}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <button
                          onClick={() => handleToggleActiveBroadcast(b)}
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold transition-colors ${
                            b.is_active && !isPastExpiry
                              ? 'bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100'
                              : 'bg-slate-100 text-slate-500 border border-slate-200 hover:bg-slate-200'
                          }`}
                          title={b.is_active ? 'Click to deactivate broadcast' : 'Click to reactivate broadcast'}
                        >
                          {b.is_active && !isPastExpiry ? (
                            <>
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping mr-0.5" />
                              Active Banner
                            </>
                          ) : isPastExpiry ? (
                            'Expired'
                          ) : (
                            'Inactive'
                          )}
                        </button>
                      </td>
                      <td className="py-3 px-4 text-slate-500 text-[11px] whitespace-nowrap">
                        <div className="flex items-center gap-1">
                          <Clock className="w-3 h-3 text-slate-400" />
                          {b.created_at ? new Date(b.created_at).toLocaleString() : 'Just now'}
                        </div>
                      </td>
                      <td className="py-3 px-4 text-right">
                        <div className="inline-flex items-center gap-1">
                          <button
                            onClick={() => openEditModal(b)}
                            className="p-1.5 text-slate-500 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                            title="Edit Broadcast & Visible Time"
                          >
                            <Pencil className="w-3.5 h-3.5" />
                          </button>
                          <button
                            onClick={() => handleDeleteBroadcast(b.id)}
                            className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                            title="Delete Broadcast"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Edit Broadcast Modal */}
      {editingBroadcast && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs animate-in fade-in">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl border border-slate-200 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 mb-4">
              <div className="flex items-center gap-2">
                <SlidersHorizontal className="w-4 h-4 text-red-600" />
                <h4 className="text-sm font-bold text-slate-900">Edit Broadcast Announcement</h4>
              </div>
              <button
                type="button"
                onClick={() => setEditingBroadcast(null)}
                className="p-1 text-slate-400 hover:text-slate-700 rounded-lg"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveEdit} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Notification Title *
                </label>
                <input
                  type="text"
                  required
                  maxLength={100}
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20 font-medium"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Message Body *
                </label>
                <textarea
                  rows={3}
                  required
                  maxLength={300}
                  value={editBody}
                  onChange={(e) => setEditBody(e.target.value)}
                  className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20 leading-relaxed font-sans"
                />
                <div className="text-[11px] text-slate-400 text-right mt-1">
                  {editBody.length} / 300 characters
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Broadcast Type
                  </label>
                  <select
                    value={editType}
                    onChange={(e) => setEditType(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                  >
                    <option value="emergency">🚨 Emergency Alert</option>
                    <option value="shortage">🩸 Blood Group Shortage</option>
                    <option value="general">📢 General Announcement</option>
                    <option value="verification">⭐ Donor Verification Drive</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Target City / Region
                  </label>
                  <input
                    type="text"
                    placeholder="All Cities"
                    value={editTargetCity}
                    onChange={(e) => setEditTargetCity(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500/20"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1.5">
                  Target Blood Group
                </label>
                <div className="flex flex-wrap gap-1.5">
                  <button
                    type="button"
                    onClick={() => setEditTargetAudience('all')}
                    className={`px-3 py-1 text-xs font-bold rounded-lg border transition-all ${
                      editTargetAudience === 'all'
                        ? 'bg-red-600 text-white border-red-600'
                        : 'bg-slate-50 text-slate-600 border-slate-200'
                    }`}
                  >
                    All Donors
                  </button>
                  {BLOOD_GROUPS.map((bg) => (
                    <button
                      key={bg}
                      type="button"
                      onClick={() => {
                        setEditTargetAudience('blood_group');
                        setEditSelectedBloodGroup(bg);
                      }}
                      className={`px-2.5 py-1 text-xs font-extrabold rounded-lg border transition-all ${
                        editTargetAudience === 'blood_group' && editSelectedBloodGroup === bg
                          ? 'bg-red-600 text-white border-red-600'
                          : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'
                      }`}
                    >
                      {bg}
                    </button>
                  ))}
                </div>
              </div>

              {/* Time how much time it will show (Display Duration & Expiry) */}
              <div className="pt-2 border-t border-slate-100">
                <label className="text-xs font-bold text-slate-800 block mb-1 flex items-center gap-1.5">
                  <Clock className="w-3.5 h-3.5 text-red-600" />
                  Display Duration / Visible Time Limit
                </label>
                <p className="text-[11px] text-slate-400 mb-2">
                  Current Status:{' '}
                  <strong className="text-slate-700">
                    {formatExpiryRemaining(editingBroadcast.expires_at, editingBroadcast.is_active).text}
                  </strong>
                </p>

                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => setEditDurationPreset('keep')}
                    className={`px-2.5 py-1.5 rounded-lg text-xs font-medium border text-center transition-all ${
                      editDurationPreset === 'keep'
                        ? 'border-red-600 bg-red-50 text-red-800 font-bold'
                        : 'border-slate-200 text-slate-600 bg-slate-50'
                    }`}
                  >
                    Keep Existing Expiry
                  </button>
                  <button
                    type="button"
                    onClick={() => setEditDurationPreset('1h')}
                    className={`px-2.5 py-1.5 rounded-lg text-xs font-medium border text-center transition-all ${
                      editDurationPreset === '1h'
                        ? 'border-red-600 bg-red-50 text-red-800 font-bold'
                        : 'border-slate-200 text-slate-600 bg-slate-50'
                    }`}
                  >
                    +1 Hour
                  </button>
                  <button
                    type="button"
                    onClick={() => setEditDurationPreset('6h')}
                    className={`px-2.5 py-1.5 rounded-lg text-xs font-medium border text-center transition-all ${
                      editDurationPreset === '6h'
                        ? 'border-red-600 bg-red-50 text-red-800 font-bold'
                        : 'border-slate-200 text-slate-600 bg-slate-50'
                    }`}
                  >
                    +6 Hours
                  </button>
                  <button
                    type="button"
                    onClick={() => setEditDurationPreset('24h')}
                    className={`px-2.5 py-1.5 rounded-lg text-xs font-medium border text-center transition-all ${
                      editDurationPreset === '24h'
                        ? 'border-red-600 bg-red-50 text-red-800 font-bold'
                        : 'border-slate-200 text-slate-600 bg-slate-50'
                    }`}
                  >
                    +24 Hours
                  </button>
                  <button
                    type="button"
                    onClick={() => setEditDurationPreset('3d')}
                    className={`px-2.5 py-1.5 rounded-lg text-xs font-medium border text-center transition-all ${
                      editDurationPreset === '3d'
                        ? 'border-red-600 bg-red-50 text-red-800 font-bold'
                        : 'border-slate-200 text-slate-600 bg-slate-50'
                    }`}
                  >
                    +3 Days
                  </button>
                  <button
                    type="button"
                    onClick={() => setEditDurationPreset('indefinite')}
                    className={`px-2.5 py-1.5 rounded-lg text-xs font-medium border text-center transition-all ${
                      editDurationPreset === 'indefinite'
                        ? 'border-red-600 bg-red-50 text-red-800 font-bold'
                        : 'border-slate-200 text-slate-600 bg-slate-50'
                    }`}
                  >
                    Permanent
                  </button>
                  <button
                    type="button"
                    onClick={() => setEditDurationPreset('custom')}
                    className={`px-2.5 py-1.5 rounded-lg text-xs font-medium border text-center transition-all ${
                      editDurationPreset === 'custom'
                        ? 'border-red-600 bg-red-50 text-red-800 font-bold'
                        : 'border-slate-200 text-slate-600 bg-slate-50'
                    }`}
                  >
                    Custom Time
                  </button>
                </div>

                {editDurationPreset === 'custom' && (
                  <div className="mt-2.5 p-2.5 bg-amber-50 rounded-xl border border-amber-200">
                    <label className="text-[11px] font-semibold text-amber-900 block mb-1">
                      Pick New Date & Expiry Time:
                    </label>
                    <input
                      type="datetime-local"
                      required
                      value={editCustomExpiry}
                      onChange={(e) => setEditCustomExpiry(e.target.value)}
                      className="w-full px-3 py-1.5 text-xs bg-white border border-amber-300 rounded-lg text-slate-800"
                    />
                  </div>
                )}
              </div>

              {/* Active Banner Status */}
              <div className="pt-2 flex items-center justify-between">
                <div>
                  <div className="text-xs font-bold text-slate-800">Banner Publication Status</div>
                  <div className="text-[11px] text-slate-400">
                    Active banners are displayed in-app on the donor homepage until dismissed or expired.
                  </div>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={editIsActive}
                    onChange={(e) => setEditIsActive(e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-slate-200 peer-focus:outline-hidden rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-red-600"></div>
                </label>
              </div>

              <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setEditingBroadcast(null)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSavingEdit || !editTitle.trim() || !editBody.trim()}
                  className="px-5 py-2 text-xs font-bold bg-red-600 hover:bg-red-700 disabled:bg-slate-300 text-white rounded-xl shadow-md transition-colors"
                >
                  {isSavingEdit ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
