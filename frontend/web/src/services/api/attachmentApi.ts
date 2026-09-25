/**
 * Attachment API — upload, binary preview fetch, and delete for multimodal conversation attachments.
 * Phase 8B.6 — Master Plan §16.4
 */
import { getApiBaseUrl, getApiKey, apiFetch, ApiError } from './client';

// Canonical attachment constraints matching backend schemas
export const ALLOWED_MIME_TYPES = ['image/png', 'image/jpeg'] as const;
export const MAX_SIZE_BYTES = 10 * 1024 * 1024; // 10 MiB raw file ceiling
export const MAX_ATTACHMENTS_PER_MESSAGE = 4;   // Max staged attachments per turn

export interface AttachmentOut {
  id: string;
  conversation_id: string;
  message_id: string | null;
  filename_display: string;
  mime_type: string;
  size_bytes: number;
  image_width: number | null;
  image_height: number | null;
  created_at: string;
}

export interface AttachmentRef {
  id: string;
  filename_display: string;
  mime_type: string;
  size_bytes: number;
}

export async function uploadAttachment(
  conversationId: string,
  file: File,
): Promise<AttachmentOut> {
  const form = new FormData();
  form.append('file', file);

  return apiFetch<AttachmentOut>(
    `/api/v1/conversations/${encodeURIComponent(conversationId)}/attachments`,
    {
      method: 'POST',
      body: form,
    },
  );
}

export async function fetchAttachmentBlobUrl(
  conversationId: string,
  attachmentId: string,
): Promise<string> {
  const baseUrl = getApiBaseUrl();
  const apiKey = getApiKey();
  const url = `${baseUrl}/api/v1/conversations/${encodeURIComponent(conversationId)}/attachments/${encodeURIComponent(attachmentId)}/preview`;

  const headers = new Headers();
  if (apiKey) {
    headers.set('Authorization', `Bearer ${apiKey}`);
  }

  const response = await fetch(url, {
    method: 'GET',
    headers,
  });

  if (!response.ok) {
    throw new ApiError({
      code: 'ATTACHMENT_PREVIEW_FAILED',
      message: `Failed to fetch attachment preview (${response.status})`,
      status: response.status,
    });
  }

  const blob = await response.blob();
  return URL.createObjectURL(blob);
}

export async function deleteAttachment(
  conversationId: string,
  attachmentId: string,
): Promise<void> {
  await apiFetch<void>(
    `/api/v1/conversations/${encodeURIComponent(conversationId)}/attachments/${encodeURIComponent(attachmentId)}`,
    {
      method: 'DELETE',
    },
  );
}
