// Neon Postgres access. Same philosophy as inaayat.xyz's lib/db.js:
// lazy client, and the schema provisions itself on first use so a fresh
// database needs no migration step. All dumpster tables are prefixed and
// scoped by user_id (the Neon Auth user id), sharing the database with
// the rest of inaayat.xyz. For changes to *existing* tables, run an
// ALTER in the Neon SQL editor and mirror it here.
import { neon } from '@neondatabase/serverless';

let _sql: ReturnType<typeof neon> | null = null;

export function db() {
  if (!_sql) {
    if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL not configured');
    _sql = neon(process.env.DATABASE_URL);
  }
  return _sql;
}

let _schemaReady: Promise<unknown> | null = null;

export function ensureSchema(): Promise<unknown> {
  if (!_schemaReady) {
    const sql = db();
    _schemaReady = (async () => {
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_tags (
          id         TEXT PRIMARY KEY,
          user_id    TEXT NOT NULL,
          name       TEXT NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          UNIQUE (user_id, name)
        )`;
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_tag_relationships (
          id            TEXT PRIMARY KEY,
          user_id       TEXT NOT NULL,
          parent_tag_id TEXT NOT NULL REFERENCES dumpster_tags(id) ON DELETE CASCADE,
          child_tag_id  TEXT NOT NULL REFERENCES dumpster_tags(id) ON DELETE CASCADE,
          created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
          UNIQUE (user_id, parent_tag_id, child_tag_id)
        )`;
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_items (
          id                    TEXT PRIMARY KEY,
          user_id               TEXT NOT NULL,
          text                  TEXT NOT NULL,
          category              TEXT NOT NULL DEFAULT 'brainstorm',
          priority              TEXT NOT NULL DEFAULT 'medium',
          done                  BOOLEAN NOT NULL DEFAULT false,
          done_at               TIMESTAMPTZ,
          due_date              TIMESTAMPTZ,
          url                   TEXT,
          url_title             TEXT,
          notes                 TEXT,
          incorporated_into_doc BOOLEAN NOT NULL DEFAULT false,
          dismissed_from_doc    BOOLEAN NOT NULL DEFAULT false,
          created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
        )`;
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_item_tags (
          user_id TEXT NOT NULL,
          item_id TEXT NOT NULL REFERENCES dumpster_items(id) ON DELETE CASCADE,
          tag_id  TEXT NOT NULL REFERENCES dumpster_tags(id) ON DELETE CASCADE,
          PRIMARY KEY (item_id, tag_id)
        )`;
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_daily_dumps (
          id         TEXT PRIMARY KEY,
          user_id    TEXT NOT NULL,
          date       TEXT NOT NULL,
          content    TEXT NOT NULL DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          UNIQUE (user_id, date)
        )`;
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_master_docs (
          id         TEXT PRIMARY KEY,
          user_id    TEXT NOT NULL,
          title      TEXT NOT NULL,
          content    TEXT NOT NULL DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )`;
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_master_doc_tags (
          user_id TEXT NOT NULL,
          doc_id  TEXT NOT NULL REFERENCES dumpster_master_docs(id) ON DELETE CASCADE,
          tag_id  TEXT NOT NULL REFERENCES dumpster_tags(id) ON DELETE CASCADE,
          PRIMARY KEY (doc_id, tag_id)
        )`;
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_wins (
          id         TEXT PRIMARY KEY,
          user_id    TEXT NOT NULL,
          text       TEXT NOT NULL,
          artifact   TEXT,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )`;
      await sql`
        CREATE TABLE IF NOT EXISTS dumpster_hidden_bullets (
          id          TEXT PRIMARY KEY,
          user_id     TEXT NOT NULL,
          bullet_text TEXT NOT NULL,
          created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        )`;
      await sql`CREATE INDEX IF NOT EXISTS idx_dumpster_items_user ON dumpster_items(user_id, done)`;
      await sql`CREATE INDEX IF NOT EXISTS idx_dumpster_tags_user ON dumpster_tags(user_id)`;
      await sql`CREATE INDEX IF NOT EXISTS idx_dumpster_dumps_user ON dumpster_daily_dumps(user_id, date)`;
      await sql`CREATE INDEX IF NOT EXISTS idx_dumpster_docs_user ON dumpster_master_docs(user_id)`;
      await sql`CREATE INDEX IF NOT EXISTS idx_dumpster_wins_user ON dumpster_wins(user_id)`;
    })().catch((err) => {
      _schemaReady = null; // let the next request retry
      throw err;
    });
  }
  return _schemaReady;
}
