import React, { useState, useMemo } from 'react';
import {
  CheckSquare,
  Plus,
  Search,
  Calendar,
  Clock,
  Bell,
  BellOff,
  Edit3,
  Trash2,
  CheckCircle2,
  Circle,
  Tag,
  AlertCircle,
  X,
  Filter,
  Flame,
  ArrowUpDown,
  Check,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { SearchInput } from '../ui/SearchInput';
import { Modal } from '../ui/Modal';
import { TextInput } from '../ui/TextInput';
import { Select } from '../ui/Select';
import { Toggle } from '../ui/Toggle';
import { TaskItem, TaskPriority } from '../../types';
import { mockTaskItems } from '../../mock/localAiData';

type TaskViewTab = 'today' | 'upcoming' | 'completed';

const CATEGORIES = ['All', 'Core System', 'Work', 'Personal', 'Automation', 'Health'];
const PRIORITIES: { label: string; value: TaskPriority | 'all' }[] = [
  { label: 'All', value: 'all' },
  { label: 'Urgent', value: 'urgent' },
  { label: 'High', value: 'high' },
  { label: 'Medium', value: 'medium' },
  { label: 'Low', value: 'low' },
];

export const TasksView: React.FC = () => {
  const [tasks, setTasks] = useState<TaskItem[]>(mockTaskItems);
  const [currentTab, setCurrentTab] = useState<TaskViewTab>('today');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [selectedPriority, setSelectedPriority] = useState<TaskPriority | 'all'>('all');

  // Modal states
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [editingTask, setEditingTask] = useState<TaskItem | null>(null);
  const [taskToDelete, setTaskToDelete] = useState<TaskItem | null>(null);

  // Task form fields
  const [formTitle, setFormTitle] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formCategory, setFormCategory] = useState('Work');
  const [formDueDate, setFormDueDate] = useState('2026-09-09');
  const [formDueTime, setFormDueTime] = useState('12:00');
  const [formPriority, setFormPriority] = useState<TaskPriority>('medium');
  const [formHasReminder, setFormHasReminder] = useState(false);
  const [formReminderTime, setFormReminderTime] = useState('11:45');
  const [formError, setFormError] = useState('');

  // Counts for tabs
  const todayDate = '2026-09-09';
  const counts = useMemo(() => {
    return {
      today: tasks.filter((t) => !t.completed && t.dueDate <= todayDate).length,
      upcoming: tasks.filter((t) => !t.completed && t.dueDate > todayDate).length,
      completed: tasks.filter((t) => t.completed).length,
    };
  }, [tasks, todayDate]);

  // Filtered task rows
  const filteredTasks = useMemo(() => {
    return tasks.filter((task) => {
      // 1. Tab view filter
      if (currentTab === 'today') {
        if (task.completed || task.dueDate > todayDate) return false;
      } else if (currentTab === 'upcoming') {
        if (task.completed || task.dueDate <= todayDate) return false;
      } else if (currentTab === 'completed') {
        if (!task.completed) return false;
      }

      // 2. Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesTitle = task.title.toLowerCase().includes(q);
        const matchesDesc = task.description?.toLowerCase().includes(q);
        const matchesCat = task.category.toLowerCase().includes(q);
        if (!matchesTitle && !matchesDesc && !matchesCat) return false;
      }

      // 3. Category filter
      if (selectedCategory !== 'All' && task.category !== selectedCategory) {
        return false;
      }

      // 4. Priority filter
      if (selectedPriority !== 'all' && task.priority !== selectedPriority) {
        return false;
      }

      return true;
    });
  }, [tasks, currentTab, todayDate, searchQuery, selectedCategory, selectedPriority]);

  // Complete / Uncomplete Toggle
  const handleToggleComplete = (id: string, e?: React.MouseEvent) => {
    e?.stopPropagation();
    setTasks((prev) =>
      prev.map((task) => {
        if (task.id === id) {
          const nextCompleted = !task.completed;
          return {
            ...task,
            completed: nextCompleted,
            completedAt: nextCompleted ? new Date().toISOString().replace('T', ' ').substring(0, 16) : undefined,
          };
        }
        return task;
      })
    );
  };

  // Open Create Modal
  const handleOpenCreate = () => {
    setEditingTask(null);
    setFormTitle('');
    setFormDescription('');
    setFormCategory('Work');
    setFormDueDate(currentTab === 'upcoming' ? '2026-09-10' : '2026-09-09');
    setFormDueTime('12:00');
    setFormPriority('medium');
    setFormHasReminder(false);
    setFormReminderTime('11:45');
    setFormError('');
    setIsEditorOpen(true);
  };

  // Open Edit Modal
  const handleOpenEdit = (task: TaskItem, e?: React.MouseEvent) => {
    e?.stopPropagation();
    setEditingTask(task);
    setFormTitle(task.title);
    setFormDescription(task.description || '');
    setFormCategory(task.category);
    setFormDueDate(task.dueDate);
    setFormDueTime(task.dueTime || '12:00');
    setFormPriority(task.priority);
    setFormHasReminder(task.hasReminder);
    setFormReminderTime(task.reminderTime || '11:45');
    setFormError('');
    setIsEditorOpen(true);
  };

  // Save Task (Create / Edit)
  const handleSaveTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formTitle.trim()) {
      setFormError('Task title is required.');
      return;
    }

    if (editingTask) {
      // Update existing
      setTasks((prev) =>
        prev.map((t) =>
          t.id === editingTask.id
            ? {
                ...t,
                title: formTitle.trim(),
                description: formDescription.trim() || undefined,
                category: formCategory,
                dueDate: formDueDate,
                dueTime: formDueTime,
                priority: formPriority,
                hasReminder: formHasReminder,
                reminderTime: formHasReminder ? formReminderTime : undefined,
              }
            : t
        )
      );
    } else {
      // Create new
      const newTask: TaskItem = {
        id: `task-${Date.now()}`,
        title: formTitle.trim(),
        description: formDescription.trim() || undefined,
        completed: false,
        category: formCategory,
        dueDate: formDueDate,
        dueTime: formDueTime,
        priority: formPriority,
        hasReminder: formHasReminder,
        reminderTime: formHasReminder ? formReminderTime : undefined,
        createdAt: new Date().toISOString(),
      };
      setTasks((prev) => [newTask, ...prev]);
    }

    setIsEditorOpen(false);
  };

  // Delete Task
  const handleConfirmDelete = () => {
    if (!taskToDelete) return;
    setTasks((prev) => prev.filter((t) => t.id !== taskToDelete.id));
    setTaskToDelete(null);
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
              Tasks & Action Items
            </h1>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Compact local task manager with priority queues, schedule deadlines, and tactile controls.
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

      {/* 2. Controls Bar: Segmented Views, Search, and Selective Neumorphic Filters */}
      <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3.5">
        {/* Neumorphic Segmented Control for Views (Today / Upcoming / Completed) */}
        <div
          id="tasks-view-segmented-controls"
          className="flex items-center p-1 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] gap-1 flex-shrink-0"
        >
          {(['today', 'upcoming', 'completed'] as TaskViewTab[]).map((tab) => {
            const isSelected = currentTab === tab;
            const count = counts[tab];
            const labels = {
              today: 'Today',
              upcoming: 'Upcoming',
              completed: 'Completed',
            };

            return (
              <button
                key={tab}
                id={`task-tab-${tab}`}
                type="button"
                onClick={() => setCurrentTab(tab)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-2 cursor-pointer select-none segmented-control-item ${
                  isSelected
                    ? 'segmented-control-item-active'
                    : 'segmented-control-item-inactive'
                }`}
              >
                <span>{labels[tab]}</span>
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
            placeholder="Search tasks by title or category..."
          />
        </div>
      </div>

      {/* 3. Selective Filters Row (Categories & Priorities) */}
      <div className="flex flex-wrap items-center justify-between gap-3 text-xs">
        {/* Category Pills */}
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="text-[11px] font-semibold text-[var(--color-text-muted)] uppercase tracking-wider mr-1 select-none">
            Project:
          </span>
          {CATEGORIES.map((cat) => {
            const isCatActive = selectedCategory === cat;
            return (
              <button
                key={cat}
                type="button"
                onClick={() => setSelectedCategory(cat)}
                className={`px-2.5 py-1 rounded-lg text-xs font-medium cursor-pointer select-none segmented-control-item ${
                  isCatActive
                    ? 'segmented-control-item-active font-semibold shadow-xs'
                    : 'segmented-control-item-inactive'
                }`}
              >
                {cat}
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

      {/* 4. Compact Readable Task Rows (No oversized bloated glass cards) */}
      <div
        id="tasks-list-container"
        className="rounded-2xl surface-raised border border-[var(--color-border-subtle)] divide-y divide-[var(--color-border-subtle)] overflow-hidden shadow-xs"
      >
        {filteredTasks.length === 0 ? (
          <div className="py-12 px-4 text-center flex flex-col items-center justify-center gap-2.5">
            <div className="w-10 h-10 rounded-2xl surface-recessed flex items-center justify-center text-[var(--color-text-muted)] border border-[var(--color-border-subtle)]">
              <CheckSquare className="w-5 h-5 opacity-60" />
            </div>
            <p className="text-sm font-semibold text-[var(--color-text-primary)]">
              No tasks found in {currentTab} view
            </p>
            <p className="text-xs text-[var(--color-text-muted)] max-w-sm">
              {searchQuery || selectedCategory !== 'All' || selectedPriority !== 'all'
                ? 'Try clearing active search or category filters to see more tasks.'
                : currentTab === 'completed'
                ? 'Completed tasks will be archived here once checked off.'
                : 'All clear! Create a task above to schedule your next action.'}
            </p>
            {(searchQuery || selectedCategory !== 'All' || selectedPriority !== 'all') && (
              <button
                type="button"
                onClick={() => {
                  setSearchQuery('');
                  setSelectedCategory('All');
                  setSelectedPriority('all');
                }}
                className="mt-2 text-xs text-[var(--color-accent)] hover:underline cursor-pointer font-medium"
              >
                Reset active filters
              </button>
            )}
          </div>
        ) : (
          filteredTasks.map((task) => {
            const isCompleted = task.completed;

            return (
              <div
                key={task.id}
                id={`task-row-${task.id}`}
                className={`group px-3 sm:px-4 py-2.5 sm:py-3 flex items-center justify-between gap-3 transition-colors ${
                  isCompleted
                    ? 'bg-black/[0.02] dark:bg-white/[0.01] hover:bg-black/[0.04] dark:hover:bg-white/[0.02]'
                    : 'hover:bg-[var(--color-surface-secondary)]/40'
                }`}
              >
                {/* Left: Completion Control + Title + Badges */}
                <div className="flex items-center gap-3 min-w-0 flex-1">
                  {/* Neumorphic Completion Button */}
                  <button
                    id={`task-complete-toggle-${task.id}`}
                    type="button"
                    onClick={(e) => handleToggleComplete(task.id, e)}
                    aria-label={isCompleted ? 'Mark task pending' : 'Mark task completed'}
                    className={`w-5 h-5 rounded-lg flex items-center justify-center transition-all cursor-pointer flex-shrink-0 select-none ${
                      isCompleted
                        ? 'bg-emerald-500 text-white shadow-xs border border-emerald-600'
                        : 'surface-recessed border border-[var(--color-border-subtle)] text-transparent hover:border-[var(--color-accent)] hover:text-[var(--color-accent)]/40'
                    }`}
                  >
                    <Check className={`w-3 h-3 ${isCompleted ? 'stroke-[2.5]' : ''}`} />
                  </button>

                  {/* Task Text & Metadata */}
                  <div className="flex flex-col min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span
                        className={`text-sm tracking-tight font-medium truncate ${
                          isCompleted
                            ? 'line-through text-[var(--color-text-muted)] opacity-70'
                            : 'text-[var(--color-text-primary)]'
                        }`}
                      >
                        {task.title}
                      </span>

                      {/* Priority Badge */}
                      <span className="flex-shrink-0">{getPriorityBadge(task.priority)}</span>
                    </div>

                    {/* Secondary Row: Category, Due Date, Reminder */}
                    <div className="flex items-center gap-2.5 mt-0.5 text-[11px] text-[var(--color-text-muted)] flex-wrap">
                      <span className="inline-flex items-center gap-1 font-medium text-[var(--color-text-secondary)]">
                        <Tag className="w-3 h-3 opacity-60" /> {task.category}
                      </span>

                      <span>•</span>

                      <span className="inline-flex items-center gap-1 font-mono">
                        <Clock className="w-3 h-3 opacity-60" />
                        {task.dueDate === todayDate ? 'Today' : task.dueDate}
                        {task.dueTime ? ` at ${task.dueTime}` : ''}
                      </span>

                      {task.hasReminder && (
                        <>
                          <span>•</span>
                          <span className="inline-flex items-center gap-1 text-[var(--color-accent)] font-medium">
                            <Bell className="w-3 h-3" />
                            {task.reminderTime || 'Alert'}
                          </span>
                        </>
                      )}

                      {isCompleted && task.completedAt && (
                        <>
                          <span>•</span>
                          <span className="text-emerald-600 dark:text-emerald-400 font-mono text-[10px]">
                            Done {task.completedAt}
                          </span>
                        </>
                      )}
                    </div>
                  </div>
                </div>

                {/* Right: Quick Action Controls (Selectively Neumorphic) */}
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
        description="Configure task metadata, priorities, and local reminder timing."
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
              onClick={handleSaveTask}
            >
              {editingTask ? 'Save Changes' : 'Create Task'}
            </NeumorphicButton>
          </>
        }
      >
        <form onSubmit={handleSaveTask} className="space-y-4">
          {formError && (
            <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-600 dark:text-rose-400 text-xs flex items-center gap-2">
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
              placeholder="e.g. Consolidate local vector memory for project notes"
              autoFocus
            />
          </div>

          {/* Description */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
              Description (Optional)
            </label>
            <textarea
              id="task-form-description"
              value={formDescription}
              onChange={(e) => setFormDescription(e.target.value)}
              placeholder="Add relevant context or steps..."
              rows={2}
              className="w-full px-3.5 py-2 text-sm rounded-xl surface-recessed border border-[var(--color-border-subtle)] focus:border-[var(--color-accent)] focus:outline-none focus:ring-1 focus:ring-[var(--color-accent)]/25 text-[var(--color-text-primary)] resize-none"
            />
          </div>

          {/* Category & Priority Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <Select
                id="task-form-category"
                label="Project / Category"
                value={formCategory}
                onChange={setFormCategory}
                options={CATEGORIES.filter((c) => c !== 'All').map((c) => ({
                  value: c,
                  label: c,
                }))}
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
                Priority Level
              </label>
              <div className="grid grid-cols-4 gap-1 p-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
                {(['low', 'medium', 'high', 'urgent'] as TaskPriority[]).map((p) => {
                  const isPrio = formPriority === p;
                  return (
                    <button
                      key={p}
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

          {/* Due Date & Time */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <TextInput
                id="task-form-duedate"
                label="Due Date"
                type="date"
                value={formDueDate}
                onChange={(e) => setFormDueDate(e.target.value)}
              />
            </div>

            <div>
              <TextInput
                id="task-form-duetime"
                label="Due Time"
                type="time"
                value={formDueTime}
                onChange={(e) => setFormDueTime(e.target.value)}
              />
            </div>
          </div>

          {/* Reminder Section */}
          <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Bell className="w-4 h-4 text-[var(--color-accent)]" />
                <div>
                  <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                    Local Notification Alert
                  </h4>
                  <p className="text-[11px] text-[var(--color-text-secondary)]">
                    Trigger desktop toast & optional assistant audio cue.
                  </p>
                </div>
              </div>

              <Toggle
                id="task-form-reminder-toggle"
                checked={formHasReminder}
                onChange={setFormHasReminder}
                size="sm"
              />
            </div>

            {formHasReminder && (
              <div className="pt-2 border-t border-[var(--color-border-subtle)] flex items-center gap-3">
                <span className="text-xs font-medium text-[var(--color-text-secondary)]">
                  Remind at:
                </span>
                <input
                  id="task-form-remindertime"
                  type="time"
                  value={formReminderTime}
                  onChange={(e) => setFormReminderTime(e.target.value)}
                  className="px-2.5 py-1 text-xs rounded-lg surface-raised border border-[var(--color-border-subtle)] text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)]"
                />
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
        description="Are you sure you want to delete this task? This action cannot be undone."
        maxWidth="sm"
        footer={
          <>
            <NeumorphicButton
              id="cancel-delete-task-btn"
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => setTaskToDelete(null)}
            >
              Cancel
            </NeumorphicButton>

            <NeumorphicButton
              id="confirm-delete-task-btn"
              type="button"
              variant="danger"
              size="sm"
              onClick={handleConfirmDelete}
            >
              Confirm Delete
            </NeumorphicButton>
          </>
        }
      >
        {taskToDelete && (
          <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-1 text-xs">
            <span className="font-semibold text-[var(--color-text-primary)] line-clamp-2">
              &quot;{taskToDelete.title}&quot;
            </span>
            <div className="text-[var(--color-text-muted)] flex items-center gap-2">
              <span>{taskToDelete.category}</span>
              <span>•</span>
              <span>Due {taskToDelete.dueDate}</span>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};
