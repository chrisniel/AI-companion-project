import { apiFetch, getApiBaseUrl } from './client';

export interface ProfileSession {
  token: string;
  profile_id: string;
  expires_at: string;
  client_type: string;
}
export interface SessionMetadata {
  id: string;
  name: string;
  is_default: boolean;
  status: string;
  pin_protected: boolean;
  expires_at: string;
}
export interface BrowserClaim { request_id: string; expires_at: string; secret: string; origin: string; runtimeUrl: string }
const bootstrapHeaders = { 'X-Companion-Bootstrap': '1', 'Content-Type': 'application/json' };

export async function createBrowserClaim(): Promise<BrowserClaim> {
  const runtimeUrl = getApiBaseUrl();
  const runtime = new URL(runtimeUrl);
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(runtime.hostname)) {
    throw new Error('Open this browser on the local host to request Desktop approval.');
  }
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const secret = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret));
  const claim_secret_hash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
  if (getApiBaseUrl() !== runtimeUrl) throw new Error('Runtime changed. Request fresh Desktop approval.');
  const result = await apiFetch<{request_id: string; expires_at: string}>('/api/v1/auth/session/claim', {
    method: 'POST', headers: bootstrapHeaders, body: JSON.stringify({ claim_secret_hash }), redirect:'error',
  });
  return { ...result, secret, origin: window.location.origin, runtimeUrl };
}
export function exchangeBrowserClaim(claim: BrowserClaim): Promise<ProfileSession> {
  if (getApiBaseUrl() !== claim.runtimeUrl) return Promise.reject(new Error('Runtime changed. Request fresh Desktop approval.'));
  return apiFetch('/api/v1/auth/session/exchange', {
    method: 'POST', headers: bootstrapHeaders, redirect:'error',
    body: JSON.stringify({ request_id: claim.request_id, claim_secret: claim.secret }),
  });
}
export function revokeProfileSession(): Promise<void> {
  return apiFetch('/api/v1/auth/session/revoke', { method: 'POST' });
}
export function getOwnSession(): Promise<SessionMetadata> {
  return apiFetch('/api/v1/auth/session/me');
}
