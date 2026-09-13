/**
 * Memory API client for user facts, preferences, and context.
 */

import { apiFetch } from './client';

export interface MemoryOut {
  id: string;
  content: string;
  category: string;
  importance: number;
  source_type: string;
  user_verified: boolean;
  created_at: string;
  owner_id: string;
}

export interface MemoryListOut {
  items: MemoryOut[];
  total: number;
  page: number;
  page_size: number;
}

export async function listMemories(
  category?: string,
  skip: number = 0,
  limit: number = 50
): Promise<MemoryListOut> {
  const query = new URLSearchParams({ skip: String(skip), limit: String(limit) });
  if (category) {
    query.set('category', category);
  }
  return apiFetch<MemoryListOut>(`/api/v1/memories?${query.toString()}`, {
    method: 'GET',
  });
}

export async function createMemory(
  content: string,
  category: 'fact' | 'preference' | 'context' = 'fact',
  importance: number = 1.0
): Promise<MemoryOut> {
  return apiFetch<MemoryOut>('/api/v1/memories', {
    method: 'POST',
    body: JSON.stringify({ content, category, importance }),
  });
}

export async function updateMemory(
  id: string,
  updates: { content?: string; category?: 'fact' | 'preference' | 'context'; importance?: number }
): Promise<MemoryOut> {
  return apiFetch<MemoryOut>(`/api/v1/memories/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(updates),
  });
}

export async function deleteMemory(id: string): Promise<void> {
  return apiFetch<void>(`/api/v1/memories/${id}`, {
    method: 'DELETE',
  });
}
