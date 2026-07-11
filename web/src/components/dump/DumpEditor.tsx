'use client';

// The daily dump editor. A textarea with an exactly-aligned backdrop div
// colorizes #tags inline as you type (the technique the native apps'
// NSTextView styling maps to on the web). Enter completes a line: the
// line is sent for magic-tag processing and a fresh bullet starts.
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from 'react';
import { MAGIC_TAGS, extractTags, isMagicTag, tagClass } from '@/lib/magic';

const BULLET = '• ';

const sharedTextStyle: CSSProperties = {
  fontFamily: 'inherit',
  fontSize: '15px',
  lineHeight: '1.7',
  whiteSpace: 'pre-wrap',
  overflowWrap: 'break-word',
  padding: '16px',
  margin: 0,
  border: 0,
};

// Renders dump text with colored tag spans; used by the editor backdrop
// and read-only past-day views.
export function ColorizedDump({ text }: { text: string }) {
  const parts: React.ReactNode[] = [];
  let last = 0;
  let key = 0;
  for (const match of text.matchAll(/#[\w-]+/g)) {
    const start = match.index!;
    if (start > last) parts.push(text.slice(last, start));
    const tag = match[0].slice(1).toLowerCase();
    parts.push(
      <span key={key++} className={tagClass(tag)}>
        {match[0]}
      </span>,
    );
    last = start + match[0].length;
  }
  if (last < text.length) parts.push(text.slice(last));
  return <>{parts}</>;
}

interface Props {
  value: string;
  onChange: (next: string) => void;
  onLineCompleted: (line: string) => void;
  knownTags: string[]; // registered topic tag names for autocomplete
  placeholder?: string;
}

export default function DumpEditor({ value, onChange, onLineCompleted, knownTags, placeholder }: Props) {
  const taRef = useRef<HTMLTextAreaElement>(null);
  const backdropRef = useRef<HTMLDivElement>(null);
  const [caret, setCaret] = useState(0);

  // Keep the backdrop scroll-locked to the textarea.
  const syncScroll = useCallback(() => {
    if (taRef.current && backdropRef.current) {
      backdropRef.current.scrollTop = taRef.current.scrollTop;
      backdropRef.current.scrollLeft = taRef.current.scrollLeft;
    }
  }, []);

  // Grow with content (like the apps' smoothly-growing editor).
  useEffect(() => {
    const ta = taRef.current;
    if (!ta) return;
    ta.style.height = 'auto';
    ta.style.height = `${Math.max(ta.scrollHeight, 180)}px`;
    syncScroll();
  }, [value, syncScroll]);

  // Tag autocomplete: partial "#..." word ending at the caret.
  const partialTag = useMemo(() => {
    const before = value.slice(0, caret);
    const match = before.match(/#([\w-]*)$/);
    return match ? match[1].toLowerCase() : null;
  }, [value, caret]);

  const suggestions = useMemo(() => {
    if (partialTag === null) return [];
    const topic = knownTags
      .filter((t) => t.startsWith(partialTag) && t !== partialTag)
      .slice(0, 6);
    const magic = MAGIC_TAGS.filter(
      (t) => t.startsWith(partialTag) && t !== partialTag && !topic.includes(t),
    ).slice(0, 3);
    return [...topic, ...magic];
  }, [partialTag, knownTags]);

  const acceptSuggestion = (tag: string) => {
    const ta = taRef.current;
    if (!ta || partialTag === null) return;
    const before = value.slice(0, caret).replace(/#[\w-]*$/, `#${tag} `);
    const next = before + value.slice(caret);
    onChange(next);
    requestAnimationFrame(() => {
      ta.focus();
      ta.setSelectionRange(before.length, before.length);
      setCaret(before.length);
    });
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    const ta = taRef.current;
    if (!ta) return;

    if (e.key === 'Tab' && suggestions.length) {
      e.preventDefault();
      acceptSuggestion(suggestions[0]);
      return;
    }

    if (e.key === 'Enter') {
      e.preventDefault();
      const pos = ta.selectionStart;
      const lineStart = value.lastIndexOf('\n', pos - 1) + 1;
      let lineEnd = value.indexOf('\n', pos);
      if (lineEnd === -1) lineEnd = value.length;
      const line = value.slice(lineStart, lineEnd);

      // New bullet on the next line; completed line goes to processing.
      const insertion = `\n${BULLET}`;
      const next = value.slice(0, lineEnd) + insertion + value.slice(lineEnd);
      onChange(next);
      const newPos = lineEnd + insertion.length;
      requestAnimationFrame(() => {
        ta.setSelectionRange(newPos, newPos);
        setCaret(newPos);
      });

      if (line.replace(/^\s*•\s?/, '').trim()) onLineCompleted(line);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    let next = e.target.value;
    let pos = e.target.selectionStart;

    // First character of an empty dump starts a bullet.
    if (value === '' && next !== '' && !next.startsWith(BULLET) && next !== '\n') {
      next = BULLET + next;
      pos += BULLET.length;
    }

    // Typing "* " at a line start converts to a bullet.
    const lineStart = next.lastIndexOf('\n', pos - 1) + 1;
    if (next.slice(lineStart, pos) === '* ') {
      next = next.slice(0, lineStart) + BULLET + next.slice(pos);
      pos = lineStart + BULLET.length;
    }

    onChange(next);
    requestAnimationFrame(() => {
      taRef.current?.setSelectionRange(pos, pos);
      setCaret(pos);
    });
  };

  return (
    <div className="relative">
      {suggestions.length > 0 && (
        <div className="absolute -top-9 left-0 z-10 flex gap-1.5 overflow-x-auto">
          {suggestions.map((tag, i) => (
            <button
              key={tag}
              type="button"
              onMouseDown={(e) => {
                e.preventDefault();
                acceptSuggestion(tag);
              }}
              className="whitespace-nowrap rounded-full border px-2 py-0.5 text-[11px] font-medium"
              style={{
                borderColor: 'var(--color-accent)',
                background: i === 0 ? 'var(--color-accent)' : 'var(--color-card)',
                color: i === 0 ? '#fff' : 'var(--color-accent)',
              }}
            >
              #{tag}
              {i === 0 && <span className="ml-1 opacity-70">⇥</span>}
            </button>
          ))}
        </div>
      )}

      <div className="relative overflow-hidden rounded-xl border border-edge bg-card">
        <div
          ref={backdropRef}
          aria-hidden
          className="pointer-events-none absolute inset-0 overflow-hidden"
          style={{ ...sharedTextStyle, color: 'var(--color-ink)' }}
        >
          <ColorizedDump text={value} />
          {/* trailing newline keeps backdrop height == textarea height */}
          {'\n'}
        </div>
        <textarea
          ref={taRef}
          value={value}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          onScroll={syncScroll}
          onSelect={(e) => setCaret(e.currentTarget.selectionStart)}
          onClick={(e) => setCaret(e.currentTarget.selectionStart)}
          placeholder={placeholder ?? `${BULLET}dump your thoughts… #tags organize them`}
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
          className="relative block w-full resize-none bg-transparent focus:outline-none"
          style={{
            ...sharedTextStyle,
            color: 'transparent',
            caretColor: 'var(--color-ink)',
            minHeight: '180px',
          }}
        />
      </div>

      {/* Ensure extra tags registered while typing are visible: extraction
          happens server-side on save, this is just a subtle live count. */}
      <p className="mt-1.5 text-right text-[11px]" style={{ color: 'var(--color-ink-muted)' }}>
        {extractTags(value).filter((t) => !isMagicTag(t)).length > 0 &&
          `#${[...new Set(extractTags(value).filter((t) => !isMagicTag(t)))].join(' #')}`}
      </p>
    </div>
  );
}
