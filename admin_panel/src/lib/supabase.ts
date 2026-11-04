// admin_panel/src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gygaensofsguorvyqtag.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_cG6gaMgVMH_1N2dnZQQnHg_Wrj9iC7U';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});
