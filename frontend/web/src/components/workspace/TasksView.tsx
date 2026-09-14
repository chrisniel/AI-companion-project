import React, { useState, useEffect, useMemo, useCallback } from 'react';
import {
  CheckSquare,
  Plus,
  Clock,
  Bell,
  Edit3,
  Trash2,
  Tag,
  AlertCircle,
  Flame,
  Check,
  RotateCcw,
  Loader2,
  Calendar,
  AlertTriangle,
} from 'lucide-react';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { SearchInput } from '../ui/SearchInput';
import { Modal } from '../ui/Modal';
import { TextInput } from '../ui/TextInput';
import { Select } from '../ui/Select';
import {
  taskApi,
  TaskResponse,
  TaskStatus,
  TaskPriority,
  TaskCategory,
} from '../../services/api';
import {
  getLocalDateString,
  getLocalTimeString,
  formatLocalDate,
  formatLocalTime,
  parseIsoToLocal,
  combineLocalDateAndTimeToIso,
  isOverdue,
  getReminderLabel,
} from '../../utils/dateUtils';

export type TaskViewTab = 'today' | 'upcoming' | 'unscheduled' | 'completed' | 'cancelled';

const CATEGORY_OPTIONS: { label: string; value: TaskCategory | 'all' }[] = [
  { label: 'All', value: 'all' },
  { label: 'General', value: 'general' },
  { label: 'Work', value: 'work' },
  { label: 'Personal', value: 'personal' },
  { label: 'Dev', value: 'dev' },
  { label: 'Shopping', value: 'shopping' },
  { label: 'Health', value: 'health' },
];

const PRIORITIES: { label: string; value: TaskPriority | 'all' }[] = [
  { label: 'All', value: 'all' },
  { label: 'Urgent', value: 'urgent' },
  { label: 'High', value: 'high' },
  { label: 'Medium', value: 'medium' },
  { label: 'Low', value: 'low' },
];

const REMINDER_OPTIONS: { label: string; value: number | null }[] = [
  { label: 'None', value: null },
  { label: 'At due time', value: 0 },
  { label: '15 minutes before', value: 15 },
  { label: '30 minutes before', value: 30 },
  { label: '1 hour before', value: 60 },
  { label: '1 day before', value: 1440 },
];

interface TasksViewProps {
  initialTasks?: TaskResponse[];
}

export const TasksView: React.FC<TasksViewProps> = ({ initialTasks }) => {
  const [tasks, setTasks] = useState<TaskResponse[]>(initialTasks ?? []);
  const [isLoading, setIsLoading] = useState(!initialTasks);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [mutatingTaskId, setMutatingTaskId] = useState<string | null>(null);

  const [currentTab, setCurrentTab] = useState<TaskViewTab>('today');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<TaskCategory | 'all'>('all');
  const [selectedPriority, setSelectedPriority] = useState<TaskPriority | 'all'>('all');

  // Modal states
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [editingTask, setEditingTask] = useState<TaskResponse | null>(null);
  const [taskToDelete, setTaskToDelete] = useState<TaskResponse | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  // Task form fields
  const [formTitle, setFormTitle] = useState('');
  const [formNotes, setFormNotes] = useState('');
  const [formCategory, setFormCategory] = useState<TaskCategory>('general');
  const [formPriority, setFormPriority] = useState<TaskPriority>('medium');
  const [formStatus, setFormStatus] = useState<TaskStatus>('pending');
  const [formHasDueDate, setFormHasDueDate] = useState(false);
  const [formDueDate, setFormDueDate] = useState('');
  const [formDueTime, setFormDueTime] = useState('12:00');
  const [formReminderMinutesBefore, setFormReminderMinutesBefore] = useState<number | null>(null);
  const [formError, setFormError] = useState('');

  // Fetch tasks from backend
  const loadTasks = useCallback(async () => {
    setIsLoading(true);
    setLoadError(null);
    try {
      const res = await taskApi.listAllTasks();
      setTasks(res.items);
    } catch (err: any) {
      setLoadError(err.message || 'Failed to load tasks from backend');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!initialTasks) {
      loadTasks();
    }
  }, [loadTasks, initialTasks]);

  const todayDateStr = getLocalDateString();

  // Tab counts
  const counts = useMemo(() => {
    let today = 0;
    let upcoming = 0;
    let unscheduled = 0;
    let completed = 0;
    let cancelled = 0;

    for (const t of tasks) {
      if (t.status === 'completed') {
        completed++;
      } else if (t.status === 'cancelled') {
        cancelled++;
      } else if (t.status === 'pending' || t.status === 'in_progress') {
        if (!t.due_date) {
          unscheduled++;
        } else {
          const { dateStr } = parseIsoToLocal(t.due_date);
          if (dateStr <= todayDateStr) {
            today++;
          } else {
            upcoming++;
          }
        }
      }
    }
    return { today, upcoming, unscheduled, completed, cancelled };
  }, [tasks, todayDateStr]);

  // Filtered tasks
  const filteredTasks = useMemo(() => {
    return tasks.filter((task) => {
      // 1. Tab view filter
      if (currentTab === 'today') {
        if (task.status !== 'pending' && task.status !== 'in_progress') return false;
        if (!task.due_date) return false;
        const { dateStr } = parseIsoToLocal(task.due_date);
        if (dateStr > todayDateStr) return false;
      } else if (currentTab === 'upcoming') {
        if (task.status !== 'pending' && task.status !== 'in_progress') return false;
        if (!task.due_date) return false;
        const { dateStr } = parseIsoToLocal(task.due_date);
        if (dateStr <= todayDateStr) return false;
      } else if (currentTab === 'unscheduled') {
        if (task.status !== 'pending' && task.status !== 'in_progress') return false;
        if (task.due_date) return false;
      } else if (currentTab === 'completed') {
        if (task.status !== 'completed') return false;
      } else if (currentTab === 'cancelled') {
        if (task.status !== 'cancelled') return false;
      }

      // 2. Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesTitle = task.title.toLowerCase().includes(q);
        const matchesNotes = task.notes?.toLowerCase().includes(q) ?? false;
        const matchesCat = task.category.toLowerCase().includes(q);
        if (!matchesTitle && !matchesNotes && !matchesCat) return false;
      }

      // 3. Category filter
      if (selectedCategory !== 'all' && task.category !== selectedCategory) {
        return false;
      }

      // 4. Priority filter
      if (selectedPriority !== 'all' && task.priority !== selectedPriority) {
        return false;
      }

      return true;
    });
  }, [tasks, currentTab, todayDateStr, searchQuery, selectedCategory, selectedPriority]);

  // Complete / Reopen Toggle
  const handleToggleComplete = async (task: TaskResponse, e?: React.MouseEvent) => {
    e?.stopPropagation();
    setActionError(null);
    setMutatingTaskId(task.id);
    const nextStatus: TaskStatus = task.status === 'completed' ? 'pending' : 'completed';
    try {
      const updated = await taskApi.updateTask(task.id, { status: nextStatus });
      setTasks((prev) => prev.map((t) => (t.id === task.id ? updated : t)));
    } catch (err: any) {
      setActionError(err.message || 'Failed to update task status');
    } finally {
      setMutatingTaskId(null);
    }
  };

  // Open Create Modal
  const handleOpenCreate = () => {
    setEditingTask(null);
    setFormTitle('');
    setFormNotes('');
    setFormCategory('general');
    setFormPriority('medium');
    setFormStatus('pending');
    setFormHasDueDate(currentTab === 'today' || currentTab === 'upcoming');
    setFormDueDate(todayDateStr);
    setFormDueTime('12:00');
    setFormReminderMinutesBefore(null);
    setFormError('');
    setIsEditorOpen(true);
  };

  // Open Edit Modal
  const handleOpenEdit = (task: TaskResponse, e?: React.MouseEvent) => {
    e?.stopPropagation();
    setEditingTask(task);
    setFormTitle(task.title);
    setFormNotes(task.notes || '');
    setFormCategory(task.category);
    setFormPriority(task.priority);
    setFormStatus(task.status);
    if (task.due_date) {
      setFormHasDueDate(true);
      const { dateStr, timeStr } = parseIsoToLocal(task.due_date);
      setFormDueDate(dateStr);
      setFormDueTime(timeStr || '12:00');
      setFormReminderMinutesBefore(task.reminder_minutes_before ?? null);
    } else {
      setFormHasDueDate(false);
      setFormDueDate(todayDateStr);
      setFormDueTime('12:00');
      setFormReminderMinutesBefore(null);
    }
    setFormError('');
    setIsEditorOpen(true);
  };

  // Save Task (Create / Edit)
  const handleSaveTask = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formTitle.trim()) {
      setFormError('Task title is required.');
      return;
    }

    if (formHasDueDate) {
      if (!formDueDate || !formDueTime) {
        setFormError('Both local date and local time are required when due date is enabled.');
        return;
      }
    }

    setIsSubmitting(true);
    setFormError('');
    setActionError(null);

    const calculatedDueDate = formHasDueDate
      ? combineLocalDateAndTimeToIso(formDueDate, formDueTime)
      : null;

    const calculatedReminder = formHasDueDate ? formReminderMinutesBefore : null;

    try {
      if (editingTask) {
        // Update existing task
        const updated = await taskApi.updateTask(editingTask.id, {
          title: formTitle.trim(),
          notes: formNotes.trim() ? formNotes.trim() : null,
          category: formCategory,
          priority: formPriority,
          status: formStatus,
          due_date: calculatedDueDate,
          reminder_minutes_before: calculatedReminder,
        });
        setTasks((prev) => prev.map((t) => (t.id === editingTask.id ? updated : t)));
      } else {
        // Create new task
        const created = await taskApi.createTask({
          title: formTitle.trim(),
          notes: formNotes.trim() || undefined,
          category: formCategory,
          priority: formPriority,
          due_date: calculatedDueDate || undefined,
          reminder_minutes_before: calculatedReminder ?? undefined,
        });
        setTasks((prev) => [created, ...prev]);
      }
      setIsEditorOpen(false);
    } catch (err: any) {
      setFormError(err.message || 'Failed to save task.');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Delete Task
  const handleConfirmDelete = async () => {
    if (!taskToDelete) return;
    setIsDeleting(true);
    setActionError(null);
    try {
      await taskApi.deleteTask(taskToDelete.id);
      setTasks((prev) => prev.filter((t) => t.id !== taskToDelete.id));
      setTaskToDelete(null);
    } catch (err: any) {
      setActionError(err.message || 'Failed to delete task.');
    } finally {
      setIsDeleting(false);
    }
  };

  // Priority styling helper
  const getPriorityBadge = (priority: TaskPriority) => {
    switch (priority) {
      case 'urgent':
        return (
          <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-rose-600 dark:text-rose-400 bg-rose-500/10 border border-rose-500/20 px-2 py-0.5 rounded-md">
            <Flame className="w-3 h-3" /> Urgent
          </span>
        );
      case 'high':
        return (
          <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-amber-600 dark:text-amber-400 bg-amber-500/10 border border-amber-500/20 px-2 py-0.5 rounded-md">
            High
          </span>
        );
      case 'medium':
        return (
          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-sky-600 dark:text-sky-400 bg-sky-500/10 border border-sky-500/20 px-2 py-0.5 rounded-md">
            Medium
          </span>
        );
      case 'low':
        return (
          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-[var(--color-text-muted)] bg-slate-500/10 border border-[var(--color-border-subtle)] px-2 py-0.5 rounded-md">
            Low
          </span>
        );
    }
  };

  return (
    <div id="tasks-view" className="space-y-6">
      {/* 1. Header with Title & Primary Quick Action */}
      <div
        id="tasks-header-card"
        className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col sm:flex-row sm:items-center justify-between gap-4"
      >
        <div className="flex items-center gap-3.5">
          <div className="w-10 h-10 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0 shadow-sm">
            <CheckSquare className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-lg font-bold text-[var(--color-text-primary)] tracking-tight">
              Tasks
            </h1>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Authoritative local task manager backed by real SQLite storage.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2.5 self-end sm:self-auto">
          <NeumorphicButton
            id="create-task-btn"
            variant="primary"
            size="sm"
            onClick={handleOpenCreate}
            icon={<Plus className="w-3.5 h-3.5 text-white" />}
          >
            New Task
          </NeumorphicButton>
        </div>
      </div>

      {/* Global Action Error Alert */}
      {actionError && (
        <div
          id="task-action-error"
          className="p-3.5 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-600 dark:text-rose-400 text-xs flex items-center justify-between gap-3"
        >
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{actionError}</span>
          </div>
          <button
            type="button"
            onClick={() => setActionError(null)}
            className="text-xs font-semibold hover:underline cursor-pointer"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* 2. Controls Bar: Segmented Views, Search, and Selective Neumorphic Filters */}
      <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3.5">
        {/* Neumorphic Segmented Control for Views */}
        <div
          id="tasks-view-segmented-controls"
          className="flex items-center p-1 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] gap-1 flex-shrink-0 overflow-x-auto"
        >
          {(
            [
              { key: 'today', label: 'Today' },
              { key: 'upcoming', label: 'Upcoming' },
              { key: 'unscheduled', label: 'Unscheduled' },
              { key: 'completed', label: 'Completed' },
              { key: 'cancelled', label: 'Cancelled' },
            ] as const
          ).map((tab) => {
            const isSelected = currentTab === tab.key;
            const count = counts[tab.key];

            return (
              <button
                key={tab.key}
                id={`task-tab-${tab.key}`}
                type="button"
                onClick={() => setCurrentTab(tab.key)}
                className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-1.5 cursor-pointer select-none segmented-control-item whitespace-nowrap ${
                  isSelected
                    ? 'segmented-control-item-active'
                    : 'segmented-control-item-inactive'
                }`}
              >
                <span>{tab.label}</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono font-bold transition-colors ${
                    isSelected
                      ? 'bg-[var(--color-accent)]/15 text-[var(--color-accent)]'
                      : 'bg-black/5 dark:bg-white/5 text-[var(--color-text-muted)]'
                  }`}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        {/* Search Input */}
        <div className="flex-1 max-w-md">
          <SearchInput
            id="tasks-search-input"
            value={searchQuery}
            onChange={setSearchQuery}
            placeholder="Search tasks by title, notes, or category..."
          />
        </div>
      </div>

      {/* 3. Selective Filters Row (Categories & Priorities) */}
      <div className="flex flex-wrap items-center justify-between gap-3 text-xs">
        {/* Category Pills */}
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="text-[11px] font-semibold text-[var(--color-text-muted)] uppercase tracking-wider mr-1 select-none">
            Category:
          </span>
          {CATEGORY_OPTIONS.map((cat) => {
            const isCatActive = selectedCategory === cat.value;
            return (
              <button
                key={cat.value}
                id={`filter-category-${cat.value}`}
                type="button"
                onClick={() => setSelectedCategory(cat.value)}
                className={`px-2.5 py-1 rounded-lg text-xs font-medium cursor-pointer select-none segmented-control-item capitalize ${
                  isCatActive
                    ? 'segmented-control-item-active font-semibold shadow-xs'
                    : 'segmented-control-item-inactive'
                }`}
              >
                {cat.label}
              </button>
            );
          })}
        </div>

        {/* Priority Filter */}
        <div className="flex items-center gap-1.5">
          <span className="text-[11px] font-semibold text-[var(--color-text-muted)] uppercase tracking-wider mr-1 select-none">
            Priority:
          </span>
          {PRIORITIES.map((p) => {
            const isPrioActive = selectedPriority === p.value;
            return (
              <button
                key={p.value}
                id={`filter-priority-${p.value}`}
                type="button"
                onClick={() => setSelectedPriority(p.value)}
                className={`px-2.5 py-1 rounded-lg text-xs font-medium cursor-pointer select-none segmented-control-item ${
                  isPrioActive
                    ? 'segmented-control-item-active font-semibold'
                    : 'segmented-control-item-inactive'
                }`}
              >
                {p.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* 4. Task List Container */}
      <div
        id="tasks-list-container"
        className="rounded-2xl surface-raised border border-[var(--color-border-subtle)] divide-y divide-[var(--color-border-subtle)] overflow-hidden shadow-xs min-h-[140px]"
      >
        {/* Loading State */}
        {isLoading ? (
          <div
            id="tasks-loading-state"
            className="py-14 px-4 text-center flex flex-col items-center justify-center gap-3"
          >
            <Loader2 className="w-6 h-6 animate-spin text-[var(--color-accent)]" />
            <p className="text-xs font-medium text-[var(--color-text-secondary)]">
              Loading tasks from backend...
            </p>
          </div>
        ) : loadError ? (
          /* Error State with Retry */
          <div
            id="tasks-error-state"
            className="py-12 px-4 text-center flex flex-col items-center justify-center gap-3"
          >
            <div className="w-10 h-10 rounded-2xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-500">
              <AlertCircle className="w-5 h-5" />
            </div>
            <div className="space-y-1 max-w-sm">
              <p className="text-sm font-bold text-[var(--color-text-primary)]">
                Unable to load tasks
              </p>
              <p className="text-xs text-[var(--color-text-muted)]">{loadError}</p>
            </div>
            <NeumorphicButton
              id="tasks-retry-btn"
              size="sm"
              onClick={loadTasks}
              icon={<RotateCcw className="w-3.5 h-3.5" />}
            >
              Retry
            </NeumorphicButton>
          </div>
        ) : filteredTasks.length === 0 ? (
          /* Empty State */
          <div
            id="tasks-empty-state"
            className="py-12 px-4 text-center flex flex-col items-center justify-center gap-2.5"
          >
            <div className="w-10 h-10 rounded-2xl surface-recessed flex items-center justify-center text-[var(--color-text-muted)] border border-[var(--color-border-subtle)]">
              <CheckSquare className="w-5 h-5 opacity-60" />
            </div>
            <p className="text-sm font-semibold text-[var(--color-text-primary)]">
              {tasks.length === 0
                ? 'No tasks yet'
                : `No tasks found in ${currentTab} view`}
            </p>
            <p className="text-xs text-[var(--color-text-muted)] max-w-sm">
              {tasks.length === 0
                ? 'Create a task above to schedule your next action.'
                : searchQuery || selectedCategory !== 'all' || selectedPriority !== 'all'
                ? 'Try clearing active search or category filters to see more tasks.'
                : currentTab === 'completed'
                ? 'Completed tasks will be archived here once checked off.'
                : currentTab === 'cancelled'
                ? 'Cancelled tasks will appear here.'
                : currentTab === 'unscheduled'
                ? 'Tasks without a due date will appear here.'
                : 'All clear for this view!'}
            </p>
            {(searchQuery || selectedCategory !== 'all' || selectedPriority !== 'all') && (
              <button
                type="button"
                onClick={() => {
                  setSearchQuery('');
                  setSelectedCategory('all');
                  setSelectedPriority('all');
                }}
                className="mt-2 text-xs text-[var(--color-accent)] hover:underline cursor-pointer font-medium"
              >
                Reset active filters
              </button>
            )}
          </div>
        ) : (
          /* Task Rows */
          filteredTasks.map((task) => {
            const isCompleted = task.status === 'completed';
            const isCancelled = task.status === 'cancelled';
            const isInProgress = task.status === 'in_progress';
            const taskIsOverdue = isOverdue(task.due_date, task.status);
            const isMutating = mutatingTaskId === task.id;

            // Formatted date & time
            let dueDateDisplay = 'No deadline';
            let dueTimeDisplay = '';
            if (task.due_date) {
              const d = new Date(task.due_date);
              const { dateStr } = parseIsoToLocal(task.due_date);
              if (dateStr === todayDateStr) {
                dueDateDisplay = 'Today';
              } else {
                dueDateDisplay = formatLocalDate(d);
              }
              dueTimeDisplay = formatLocalTime(d);
            }

            const reminderLabel = getReminderLabel(task.reminder_minutes_before);

            return (
              <div
                key={task.id}
                id={`task-row-${task.id}`}
                className={`group px-3 sm:px-4 py-2.5 sm:py-3 flex items-center justify-between gap-3 transition-colors ${
                  isCompleted
                    ? 'bg-black/[0.02] dark:bg-white/[0.01] hover:bg-black/[0.04] dark:hover:bg-white/[0.02]'
                    : isCancelled
                    ? 'opacity-60 bg-black/[0.01] dark:bg-white/[0.005]'
                    : 'hover:bg-[var(--color-surface-secondary)]/40'
                }`}
              >
                {/* Left: Completion Control + Title + Badges */}
                <div className="flex items-center gap-3 min-w-0 flex-1">
                  {/* Completion Button */}
                  <button
                    id={`task-complete-toggle-${task.id}`}
                    type="button"
                    disabled={isMutating}
                    onClick={(e) => handleToggleComplete(task, e)}
                    aria-label={isCompleted ? 'Mark task pending' : 'Mark task completed'}
                    className={`w-5 h-5 rounded-lg flex items-center justify-center transition-all cursor-pointer flex-shrink-0 select-none ${
                      isCompleted
                        ? 'bg-emerald-500 text-white shadow-xs border border-emerald-600'
                        : isCancelled
                        ? 'surface-recessed border border-slate-400/40 text-slate-400'
                        : 'surface-recessed border border-[var(--color-border-subtle)] text-transparent hover:border-[var(--color-accent)] hover:text-[var(--color-accent)]/40'
                    }`}
                  >
                    {isMutating ? (
                      <Loader2 className="w-3 h-3 animate-spin text-[var(--color-accent)]" />
                    ) : (
                      <Check className={`w-3 h-3 ${isCompleted ? 'stroke-[2.5]' : ''}`} />
                    )}
                  </button>

                  {/* Task Text & Metadata */}
                  <div className="flex flex-col min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span
                        className={`text-sm tracking-tight font-medium truncate ${
                          isCompleted
                            ? 'line-through text-[var(--color-text-muted)] opacity-70'
                            : isCancelled
                            ? 'line-through text-[var(--color-text-muted)] opacity-60'
                            : 'text-[var(--color-text-primary)]'
                        }`}
                      >
                        {task.title}
                      </span>

                      {/* Status Badges */}
                      {isInProgress && (
                        <span className="text-[10px] font-semibold text-sky-600 dark:text-sky-400 bg-sky-500/10 border border-sky-500/20 px-1.5 py-0.2 rounded">
                          In Progress
                        </span>
                      )}

                      {isCancelled && (
                        <span className="text-[10px] font-semibold text-slate-500 bg-slate-500/10 border border-slate-500/20 px-1.5 py-0.2 rounded">
                          Cancelled
                        </span>
                      )}

                      {/* Priority Badge */}
                      <span className="flex-shrink-0">{getPriorityBadge(task.priority)}</span>

                      {/* Overdue Badge */}
                      {taskIsOverdue && (
                        <span
                          id={`task-overdue-badge-${task.id}`}
                          className="inline-flex items-center gap-1 text-[10px] font-bold text-rose-600 dark:text-rose-400 bg-rose-500/10 border border-rose-500/20 px-1.5 py-0.2 rounded"
                        >
                          <AlertTriangle className="w-2.5 h-2.5" /> Overdue
                        </span>
                      )}
                    </div>

                    {/* Secondary Row: Notes preview if any */}
                    {task.notes && (
                      <p className="text-xs text-[var(--color-text-secondary)] line-clamp-1 mt-0.5">
                        {task.notes}
                      </p>
                    )}

                    {/* Tertiary Row: Category, Due Date, Reminder */}
                    <div className="flex items-center gap-2.5 mt-0.5 text-[11px] text-[var(--color-text-muted)] flex-wrap">
                      <span className="inline-flex items-center gap-1 font-medium text-[var(--color-text-secondary)] capitalize">
                        <Tag className="w-3 h-3 opacity-60" /> {task.category}
                      </span>

                      <span>•</span>

                      <span className="inline-flex items-center gap-1 font-mono">
                        <Clock className="w-3 h-3 opacity-60" />
                        {dueDateDisplay}
                        {dueTimeDisplay ? ` at ${dueTimeDisplay}` : ''}
                      </span>

                      {reminderLabel && (
                        <>
                          <span>•</span>
                          <span className="inline-flex items-center gap-1 text-[var(--color-accent)] font-medium">
                            <Bell className="w-3 h-3" />
                            {reminderLabel}
                          </span>
                        </>
                      )}
                    </div>
                  </div>
                </div>

                {/* Right: Quick Action Controls */}
                <div className="flex items-center gap-1 opacity-80 group-hover:opacity-100 transition-opacity flex-shrink-0">
                  <button
                    id={`task-edit-btn-${task.id}`}
                    type="button"
                    onClick={(e) => handleOpenEdit(task, e)}
                    title="Edit task"
                    className="w-7 h-7 rounded-lg surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-center text-[var(--color-text-secondary)] hover:text-[var(--color-accent)] hover:border-[var(--color-accent)]/40 transition-all cursor-pointer"
                  >
                    <Edit3 className="w-3.5 h-3.5" />
                  </button>

                  <button
                    id={`task-delete-btn-${task.id}`}
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      setTaskToDelete(task);
                    }}
                    title="Delete task"
                    className="w-7 h-7 rounded-lg surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-center text-[var(--color-text-secondary)] hover:text-rose-500 hover:border-rose-500/40 transition-all cursor-pointer"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* 5. Create / Edit Task Modal */}
      <Modal
        isOpen={isEditorOpen}
        onClose={() => setIsEditorOpen(false)}
        title={editingTask ? 'Edit Task' : 'Create New Task'}
        description="Configure task details, category, priority, and optional due date."
        maxWidth="md"
        footer={
          <>
            <NeumorphicButton
              id="task-cancel-btn"
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => setIsEditorOpen(false)}
            >
              Cancel
            </NeumorphicButton>

            <NeumorphicButton
              id="task-submit-btn"
              type="button"
              variant="primary"
              size="sm"
              disabled={isSubmitting}
              onClick={handleSaveTask}
            >
              {isSubmitting ? (
                <span className="flex items-center gap-1.5">
                  <Loader2 className="w-3.5 h-3.5 animate-spin" /> Saving...
                </span>
              ) : editingTask ? (
                'Save Changes'
              ) : (
                'Create Task'
              )}
            </NeumorphicButton>
          </>
        }
      >
        <form onSubmit={handleSaveTask} className="space-y-4">
          {formError && (
            <div
              id="task-form-error"
              className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-600 dark:text-rose-400 text-xs flex items-center gap-2"
            >
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span>{formError}</span>
            </div>
          )}

          {/* Title */}
          <div>
            <TextInput
              id="task-form-title"
              label="Task Title *"
              value={formTitle}
              onChange={(e) => {
                setFormTitle(e.target.value);
                if (formError) setFormError('');
              }}
              placeholder="e.g. Inspect local model quantization settings"
              autoFocus
            />
          </div>

          {/* Notes / Description */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
              Notes (Optional)
            </label>
            <textarea
              id="task-form-notes"
              value={formNotes}
              onChange={(e) => setFormNotes(e.target.value)}
              placeholder="Add relevant notes or steps..."
              rows={2}
              className="w-full px-3.5 py-2 text-sm rounded-xl surface-recessed border border-[var(--color-border-subtle)] focus:border-[var(--color-accent)] focus:outline-none focus:ring-1 focus:ring-[var(--color-accent)]/25 text-[var(--color-text-primary)] resize-none"
            />
          </div>

          {/* Category & Status Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <Select
                id="task-form-category"
                label="Category"
                value={formCategory}
                onChange={(val) => setFormCategory(val as TaskCategory)}
                options={CATEGORY_OPTIONS.filter((c) => c.value !== 'all').map((c) => ({
                  value: c.value,
                  label: c.label,
                }))}
              />
            </div>

            {/* Status (editable when editing existing task) */}
            {editingTask && (
              <div>
                <Select
                  id="task-form-status"
                  label="Status"
                  value={formStatus}
                  onChange={(val) => setFormStatus(val as TaskStatus)}
                  options={[
                    { value: 'pending', label: 'Pending' },
                    { value: 'in_progress', label: 'In Progress' },
                    { value: 'completed', label: 'Completed' },
                    { value: 'cancelled', label: 'Cancelled' },
                  ]}
                />
              </div>
            )}

            {/* Priority Level */}
            <div className={`flex flex-col gap-1.5 ${!editingTask ? 'sm:col-span-1' : 'sm:col-span-2'}`}>
              <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
                Priority Level
              </label>
              <div className="grid grid-cols-4 gap-1 p-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
                {(['low', 'medium', 'high', 'urgent'] as TaskPriority[]).map((p) => {
                  const isPrio = formPriority === p;
                  return (
                    <button
                      key={p}
                      id={`task-form-priority-${p}`}
                      type="button"
                      onClick={() => setFormPriority(p)}
                      className={`py-1 rounded-lg text-xs font-semibold capitalize cursor-pointer select-none segmented-control-item ${
                        isPrio
                          ? 'segmented-control-item-active shadow-xs'
                          : 'segmented-control-item-inactive'
                      }`}
                    >
                      {p}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Due Date Switch & Section */}
          <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Calendar className="w-4 h-4 text-[var(--color-accent)]" />
                <div>
                  <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                    Schedule Deadline
                  </h4>
                  <p className="text-[11px] text-[var(--color-text-secondary)]">
                    Tasks with due dates appear in the Schedule view.
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <input
                  id="task-form-has-duedate-checkbox"
                  type="checkbox"
                  checked={formHasDueDate}
                  onChange={(e) => {
                    const checked = e.target.checked;
                    setFormHasDueDate(checked);
                    if (checked && !formDueDate) {
                      setFormDueDate(todayDateStr);
                    }
                    if (!checked) {
                      setFormReminderMinutesBefore(null);
                    }
                  }}
                  className="w-4 h-4 rounded text-[var(--color-accent)] border-[var(--color-border-subtle)] cursor-pointer"
                />
                <label
                  htmlFor="task-form-has-duedate-checkbox"
                  className="text-xs font-semibold text-[var(--color-text-primary)] cursor-pointer select-none"
                >
                  Set Due Date
                </label>
              </div>
            </div>

            {formHasDueDate && (
              <div className="pt-2 border-t border-[var(--color-border-subtle)] space-y-3">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <TextInput
                      id="task-form-duedate"
                      label="Due Date *"
                      type="date"
                      value={formDueDate}
                      onChange={(e) => setFormDueDate(e.target.value)}
                    />
                  </div>
                  <div>
                    <TextInput
                      id="task-form-duetime"
                      label="Due Time *"
                      type="time"
                      value={formDueTime}
                      onChange={(e) => setFormDueTime(e.target.value)}
                    />
                  </div>
                </div>

                {/* Reminder Timing Selection */}
                <div>
                  <Select
                    id="task-form-reminder"
                    label="Reminder Timing"
                    value={
                      formReminderMinutesBefore === null
                        ? 'none'
                        : String(formReminderMinutesBefore)
                    }
                    onChange={(val) => {
                      if (val === 'none') {
                        setFormReminderMinutesBefore(null);
                      } else {
                        setFormReminderMinutesBefore(Number(val));
                      }
                    }}
                    options={REMINDER_OPTIONS.map((opt) => ({
                      value: opt.value === null ? 'none' : String(opt.value),
                      label: opt.label,
                    }))}
                  />
                  <p className="text-[10px] text-[var(--color-text-muted)] mt-1">
                    Notification timing relative to the scheduled deadline.
                  </p>
                </div>
              </div>
            )}
          </div>
        </form>
      </Modal>

      {/* 6. Delete Confirmation Modal */}
      <Modal
        isOpen={Boolean(taskToDelete)}
        onClose={() => setTaskToDelete(null)}
        title="Delete Task"
        description="Are you sure you want to delete this task? This action will remove it from your active task list."
        maxWidth="sm"
        footer={
          <>
            <NeumorphicButton
              id="cancel-delete-task-btn"
              type="button"
              variant="ghost"
              size="sm"
              disabled={isDeleting}
              onClick={() => setTaskToDelete(null)}
            >
              Cancel
            </NeumorphicButton>

            <NeumorphicButton
              id="confirm-delete-task-btn"
              type="button"
              variant="danger"
              size="sm"
              disabled={isDeleting}
              onClick={handleConfirmDelete}
            >
              {isDeleting ? 'Deleting...' : 'Confirm Delete'}
            </NeumorphicButton>
          </>
        }
      >
        {taskToDelete && (
          <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-1 text-xs">
            <span className="font-semibold text-[var(--color-text-primary)] line-clamp-2">
              &quot;{taskToDelete.title}&quot;
            </span>
            <div className="text-[var(--color-text-muted)] flex items-center gap-2 capitalize">
              <span>{taskToDelete.category}</span>
              <span>•</span>
              <span>
                {taskToDelete.due_date
                  ? `Due ${formatLocalDate(new Date(taskToDelete.due_date))}`
                  : 'No deadline'}
              </span>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};
