'use client';

// Small shared UI primitives + a toast system. Kept in one file on
// purpose: these are the app's design vocabulary.
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import type { Category, Priority } from '@/lib/types';

export const CATEGORY_COLOR: Record<Category, string> = {
  action: 'var(--color-action)',
  brainstorm: 'var(--color-brainstorm)',
  resource: 'var(--color-resource)',
};

export const CATEGORY_TINT: Record<Category, string> = {
  action: 'var(--color-action-tint)',
  brainstorm: 'var(--color-brainstorm-tint)',
  resource: 'var(--color-resource-tint)',
};

export const CATEGORY_LABEL: Record<Category, string> = {
  action: 'Action',
  brainstorm: 'Brainstorm',
  resource: 'Resource',
};

export const PRIORITY_LABEL: Record<Priority, string> = {
  high: 'High',
  medium: 'Medium',
  low: 'Low',
  backlog: 'Backlog',
};

export function CategoryBadge({ category }: { category: Category }) {
  return (
    <span
      className="rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide"
      style={{ background: CATEGORY_TINT[category], color: CATEGORY_COLOR[category] }}
    >
      {CATEGORY_LABEL[category]}
    </span>
  );
}

export function PriorityBadge({ priority }: { priority: Priority }) {
  if (priority === 'medium') return null;
  const color =
    priority === 'high' ? 'var(--color-warn)' : priority === 'backlog' ? 'var(--color-ink-muted)' : 'var(--color-accent)';
  return (
    <span
      className="rounded border px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide"
      style={{ borderColor: color, color }}
    >
      {PRIORITY_LABEL[priority]}
    </span>
  );
}

export function TagPill({
  name,
  onClick,
  active,
  small,
}: {
  name: string;
  onClick?: () => void;
  active?: boolean;
  small?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-full border font-medium transition-colors ${
        small ? 'px-2 py-0.5 text-[11px]' : 'px-2.5 py-1 text-xs'
      } ${onClick ? 'cursor-pointer' : 'cursor-default'}`}
      style={{
        borderColor: 'var(--color-accent)',
        background: active ? 'var(--color-accent)' : 'var(--color-accent-tint)',
        color: active ? '#fff' : 'var(--color-accent)',
      }}
    >
      #{name}
    </button>
  );
}

export function Spinner() {
  return (
    <div className="flex justify-center py-12">
      <div
        className="h-6 w-6 animate-spin rounded-full border-2 border-t-transparent"
        style={{ borderColor: 'var(--color-accent)', borderTopColor: 'transparent' }}
      />
    </div>
  );
}

export function EmptyState({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="py-16 text-center">
      <p className="text-sm font-semibold" style={{ color: 'var(--color-ink-secondary)' }}>
        {title}
      </p>
      {hint && (
        <p className="mt-1 text-xs" style={{ color: 'var(--color-ink-muted)' }}>
          {hint}
        </p>
      )}
    </div>
  );
}

export function Modal({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 sm:items-center"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full overflow-y-auto rounded-t-2xl bg-card p-5 shadow-xl sm:max-w-md sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-base font-bold">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            className="rounded-full px-2 py-1 text-sm"
            style={{ color: 'var(--color-ink-muted)' }}
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export const inputClass =
  'w-full rounded-lg border border-edge bg-card px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--color-accent)]';

export const buttonClass =
  'rounded-lg px-4 py-2 text-sm font-semibold text-white transition-opacity disabled:opacity-50';

export function PrimaryButton({
  children,
  onClick,
  disabled,
  type = 'button',
}: {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  type?: 'button' | 'submit';
}) {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={buttonClass}
      style={{ background: 'var(--color-accent)' }}
    >
      {children}
    </button>
  );
}

// ---------------------------------------------------------------- toasts

interface Toast {
  id: number;
  text: string;
  kind: 'info' | 'success' | 'error';
}

const ToastContext = createContext<(text: string, kind?: Toast['kind']) => void>(() => {});

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const push = useCallback((text: string, kind: Toast['kind'] = 'info') => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, text, kind }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3200);
  }, []);

  return (
    <ToastContext.Provider value={push}>
      {children}
      <div className="pointer-events-none fixed bottom-20 left-0 right-0 z-[60] flex flex-col items-center gap-2 px-4 sm:bottom-6">
        {toasts.map((t) => (
          <div
            key={t.id}
            className="rounded-lg px-4 py-2 text-sm font-medium text-white shadow-lg"
            style={{
              background:
                t.kind === 'error'
                  ? 'var(--color-danger)'
                  : t.kind === 'success'
                    ? 'var(--color-brainstorm)'
                    : 'var(--color-sidebar)',
            }}
          >
            {t.text}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export const useToast = () => useContext(ToastContext);
