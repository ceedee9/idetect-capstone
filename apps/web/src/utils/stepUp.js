import { authAPI } from "../services/api";

let cached = null; // { token, expiresAt }
let requester = null; // set by <StepUpHost />

export function registerStepUpHost(fn) {
  requester = fn;
  return () => {
    if (requester === fn) requester = null;
  };
}

// Resolves with a step-up token, prompting for the password if none is fresh.
export async function getStepUpToken(reason) {
  if (cached && cached.expiresAt > Date.now() + 5000) return cached.token;
  if (!requester) throw new Error("Step-up prompt unavailable");
  const token = await requester(reason, async (password) => {
    const res = await authAPI.reauthenticate(password);
    return res.data;
  });
  cached = { token: token.step_up_token, expiresAt: Date.now() + token.expires_in * 1000 };
  return cached.token;
}

export function clearStepUpToken() {
  cached = null;
}

export const stepUpHeaders = (token) => ({ "X-Step-Up-Token": token });
