CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  external_manager_id TEXT,
  name TEXT,
  role TEXT DEFAULT 'manager',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_company ON users(company_id);

CREATE TABLE IF NOT EXISTS calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  external_call_id TEXT NOT NULL,
  manager_id UUID REFERENCES users(id),
  external_manager_id TEXT,
  duration INT,
  recording_url TEXT,
  call_timestamp TIMESTAMP,
  raw_payload_json JSONB,
  processing_status TEXT DEFAULT 'PENDING',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_call
ON calls(company_id, external_call_id);

CREATE INDEX IF NOT EXISTS idx_calls_status ON calls(processing_status);
CREATE INDEX IF NOT EXISTS idx_calls_company ON calls(company_id);

CREATE TABLE IF NOT EXISTS call_transcripts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID REFERENCES calls(id) ON DELETE CASCADE,
  transcript TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS call_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID REFERENCES calls(id) ON DELETE CASCADE,
  score INT,
  criteria JSONB,
  summary TEXT,
  comments JSONB,
  filler_words_count INT,
  created_at TIMESTAMP DEFAULT NOW()
);
