-- ============================================================
-- iDetect — Development Seed Data
-- Realistic sample data for local development and testing.
-- DO NOT run on production.
-- Usage: psql -U postgres -d idetect -f database/seeds/dev_seed.sql
-- Passwords below are all: Password123! (bcrypt hashed)
-- ============================================================

-- ── BPLO / OSCA / PDAO Admin Users ──────────────────────────
INSERT INTO users (id, email, password_hash, full_name, role) VALUES
  (
    '11111111-0000-0000-0000-000000000001',
    'bplo.admin@valenzuela.gov.ph',
    '$2a$12$K3Rcc3BAdV/GkG5SyeCQN.jhpqijpHhhNHDFNj5nitSUcCF1cIS16',
    'Maria Santos',
    'bplo_admin'
  ),
  (
    '11111111-0000-0000-0000-000000000002',
    'osca.admin@valenzuela.gov.ph',
    '$2a$12$K3Rcc3BAdV/GkG5SyeCQN.jhpqijpHhhNHDFNj5nitSUcCF1cIS16',
    'Jose Reyes',
    'osca_admin'
  ),
  (
    '11111111-0000-0000-0000-000000000003',
    'pdao.admin@valenzuela.gov.ph',
    '$2a$12$K3Rcc3BAdV/GkG5SyeCQN.jhpqijpHhhNHDFNj5nitSUcCF1cIS16',
    'Ana Cruz',
    'pdao_admin'
  );

-- ── Establishments ───────────────────────────────────────────
INSERT INTO establishments (
  id, email, password_hash, business_name,
  business_permit_no, owner_name, address,
  contact_number, status, approved_by, approved_at
) VALUES
  (
    '22222222-0000-0000-0000-000000000001',
    'jollibee.mcarthur@example.com',
    '$2a$12$K3Rcc3BAdV/GkG5SyeCQN.jhpqijpHhhNHDFNj5nitSUcCF1cIS16',
    'Jollibee McArthur Highway',
    'VLZ-BP-2024-001234',
    'Juan dela Cruz',
    'McArthur Highway, Valenzuela City',
    '09171234567',
    'approved',
    '11111111-0000-0000-0000-000000000001',
    NOW() - INTERVAL '30 days'
  ),
  (
    '22222222-0000-0000-0000-000000000002',
    'chowking.polo@example.com',
    '$2a$12$K3Rcc3BAdV/GkG5SyeCQN.jhpqijpHhhNHDFNj5nitSUcCF1cIS16',
    'Chowking Polo',
    'VLZ-BP-2024-005678',
    'Pedro Reyes',
    'Polo Road, Valenzuela City',
    '09189876543',
    'approved',
    '11111111-0000-0000-0000-000000000001',
    NOW() - INTERVAL '20 days'
  ),
  (
    '22222222-0000-0000-0000-000000000003',
    'pending.resto@example.com',
    '$2a$12$K3Rcc3BAdV/GkG5SyeCQN.jhpqijpHhhNHDFNj5nitSUcCF1cIS16',
    'Lola Nena''s Carinderia',
    'VLZ-BP-2024-009999',
    'Nena Bautista',
    'Karuhatan Road, Valenzuela City',
    '09201112233',
    'pending',
    NULL,
    NULL
  );

-- ── Beneficiaries ────────────────────────────────────────────
INSERT INTO beneficiaries (
  id, id_number, full_name, birthdate,
  beneficiary_type, issuing_office,
  validity_start, validity_end, status, registered_mobile
) VALUES
  -- Valid Senior Citizen
  (
    '33333333-0000-0000-0000-000000000001',
    'OSCA-VLZ-2020-00001',
    'Remedios Villanueva',
    '1950-03-15',
    'senior_citizen',
    'OSCA Valenzuela',
    '2020-01-01', '2025-12-31',
    'active',
    '09171111111'
  ),
  -- Valid PWD
  (
    '33333333-0000-0000-0000-000000000002',
    'PWD-VLZ-2022-00042',
    'Roberto Liwanag',
    '1985-07-22',
    'pwd',
    'PDAO Valenzuela',
    '2022-06-01', '2025-05-31',
    'active',
    '09182222222'
  ),
  -- Suspended Senior Citizen (under investigation)
  (
    '33333333-0000-0000-0000-000000000003',
    'OSCA-VLZ-2019-00777',
    'Crisanto Dela Torre',
    '1948-11-05',
    'senior_citizen',
    'OSCA Valenzuela',
    '2019-01-01', '2024-12-31',
    'suspended',
    NULL
  ),
  -- Expired PWD
  (
    '33333333-0000-0000-0000-000000000004',
    'PWD-VLZ-2020-00015',
    'Luisa Mendoza',
    '1990-04-18',
    'pwd',
    'PDAO Valenzuela',
    '2020-01-01', '2023-12-31',
    'expired',
    '09193333333'
  );

-- ── Beneficiary Accounts (app users) ────────────────────────
INSERT INTO beneficiary_accounts (id, beneficiary_id, is_active) VALUES
  (
    '44444444-0000-0000-0000-000000000001',
    '33333333-0000-0000-0000-000000000001',
    TRUE
  ),
  (
    '44444444-0000-0000-0000-000000000002',
    '33333333-0000-0000-0000-000000000002',
    TRUE
  );

-- ── Sample Verification Logs ─────────────────────────────────
INSERT INTO verification_logs (
  establishment_id, beneficiary_id, id_number_scanned,
  beneficiary_type_detected, result, ocr_confidence_score,
  manually_entered, verified_at
) VALUES
  -- Valid scan at Jollibee
  (
    '22222222-0000-0000-0000-000000000001',
    '33333333-0000-0000-0000-000000000001',
    'OSCA-VLZ-2020-00001',
    'senior_citizen', 'valid', 94.50, FALSE,
    NOW() - INTERVAL '2 hours'
  ),
  -- Invalid scan (not in DB) at Chowking
  (
    '22222222-0000-0000-0000-000000000002',
    NULL,
    'OSCA-VLZ-FAKE-99999',
    'senior_citizen', 'invalid', 88.20, FALSE,
    NOW() - INTERVAL '1 hour'
  ),
  -- Suspicious (suspended) scan at Jollibee
  (
    '22222222-0000-0000-0000-000000000001',
    '33333333-0000-0000-0000-000000000003',
    'OSCA-VLZ-2019-00777',
    'senior_citizen', 'suspicious', 91.00, FALSE,
    NOW() - INTERVAL '30 minutes'
  );

\echo '=== Dev seed data inserted ==='
