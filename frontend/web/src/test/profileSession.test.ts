import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';
import { apiFetch, getApiKey, setSessionToken } from '../services/api/client';
import { createBrowserClaim, exchangeBrowserClaim } from '../services/api/sessionApi';

describe('profile session transport', () => {
  beforeEach(() => { localStorage.clear(); setSessionToken(''); });
  afterEach(() => vi.unstubAllGlobals());
  it('purges legacy pairing keys and never uses them as personal authority', async () => {
    localStorage.setItem('companion_api_key', 'legacy-pairing');
    localStorage.setItem('COMPANION_API_KEY', 'legacy-pairing');
    const fetcher = vi.fn().mockResolvedValue(new Response('{}'));
    vi.stubGlobal('fetch', fetcher);
    expect(getApiKey()).toBe('');
    await apiFetch('/api/v1/conversations');
    expect(new Headers(fetcher.mock.calls[0][1].headers).has('Authorization')).toBe(false);
    expect(localStorage.getItem('companion_api_key')).toBeNull();
    expect(localStorage.getItem('COMPANION_API_KEY')).toBeNull();
  });
  it('keeps session credentials in memory and sends no admin authority', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response('{}'));
    vi.stubGlobal('fetch', fetcher);
    setSessionToken('psk_test');
    await apiFetch('/api/v1/conversations');
    const headers = new Headers(fetcher.mock.calls[0][1].headers);
    expect(headers.get('Authorization')).toBe('Bearer psk_test');
    expect(headers.has('X-Host-Admin-Secret')).toBe(false);
    expect(localStorage.length).toBe(0);
  });
  it('clears expired authority and informs mounted workspaces on unauthorized response', async () => {
    setSessionToken('psk_expired');
    const invalid = vi.fn();
    window.addEventListener('companion-session-invalid', invalid);
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}',{status:401})));
    await expect(apiFetch('/api/v1/conversations')).rejects.toThrow();
    expect(getApiKey()).toBe('');
    expect(invalid).toHaveBeenCalledOnce();
    window.removeEventListener('companion-session-invalid', invalid);
  });
  it('keeps native host administration out of the browser transport', async () => {
    setSessionToken('psk_browser');
    const fetcher = vi.fn().mockResolvedValue(new Response('{}'));
    vi.stubGlobal('fetch',fetcher);
    await expect(apiFetch('/api/v1/system/status')).rejects.toThrow('Flutter Desktop');
    await expect(apiFetch('/api/v1/models/load',{method:'POST'})).rejects.toThrow('Flutter Desktop');
    expect(fetcher).not.toHaveBeenCalled();
    expect(getApiKey()).toBe('psk_browser');
  });
  it('posts only a claim hash, then exchanges with secret after explicit Desktop approval', async () => {
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({request_id:'req-1', expires_at:'2099-01-01T00:00:00Z'})))
      .mockResolvedValueOnce(new Response(JSON.stringify({token:'psk_new', profile_id:'p1', expires_at:'2099-01-01', client_type:'browser'})));
    vi.stubGlobal('fetch', fetcher);
    const claim = await createBrowserClaim();
    const init = fetcher.mock.calls[0][1];
    expect(init.redirect).toBe('error');
    expect(new Headers(init.headers).get('X-Companion-Bootstrap')).toBe('1');
    const payload = JSON.parse(init.body);
    expect(payload.claim_secret_hash).toMatch(/^[a-f0-9]{64}$/);
    expect(init.body).not.toContain(claim.secret);
    expect(claim.secret.length).toBeGreaterThanOrEqual(64);
    await exchangeBrowserClaim(claim);
    expect(fetcher.mock.calls[1][1].redirect).toBe('error');
    expect(JSON.parse(fetcher.mock.calls[1][1].body)).toEqual({request_id:'req-1', claim_secret:claim.secret});
    expect(fetcher.mock.calls.every(([url]) => !String(url).includes('?'))).toBe(true);
    expect(localStorage.getItem('companion_api_key')).toBeNull();
  });
});
