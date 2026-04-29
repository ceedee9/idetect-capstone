require("dotenv").config();
const pool = require("./src/config/database");
pool
  .query(
    `SELECT notification_type, title, is_read, sent_at
   FROM notifications
   WHERE beneficiary_account_id = 'acaa5304-bdd7-414d-b457-c53baa928665'
   ORDER BY sent_at DESC LIMIT 10`,
  )
  .then((r) => {
    console.log(JSON.stringify(r.rows, null, 2));
    pool.end();
  })
  .catch((e) => {
    console.error(e.message);
    pool.end();
  });
