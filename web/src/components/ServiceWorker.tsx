'use client';

import { useEffect } from 'react';

export default function ServiceWorker() {
  useEffect(() => {
    if ('serviceWorker' in navigator && process.env.NODE_ENV === 'production') {
      navigator.serviceWorker.register('/sw.js').catch(() => {
        // Non-fatal: the app works without offline support.
      });
    }
  }, []);
  return null;
}
