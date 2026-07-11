import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  headers: async () => [
    {
      // The service worker must never be cached aggressively, or updates
      // to the app shell would take a full cache cycle to reach installed
      // PWAs.
      source: '/sw.js',
      headers: [{ key: 'Cache-Control', value: 'no-cache, no-store, must-revalidate' }],
    },
  ],
};

export default nextConfig;
