import React from 'react';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { BackendProvider } from '../context/BackendContext';
import { getSessionToken, setSessionToken } from '../services/api/client';

afterEach(() => { cleanup(); vi.unstubAllGlobals(); localStorage.clear(); setSessionToken(''); });
it('requires a browser request and shows Desktop approval details without persisting credentials', async () => {
  vi.stubGlobal('fetch', vi.fn(async (url: string) => {
    if (url.endsWith('/auth/session/claim')) return new Response(JSON.stringify({request_id:'review-me', expires_at:'2099-01-01T00:00:00Z'}));
    if (url.endsWith('/health')) return new Response('{"status":"healthy"}');
    return new Response('{}', {status:401});
  }));
  render(<BackendProvider><div>Workspace</div></BackendProvider>);
  expect(getSessionToken()).toBe('');
  fireEvent.click(screen.getByRole('button', { name:'Request Desktop approval' }));
  await waitFor(() => expect(screen.getByText(/review-me/)).toBeTruthy());
  expect(screen.getByText(/Select a Profile in Flutter Desktop/)).toBeTruthy();
  expect(screen.queryByPlaceholderText('companion_sec_...')).toBeNull();
  expect(localStorage.getItem('companion_api_key')).toBeNull();
});

it('waits through pending approval, activates only the approved session, and clears workspace on sign out', async () => {
  let polls = 0;
  const expiry = new Date(Date.now()+60_000).toISOString();
  const fetcher = vi.fn(async (url: string) => {
    if (url.endsWith('/auth/session/claim')) return new Response(JSON.stringify({request_id:'approved-request', expires_at:expiry}));
    if (url.endsWith('/auth/session/exchange')) {
      polls++;
      if (polls === 1) return new Response('{}',{status:409});
      return new Response(JSON.stringify({token:'psk_approved',profile_id:'profile-1',expires_at:expiry,client_type:'web_browser'}));
    }
    if (url.endsWith('/auth/session/revoke')) return new Response(null,{status:204});
    if (url.endsWith('/health')) return new Response('{"status":"healthy"}');
    return new Response('{}');
  });
  vi.stubGlobal('fetch',fetcher);
  render(<BackendProvider><div>Workspace</div></BackendProvider>);
  fireEvent.click(screen.getByRole('button',{name:'Request Desktop approval'}));
  await waitFor(() => expect(screen.getByText(/approved-request/)).toBeTruthy());
  await waitFor(() => expect(screen.getByText('Profile session: profile-1')).toBeTruthy(),{timeout:4000});
  expect(polls).toBe(2);
  expect(getSessionToken()).toBe('psk_approved');
  expect(localStorage.getItem('companion_api_key')).toBeNull();
  fireEvent.click(screen.getByRole('button',{name:'Sign out'}));
  expect(getSessionToken()).toBe('');
  expect(screen.queryByText('Profile session: profile-1')).toBeNull();
});
