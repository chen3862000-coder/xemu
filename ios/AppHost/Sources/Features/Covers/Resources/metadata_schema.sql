PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS rom_hash_map (
    console TEXT NOT NULL,
    sha1 TEXT NOT NULL,
    crc32 TEXT,
    title_id TEXT NOT NULL,
    region TEXT,
    revision TEXT,
    PRIMARY KEY (console, sha1)
);

CREATE TABLE IF NOT EXISTS titles (
    title_id TEXT PRIMARY KEY,
    canonical_title TEXT NOT NULL,
    sort_title TEXT,
    release_year INTEGER,
    developer TEXT,
    publisher TEXT,
    genre TEXT,
    languages TEXT,
    series TEXT,
    tags TEXT
);

CREATE TABLE IF NOT EXISTS aliases (
    console TEXT NOT NULL,
    alias_norm TEXT NOT NULL,
    title_id TEXT NOT NULL,
    confidence REAL NOT NULL,
    PRIMARY KEY (console, alias_norm, title_id)
);

CREATE INDEX IF NOT EXISTS idx_rom_hash_map_sha1 ON rom_hash_map(sha1);
CREATE INDEX IF NOT EXISTS idx_aliases_console_alias ON aliases(console, alias_norm);
CREATE INDEX IF NOT EXISTS idx_aliases_title_id ON aliases(title_id);
