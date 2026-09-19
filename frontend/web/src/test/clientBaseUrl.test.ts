import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { getApiBaseUrl, setApiBaseUrl, apiFetch } from '../services/api/client';

describe('Frontend API Base URL resolution', () => {
  const originalLocation = window.location;

  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    localStorage.clear();
    // Restore original window.location
    Object.defineProperty(window, 'location', {
      writable: true,
      value: originalLocation,
    });
  });

  it('uses companion_api_url from localStorage if present', () => {
    localStorage.setItem('companion_api_url', 'https://custom-backend.internal:8000');
    expect(getApiBaseUrl()).toBe('https://custom-backend.internal:8000');
  });

  it('defaults to http://127.0.0.1:8000 when hostname is localhost', () => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: {
        hostname: 'localhost',
        origin: 'http://localhost:3000',
      },
    });
    expect(getApiBaseUrl()).toBe('http://127.0.0.1:8000');
  });

  it('defaults to http://127.0.0.1:8000 when hostname is 127.0.0.1', () => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: {
        hostname: '127.0.0.1',
        origin: 'http://127.0.0.1:3000',
      },
    });
    expect(getApiBaseUrl()).toBe('http://127.0.0.1:8000');
  });

  it('uses window.location.origin when hostname is remote / Tailscale', () => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: {
        hostname: 'my-pc.my-tailnet.ts.net',
        origin: 'https://my-pc.my-tailnet.ts.net',
      },
    });
    expect(getApiBaseUrl()).toBe('https://my-pc.my-tailnet.ts.net');
  });

  it('strips trailing slash from window.location.origin if present', () => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: {
        hostname: 'my-pc.my-tailnet.ts.net',
        origin: 'https://my-pc.my-tailnet.ts.net/',
      },
    });
    expect(getApiBaseUrl()).toBe('https://my-pc.my-tailnet.ts.net');
  });

  it('allows setApiBaseUrl to override any location origin', () => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: {
        hostname: 'my-pc.my-tailnet.ts.net',
        origin: 'https://my-pc.my-tailnet.ts.net',
      },
    });
    setApiBaseUrl('https://override.ts.net:8443');
    expect(getApiBaseUrl()).toBe('https://override.ts.net:8443');
  });
});
