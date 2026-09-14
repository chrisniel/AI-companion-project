import React, { useState, useEffect, useMemo, useCallback } from 'react';
import {
  Calendar as CalendarIcon,
  Clock,
  Bell,
  CheckSquare,
  ChevronLeft,
  ChevronRight,
  RotateCcw,
  Loader2,
  AlertCircle,
  Tag,
  AlertTriangle,
  Flame,
  Info,
} from 'lucide-react';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import {
  taskApi,
  TaskResponse,
  TaskStatus,
  TaskPriority,
  TaskCategory,
} from '../../services/api';
import {
  getLocalDateString,
  formatLocalDate,
  formatLocalTime,
  parseIsoToLocal,
  isOverdue,
  getReminderLabel,
  getWeekDays,
  addDays,
} from '../../utils/dateUtils';

type ScheduleViewMode = 'day' | 'week' | 'agenda';

export interface ProjectedTask {
  id: string;
  title: string;
  notes?: string;
  category: TaskCategory;
  status: TaskStatus;
  priority: TaskPriority;
  dueTimestamp: number;
  localDate: string; // YYYY-MM-DD
  localTimeDisplay: string;
  reminderLabel: string | null;
  reminderAtDisplay?: string;
  isOverdue: boolean;
}

interface ScheduleViewProps {
  initialTasks?: TaskResponse[];
}

export const ScheduleView: React.FC<ScheduleViewProps> = ({ initialTasks }) => {
  const [tasks, setTasks] = useState<TaskResponse[]>(initialTasks ?? []);
  const [isLoading, setIsLoading] = useState(!initialTasks);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [viewMode, setViewMode] = useState<ScheduleViewMode>('day');
  const [selectedDate, setSelectedDate] = useState<string>(() => getLocalDateString());

  // Load tasks from backend
  const loadTasks = useCallback(async () => {
    setIsLoading(true);
    setLoadError(null);
    try {
      const res = await taskApi.listAllTasks();
      setTasks(res.items);
    } catch (err: any) {
      setLoadError(err.message || 'Failed to load scheduled tasks from backend');
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

  // Project tasks with due_date into Schedule presentation model
  const projectedTasks: ProjectedTask[] = useMemo(() => {
    return tasks
      .filter((t) => Boolean(t.due_date))
      .map((t) => {
        const d = new Date(t.due_date!);
        const { dateStr } = parseIsoToLocal(t.due_date!);
        let reminderAtDisplay: string | undefined;
        if (t.reminder_at) {
          reminderAtDisplay = formatLocalTime(new Date(t.reminder_at));
        }

        return {
          id: t.id,
          title: t.title,
          notes: t.notes,
          category: t.category,
          status: t.status,
          priority: t.priority,
          dueTimestamp: d.getTime(),
          localDate: dateStr,
          localTimeDisplay: formatLocalTime(d),
          reminderLabel: getReminderLabel(t.reminder_minutes_before),
          reminderAtDisplay,
          isOverdue: isOverdue(t.due_date, t.status),
        };
      })
      .sort((a, b) => a.dueTimestamp - b.dueTimestamp);
  }, [tasks]);

  // Derived metrics for summary bar
  const summaryMetrics = useMemo(() => {
    let dueToday = 0;
    let upcoming = 0;
    let overdue = 0;
    let completed = 0;

    for (const pt of projectedTasks) {
      if (pt.status === 'completed') {
        completed++;
      } else if (pt.isOverdue) {
        overdue++;
      } else if (pt.localDate === todayDateStr) {
        dueToday++;
      } else if (pt.localDate > todayDateStr) {
        upcoming++;
      }
    }

    return {
      total: projectedTasks.length,
      dueToday,
      upcoming,
      overdue,
      completed,
    };
  }, [projectedTasks, todayDateStr]);

  // Day View: tasks matching selectedDate
  const dayTasks = useMemo(() => {
    return projectedTasks.filter((pt) => pt.localDate === selectedDate);
  }, [projectedTasks, selectedDate]);

  // Week View: dynamically calculate week days for selectedDate
  const weekDays = useMemo(() => {
    const [y, m, d] = selectedDate.split('-').map(Number);
    const dateObj = new Date(y, m - 1, d || 1);
    return getWeekDays(dateObj);
  }, [selectedDate]);

  // Agenda View: dates with scheduled tasks
  const agendaDateGroups = useMemo(() => {
    const map = new Map<string, ProjectedTask[]>();
    for (const pt of projectedTasks) {
      const existing = map.get(pt.localDate) || [];
      existing.push(pt);
      map.set(pt.localDate, existing);
    }
    const sortedDates = Array.from(map.keys()).sort();
    return sortedDates.map((dateStr) => ({
      dateStr,
      tasks: map.get(dateStr)!,
    }));
  }, [projectedTasks]);

  // Navigation handlers
  const handlePrev = () => {
    if (viewMode === 'week') {
      setSelectedDate((cur) => addDays(cur, -7));
    } else {
      setSelectedDate((cur) => addDays(cur, -1));
    }
  };

  const handleNext = () => {
    if (viewMode === 'week') {
      setSelectedDate((cur) => addDays(cur, 7));
    } else {
      setSelectedDate((cur) => addDays(cur, 1));
    }
  };

  const handleToday = () => {
    setSelectedDate(todayDateStr);
  };

  // Priority badge helper
  const getPriorityBadge = (priority: TaskPriority) => {
    switch (priority) {
      case 'urgent':
        return (
          <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-rose-600 dark:text-rose-400 bg-rose-500/10 border border-rose-500/20 px-1.5 py-0.2 rounded">
            <Flame className="w-2.5 h-2.5" /> Urgent
          </span>
        );
      case 'high':
        return (
          <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-amber-600 dark:text-amber-400 bg-amber-500/10 border border-amber-500/20 px-1.5 py-0.2 rounded">
            High
          </span>
        );
      case 'medium':
        return (
          <span className="inline-flex items-center gap-1 text-[10px] font-medium text-sky-600 dark:text-sky-400 bg-sky-500/10 border border-sky-500/20 px-1.5 py-0.2 rounded">
            Medium
          </span>
        );
      case 'low':
        return (
          <span className="inline-flex items-center gap-1 text-[10px] font-medium text-[var(--color-text-muted)] bg-slate-500/10 border border-[var(--color-border-subtle)] px-1.5 py-0.2 rounded">
            Low
          </span>
        );
    }
  };

  return (
    <div id="schedule-view" className="space-y-6">
      {/* 1. View Header Card */}
      <div
        id="schedule-header-card"
        className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col sm:flex-row sm:items-center justify-between gap-4"
      >
        <div className="flex items-center gap-3.5">
          <div className="w-10 h-10 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0 shadow-sm">
            <CalendarIcon className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-lg font-bold text-[var(--color-text-primary)] tracking-tight">
              Schedule
            </h1>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Tasks with due dates appear here. Chronological projection derived from backend tasks.
            </p>
          </div>
        </div>

        {/* Informational Planned Affordance */}
        <div className="flex items-center gap-2 self-start sm:self-auto">
          <span
            id="schedule-planned-notice"
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[11px] text-[var(--color-text-muted)] select-none"
          >
            <Info className="w-3.5 h-3.5 text-[var(--color-accent)] opacity-80" />
            <span>Standalone alarms planned</span>
          </span>
        </div>
      </div>

      {/* 2. Controls & Segmented Views Bar */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3.5">
        {/* Neumorphic Segmented Control for Views (Day / Week / Agenda) */}
        <div
          id="schedule-view-segmented-controls"
          className="flex items-center p-1 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] gap-1 self-start select-none"
        >
          {(['day', 'week', 'agenda'] as ScheduleViewMode[]).map((mode) => {
            const isSelected = viewMode === mode;
            return (
              <button
                key={mode}
                id={`schedule-mode-${mode}`}
                type="button"
                onClick={() => setViewMode(mode)}
                className={`px-4 py-1.5 rounded-xl text-xs font-semibold capitalize cursor-pointer select-none segmented-control-item ${
                  isSelected
                    ? 'segmented-control-item-active'
                    : 'segmented-control-item-inactive'
                }`}
              >
                {mode}
              </button>
            );
          })}
        </div>

        {/* Date Selector / Navigation (Hidden in Agenda mode since Agenda shows complete chronological projection) */}
        {viewMode !== 'agenda' && (
          <div
            id="schedule-date-nav"
            className="flex items-center justify-between sm:justify-end gap-2 text-xs font-medium"
          >
            <button
              id="schedule-prev-btn"
              type="button"
              onClick={handlePrev}
              className="p-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] cursor-pointer transition-colors"
              title={viewMode === 'week' ? 'Previous Week' : 'Previous Day'}
            >
              <ChevronLeft className="w-4 h-4" />
            </button>

            <button
              id="schedule-today-btn"
              type="button"
              onClick={handleToday}
              className="px-3 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] cursor-pointer hover:border-[var(--color-accent)]/40 transition-colors"
            >
              {selectedDate === todayDateStr
                ? 'Today'
                : selectedDate}
            </button>

            <button
              id="schedule-next-btn"
              type="button"
              onClick={handleNext}
              className="p-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] cursor-pointer transition-colors"
              title={viewMode === 'week' ? 'Next Week' : 'Next Day'}
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>

      {/* 3. Truthful Summary Bar */}
      <div
        id="schedule-summary-bar"
        className="flex flex-wrap items-center gap-2 text-xs"
      >
        <span className="text-[11px] font-semibold text-[var(--color-text-muted)] uppercase tracking-wider mr-1 select-none">
          Scheduled Tasks:
        </span>
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg surface-recessed text-[var(--color-text-primary)] border border-[var(--color-border-subtle)] font-mono font-medium">
          <CheckSquare className="w-3 h-3 text-[var(--color-accent)]" />
          <span>{summaryMetrics.total} Total</span>
        </span>
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-sky-500/10 text-sky-600 dark:text-sky-400 border border-sky-500/20 font-mono font-medium">
          <Clock className="w-3 h-3" />
          <span>{summaryMetrics.dueToday} Today</span>
        </span>
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-500/20 font-mono font-medium">
          <CalendarIcon className="w-3 h-3" />
          <span>{summaryMetrics.upcoming} Upcoming</span>
        </span>
        {summaryMetrics.overdue > 0 && (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/20 font-mono font-medium">
            <AlertTriangle className="w-3 h-3" />
            <span>{summaryMetrics.overdue} Overdue</span>
          </span>
        )}
        {summaryMetrics.completed > 0 && (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 font-mono font-medium">
            <span>{summaryMetrics.completed} Completed</span>
          </span>
        )}
      </div>

      {/* 4. MAIN VIEW CONTENT: DAY, WEEK, OR AGENDA */}
      {isLoading ? (
        <div
          id="schedule-loading-state"
          className="p-12 rounded-3xl surface-raised border border-[var(--color-border-subtle)] text-center flex flex-col items-center justify-center gap-3"
        >
          <Loader2 className="w-6 h-6 animate-spin text-[var(--color-accent)]" />
          <p className="text-xs font-medium text-[var(--color-text-secondary)]">
            Loading scheduled tasks...
          </p>
        </div>
      ) : loadError ? (
        <div
          id="schedule-error-state"
          className="p-10 rounded-3xl surface-raised border border-[var(--color-border-subtle)] text-center flex flex-col items-center justify-center gap-3"
        >
          <div className="w-10 h-10 rounded-2xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-500">
            <AlertCircle className="w-5 h-5" />
          </div>
          <div className="space-y-1 max-w-sm">
            <p className="text-sm font-bold text-[var(--color-text-primary)]">
              Unable to load schedule
            </p>
            <p className="text-xs text-[var(--color-text-muted)]">{loadError}</p>
          </div>
          <NeumorphicButton
            id="schedule-retry-btn"
            size="sm"
            onClick={loadTasks}
            icon={<RotateCcw className="w-3.5 h-3.5" />}
          >
            Retry
          </NeumorphicButton>
        </div>
      ) : projectedTasks.length === 0 ? (
        /* Global Empty State */
        <div
          id="schedule-empty-state"
          className="p-12 rounded-3xl surface-raised border border-[var(--color-border-subtle)] text-center flex flex-col items-center justify-center gap-2.5"
        >
          <div className="w-10 h-10 rounded-2xl surface-recessed flex items-center justify-center text-[var(--color-text-muted)] border border-[var(--color-border-subtle)]">
            <CalendarIcon className="w-5 h-5 opacity-60" />
          </div>
          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
            No scheduled tasks
          </p>
          <p className="text-xs text-[var(--color-text-muted)] max-w-sm">
            Tasks with due dates appear here. Add a due date to any task in the Tasks view to project it onto the schedule.
          </p>
        </div>
      ) : (
        <>
          {/* A. DAY VIEW */}
          {viewMode === 'day' && (
            <div
              id="schedule-day-view"
              className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4"
            >
              <div className="flex items-center justify-between pb-3 border-b border-[var(--color-border-subtle)]">
                <h2 className="text-sm font-bold text-[var(--color-text-primary)] flex items-center gap-2">
                  <span>Day Timeline</span>
                  <span className="text-xs font-normal text-[var(--color-text-muted)] font-mono">
                    {selectedDate === todayDateStr
                      ? `Today (${selectedDate})`
                      : selectedDate}
                  </span>
                </h2>

                <span className="text-[11px] text-[var(--color-text-muted)] font-mono">
                  {dayTasks.length} {dayTasks.length === 1 ? 'task' : 'tasks'} scheduled
                </span>
              </div>

              {dayTasks.length === 0 ? (
                <div
                  id="schedule-day-empty"
                  className="py-12 text-center text-xs text-[var(--color-text-muted)]"
                >
                  No tasks scheduled for {selectedDate}.
                </div>
              ) : (
                <div className="relative pl-6 sm:pl-8 space-y-4 before:absolute before:left-3 before:top-2 before:bottom-2 before:w-0.5 before:bg-[var(--color-border-subtle)]">
                  {dayTasks.map((task) => {
                    const isCompleted = task.status === 'completed';
                    const isCancelled = task.status === 'cancelled';

                    return (
                      <div key={task.id} className="relative group">
                        {/* Node Dot */}
                        <div
                          className={`absolute -left-6 sm:-left-8 top-3 w-3.5 h-3.5 rounded-full border-2 border-[var(--color-app-bg)] shadow-xs ${
                            isCompleted
                              ? 'bg-emerald-500'
                              : task.isOverdue
                              ? 'bg-rose-500'
                              : 'bg-[var(--color-accent)]'
                          }`}
                        />

                        {/* Compact Task Card */}
                        <div
                          id={`day-task-${task.id}`}
                          className={`p-3 sm:p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col sm:flex-row sm:items-center justify-between gap-3 group-hover:border-[var(--color-accent)]/40 transition-all ${
                            isCompleted
                              ? 'opacity-70 bg-black/[0.02] dark:bg-white/[0.01]'
                              : isCancelled
                              ? 'opacity-50'
                              : ''
                          }`}
                        >
                          {/* Left Details */}
                          <div className="flex items-start sm:items-center gap-3 min-w-0">
                            <div className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0 bg-[var(--color-accent)]/10 text-[var(--color-accent)] border border-[var(--color-accent)]/20">
                              <Clock className="w-4 h-4" />
                            </div>

                            <div className="min-w-0">
                              <div className="flex items-center gap-2 flex-wrap">
                                <span className="font-mono text-xs font-bold text-[var(--color-text-primary)]">
                                  {task.localTimeDisplay}
                                </span>

                                <span className="text-[10px] font-semibold px-2 py-0.5 rounded-md uppercase tracking-wider bg-black/5 dark:bg-white/5 text-[var(--color-text-muted)] capitalize">
                                  {task.category}
                                </span>

                                {getPriorityBadge(task.priority)}

                                {task.isOverdue && (
                                  <span className="inline-flex items-center gap-1 text-[10px] font-bold text-rose-600 dark:text-rose-400 bg-rose-500/10 border border-rose-500/20 px-1.5 py-0.2 rounded">
                                    <AlertTriangle className="w-2.5 h-2.5" /> Overdue
                                  </span>
                                )}

                                {task.status === 'in_progress' && (
                                  <span className="text-[10px] font-semibold text-sky-600 dark:text-sky-400 bg-sky-500/10 border border-sky-500/20 px-1.5 py-0.2 rounded">
                                    In Progress
                                  </span>
                                )}

                                {isCompleted && (
                                  <span className="text-[10px] font-semibold text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-1.5 py-0.2 rounded">
                                    Completed
                                  </span>
                                )}

                                {isCancelled && (
                                  <span className="text-[10px] font-semibold text-slate-500 bg-slate-500/10 border border-slate-500/20 px-1.5 py-0.2 rounded">
                                    Cancelled
                                  </span>
                                )}
                              </div>

                              <h3
                                className={`text-sm font-bold mt-0.5 truncate ${
                                  isCompleted
                                    ? 'line-through text-[var(--color-text-muted)]'
                                    : 'text-[var(--color-text-primary)]'
                                }`}
                              >
                                {task.title}
                              </h3>

                              {task.notes && (
                                <p className="text-xs text-[var(--color-text-secondary)] line-clamp-1 mt-0.5">
                                  {task.notes}
                                </p>
                              )}
                            </div>
                          </div>

                          {/* Right: Reminder Metadata (Task Attribute, not separate event) */}
                          {task.reminderLabel && (
                            <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-accent)] font-medium self-end sm:self-auto flex-shrink-0 bg-[var(--color-accent)]/10 px-2.5 py-1 rounded-lg border border-[var(--color-accent)]/20">
                              <Bell className="w-3 h-3" />
                              <span>{task.reminderLabel}</span>
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* B. WEEK VIEW */}
          {viewMode === 'week' && (
            <div
              id="schedule-week-view"
              className="p-4 sm:p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3 overflow-x-auto"
            >
              <div className="flex items-center justify-between pb-2 border-b border-[var(--color-border-subtle)]">
                <h2 className="text-sm font-bold text-[var(--color-text-primary)]">
                  Week of {weekDays[0].full} - {weekDays[6].full}
                </h2>
                <span className="text-xs text-[var(--color-text-muted)] font-mono">
                  7 Days Projected
                </span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-2.5 min-w-[700px]">
                {weekDays.map((wd) => {
                  const dayTasksInWeek = projectedTasks.filter(
                    (pt) => pt.localDate === wd.date
                  );

                  return (
                    <div
                      key={wd.date}
                      id={`week-col-${wd.date}`}
                      onClick={() => {
                        setSelectedDate(wd.date);
                        setViewMode('day');
                      }}
                      className={`p-3 rounded-2xl border transition-all cursor-pointer flex flex-col justify-between gap-2 min-h-[160px] ${
                        wd.isToday
                          ? 'surface-raised border-[var(--color-accent)]/50 shadow-sm ring-1 ring-[var(--color-accent)]/20'
                          : 'surface-recessed border border-[var(--color-border-subtle)] hover:border-[var(--color-border-highlight)]'
                      }`}
                    >
                      {/* Column Header */}
                      <div className="flex items-center justify-between pb-1.5 border-b border-[var(--color-border-subtle)]">
                        <div className="flex flex-col">
                          <span className="text-[11px] font-bold uppercase tracking-wider text-[var(--color-text-muted)]">
                            {wd.day}
                          </span>
                          <span
                            className={`text-xs font-bold ${
                              wd.isToday
                                ? 'text-[var(--color-accent)]'
                                : 'text-[var(--color-text-primary)]'
                            }`}
                          >
                            {wd.full}
                          </span>
                        </div>

                        {wd.isToday && (
                          <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-[var(--color-accent)] text-white">
                            Today
                          </span>
                        )}
                      </div>

                      {/* Compact Task Pills in Column */}
                      <div className="space-y-1.5 flex-1">
                        {dayTasksInWeek.length === 0 ? (
                          <span className="text-[10px] text-[var(--color-text-muted)] italic block pt-2">
                            No tasks
                          </span>
                        ) : (
                          dayTasksInWeek.map((t) => (
                            <div
                              key={t.id}
                              className="p-1.5 rounded-lg border border-[var(--color-border-subtle)] surface-raised text-[11px] truncate flex items-center gap-1.5 transition-all hover:border-[var(--color-accent)]/40"
                            >
                              <CheckSquare className="w-3 h-3 text-[var(--color-accent)] flex-shrink-0" />
                              <span className="font-mono text-[10px] font-bold">
                                {t.localTimeDisplay}
                              </span>
                              <span className="truncate font-medium text-[var(--color-text-primary)]">
                                {t.title}
                              </span>
                            </div>
                          ))
                        )}
                      </div>

                      {/* View Day Link */}
                      <div className="pt-1 border-t border-[var(--color-border-subtle)] text-right">
                        <span className="text-[10px] text-[var(--color-accent)] font-semibold hover:underline">
                          View Day →
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* C. AGENDA VIEW */}
          {viewMode === 'agenda' && (
            <div id="schedule-agenda-view" className="space-y-4">
              {agendaDateGroups.map(({ dateStr, tasks: groupTasks }) => {
                const isToday = dateStr === todayDateStr;
                const [y, m, d] = dateStr.split('-').map(Number);
                const dateObj = new Date(y, m - 1, d);
                const dateHeader = formatLocalDate(dateObj);

                return (
                  <div
                    key={dateStr}
                    id={`agenda-group-${dateStr}`}
                    className="p-4 sm:p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3"
                  >
                    {/* Date Heading */}
                    <div className="flex items-center justify-between pb-2 border-b border-[var(--color-border-subtle)]">
                      <div className="flex items-center gap-2">
                        <CalendarIcon className="w-4 h-4 text-[var(--color-accent)]" />
                        <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
                          {isToday ? `Today, ${dateHeader}` : dateHeader}
                        </h3>
                        {isToday && (
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[var(--color-accent)]/15 text-[var(--color-accent)]">
                            Current Day
                          </span>
                        )}
                      </div>

                      <span className="text-xs font-mono text-[var(--color-text-muted)]">
                        {groupTasks.length} {groupTasks.length === 1 ? 'task' : 'tasks'}
                      </span>
                    </div>

                    {/* Tasks in this date */}
                    <div className="space-y-2">
                      {groupTasks.map((t) => {
                        const isCompleted = t.status === 'completed';

                        return (
                          <div
                            key={t.id}
                            id={`agenda-task-${t.id}`}
                            className={`p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:border-[var(--color-accent)]/40 transition-all ${
                              isCompleted ? 'opacity-60' : ''
                            }`}
                          >
                            <div className="flex items-center gap-3 min-w-0">
                              <div className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 bg-[var(--color-accent)]/10 text-[var(--color-accent)]">
                                <Clock className="w-3.5 h-3.5" />
                              </div>

                              <div className="min-w-0">
                                <div className="flex items-center gap-2">
                                  <span className="font-mono text-xs font-bold text-[var(--color-text-primary)]">
                                    {t.localTimeDisplay}
                                  </span>
                                  <span
                                    className={`text-xs font-bold truncate ${
                                      isCompleted
                                        ? 'line-through text-[var(--color-text-muted)]'
                                        : 'text-[var(--color-text-primary)]'
                                    }`}
                                  >
                                    {t.title}
                                  </span>
                                </div>

                                <div className="flex items-center gap-2 mt-0.5 text-[11px] text-[var(--color-text-muted)] flex-wrap">
                                  <span className="capitalize">{t.category}</span>
                                  <span>•</span>
                                  {getPriorityBadge(t.priority)}
                                  {t.isOverdue && (
                                    <>
                                      <span>•</span>
                                      <span className="text-rose-500 font-semibold text-[10px]">
                                        Overdue
                                      </span>
                                    </>
                                  )}
                                </div>
                              </div>
                            </div>

                            {t.reminderLabel && (
                              <div className="flex items-center gap-1 text-[11px] text-[var(--color-accent)] font-medium self-end sm:self-auto flex-shrink-0">
                                <Bell className="w-3 h-3" />
                                <span>{t.reminderLabel}</span>
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}
    </div>
  );
};
