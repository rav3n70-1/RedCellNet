// admin_panel/src/pages/LoginPage.tsx
import React, { useState } from 'react';
import { Activity, Lock, Mail, ArrowRight, KeyRound } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

export const LoginPage: React.FC = () => {
  const { signIn, signUp } = useAuth();
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg('');
    setIsLoading(true);

    try {
      if (isSignUp) {
        if (!name.trim()) {
          setErrorMsg('Please enter your full name.');
          setIsLoading(false);
          return;
        }
        const { error } = await signUp(email.trim(), password, name.trim());
        if (error) throw error;
      } else {
        const { error } = await signIn(email.trim(), password);
        if (error) throw error;
      }
    } catch (err: any) {
      setErrorMsg(err?.message || 'Authentication failed. Please check credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  // Quick Demo Access for development and verification
  const handleDemoLogin = async () => {
    setIsLoading(true);
    setErrorMsg('');
    try {
      const demoEmail = 'rohan.admin@redcellnet.com';
      const demoPass = 'Rohan123@#';
      const { error: signInErr } = await signIn(demoEmail, demoPass);
      if (signInErr) {
        setErrorMsg(signInErr.message);
      }
    } catch (err: any) {
      setErrorMsg(err?.message || 'Demo login failed');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-900 flex flex-col justify-center items-center p-4 selection:bg-red-500 selection:text-white">
      {/* Background glow */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-red-600/10 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-md bg-white rounded-3xl p-8 shadow-2xl border border-slate-100 z-10 animate-in fade-in zoom-in-95 duration-200">
        {/* Brand */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-tr from-red-600 to-rose-500 text-white shadow-lg shadow-red-900/30 mb-3">
            <Activity className="w-8 h-8 stroke-[2.5]" />
          </div>
          <h2 className="text-2xl font-black text-slate-900 tracking-tight">RedCellNet Portal</h2>
          <p className="text-xs text-slate-500 font-medium mt-1">
            Emergency Blood Distribution & Operations Management
          </p>
        </div>

        {errorMsg && (
          <div className="mb-5 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-semibold">
            {errorMsg}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          {isSignUp && (
            <div>
              <label className="text-xs font-bold text-slate-700 block mb-1">Full Name</label>
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full px-3.5 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
              />
            </div>
          )}

          <div>
            <label className="text-xs font-bold text-slate-700 block mb-1">Email Address</label>
            <div className="relative">
              <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full pl-10 pr-3.5 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-red-500/20 focus:border-red-500 font-medium"
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-bold text-slate-700 block mb-1">Password</label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full pl-10 pr-3.5 py-2.5 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-red-500/20 focus:border-red-500 font-medium"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full mt-2 py-3 bg-red-600 hover:bg-red-700 disabled:bg-red-400 text-white font-bold text-xs rounded-xl shadow-md transition-colors flex items-center justify-center gap-2"
          >
            {isLoading ? 'Authenticating...' : isSignUp ? 'Create Admin Account' : 'Sign In to Operations'}
            <ArrowRight className="w-4 h-4" />
          </button>
        </form>

        <div className="mt-6 pt-5 border-t border-slate-100 flex flex-col items-center gap-3">
          <button
            type="button"
            onClick={() => setIsSignUp(!isSignUp)}
            className="text-xs font-semibold text-slate-500 hover:text-slate-800 transition-colors"
          >
            {isSignUp ? 'Already have an admin account? Sign In' : 'Need a new administrator account? Register'}
          </button>

          {/* Quick Demo Login Button */}
          <button
            type="button"
            disabled={isLoading}
            onClick={handleDemoLogin}
            className="w-full py-2 px-3 text-xs font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors flex items-center justify-center gap-2 border border-slate-200"
          >
            <KeyRound className="w-3.5 h-3.5 text-amber-600" />
            Quick Demo Login (Instant Access)
          </button>
        </div>
      </div>

      <p className="text-xs text-slate-500 mt-6 text-center">
        RedCellNet Blood Management System • Secured with Supabase PostgreSQL & RLS
      </p>
    </div>
  );
};
