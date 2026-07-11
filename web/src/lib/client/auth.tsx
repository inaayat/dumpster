'use client';

// Neon Auth for the browser. Same accounts as inaayat.xyz: the client
// talks to the hosted Neon Auth service directly (URL comes from
// /api/auth-config at runtime) and holds a session; API calls attach a
// short-lived JWT via getToken().
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import { createInternalNeonAuth, type VanillaBetterAuthClient } from '@neondatabase/auth';

// createInternalNeonAuth's default adapter is the vanilla Better Auth
// client; pin that shape so signIn.email/signUp.email typecheck.
interface NeonAuthClient {
  adapter: VanillaBetterAuthClient;
  getJWTToken: () => Promise<string | null>;
}

export interface SessionUser {
  id: string;
  email: string | null;
  name: string | null;
}

type Status = 'loading' | 'unconfigured' | 'signedOut' | 'signedIn';

interface AuthContextValue {
  status: Status;
  user: SessionUser | null;
  getToken: () => Promise<string | null>;
  signIn: (email: string, password: string, rememberMe?: boolean) => Promise<string | null>;
  signUp: (name: string, email: string, password: string) => Promise<string | null>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

// getSession()'s data is a union of session shapes, not all of which
// carry a user — extract defensively.
function extractUser(data: unknown): SessionUser | null {
  const u = (data as { user?: { id?: unknown; email?: unknown; name?: unknown } } | null)?.user;
  if (!u || typeof u.id !== 'string') return null;
  return {
    id: u.id,
    email: typeof u.email === 'string' ? u.email : null,
    name: typeof u.name === 'string' ? u.name : null,
  };
}

// Registered by the provider so the SWR fetcher (plain module code) can
// attach tokens without threading context everywhere.
let _getToken: (() => Promise<string | null>) | null = null;
export const getAuthToken = () => (_getToken ? _getToken() : Promise.resolve(null));

export function AuthProvider({ children }: { children: ReactNode }) {
  const [neonAuth, setNeonAuth] = useState<NeonAuthClient | null>(null);
  const [status, setStatus] = useState<Status>('loading');
  const [user, setUser] = useState<SessionUser | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      let url: string | null = null;
      try {
        const res = await fetch('/api/auth-config');
        url = (await res.json()).url;
      } catch {
        // fall through to unconfigured
      }
      if (cancelled) return;
      if (!url) {
        setStatus('unconfigured');
        return;
      }
      const auth = createInternalNeonAuth(url);
      _getToken = () => auth.getJWTToken();
      setNeonAuth(auth);
      try {
        const { data } = await auth.adapter.getSession();
        if (cancelled) return;
        const sessionUser = extractUser(data);
        if (sessionUser) {
          setUser(sessionUser);
          setStatus('signedIn');
        } else {
          setStatus('signedOut');
        }
      } catch {
        if (!cancelled) setStatus('signedOut');
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const refreshSession = useCallback(async () => {
    if (!neonAuth) return;
    const { data } = await neonAuth.adapter.getSession();
    const sessionUser = extractUser(data);
    if (sessionUser) {
      setUser(sessionUser);
      setStatus('signedIn');
    } else {
      setUser(null);
      setStatus('signedOut');
    }
  }, [neonAuth]);

  const signIn = useCallback(
    async (email: string, password: string, rememberMe = true) => {
      if (!neonAuth) return 'Auth not ready.';
      const { error } = await neonAuth.adapter.signIn.email({ email, password, rememberMe });
      if (error) return error.message || 'Sign-in failed.';
      await refreshSession();
      return null;
    },
    [neonAuth, refreshSession],
  );

  const signUp = useCallback(
    async (name: string, email: string, password: string) => {
      if (!neonAuth) return 'Auth not ready.';
      const { error } = await neonAuth.adapter.signUp.email({ name, email, password });
      if (error) return error.message || 'Sign-up failed.';
      await refreshSession();
      return null;
    },
    [neonAuth, refreshSession],
  );

  const signOut = useCallback(async () => {
    if (!neonAuth) return;
    await neonAuth.adapter.signOut();
    setUser(null);
    setStatus('signedOut');
  }, [neonAuth]);

  const getToken = useCallback(() => (neonAuth ? neonAuth.getJWTToken() : Promise.resolve(null)), [neonAuth]);

  return (
    <AuthContext.Provider value={{ status, user, getToken, signIn, signUp, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
