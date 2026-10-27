const ESTABLISHMENT_AUDIT_ACTIONS = [
  "verification_performed",
  "verification_action_taken",
  "flag_created",
  "callback_requested",
];

const AGENCY_ROLES = {
  bplo_super_admin: "bplo_admin",
  osca_super_admin: "osca_admin",
  pdao_super_admin: "pdao_admin",
};

function appendAuditScope(query, params, index, role) {
  const agencyAdminRole = AGENCY_ROLES[role];
  const allowedRoles = agencyAdminRole ? [agencyAdminRole, role] : [role];
  const rolePlaceholders = allowedRoles.map(
    (_, offset) => `$${index + offset}`,
  );
  params.push(...allowedRoles);

  if (role.startsWith("osca") || role.startsWith("pdao")) {
    const beneficiaryType = role.startsWith("pdao") ? "pwd" : "senior_citizen";
    const typeIndex = index + allowedRoles.length;
    const actionIndex = typeIndex + 1;
    params.push(beneficiaryType, ESTABLISHMENT_AUDIT_ACTIONS);

    return {
      query: `${query} AND (
        (
          u.role IN (${rolePlaceholders.join(", ")})
          AND (
            al.target_table IS NULL
            OR al.target_table NOT IN (
              'beneficiaries', 'disputes', 'fraud_flags', 'verification_logs'
            )
            OR (
              al.target_table = 'beneficiaries'
              AND EXISTS (
                SELECT 1 FROM beneficiaries scope_b
                WHERE scope_b.id = al.target_id
                  AND scope_b.beneficiary_type::text = $${typeIndex}
              )
            )
            OR (
              al.target_table = 'disputes'
              AND EXISTS (
                SELECT 1
                FROM disputes scope_d
                JOIN beneficiary_accounts scope_ba
                  ON scope_ba.id = scope_d.beneficiary_account_id
                JOIN beneficiaries scope_b
                  ON scope_b.id = scope_ba.beneficiary_id
                WHERE scope_d.id = al.target_id
                  AND scope_b.beneficiary_type::text = $${typeIndex}
              )
            )
            OR (
              al.target_table = 'fraud_flags'
              AND EXISTS (
                SELECT 1 FROM fraud_flags scope_f
                WHERE scope_f.id = al.target_id
                  AND scope_f.beneficiary_type::text = $${typeIndex}
              )
            )
            OR (
              al.target_table = 'verification_logs'
              AND EXISTS (
                SELECT 1 FROM verification_logs scope_v
                WHERE scope_v.id = al.target_id
                  AND scope_v.beneficiary_type_detected::text = $${typeIndex}
              )
            )
          )
        )
        OR (
          u.id IS NULL
          AND (
            (
              al.target_table = 'beneficiaries'
              AND EXISTS (
                SELECT 1 FROM beneficiaries scope_b
                WHERE scope_b.id = al.target_id
                  AND scope_b.beneficiary_type::text = $${typeIndex}
              )
            )
            OR (
              al.target_table = 'fraud_flags'
              AND EXISTS (
                SELECT 1 FROM fraud_flags scope_f
                WHERE scope_f.id = al.target_id
                  AND scope_f.beneficiary_type::text = $${typeIndex}
              )
            )
            OR (
              al.target_table = 'verification_logs'
              AND EXISTS (
                SELECT 1 FROM verification_logs scope_v
                WHERE scope_v.id = al.target_id
                  AND scope_v.beneficiary_type_detected::text = $${typeIndex}
              )
            )
            OR (
              al.establishment_id IS NOT NULL
              AND al.action::text = ANY($${actionIndex}::text[])
              AND (
                al.metadata->>'beneficiary_type' = $${typeIndex}
                OR EXISTS (
                  SELECT 1 FROM verification_logs scope_v
                  WHERE scope_v.id = al.target_id
                    AND scope_v.beneficiary_type_detected::text = $${typeIndex}
                )
                OR EXISTS (
                  SELECT 1 FROM fraud_flags scope_f
                  WHERE scope_f.id = al.target_id
                    AND scope_f.beneficiary_type::text = $${typeIndex}
                )
              )
            )
          )
        )
      )`,
      index: actionIndex + 1,
    };
  }

  params.push(ESTABLISHMENT_AUDIT_ACTIONS);
  return {
    query: `${query} AND (
      u.role IN (${rolePlaceholders.join(", ")})
      OR (
        u.id IS NULL
        AND al.establishment_id IS NOT NULL
        AND al.action::text = ANY($${index + allowedRoles.length}::text[])
      )
    )`,
    index: index + allowedRoles.length + 1,
  };
}

module.exports = {
  AGENCY_ROLES,
  ESTABLISHMENT_AUDIT_ACTIONS,
  appendAuditScope,
};
