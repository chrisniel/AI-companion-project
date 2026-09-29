import React from 'react';
import { render, screen, waitFor, act } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ConversationMessageItem } from '../components/workspace/ConversationMessageItem';
import { AssistantView } from '../components/workspace/AssistantView';
import { AssistantMessage } from '../types';
import * as api from '../services/api';
import { BackendProvider } from '../context/BackendContext';

// Mock API layer
vi.mock('../services/api', async (importOriginal) => {
  const actual = await importOriginal();
  return {
    ...actual as any,
    fetchAttachmentBlobUrl: vi.fn(),
    listConversations: vi.fn(),
    getMessages: vi.fn(),
    createConversation: vi.fn(),
  };
});

vi.mock('../context/BackendContext', () => ({
  useBackend: vi.fn(),
}));

describe('Phase 8B.7 Persistent Message Attachment Rendering', () => {
  const revokeObjectURLMock = vi.fn();

  beforeEach(() => {
    vi.resetAllMocks();
    global.URL.createObjectURL = vi.fn(() => 'blob:test-url');
    global.URL.revokeObjectURL = revokeObjectURLMock;

    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        { id: 'conv-123', title: 'Test Conv', character_id: 'char-1', owner_id: 'user-1', created_at: new Date().toISOString(), updated_at: new Date().toISOString() },
      ],
      total: 1,
    });
    vi.mocked(api.fetchAttachmentBlobUrl).mockResolvedValue('blob:test-url');
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('AssistantView Mapping Integration', () => {
    it('survives history mapping into AssistantMessage', async () => {
      vi.mocked(api.getMessages).mockResolvedValue({
        items: [
          {
            id: 'msg-1',
            conversation_id: 'conv-123',
            sender: 'user',
            content: 'Check out this image',
            status: 'sent',
            sequence_no: 1,
            created_at: new Date().toISOString(),
            attachments: [
              { id: 'att-1', filename_display: 'photo.png', mime_type: 'image/png', size_bytes: 1024 },
            ],
          },
        ],
        total: 1,
      });

      // We need to provide a mock BackendContext for AssistantView to boot
      const mockContextValue = {
        isOnline: true,
        modelStatus: { model_loaded: true, router_running: true, active_model: 'llama' },
        registry: [{ id: 'llama', manifest: { id: 'llama' }, library_state: { available_capabilities: ['vision'] } }],
        loadModel: vi.fn(),
        isModelLoading: false,
      };

      const { useBackend } = await import('../context/BackendContext');
      vi.mocked(useBackend).mockReturnValue(mockContextValue as any);

      render(<AssistantView />);

      // We wait for the message content to appear which confirms loading is done
      await waitFor(() => {
        expect(screen.getByText('Check out this image')).toBeInTheDocument();
      });

      // It should also render the attachment preview
      await waitFor(() => {
        // Because of the mock, fetchAttachmentBlobUrl should have been called
        expect(api.fetchAttachmentBlobUrl).toHaveBeenCalledWith('conv-123', 'att-1');
      });
    });

    it('handles conversation switching cleanly, revoking old URLs and fetching new ones', async () => {
      vi.mocked(api.listConversations).mockResolvedValue({
        items: [
          { id: 'conv-A', title: 'Conv A', character_id: 'char-1', owner_id: 'user-1', created_at: '2023-01-01T00:00:00Z', updated_at: '2023-01-01T00:00:00Z' },
          { id: 'conv-B', title: 'Conv B', character_id: 'char-1', owner_id: 'user-1', created_at: '2023-01-02T00:00:00Z', updated_at: '2023-01-02T00:00:00Z' },
        ],
        total: 2,
      });

      vi.mocked(api.getMessages).mockImplementation(async (convId) => {
        if (convId === 'conv-A') {
          return {
            items: [{
              id: 'msg-A', conversation_id: 'conv-A', sender: 'user', content: 'Message A', status: 'sent', sequence_no: 1, created_at: '2023-01-01T00:00:00Z',
              attachments: [{ id: 'att-A', filename_display: 'A.png', mime_type: 'image/png', size_bytes: 1024 }],
            }],
            total: 1,
          };
        } else {
          return {
            items: [{
              id: 'msg-B', conversation_id: 'conv-B', sender: 'user', content: 'Message B', status: 'sent', sequence_no: 1, created_at: '2023-01-02T00:00:00Z',
              attachments: [{ id: 'att-B', filename_display: 'B.png', mime_type: 'image/png', size_bytes: 1024 }],
            }],
            total: 1,
          };
        }
      });

      const mockContextValue = {
        isOnline: true,
        modelStatus: { model_loaded: true, router_running: true, active_model: 'llama' },
        registry: [{ id: 'llama', manifest: { id: 'llama' }, library_state: { available_capabilities: ['vision'] } }],
        loadModel: vi.fn(),
        isModelLoading: false,
      };

      const { useBackend } = await import('../context/BackendContext');
      vi.mocked(useBackend).mockReturnValue(mockContextValue as any);

      render(<AssistantView />);

      // Wait for A to load
      await waitFor(() => {
        expect(screen.getByText('Message A')).toBeInTheDocument();
      });

      expect(api.fetchAttachmentBlobUrl).toHaveBeenCalledWith('conv-A', 'att-A');

      // Click history to switch to B
      const historyButton = screen.getByTitle('Open Conversation History');
      act(() => { historyButton.click(); });

      const convBButton = await screen.findByText('Conv B');
      act(() => { convBButton.click(); });

      // Wait for B to load
      await waitFor(() => {
        expect(screen.getByText('Message B')).toBeInTheDocument();
      });

      // Verify B fetch
      expect(api.fetchAttachmentBlobUrl).toHaveBeenCalledWith('conv-B', 'att-B');

      // Verify A is not visible
      expect(screen.queryByText('Message A')).not.toBeInTheDocument();

      // Verify A's blob was revoked (from the mocked 'blob:test-url')
      expect(revokeObjectURLMock).toHaveBeenCalledWith('blob:test-url');
    });
  });

  describe('ConversationMessageItem Rendering & Lifecycle', () => {
    const defaultAttachment = { id: 'att-1', filename_display: 'test.png', mime_type: 'image/png', size_bytes: 1234 };
    
    const renderMessageItem = (attachments = [defaultAttachment], activeConversationId = 'conv-123') => {
      const message: AssistantMessage = {
        id: 'msg-1',
        type: 'user',
        timestamp: '12:00 PM',
        content: 'Test message',
        attachments,
      };

      return render(
        <ConversationMessageItem
          message={message}
          activeConversationId={activeConversationId}
        />
      );
    };

    it('uses correct conversation + attachment IDs for preview fetching', async () => {
      let resolveFetch: (url: string) => void;
      vi.mocked(api.fetchAttachmentBlobUrl).mockReturnValue(new Promise((resolve) => {
        resolveFetch = resolve;
      }));

      renderMessageItem();

      expect(api.fetchAttachmentBlobUrl).toHaveBeenCalledWith('conv-123', 'att-1');

      await act(async () => {
        resolveFetch('blob:test-url-1');
      });

      const img = screen.getByAltText('test.png');
      expect(img).toBeInTheDocument();
      expect(img).toHaveAttribute('src', 'blob:test-url-1');
    });

    it('shows a safe fallback on preview failure', async () => {
      vi.mocked(api.fetchAttachmentBlobUrl).mockRejectedValue(new Error('Failed to load'));

      renderMessageItem();

      await waitFor(() => {
        // We verify the warning icon or the filename is displayed
        expect(screen.getByText('test.png')).toBeInTheDocument();
        // Since we can't easily query the Lucide icon, we verify the img tag is absent
        expect(screen.queryByRole('img')).not.toBeInTheDocument();
        // title="Preview unavailable" is in the fallback
        expect(screen.getByTitle('Preview unavailable')).toBeInTheDocument();
      });
    });

    it('handles unsupported MIME types safely without attempting image load', async () => {
      vi.mocked(api.fetchAttachmentBlobUrl).mockResolvedValue('blob:test-doc');

      renderMessageItem([
        { id: 'att-doc', filename_display: 'document.pdf', mime_type: 'application/pdf', size_bytes: 5000 }
      ]);

      await waitFor(() => {
        // Expecting the generic file fallback container
        expect(screen.getByTitle('document.pdf')).toBeInTheDocument();
        expect(screen.queryByRole('img')).not.toBeInTheDocument();
      });
    });

    it('does not fetch or render an img for an unexpected image MIME type like image/webp', async () => {
      renderMessageItem([
        { id: 'att-webp', filename_display: 'photo.webp', mime_type: 'image/webp', size_bytes: 5000 }
      ]);

      await waitFor(() => {
        expect(screen.getByTitle('photo.webp')).toBeInTheDocument();
        expect(screen.queryByRole('img')).not.toBeInTheDocument();
      });

      expect(api.fetchAttachmentBlobUrl).not.toHaveBeenCalled();
    });

    it('revokes owned Blob URLs on unmount', async () => {
      let resolveFetch: (url: string) => void;
      vi.mocked(api.fetchAttachmentBlobUrl).mockReturnValue(new Promise((resolve) => {
        resolveFetch = resolve;
      }));

      const { unmount } = renderMessageItem();

      await act(async () => {
        resolveFetch('blob:to-revoke');
      });

      await waitFor(() => {
        expect(screen.getByAltText('test.png')).toBeInTheDocument();
      });

      unmount();

      expect(revokeObjectURLMock).toHaveBeenCalledWith('blob:to-revoke');
    });

    it('immediately revokes a Blob URL returned AFTER unmount', async () => {
      let resolveFetch: (url: string) => void;
      vi.mocked(api.fetchAttachmentBlobUrl).mockReturnValue(new Promise((resolve) => {
        resolveFetch = resolve;
      }));

      const { unmount } = renderMessageItem();

      // Unmount before resolving the promise
      unmount();

      // Resolve it after unmount
      await act(async () => {
        resolveFetch('blob:late-arrival');
      });

      // The effect should catch this and immediately revoke the late url
      expect(revokeObjectURLMock).toHaveBeenCalledWith('blob:late-arrival');
    });
  });
});
