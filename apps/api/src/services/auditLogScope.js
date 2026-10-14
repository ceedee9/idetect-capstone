const ESTABLISHMENT_AUDIT_ACTIONS = [
  "verification_performed",
  "verification_action_taken",
  "flag_created",
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
            OR COALESCE(
              tb.beneficiary_type,
              db.beneficiary_type,
              tf.beneficiary_type,
              tv.beneficiary_type_detected
            ) = $${typeIndex}
          )
        )
        OR (
          u.id IS NULL
          AND (
            COALESCE(
              tb.beneficiary_type,
              db.beneficiary_type,
              tf.beneficiary_type,
              tv.beneficiary_type_detected
            ) = $${typeIndex}
            OR (
              al.establishment_id IS NOT NULL
              AND al.action = ANY($${actionIndex}::audit_action[])
              AND COALESCE(
                al.metadata->>'beneficiary_type',
                tv.beneficiary_type_detected::text,
                tf.beneficiary_type::text
              ) = $${typeIndex}
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
        AND al.action = ANY($${index + allowedRoles.length}::audit_action[])
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
