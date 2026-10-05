-- Rename this file to match your actual next migration number
-- (check your /migrations folder for the latest, and remember to add
-- this filename to scripts/migrate.js's MIGRATIONS array too).
--
-- Adds a free-text "where did this happen" field for disputes that
-- aren't tied to a specific verification_log_id (e.g. filed from the
-- mobile app's standalone dispute form, which doesn't attach a scan).
-- Named differently from the "establishment_name" alias already used
-- in routes/disputes.js (joined from verification_logs -> establishments)
-- so the two don't collide in the same SELECT.

ALTER TABLE disputes ADD COLUMN reported_establishment_name TEXT;