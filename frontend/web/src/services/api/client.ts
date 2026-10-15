/**
 * Base HTTP API client for Local AI Companion Core.
 * Handles base URL configuration, in-memory Profile Sessions, and error handling.
 */

const DEFAULT_BASE_URL = 'http://127.0.0.1:8000';

export function getApiBaseUrl(): string {
  const stored = localStorage.getItem('companion_api_url');
  if (stored) {
    return stored;
  }

  if (typeof window !== 'undefined' && window.location) {
    const hostname = window.location.hostname;
    if (hostname === 'localhost' || hostname === '127.0.0.1') {
      return DEFAULT_BASE_URL;
    }
    if (window.location.origin) {
      return window.location.origin.replace(/\/+$/, '');
    }
  }

  return DEFAULT_BASE_URL;
}

export function setApiBaseUrl(url: string): void {
  localStorage.setItem('companion_api_url', url.replace(/\/+$/, ''));
}

let sessionToken = '';
export function purgeLegacyPairingKeys(): void {
  localStorage.removeItem('companion_api_key');
  localStorage.removeItem('COMPANION_API_KEY');
}
export function getSessionToken(): string {
  purgeLegacyPairingKeys();
  return sessionToken;
}
export function setSessionToken(token: string): void {
  purgeLegacyPairingKeys();
  sessionToken = token;
}
// Compatibility name for existing transport consumers; this is exclusively a session.
export const getApiKey = getSessionToken;
export function setApiKey(_key: string): void { purgeLegacyPairingKeys(); }
export function invalidateUnauthorizedSession(status: number): void {
  if ((status === 401 || status === 403) && sessionToken) {
    setSessionToken('');
    window.dispatchEvent(new Event('companion-session-invalid'));
  }
}

export interface ApiErrorDetail {
  code: string;
  message: string;
  details?: unknown;
  requestId?: string;
  status: number;
}

export class ApiError extends Error {
  code: string;
  details?: unknown;
  requestId?: string;
  status: number;

  constructor(error: ApiErrorDetail) {
    super(error.message);
    this.name = 'ApiError';
    this.code = error.code;
    this.details = error.details;
    this.requestId = error.requestId;
    this.status = error.status;
  }
}

export async function apiFetch<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  if (/^\/?api\/v1\/(system\/status|models\/(load|select|unload|profile)|auth\/bootstrap(?:\/|$)|profiles(?:\/|$))/.test(path)) {
    throw new ApiError({ code:'HOST_ADMIN_REQUIRED', message:'Host administration is available in Flutter Desktop.', status:403 });
  }
  const baseUrl = getApiBaseUrl();
  const apiKey = getApiKey();

  const url = `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`;

  const headers = new Headers(options.headers || {});
  headers.delete('X-Host-Admin-Secret');
  if (!headers.has('Content-Type') && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  if (apiKey && !headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${apiKey}`);
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (!response.ok) {
    invalidateUnauthorizedSession(response.status);
    let errorDetail: ApiErrorDetail = {
      code: 'HTTP_ERROR',
      message: `Request failed with status ${response.status}`,
      status: response.status,
    };

    try {
      const data = await response.json();
      if (data.error) {
        errorDetail = {
          code: data.error.code || 'API_ERROR',
          message: data.error.message || errorDetail.message,
          details: data.error.details,
          requestId: data.error.request_id,
          status: response.status,
        };
      } else if (data.detail) {
        errorDetail.message = typeof data.detail === 'string' ? data.detail : JSON.stringify(data.detail);
      }
    } catch {
      // Non-JSON response
    }

    throw new ApiError(errorDetail);
  }

  if (response.status === 204) {
    return {} as T;
  }

  return (await response.json()) as T;
}
