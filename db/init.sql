CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Компании
CREATE TABLE IF NOT EXISTS companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  balance_minutes INT DEFAULT 0,
  subscription_status TEXT DEFAULT 'active',
  created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Пользователи
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  external_manager_id TEXT,               -- ID из внешней системы (CRM/Телефонии)
  email TEXT UNIQUE,
  password_hash TEXT,
  name TEXT,
  role TEXT DEFAULT 'manager',
  created_at TIMESTAMP DEFAULT NOW()
);

-- 3. Реестр промптов
CREATE TABLE IF NOT EXISTS prompt_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id), 
  call_category TEXT NOT NULL,
  prompt_body TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 4. Звонки
CREATE TABLE IF NOT EXISTS calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  external_call_id TEXT NOT NULL,         -- ID звонка во внешней системе
  manager_id UUID REFERENCES users(id),
  external_manager_id TEXT,               -- Дублируем для быстрой привязки, если юзера еще нет
  duration INT,
  recording_url TEXT,
  call_timestamp TIMESTAMP,
  call_category TEXT,
  raw_payload_json JSONB,                 -- ВСЕ данные от телефонии "как есть"
  processing_status TEXT DEFAULT 'PENDING',
  error_log TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 5. Транскрипты
CREATE TABLE IF NOT EXISTS call_transcripts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID REFERENCES calls(id) ON DELETE CASCADE,
  utterances JSONB,
  full_text TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 6. Анализ
CREATE TABLE IF NOT EXISTS call_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID REFERENCES calls(id) ON DELETE CASCADE,
  score INT,
  summary TEXT,
  analysis_data JSONB,
  recommendations TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 7. Логи биллинга
CREATE TABLE IF NOT EXISTS billing_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  call_id UUID REFERENCES calls(id),
  minutes_spent INT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Индексы
CREATE UNIQUE INDEX IF NOT EXISTS uniq_call ON calls(company_id, external_call_id);
CREATE INDEX IF NOT EXISTS idx_calls_company ON calls(company_id);
CREATE INDEX IF NOT EXISTS idx_prompts_lookup ON prompt_templates(company_id, call_category);
CREATE INDEX IF NOT EXISTS idx_users_external ON users(external_manager_id); -- Для быстрого поиска менеджера

-- Триггер для updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_calls_modtime
    BEFORE UPDATE ON calls
    FOR EACH ROW
    EXECUTE PROCEDURE update_updated_at_column();

/* v2.1
- Добавлена автоматизация updated_at (контроль воронки).
- Поддержка двухэтапного анализа (Classifier -> Deep Analysis).
- Биллинг и Multi-tenancy на уровне архитектуры.

v2
Что изменилось и почему:
- call_transcripts.utterances (JSONB): Теперь ты можешь хранить там данные со спикерами и таймкодами. Фронтенду будет легко отрисовать чат.
- calls.call_category: Сюда мы запишем результат первого прохода (1, 2, 3).
- prompt_templates: Сюда ты положишь один системный промпт с категорией classifier и по одному промпту для категорий 1, 2 и 3.
- call_analysis.analysis_data (JSONB): В LLM-анализе часто много полей (соблюдение скрипта, работа с возражениями). Пихать их в отдельные колонки в MVP — больно. Проще сохранить весь JSON от LLM сюда. 
*/