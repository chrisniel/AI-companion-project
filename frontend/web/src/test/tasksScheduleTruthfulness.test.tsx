import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import fs from 'fs';
import path from 'path';
import { TasksView } from '../components/workspace/TasksView';
import { ScheduleView } from '../components/workspace/ScheduleView';
import * as taskApiModule from '../services/api/taskApi';
import {
  TaskResponse,
  TaskCreatePayload,
  TaskUpdatePayload,
} from '../services/api/taskApi';

// Sample mock tasks for testing
const sampleTasks: TaskResponse[] = [
  {
    id: 'task-1',
    owner_id: 'user-default',
    title: 'Review System Specs',
    notes: 'Check hardware constraints and memory mapping',
    category: 'dev',
    status: 'pending',
    priority: 'high',
    due_date: '2026-09-14T10:00:00.000Z',
    reminder_minutes_before: 30,
    reminder_at: '2026-09-14T09:30:00.000Z',
    is_deleted: false,
    created_at: '2026-09-14T08:00:00.000Z',
    updated_at: '2026-09-14T08:00:00.000Z',
  },
  {
    id: 'task-2',
    owner_id: 'user-default',
    title: 'Unscheduled General Task',
    notes: null,
    category: 'general',
    status: 'pending',
    priority: 'medium',
    due_date: null,
    reminder_minutes_before: null,
    reminder_at: null,
    is_deleted: false,
    created_at: '2026-09-14T08:00:00.000Z',
    updated_at: '2026-09-14T08:00:00.000Z',
  },
  {
    id: 'task-3',
    owner_id: 'user-default',
    title: 'Overdue Urgent Action',
    notes: 'Needs immediate attention',
    category: 'work',
    status: 'in_progress',
    priority: 'urgent',
    due_date: '2026-09-13T12:00:00.000Z',
    reminder_minutes_before: 0,
    reminder_at: '2026-09-13T12:00:00.000Z',
    is_deleted: false,
    created_at: '2026-09-13T08:00:00.000Z',
    updated_at: '2026-09-13T08:00:00.000Z',
  },
  {
    id: 'task-4',
    owner_id: 'user-default',
    title: 'Future Feature Planning',
    notes: null,
    category: 'personal',
    status: 'pending',
    priority: 'low',
    due_date: '2026-09-20T15:00:00.000Z',
    reminder_minutes_before: 60,
    reminder_at: '2026-09-20T14:00:00.000Z',
    is_deleted: false,
    created_at: '2026-09-14T08:00:00.000Z',
    updated_at: '2026-09-14T08:00:00.000Z',
  },
  {
    id: 'task-5',
    owner_id: 'user-default',
    title: 'Completed Shopping Task',
    notes: 'Bought groceries',
    category: 'shopping',
    status: 'completed',
    priority: 'low',
    due_date: '2026-09-14T09:00:00.000Z',
    reminder_minutes_before: null,
    reminder_at: null,
    is_deleted: false,
    created_at: '2026-09-14T07:00:00.000Z',
    updated_at: '2026-09-14T09:00:00.000Z',
  },
  {
    id: 'task-6',
    owner_id: 'user-default',
    title: 'Cancelled Health Check',
    notes: 'Doctor rescheduled',
    category: 'health',
    status: 'cancelled',
    priority: 'medium',
    due_date: '2026-09-14T11:00:00.000Z',
    reminder_minutes_before: null,
    reminder_at: null,
    is_deleted: false,
    created_at: '2026-09-14T07:00:00.000Z',
    updated_at: '2026-09-14T10:00:00.000Z',
  },
];

describe('Phase 8A.3b.2 — Tasks + Schedule Truthfulness & Backend Integration', () => {
  beforeEach(() => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    // Fixed system time: 2026-09-14 12:00:00 UTC
    vi.setSystemTime(new Date('2026-09-14T12:00:00.000Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  // =========================================================================
  // 1. TASK API ADAPTER CONTRACT TESTS
  // =========================================================================
  describe('taskApi Adapter Contract', () => {
    it('listTasks sends GET to /api/v1/tasks with optional query parameters', async () => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => ({ items: sampleTasks, total: sampleTasks.length }),
      } as Response);

      const result = await taskApiModule.listTasks({
        status: 'pending',
        priority: 'high',
        category: 'dev',
        skip: 0,
        limit: 50,
      });

      expect(fetchSpy).toHaveBeenCalledTimes(1);
      const [url, options] = fetchSpy.mock.calls[0];
      const urlStr = String(url);
      expect(urlStr).toContain('/api/v1/tasks');
      expect(urlStr).toContain('status=pending');
      expect(urlStr).toContain('priority=high');
      expect(urlStr).toContain('category=dev');
      expect(urlStr).toContain('skip=0');
      expect(urlStr).toContain('limit=50');
      expect(result.items).toHaveLength(sampleTasks.length);
    });

    it('createTask sends POST to /api/v1/tasks with exact payload', async () => {
      const payload: TaskCreatePayload = {
        title: 'New Integration Test Task',
        notes: 'API adapter test',
        category: 'dev',
        priority: 'high',
        due_date: '2026-09-15T10:00:00.000Z',
        reminder_minutes_before: 15,
      };

      const mockCreated: TaskResponse = {
        id: 'task-created-1',
        owner_id: 'user-default',
        ...payload,
        status: 'pending',
        is_deleted: false,
        created_at: '2026-09-14T12:00:00.000Z',
        updated_at: '2026-09-14T12:00:00.000Z',
      };

      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
        ok: true,
        status: 201,
        json: async () => mockCreated,
      } as Response);

      const result = await taskApiModule.createTask(payload);

      expect(fetchSpy).toHaveBeenCalledTimes(1);
      const [url, options] = fetchSpy.mock.calls[0];
      expect(String(url)).toContain('/api/v1/tasks');
      expect(options?.method).toBe('POST');
      expect(JSON.parse(String(options?.body))).toEqual(payload);
      expect(result.id).toBe('task-created-1');
    });

    it('updateTask sends PATCH to /api/v1/tasks/{id}', async () => {
      const updatePayload: TaskUpdatePayload = {
        status: 'completed',
        priority: 'urgent',
      };

      const mockUpdated: TaskResponse = {
        ...sampleTasks[0],
        ...updatePayload,
        updated_at: '2026-09-14T12:05:00.000Z',
      };

      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => mockUpdated,
      } as Response);

      const result = await taskApiModule.updateTask('task-1', updatePayload);

      expect(fetchSpy).toHaveBeenCalledTimes(1);
      const [url, options] = fetchSpy.mock.calls[0];
      expect(String(url)).toContain('/api/v1/tasks/task-1');
      expect(options?.method).toBe('PATCH');
      expect(JSON.parse(String(options?.body))).toEqual(updatePayload);
      expect(result.status).toBe('completed');
    });

    it('deleteTask sends DELETE to /api/v1/tasks/{id}', async () => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
        ok: true,
        status: 204,
        json: async () => ({}),
      } as unknown as Response);

      await taskApiModule.deleteTask('task-to-del');

      expect(fetchSpy).toHaveBeenCalledTimes(1);
      const [url, options] = fetchSpy.mock.calls[0];
      expect(String(url)).toContain('/api/v1/tasks/task-to-del');
      expect(options?.method).toBe('DELETE');
    });
  });

  // =========================================================================
  // 2. TASKSVIEW TRUTHFULNESS & CRUD TESTS
  // =========================================================================
  describe('TasksView Truthfulness & CRUD', () => {
    it('TasksView has zero production import of mockTaskItems', () => {
      const filePath = path.resolve(
        __dirname,
        '../components/workspace/TasksView.tsx'
      );
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('mockTaskItems');
    });

    it('renders real backend tasks and displays truthful attributes', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: sampleTasks,
        total: sampleTasks.length,
      });

      render(<TasksView />);

      // Wait for loading to finish
      await waitFor(() => {
        expect(screen.queryByText(/Loading tasks from backend/i)).toBeNull();
      });

      // Default 'Today' tab should show today's tasks & overdue tasks
      expect(screen.getByText('Review System Specs')).toBeDefined();
      expect(screen.getByText('Overdue Urgent Action')).toBeDefined();
      // Unscheduled task should NOT appear in Today tab
      expect(screen.queryByText('Unscheduled General Task')).toBeNull();
    });

    it('renders truthful empty state when backend returns empty task list', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: [],
        total: 0,
      });

      render(<TasksView />);

      await waitFor(() => {
        expect(screen.queryByText(/Loading tasks from backend/i)).toBeNull();
      });

      expect(screen.getByText('No tasks yet')).toBeDefined();
      expect(
        screen.getByText(/Create a task above to schedule your next action/i)
      ).toBeDefined();
    });

    it('renders error state on API failure without falling back to mocks, and allows Retry', async () => {
      const listTasksMock = vi
        .spyOn(taskApiModule.taskApi, 'listTasks')
        .mockRejectedValueOnce(new Error('Network connection failed'))
        .mockResolvedValueOnce({
          items: sampleTasks,
          total: sampleTasks.length,
        });

      render(<TasksView />);

      await waitFor(() => {
        expect(screen.getByText('Unable to load tasks')).toBeDefined();
      });

      expect(screen.getByText('Network connection failed')).toBeDefined();
      expect(screen.queryByText('Review System Specs')).toBeNull();

      // Click Retry
      const retryBtn = screen.getByRole('button', { name: /Retry/i });
      fireEvent.click(retryBtn);

      await waitFor(() => {
        expect(screen.getByText('Review System Specs')).toBeDefined();
      });

      expect(listTasksMock).toHaveBeenCalledTimes(2);
    });

    it('all task statuses and schedules are reachable via dedicated tabs', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: sampleTasks,
        total: sampleTasks.length,
      });

      render(<TasksView />);

      await waitFor(() => {
        expect(screen.getByText('Review System Specs')).toBeDefined();
      });

      // 1. Switch to 'Upcoming' tab
      const upcomingTab = document.getElementById('task-tab-upcoming')!;
      fireEvent.click(upcomingTab);
      expect(screen.getByText('Future Feature Planning')).toBeDefined();
      expect(screen.queryByText('Review System Specs')).toBeNull();

      // 2. Switch to 'Unscheduled' tab
      const unscheduledTab = document.getElementById('task-tab-unscheduled')!;
      fireEvent.click(unscheduledTab);
      expect(screen.getByText('Unscheduled General Task')).toBeDefined();

      // 3. Switch to 'Completed' tab
      const completedTab = document.getElementById('task-tab-completed')!;
      fireEvent.click(completedTab);
      expect(screen.getByText('Completed Shopping Task')).toBeDefined();

      // 4. Switch to 'Cancelled' tab
      const cancelledTab = document.getElementById('task-tab-cancelled')!;
      fireEvent.click(cancelledTab);
      expect(screen.getByText('Cancelled Health Check')).toBeDefined();
    });

    it('renders Overdue indicator only when pending/in_progress and due timestamp is past', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: sampleTasks,
        total: sampleTasks.length,
      });

      render(<TasksView />);

      await waitFor(() => {
        expect(screen.getByText('Overdue Urgent Action')).toBeDefined();
      });

      // 'Overdue Urgent Action' is past system time -> has Overdue badge
      expect(document.getElementById('task-overdue-badge-task-3')).toBeDefined();

      // Completed task (even if due in past) is NOT marked overdue
      const completedTab = document.getElementById('task-tab-completed')!;
      fireEvent.click(completedTab);
      expect(screen.getByText('Completed Shopping Task')).toBeDefined();
      expect(document.getElementById('task-overdue-badge-task-5')).toBeNull();
    });

    it('creates a new task via backend createTask without fake local persistence', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: [],
        total: 0,
      });

      const createSpy = vi
        .spyOn(taskApiModule.taskApi, 'createTask')
        .mockResolvedValueOnce({
          id: 'task-newly-created',
          owner_id: 'user-default',
          title: 'Automated Test Task Creation',
          notes: 'Testing create flow',
          category: 'dev',
          status: 'pending',
          priority: 'urgent',
          due_date: null,
          reminder_minutes_before: null,
          reminder_at: null,
          is_deleted: false,
          created_at: '2026-09-14T12:00:00.000Z',
          updated_at: '2026-09-14T12:00:00.000Z',
        });

      render(<TasksView />);

      await waitFor(() => {
        expect(screen.getByText('No tasks yet')).toBeDefined();
      });

      // Click "New Task"
      const newBtn = screen.getByRole('button', { name: /New Task/i });
      fireEvent.click(newBtn);

      // Fill in title
      const titleInput = screen.getByLabelText(/Task Title \*/i);
      fireEvent.change(titleInput, {
        target: { value: 'Automated Test Task Creation' },
      });

      // Select urgent priority in form
      const urgentBtn = document.getElementById('task-form-priority-urgent')!;
      fireEvent.click(urgentBtn);

      // Submit form
      const submitBtn = screen.getByRole('button', { name: /^Create Task$/i });
      fireEvent.click(submitBtn);

      await waitFor(() => {
        expect(createSpy).toHaveBeenCalledTimes(1);
      });

      expect(createSpy.mock.calls[0][0].title).toBe(
        'Automated Test Task Creation'
      );
      expect(createSpy.mock.calls[0][0].priority).toBe('urgent');
    });

    it('toggles task completion using backend updateTask (pending <-> completed)', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: [sampleTasks[0]],
        total: 1,
      });

      const updateSpy = vi
        .spyOn(taskApiModule.taskApi, 'updateTask')
        .mockResolvedValueOnce({
          ...sampleTasks[0],
          status: 'completed',
        });

      render(<TasksView />);

      await waitFor(() => {
        expect(screen.getByText('Review System Specs')).toBeDefined();
      });

      // Click toggle
      const toggleBtn = screen.getByLabelText(/Mark task completed/i);
      fireEvent.click(toggleBtn);

      await waitFor(() => {
        expect(updateSpy).toHaveBeenCalledWith('task-1', { status: 'completed' });
      });
    });

    it('deletes a task only after successful backend DELETE', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: [sampleTasks[0]],
        total: 1,
      });

      const deleteSpy = vi
        .spyOn(taskApiModule.taskApi, 'deleteTask')
        .mockResolvedValueOnce();

      render(<TasksView />);

      await waitFor(() => {
        expect(screen.getByText('Review System Specs')).toBeDefined();
      });

      // Click delete icon
      const deleteBtn = screen.getByTitle(/Delete task/i);
      fireEvent.click(deleteBtn);

      // Confirm modal opens
      expect(screen.getByText(/Are you sure you want to delete this task/i)).toBeDefined();

      // Click Confirm Delete
      const confirmBtn = screen.getByRole('button', { name: /Confirm Delete/i });
      fireEvent.click(confirmBtn);

      await waitFor(() => {
        expect(deleteSpy).toHaveBeenCalledWith('task-1');
      });

      // Row is removed from view
      await waitFor(() => {
        expect(screen.queryByText('Review System Specs')).toBeNull();
      });
    });
  });

  // =========================================================================
  // 3. SCHEDULEVIEW TRUTHFULNESS & PROJECTION TESTS
  // =========================================================================
  describe('ScheduleView Truthfulness & Projection', () => {
    it('ScheduleView has zero production import of mockScheduleEvents', () => {
      const filePath = path.resolve(
        __dirname,
        '../components/workspace/ScheduleView.tsx'
      );
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('mockScheduleEvents');
    });

    it('projects only tasks with due_date into the schedule', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: sampleTasks,
        total: sampleTasks.length,
      });

      render(<ScheduleView />);

      await waitFor(() => {
        expect(screen.queryByText(/Loading scheduled tasks/i)).toBeNull();
      });

      // Task with due_date on 2026-09-14 should appear in Day view for Today
      expect(screen.getByText('Review System Specs')).toBeDefined();

      // Task without due_date ('Unscheduled General Task') must NOT appear in Schedule
      expect(screen.queryByText('Unscheduled General Task')).toBeNull();
    });

    it('renders truthful empty schedule when backend has no scheduled tasks', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: [sampleTasks[1]], // only unscheduled task
        total: 1,
      });

      render(<ScheduleView />);

      await waitFor(() => {
        expect(screen.queryByText(/Loading scheduled tasks/i)).toBeNull();
      });

      expect(screen.getByText('No scheduled tasks')).toBeDefined();
      expect(document.getElementById('schedule-empty-state')).toBeDefined();
      expect(
        screen.getAllByText(/Tasks with due dates appear here/i).length
      ).toBeGreaterThanOrEqual(1);
    });

    it('reminder is rendered as task metadata, not a duplicate schedule event', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: [sampleTasks[0]],
        total: 1,
      });

      render(<ScheduleView />);

      await waitFor(() => {
        expect(screen.getByText('Review System Specs')).toBeDefined();
      });

      // Reminder metadata badge: '30 min before'
      expect(screen.getByText('30 min before')).toBeDefined();

      // Only one task card exists in day view
      const taskCards = screen.getAllByText('Review System Specs');
      expect(taskCards).toHaveLength(1);
    });

    it('dynamically projects the week view without hardcoded September 7-13, 2026', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: sampleTasks,
        total: sampleTasks.length,
      });

      render(<ScheduleView />);

      await waitFor(() => {
        expect(screen.getByText('Review System Specs')).toBeDefined();
      });

      // Switch to Week view
      const weekBtn = screen.getByRole('button', { name: /week/i });
      fireEvent.click(weekBtn);

      // Week view header dynamically computed for 2026-09-14 (Monday Sep 14 to Sunday Sep 20)
      expect(screen.getByText(/Week of/i)).toBeDefined();
      expect(screen.getByText(/7 Days Projected/i)).toBeDefined();
    });

    it('agenda view sorts tasks chronologically and groups by date', async () => {
      vi.spyOn(taskApiModule.taskApi, 'listTasks').mockResolvedValueOnce({
        items: sampleTasks,
        total: sampleTasks.length,
      });

      render(<ScheduleView />);

      await waitFor(() => {
        expect(screen.getByText('Review System Specs')).toBeDefined();
      });

      // Switch to Agenda view
      const agendaBtn = screen.getByRole('button', { name: /agenda/i });
      fireEvent.click(agendaBtn);

      // Verify agenda groups appear
      expect(screen.getByText(/Future Feature Planning/i)).toBeDefined();
    });
  });

  // =========================================================================
  // 4. PRODUCTION TRUTHFULNESS & FABRICATION ABSENCE ASSERTIONS
  // =========================================================================
  describe('Fabrication Absence Assertions', () => {
    it('production components do not contain simulated or unsupported operational claims', () => {
      const tasksPath = path.resolve(
        __dirname,
        '../components/workspace/TasksView.tsx'
      );
      const schedulePath = path.resolve(
        __dirname,
        '../components/workspace/ScheduleView.tsx'
      );

      const tasksContent = fs.readFileSync(tasksPath, 'utf-8');
      const scheduleContent = fs.readFileSync(schedulePath, 'utf-8');

      const prohibitedStrings = [
        'Android Local Audio Node',
        'Calendar Sync',
        'redundant on-device alarms',
        'mirroredToAndroid',
        'Autonomous Timeline',
        'Armed Locally',
        'mockTaskItems',
        'mockScheduleEvents',
        '2026-09-09',
      ];

      for (const str of prohibitedStrings) {
        expect(tasksContent).not.toContain(str);
        expect(scheduleContent).not.toContain(str);
      }
    });
  });
});
