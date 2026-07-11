import type { Metadata, Viewport } from 'next';
import localFont from 'next/font/local';
import './globals.css';
import { AuthProvider } from '@/lib/client/auth';
import AppShell from '@/components/AppShell';
import ServiceWorker from '@/components/ServiceWorker';

const inter = localFont({
  src: [
    { path: '../fonts/Inter-Regular.woff2', weight: '400' },
    { path: '../fonts/Inter-Medium.woff2', weight: '500' },
    { path: '../fonts/Inter-SemiBold.woff2', weight: '600' },
    { path: '../fonts/Inter-Bold.woff2', weight: '700' },
  ],
  variable: '--font-inter',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Dumpster',
  description: 'Dump your thoughts, turn them into organized work.',
  manifest: '/manifest.webmanifest',
  icons: { icon: '/icons/icon-192.png', apple: '/icons/icon-192.png' },
  appleWebApp: { capable: true, statusBarStyle: 'black-translucent', title: 'Dumpster' },
};

export const viewport: Viewport = {
  themeColor: '#2d2d2d',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1, // stop iOS zooming inputs; the app manages its own type scale
  viewportFit: 'cover',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body style={{ fontFamily: 'var(--font-inter), ui-sans-serif, system-ui, sans-serif' }}>
        <AuthProvider>
          <AppShell>{children}</AppShell>
        </AuthProvider>
        <ServiceWorker />
      </body>
    </html>
  );
}
