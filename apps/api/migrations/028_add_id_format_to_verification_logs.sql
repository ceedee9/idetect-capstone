CREATE TYPE id_format_type AS ENUM ('old', 'new');

ALTER TABLE verification_logs
ADD COLUMN IF NOT EXISTS id_format id_format_type NOT NULL DEFAULT 'old';