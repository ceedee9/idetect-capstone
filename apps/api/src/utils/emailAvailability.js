// An email may belong to only one establishment login. Establishment accounts
// live in two tables, and login checks both, so a clash across them locks
// one of the accounts out. Pass a pool or client as `db`.
async function isEstablishmentEmailTaken(db, email) {
  const { rows } = await db.query(
    `SELECT 1 FROM establishments WHERE lower(email) = lower($1)
     UNION ALL
     SELECT 1 FROM establishment_users WHERE lower(email) = lower($1)
     LIMIT 1`,
    [email],
  );
  return rows.length > 0;
}

module.exports = { isEstablishmentEmailTaken };
