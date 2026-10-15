import { getApiBaseUrl, getStaffToken } from "../services/api";

const MIN_RETRY_MS = 2000;
const MAX_RETRY_MS = 30000;

function parseFrame(frame) {
  let event = "message";
  const dataLines = [];
  for (const line of frame.split("\n")) {
    if (line.startsWith("event:")) event = line.slice(6).trim();
    else if (line.startsWith("data:")) dataLines.push(line.slice(5).trim());
  }
  if (!dataLines.length) return null;
  try {
    return { event, data: JSON.parse(dataLines.join("\n")) };
  } catch {
    return null;
  }
}

// Reads the staff alert Server-Sent Events stream with fetch so the staff
// token travels in the Authorization header rather than the URL. Reconnects
// automatically with backoff; the caller keeps a slower poll as a safety net.
export function connectStaffAlertStream({ onAlert, onStatus }) {
  let stopped = false;
  let controller = null;
  let retryMs = MIN_RETRY_MS;
  let retryTimer = null;

  const wait = (ms) =>
    new Promise((resolve) => {
      retryTimer = setTimeout(resolve, ms);
    });

  async function run() {
    while (!stopped) {
      const token = getStaffToken();
      if (token) {
        controller = new AbortController();
        try {
          const response = await fetch(`${getApiBaseUrl()}/staff/alerts/stream`, {
            headers: {
              Authorization: `Bearer ${token}`,
              Accept: "text/event-stream",
            },
            cache: "no-store",
            signal: controller.signal,
          });
          if (!response.ok || !response.body) {
            throw new Error(`Alert stream rejected (${response.status})`);
          }

          onStatus?.("live");
          retryMs = MIN_RETRY_MS;
          const reader = response.body.getReader();
          const decoder = new TextDecoder();
          let buffer = "";

          while (!stopped) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true }).replace(/\r\n/g, "\n");
            let boundary;
            while ((boundary = buffer.indexOf("\n\n")) !== -1) {
              const parsed = parseFrame(buffer.slice(0, boundary));
              buffer = buffer.slice(boundary + 2);
              if (parsed?.event === "alert") onAlert(parsed.data);
            }
          }
        } catch {
          // Fall through to the reconnect delay below.
        }
      }

      if (stopped) return;
      onStatus?.("reconnecting");
      await wait(retryMs);
      retryMs = Math.min(retryMs * 2, MAX_RETRY_MS);
    }
  }

  run();

  return () => {
    stopped = true;
    clearTimeout(retryTimer);
    controller?.abort();
  };
}
