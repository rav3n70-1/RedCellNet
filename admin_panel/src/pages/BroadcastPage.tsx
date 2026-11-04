// admin_panel/src/pages/BroadcastPage.tsx
import React, { useState } from 'react';
import {
  Send,
  Users,
  AlertTriangle,
  Smartphone,
  CheckCircle2,
  Sparkles,
} from 'lucide-react';
import type { BloodGroup, UserProfile } from '../types';
import { supabase } from '../lib/supabase';

interface BroadcastPageProps {
  donors: UserProfile[];
  onRefresh: () => void;
}

const BLOOD_GROUPS: BloodGroup[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

export const BroadcastPage: React.FC<BroadcastPageProps> = ({ donors, onRefresh }) => {
  const [targetAudience, setTargetAudience] = useState<'all' | 'blood_group' | 'single_user'>('all');
  const [selectedBloodGroup, setSelectedBloodGroup] = useState<BloodGroup>('O-');
  const [specificUserId, setSpecificUserId] = useState('');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [notificationType, setNotificationType] = useState('emergency');
  const [isSending, setIsSending] = useState(false);
  const [sentSuccessCount, setSentSuccessCount] = useState<number | null>(null);

  // Quick Preset Templates
  const templates = [
    {
      label: '🚨 Critical O- Blood Shortage',
      title: 'URGENT: Critical O- Shortage in Dhaka',
      body: 'Dhaka Medical College & NICVD urgently require 4 units of O- Negative blood for emergency surgeries. Please respond if you are nearby!',
      type: 'emergency',
      audience: 'blood_group' as const,
      group: 'O-' as BloodGroup,
    },
    {
      label: '🩸 Monsoon Blood Drive Notice',
      title: 'Monsoon Voluntary Blood Donation Drive',
      body: 'Certified donation centers across Bangladesh are open today. Every donation saves up to 3 lives. Find your nearest verified blood bank on the map.',
      type: 'general',
      audience: 'all' as const,
      group: 'A+' as BloodGroup,
    },
    {
      label: '⭐ Verification Badge Reminder',
      title: 'Verify Your Donor Profile Today',
      body: 'Upload your laboratory blood grouping certificate to earn the official RedCellNet Verified Donor Shield Badge and help patients faster.',
      type: 'verification',
      audience: 'all' as const,
      group: 'B+' as BloodGroup,
    },
  ];

  const applyTemplate = (t: typeof templates[0]) => {
    setTitle(t.title);
    setBody(t.body);
    setNotificationType(t.type);
    setTargetAudience(t.audience);
    if (t.group) setSelectedBloodGroup(t.group);
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

    setIsSending(true);
    setSentSuccessCount(null);

    try {
      let recipientUserIds: string[] = [];

      if (targetAudience === 'all') {
        recipientUserIds = donors.map((d) => d.id);
      } else if (targetAudience === 'blood_group') {
        recipientUserIds = donors
          .filter((d) => d.blood_type === selectedBloodGroup)
          .map((d) => d.id);
      } else if (targetAudience === 'single_user') {
        if (specificUserId.trim()) {
          recipientUserIds = [specificUserId.trim()];
        }
      }

      // If database has no recipient IDs (e.g. fresh database), create a broadcast record
      if (recipientUserIds.length === 0) {
        recipientUserIds = ['broadcast-all'];
      }

      const rows = recipientUserIds.map((uid) => ({
        user_id: uid,
        title: title.trim(),
        body: body.trim(),
        type: notificationType,
        is_read: false,
        created_at: new Date().toISOString(),
      }));

      await supabase.from('notifications').insert(rows);

      setSentSuccessCount(recipientUserIds.length);
      setTitle('');
      setBody('');
      onRefresh();
    } catch (err) {
      console.error('Error sending broadcast notification:', err);
      alert(`Error sending broadcast: ${err}`);
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
          Send instant emergency alerts, shortage broadcasts, and platform updates directly to mobile devices.
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
          Broadcast alert successfully dispatched to {sentSuccessCount} recipient(s)!
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Composer Form (Left 7 cols) */}
        <div className="lg:col-span-7 bg-white p-6 rounded-2xl border border-slate-200 shadow-xs">
          <form onSubmit={handleSendBroadcast} className="space-y-5">
            {/* Target Audience selection */}
            <div>
              <label className="text-xs font-bold uppercase tracking-wider text-slate-500 block mb-2">
                1. Select Target Recipients
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
                <div className="mt-3.5">
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Target User ID / Profile ID:
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="Enter UUID of target user..."
                    value={specificUserId}
                    onChange={(e) => setSpecificUserId(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-200 rounded-xl font-mono focus:ring-2 focus:ring-red-500/20"
                  />
                </div>
              )}
            </div>

            {/* Notification content */}
            <div>
              <label className="text-xs font-bold uppercase tracking-wider text-slate-500 block mb-2">
                2. Notification Content
              </label>

              <div className="space-y-3">
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
            <Smartphone className="w-4 h-4" /> Device Lock Screen Preview
          </div>

          {/* Smartphone Mockup */}
          <div className="w-72 bg-slate-900 rounded-[36px] p-3 shadow-2xl border-4 border-slate-800">
            {/* Phone Speaker & Notch */}
            <div className="w-24 h-4 bg-slate-800 rounded-full mx-auto mb-3" />

            {/* Screen Display */}
            <div className="bg-slate-950 rounded-[28px] p-4 min-h-[360px] flex flex-col justify-start">
              {/* Clock */}
              <div className="text-center my-3">
                <div className="text-3xl font-extralight text-white tracking-wider">12:45</div>
                <div className="text-[10px] text-slate-400">Wednesday, November 4</div>
              </div>

              {/* Push Notification Card */}
              <div className="bg-slate-900/90 border border-slate-800/80 rounded-2xl p-3 shadow-lg backdrop-blur-md mt-4 animate-in fade-in duration-300">
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-1.5">
                    <div className="w-4 h-4 rounded-full bg-red-600 flex items-center justify-center text-[8px] font-black text-white">
                      R
                    </div>
                    <span className="text-[10px] font-bold text-slate-300">RedCellNet</span>
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
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
