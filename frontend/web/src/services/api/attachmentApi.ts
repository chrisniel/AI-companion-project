/**
 * Attachment API — upload, binary fetch, and delete for multimodal conversation attachments.
 * Phase 8B.6 — Master Plan §16.4
 */
import { getApiBaseUrl, getApiKey, ApiError } from './client';

export interface AttachmentOut {
  id: string;
  conversation_id: string;
  message_id: string | null;
  file_name: string;
  content_type: string;
  byte_size: number;
  sha256: string;
  created_at: string;
}

export async function uploadAttachment(
  conversationId: string,
  file: File,
): Promise<AttachmentOut> {
  const baseUrl = getApiBaseUrl();
  const apiKey = getApiKey();
  const url = `${baseUrl}/api/v1/conversations/${conversationId}/attachments`;

  const formData = new FormData();
  formData.append('file', file);

  const headers: Record<string, string> = {};
  if (apiKey) {
    headers['Authorization'] = `Bearer ${apiKey}`;
  }
  // Note: Never set 'Content-Type': 'multipart/form-data' manually,
  // allowing the browser to append the required boundary string.

  const response = await fetch(url, {
    method: 'POST',
    headers,
    body: formData,
  });

  if (!response.ok) {
    let message = `Upload failed with status ${response.status}`;
    try {
      const err = await response.json();
      message = err.detail || err.error?.message || message;
    } catch {
      // Use fallback
    }
    throw new ApiError({
      code: 'ATTACHMENT_UPLOAD_FAILED',
      message,
      status: response.status,
    });
  }

  return response.json();
}

export async function fetchAttachmentBlobUrl(
  conversationId: string,
  attachmentId: string,
): Promise<string> {
  const baseUrl = getApiBaseUrl();
  const apiKey = getApiKey();
  const url = `${baseUrl}/api/v1/conversations/${conversationId}/attachments/${attachmentId}`;

  const headers: Record<string, string> = {};
  if (apiKey) {
    headers['Authorization'] = `Bearer ${apiKey}`;
  }

  const response = await fetch(url, {
    method: 'GET',
    headers,
  });

  if (!response.ok) {
    throw new ApiError({
      code: 'ATTACHMENT_FETCH_FAILED',
      message: `Failed to fetch attachment binary (${response.status})`,
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
  const baseUrl = getApiBaseUrl();
  const apiKey = getApiKey();
  const url = `${baseUrl}/api/v1/conversations/${conversationId}/attachments/${attachmentId}`;

  const headers: Record<string, string> = {};
  if (apiKey) {
    headers['Authorization'] = `Bearer ${apiKey}`;
  }

  const response = await fetch(url, {
    method: 'DELETE',
    headers,
  });

  if (!response.ok && response.status !== 404) {
    throw new ApiError({
      code: 'ATTACHMENT_DELETE_FAILED',
      message: `Failed to delete attachment (${response.status})`,
      status: response.status,
    });
  }
}
