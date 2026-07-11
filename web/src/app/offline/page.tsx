// Offline fallback served by the service worker when navigation fails.
export const metadata = { title: 'Dumpster — offline' };

export default function OfflinePage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center px-6 text-center">
      <p className="mb-2 text-4xl">🗑️</p>
      <h1 className="mb-2 text-xl font-bold">You&apos;re offline</h1>
      <p className="text-sm" style={{ color: 'var(--color-ink-muted)' }}>
        Dumpster needs a connection — your data lives safely in the cloud.
        <br />
        Reconnect and pull to refresh.
      </p>
    </div>
  );
}
