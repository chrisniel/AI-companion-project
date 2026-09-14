/**
 * Task Management API adapter for Local AI Companion Core.
 * Adheres strictly to backend /api/v1/tasks contract and types.
 */

import { apiFetch } from './client';

export type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'cancelled';
export type TaskPriority = 'low' | 'medium' | 'high' | 'urgent';
export type TaskCategory =
  | 'general'
  | 'work'
  | 'personal'
  | 'dev'
  | 'shopping'
  | 'health';

export interface TaskResponse {
  id: string;
  owner_id: string;
  title: string;
  notes?: string | null;
  category: TaskCategory;
  status: TaskStatus;
  priority: TaskPriority;
  due_date?: string | null;
  reminder_minutes_before?: number | null;
  reminder_at?: string | null;
  is_deleted: boolean;
  deleted_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface TaskCreatePayload {
  title: string;
  notes?: string | null;
  category: TaskCategory;
  priority: TaskPriority;
  due_date?: string | null;
  reminder_minutes_before?: number | null;
  reminder_at?: string | null;
}

export interface TaskUpdatePayload {
  title?: string;
  notes?: string | null;
  category?: TaskCategory;
  status?: TaskStatus;
  priority?: TaskPriority;
  due_date?: string | null;
  reminder_minutes_before?: number | null;
  reminder_at?: string | null;
}

export interface TaskListResponse {
  items: TaskResponse[];
  total: number;
}

export interface TaskListFilters {
  status?: TaskStatus;
  priority?: TaskPriority;
  category?: TaskCategory;
  skip?: number;
  limit?: number;
}

/**
 * Retrieve a paginated list of active tasks with optional server-side filtering.
 */
export async function listTasks(filters?: TaskListFilters): Promise<TaskListResponse> {
  const query = new URLSearchParams();
  if (filters?.status) query.set('status', filters.status);
  if (filters?.priority) query.set('priority', filters.priority);
  if (filters?.category) query.set('category', filters.category);
  if (filters?.skip !== undefined) query.set('skip', String(filters.skip));
  if (filters?.limit !== undefined) query.set('limit', String(filters.limit));

  const qs = query.toString();
  return apiFetch<TaskListResponse>(`/api/v1/tasks${qs ? `?${qs}` : ''}`);
}

/**
 * Create a new task item scoped to the authenticated owner.
 */
export async function createTask(payload: TaskCreatePayload): Promise<TaskResponse> {
  return apiFetch<TaskResponse>('/api/v1/tasks', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

/**
 * Partially update an existing task.
 */
export async function updateTask(
  taskId: string,
  payload: TaskUpdatePayload
): Promise<TaskResponse> {
  return apiFetch<TaskResponse>(`/api/v1/tasks/${encodeURIComponent(taskId)}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

/**
 * Soft delete an active task into the Recycle Bin.
 */
export async function deleteTask(taskId: string): Promise<void> {
  await apiFetch<void>(`/api/v1/tasks/${encodeURIComponent(taskId)}`, {
    method: 'DELETE',
  });
}

export const taskApi = {
  listTasks,
  createTask,
  updateTask,
  deleteTask,
};

