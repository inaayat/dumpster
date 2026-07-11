'use client';

// Email/password sign-in against the same Neon Auth instance as
// inaayat.xyz — accounts created there work here and vice versa.
import { useState } from 'react';
import { useAuth } from '@/lib/client/auth';
import { PrimaryButton, inputClass } from './ui';

export default function SignIn() {
  const { signIn, signUp } = useAuth();
  const [mode, setMode] = useState<'signin' | 'signup'>('signin');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    const err =
      mode === 'signin' ? await signIn(email, password, rememberMe) : await signUp(name, email, password);
    setBusy(false);
    if (err) setError(err);
  };

  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden px-6">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/ugly-dog-images/dog-3.png"
        alt=""
        className="pointer-events-none absolute -right-6 -top-6 h-36 w-36 select-none opacity-10"
      />
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/ugly-dog-images/dog-5.png"
        alt=""
        className="pointer-events-none absolute -bottom-8 -left-8 h-40 w-40 select-none opacity-10"
      />

      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/icons/icon-192.png" alt="" className="relative mb-4 h-16 w-16 rounded-2xl" />
      <h1 className="relative mb-1 text-2xl font-bold">Dumpster</h1>
      <p className="relative mb-8 text-sm" style={{ color: 'var(--color-ink-muted)' }}>
        Same account as inaayat.xyz
      </p>

      <div className="relative w-full max-w-sm rounded-2xl border border-edge bg-card p-6 shadow-sm">
        <div className="mb-4 flex gap-2">
          {(['signin', 'signup'] as const).map((m) => (
            <button
              key={m}
              type="button"
              onClick={() => setMode(m)}
              className="rounded-lg px-3 py-1.5 text-sm font-semibold"
              style={
                mode === m
                  ? { background: 'var(--color-accent)', color: '#fff' }
                  : { color: 'var(--color-ink-muted)' }
              }
            >
              {m === 'signin' ? 'Sign in' : 'Sign up'}
            </button>
          ))}
        </div>

        <form onSubmit={submit} className="flex flex-col gap-3">
          {mode === 'signup' && (
            <input
              className={inputClass}
              type="text"
              placeholder="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoComplete="name"
              required
            />
          )}
          <input
            className={inputClass}
            type="email"
            placeholder="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            required
          />
          <input
            className={inputClass}
            type="password"
            placeholder={mode === 'signup' ? 'password (8+ characters)' : 'password'}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete={mode === 'signup' ? 'new-password' : 'current-password'}
            minLength={mode === 'signup' ? 8 : undefined}
            required
          />
          {mode === 'signin' && (
            <label
              className="flex items-center gap-2 text-sm"
              style={{ color: 'var(--color-ink-secondary)' }}
            >
              <input
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                className="h-4 w-4 rounded border-edge"
                style={{ accentColor: 'var(--color-accent)' }}
              />
              Keep me signed in
            </label>
          )}
          {error && (
            <p className="text-xs font-semibold" style={{ color: 'var(--color-danger)' }}>
              {error}
            </p>
          )}
          <PrimaryButton type="submit" disabled={busy}>
            {busy ? '…' : mode === 'signin' ? 'Sign in' : 'Create account'}
          </PrimaryButton>
        </form>
      </div>
    </div>
  );
}
