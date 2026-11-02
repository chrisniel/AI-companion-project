import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';
import { setSessionToken } from '../services/api/client';
import { createConversation, getConversation } from '../services/api/conversationApi';

describe('conversationApi Character Foundation client behavior', () => {
  beforeEach(() => {
    localStorage.clear();
    setSessionToken('psk_test');
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('omitted characterId sends title without character_id property (selects active character)', async () => {
    const fetcher = vi.fn().mockImplementation((_url: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      expect(body.title).toBe('New Conversation');
      expect('character_id' in body).toBe(false);

      return Promise.resolve(
        new Response(
          JSON.stringify({
            id: 'conv-active-1',
            title: 'New Conversation',
            character_id: 'inst-active-1',
            character_instance_id: 'inst-active-1',
            owner_id: 'user-1',
            created_at: '2026-11-02T10:00:00Z',
            updated_at: '2026-11-02T10:00:00Z',
            message_count: 0,
          }),
          { status: 201 },
        ),
      );
    });

    vi.stubGlobal('fetch', fetcher);

    const conv = await createConversation();
    expect(conv.id).toBe('conv-active-1');
    expect(conv.character_id).toBe('inst-active-1');
    expect(conv.character_instance_id).toBe('inst-active-1');
  });

  it('custom title with omitted characterId sends only title', async () => {
    const fetcher = vi.fn().mockImplementation((_url: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      expect(body.title).toBe('Project Roadmap');
      expect('character_id' in body).toBe(false);

      return Promise.resolve(
        new Response(
          JSON.stringify({
            id: 'conv-active-2',
            title: 'Project Roadmap',
            character_id: 'default',
            character_instance_id: null,
            owner_id: 'user-1',
            created_at: '2026-11-02T10:00:00Z',
            updated_at: '2026-11-02T10:00:00Z',
            message_count: 0,
          }),
          { status: 201 },
        ),
      );
    });

    vi.stubGlobal('fetch', fetcher);

    const conv = await createConversation('Project Roadmap');
    expect(conv.character_id).toBe('default');
    expect(conv.character_instance_id).toBeNull();
  });

  it('explicit "default" characterId sends character_id: "default"', async () => {
    const fetcher = vi.fn().mockImplementation((_url: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      expect(body.title).toBe('Neutral Chat');
      expect(body.character_id).toBe('default');

      return Promise.resolve(
        new Response(
          JSON.stringify({
            id: 'conv-neutral-1',
            title: 'Neutral Chat',
            character_id: 'default',
            character_instance_id: null,
            owner_id: 'user-1',
            created_at: '2026-11-02T10:00:00Z',
            updated_at: '2026-11-02T10:00:00Z',
            message_count: 0,
          }),
          { status: 201 },
        ),
      );
    });

    vi.stubGlobal('fetch', fetcher);

    const conv = await createConversation('Neutral Chat', 'default');
    expect(conv.character_id).toBe('default');
    expect(conv.character_instance_id).toBeNull();
  });

  it('explicit "neutral-assistant" characterId sends character_id: "neutral-assistant"', async () => {
    const fetcher = vi.fn().mockImplementation((_url: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      expect(body.title).toBe('Explicit Neutral');
      expect(body.character_id).toBe('neutral-assistant');

      return Promise.resolve(
        new Response(
          JSON.stringify({
            id: 'conv-neutral-2',
            title: 'Explicit Neutral',
            character_id: 'neutral-assistant',
            character_instance_id: null,
            owner_id: 'user-1',
            created_at: '2026-11-02T10:00:00Z',
            updated_at: '2026-11-02T10:00:00Z',
            message_count: 0,
          }),
          { status: 201 },
        ),
      );
    });

    vi.stubGlobal('fetch', fetcher);

    const conv = await createConversation('Explicit Neutral', 'neutral-assistant');
    expect(conv.character_id).toBe('neutral-assistant');
    expect(conv.character_instance_id).toBeNull();
  });

  it('explicit instanceId sends character_id: instanceId', async () => {
    const fetcher = vi.fn().mockImplementation((_url: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      expect(body.title).toBe('Companion Chat');
      expect(body.character_id).toBe('inst-custom-abc');

      return Promise.resolve(
        new Response(
          JSON.stringify({
            id: 'conv-custom-1',
            title: 'Companion Chat',
            character_id: 'inst-custom-abc',
            character_instance_id: 'inst-custom-abc',
            owner_id: 'user-1',
            created_at: '2026-11-02T10:00:00Z',
            updated_at: '2026-11-02T10:00:00Z',
            message_count: 0,
          }),
          { status: 201 },
        ),
      );
    });

    vi.stubGlobal('fetch', fetcher);

    const conv = await createConversation('Companion Chat', 'inst-custom-abc');
    expect(conv.character_id).toBe('inst-custom-abc');
    expect(conv.character_instance_id).toBe('inst-custom-abc');
  });

  it('getConversation returns character_instance_id field', async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          id: 'conv-get-1',
          title: 'Fetched Chat',
          character_id: 'inst-custom-xyz',
          character_instance_id: 'inst-custom-xyz',
          owner_id: 'user-1',
          created_at: '2026-11-02T10:00:00Z',
          updated_at: '2026-11-02T10:00:00Z',
          message_count: 12,
        }),
        { status: 200 },
      ),
    );

    vi.stubGlobal('fetch', fetcher);

    const conv = await getConversation('conv-get-1');
    expect(conv.character_id).toBe('inst-custom-xyz');
    expect(conv.character_instance_id).toBe('inst-custom-xyz');
  });
});
