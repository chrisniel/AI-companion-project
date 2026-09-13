/**
 * Base HTTP API client for Local AI Companion Core.
 * Handles base URL configuration, local pairing key authentication, and error handling.
 */

const DEFAULT_BASE_URL = 'http://127.0.0.1:8000';

export function getApiBaseUrl(): string {
  return localStorage.getItem('companion_api_url') || DEFAULT_BASE_URL;
}

export function setApiBaseUrl(url: string): void {
  localStorage.setItem('companion_api_url', url.replace(/\/+$/, ''));
}

export function getApiKey(): string {
  return localStorage.getItem('companion_api_key') || '';
}

export function setApiKey(key: string): void {
  localStorage.setItem('companion_api_key', key.trim());
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
  const baseUrl = getApiBaseUrl();
  const apiKey = getApiKey();

  const url = `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`;

  const headers = new Headers(options.headers || {});
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
