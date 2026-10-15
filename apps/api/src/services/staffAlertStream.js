const pool = require("../config/database");

const POLL_MS = 2000;
const LOOKBACK_MS = 15000;
const HEARTBEAT_MS = 20000;
// Streams are recycled so a long-lived connection cannot outlive its token or
// a deactivated account; the portal reconnects with a fresh token.
const MAX_STREAM_MS = 10 * 60 * 1000;

const ALERT_COLUMNS = `id, target_role, alert_type, severity, title, body,
  target_route, related_beneficiary_id, related_dispute_id, is_read, read_at,
  created_at`;

const clients = new Set();
const sentIds = new Map();
let timer = null;
let cursor = null;
let primed = false;
let polling = false;

function writeEvent(client, event, data) {
  client.res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

async function poll() {
  if (polling) return;
  polling = true;
  try {
    if (!cursor) {
      const { rows } = await pool.query("SELECT NOW() AS now");
      cursor = rows[0].now;
    }

    // The lookback window tolerates rows that commit slightly after a newer one.
    const { rows } = await pool.query(
      `SELECT ${ALERT_COLUMNS}
         FROM staff_alerts
        WHERE created_at > $1::timestamptz - ($2 * INTERVAL '1 millisecond')
        ORDER BY created_at ASC
        LIMIT 200`,
      [cursor, LOOKBACK_MS],
    );

    for (const row of rows) {
      const createdMs = new Date(row.created_at).getTime();
      if (!sentIds.has(row.id)) {
        sentIds.set(row.id, createdMs);
        // The first pass only records what already exists; clients load the
        // current list themselves when they connect.
        if (primed) {
          for (const client of clients) {
            if (client.role === row.target_role) {
              try {
                writeEvent(client, "alert", row);
              } catch {
                // A broken socket is cleaned up by its close handler.
              }
            }
          }
        }
      }
      if (new Date(row.created_at) > new Date(cursor)) cursor = row.created_at;
    }
    primed = true;

    const pruneBefore = new Date(cursor).getTime() - 60000;
    for (const [id, createdMs] of sentIds) {
      if (createdMs < pruneBefore) sentIds.delete(id);
    }
  } catch (err) {
    console.error("[StaffAlertStream] Poll failed:", err.message);
  } finally {
    polling = false;
  }
}

function startPolling() {
  if (timer) return;
  cursor = null;
  primed = false;
  sentIds.clear();
  poll();
  timer = setInterval(poll, POLL_MS);
}

function stopPollingIfIdle() {
  if (clients.size === 0 && timer) {
    clearInterval(timer);
    timer = null;
  }
}

// Opens a Server-Sent Events stream scoped to one office role.
function openStaffAlertStream(req, res, role) {
  res.status(200).set({
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no",
  });
  res.flushHeaders();
  res.write("retry: 5000\n\n");

  const client = { res, role };
  clients.add(client);
  writeEvent(client, "ready", { role });
  startPolling();

  const heartbeat = setInterval(() => {
    try {
      res.write(": ping\n\n");
    } catch {
      cleanup();
    }
  }, HEARTBEAT_MS);
  const expiry = setTimeout(() => res.end(), MAX_STREAM_MS);

  function cleanup() {
    clearInterval(heartbeat);
    clearTimeout(expiry);
    clients.delete(client);
    stopPollingIfIdle();
  }

  req.on("close", cleanup);
}

module.exports = { openStaffAlertStream };
