'use client';

// Auth gate + navigation chrome. Desktop gets a charcoal sidebar (like
// the macOS app), mobile gets a bottom tab bar (like the iOS app).
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { ReactNode } from 'react';
import { useAuth } from '@/lib/client/auth';
import SignIn from './SignIn';
import { Spinner, ToastProvider } from './ui';

const NAV = [
  { href: '/', label: 'Dump', icon: '🗑️' },
  { href: '/items', label: 'Items', icon: '⚡' },
  { href: '/tags', label: 'Tags', icon: '#' },
  { href: '/docs', label: 'Docs', icon: '📄' },
  { href: '/wins', label: 'Wins', icon: '🏆' },
  { href: '/settings', label: 'Settings', icon: '⚙︎' },
] as const;

function isActive(pathname: string, href: string) {
  return href === '/' ? pathname === '/' : pathname.startsWith(href);
}

export default function AppShell({ children }: { children: ReactNode }) {
  const { status } = useAuth();
  const pathname = usePathname();

  // The offline fallback renders without chrome so it can be precached.
  if (pathname === '/offline') return <>{children}</>;

  if (status === 'loading') {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Spinner />
      </div>
    );
  }

  if (status === 'unconfigured') {
    return (
      <div className="mx-auto max-w-md px-6 py-24">
        <h1 className="mb-3 text-xl font-bold">Dumpster</h1>
        <p className="text-sm" style={{ color: 'var(--color-ink-secondary)' }}>
          Sign-in isn&apos;t set up yet. Configure <code>NEON_AUTH_BASE_URL</code> and{' '}
          <code>DATABASE_URL</code> in the Vercel project — see web/README.md.
        </p>
      </div>
    );
  }

  if (status === 'signedOut') return <SignIn />;

  return (
    <ToastProvider>
      <div className="flex min-h-screen">
        {/* Desktop sidebar */}
        <aside
          className="sticky top-0 hidden h-screen w-52 flex-col px-3 py-6 text-white md:flex"
          style={{ background: 'var(--color-sidebar)' }}
        >
          <div className="mb-8 flex items-center gap-2 px-2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/icons/icon-192.png" alt="" className="h-8 w-8 rounded-lg" />
            <span className="text-lg font-bold">Dumpster</span>
          </div>
          <nav className="flex flex-col gap-1">
            {NAV.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors"
                style={
                  isActive(pathname, item.href)
                    ? { background: 'var(--color-accent)', color: '#fff' }
                    : { color: 'rgba(255,255,255,0.7)' }
                }
              >
                <span className="w-5 text-center">{item.icon}</span>
                {item.label}
              </Link>
            ))}
          </nav>
        </aside>

        {/* Content */}
        <main className="min-w-0 flex-1 pb-20 md:pb-8">{children}</main>

        {/* Mobile bottom tabs */}
        <nav
          className="fixed bottom-0 left-0 right-0 z-40 flex justify-around border-t border-edge py-1 md:hidden"
          style={{
            background: 'var(--color-card)',
            paddingBottom: 'max(env(safe-area-inset-bottom), 4px)',
          }}
        >
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex flex-col items-center gap-0.5 px-2 py-1 text-[10px] font-medium"
              style={{
                color: isActive(pathname, item.href) ? 'var(--color-accent)' : 'var(--color-ink-muted)',
              }}
            >
              <span className="text-base leading-none">{item.icon}</span>
              {item.label}
            </Link>
          ))}
        </nav>
      </div>
    </ToastProvider>
  );
}
