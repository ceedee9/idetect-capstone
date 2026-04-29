// scripts/kill-port.js
// Kills any process listening on port 3000 before npm run dev.
// Runs automatically as the "predev" npm script.

const { execSync } = require("child_process");
const PORT = 3000;

try {
  if (process.platform === "win32") {
    // Find PID listening on the port, then kill it
    const out = execSync(
      `netstat -ano | findstr ":${PORT}" | findstr "LISTENING"`,
      { shell: "cmd.exe", stdio: "pipe" },
    ).toString();

    const pids = [
      ...new Set(
        out
          .trim()
          .split("\n")
          .map((line) => line.trim().split(/\s+/).pop())
          .filter(Boolean),
      ),
    ];

    for (const pid of pids) {
      try {
        execSync(`taskkill /PID ${pid} /F`, {
          shell: "cmd.exe",
          stdio: "pipe",
        });
        console.log(`[predev] Killed process ${pid} holding port ${PORT}`);
      } catch (_) {
        // Already gone
      }
    }
  } else {
    execSync(`fuser -k ${PORT}/tcp`, { stdio: "pipe" });
    console.log(`[predev] Freed port ${PORT}`);
  }
} catch (_) {
  // Port was not in use — nothing to kill, proceed normally
}
