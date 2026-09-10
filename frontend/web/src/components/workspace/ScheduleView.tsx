import React, { useState, useMemo } from 'react';
import {
  Calendar as CalendarIcon,
  Clock,
  AlarmClock,
  Bell,
  CheckSquare,
  Plus,
  ChevronLeft,
  ChevronRight,
  Smartphone,
  Monitor,
  CheckCircle2,
  AlertCircle,
  Trash2,
  Edit3,
  Radio,
  Layers,
  ShieldCheck,
  Repeat,
  Sparkles,
  Info,
  X,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { Modal } from '../ui/Modal';
import { TextInput } from '../ui/TextInput';
import { Select } from '../ui/Select';
import { Toggle } from '../ui/Toggle';
import { StatusIndicator } from '../ui/StatusIndicator';
import {
  AlarmRepeat,
  AlarmTargetDevice,
  ScheduleEvent,
  ScheduleEventType,
} from '../../types';
import { mockScheduleEvents } from '../../mock/localAiData';

type ScheduleViewMode = 'day' | 'week' | 'agenda';

const WEEKDAYS = [
  { day: 'Mon', date: '2026-09-07', full: 'September 7' },
  { day: 'Tue', date: '2026-09-08', full: 'September 8' },
  { day: 'Wed', date: '2026-09-09', full: 'September 9', isToday: true },
  { day: 'Thu', date: '2026-09-10', full: 'September 10' },
  { day: 'Fri', date: '2026-09-11', full: 'September 11' },
  { day: 'Sat', date: '2026-09-12', full: 'September 12' },
  { day: 'Sun', date: '2026-09-13', full: 'September 13' },
];

const HOURS = [
  '06:00',
  '07:00',
  '08:00',
  '09:00',
  '10:00',
  '11:00',
  '12:00',
  '13:00',
  '14:00',
  '15:00',
  '16:00',
  '17:00',
  '18:00',
  '19:00',
  '20:00',
  '21:00',
  '22:00',
  '23:00',
];

export const ScheduleView: React.FC = () => {
  const [events, setEvents] = useState<ScheduleEvent[]>(mockScheduleEvents);
  const [viewMode, setViewMode] = useState<ScheduleViewMode>('day');
  const [selectedDate, setSelectedDate] = useState('2026-09-09');

  // Alarm & Event Editor Modal State
  const [isAlarmEditorOpen, setIsAlarmEditorOpen] = useState(false);
  const [editingEvent, setEditingEvent] = useState<ScheduleEvent | null>(null);
  const [eventToDelete, setEventToDelete] = useState<ScheduleEvent | null>(null);

  // Form State
  const [formTitle, setFormTitle] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formType, setFormType] = useState<ScheduleEventType>('alarm');
  const [formDate, setFormDate] = useState('2026-09-09');
  const [formStartTime, setFormStartTime] = useState('07:30');
  const [formEndTime, setFormEndTime] = useState('07:45');
  const [formRepeat, setFormRepeat] = useState<AlarmRepeat>('weekdays');
  const [formTargetDevice, setFormTargetDevice] = useState<AlarmTargetDevice>('both');
  const [formEnabled, setFormEnabled] = useState(true);
  const [formCategory, setFormCategory] = useState('System Alarm');
  const [formError, setFormError] = useState('');

  // Counts by type
  const eventCounts = useMemo(() => {
    return {
      alarms: events.filter((e) => e.type === 'alarm').length,
      tasks: events.filter((e) => e.type === 'task').length,
      reminders: events.filter((e) => e.type === 'reminder').length,
      calendar: events.filter((e) => e.type === 'calendar').length,
    };
  }, [events]);

  // Open Alarm Editor (specifically pre-configured for Alarm)
  const handleOpenAlarmEditor = (alarm?: ScheduleEvent) => {
    if (alarm) {
      setEditingEvent(alarm);
      setFormTitle(alarm.title);
      setFormDescription(alarm.description || '');
      setFormType('alarm');
      setFormDate(alarm.date);
      setFormStartTime(alarm.startTime);
      setFormEndTime(alarm.endTime || '08:00');
      setFormRepeat(alarm.repeat || 'daily');
      setFormTargetDevice(alarm.targetDevice || 'both');
      setFormEnabled(alarm.enabled ?? true);
      setFormCategory(alarm.category || 'System Alarm');
    } else {
      setEditingEvent(null);
      setFormTitle('');
      setFormDescription('');
      setFormType('alarm');
      setFormDate(selectedDate);
      setFormStartTime('07:00');
      setFormEndTime('07:15');
      setFormRepeat('weekdays');
      setFormTargetDevice('both');
      setFormEnabled(true);
      setFormCategory('System Alarm');
    }
    setFormError('');
    setIsAlarmEditorOpen(true);
  };

  // Open Generic Event Editor
  const handleOpenEventEditor = (event?: ScheduleEvent, defaultType: ScheduleEventType = 'calendar') => {
    if (event) {
      setEditingEvent(event);
      setFormTitle(event.title);
      setFormDescription(event.description || '');
      setFormType(event.type);
      setFormDate(event.date);
      setFormStartTime(event.startTime);
      setFormEndTime(event.endTime || '12:00');
      setFormRepeat(event.repeat || 'once');
      setFormTargetDevice(event.targetDevice || 'both');
      setFormEnabled(event.enabled ?? true);
      setFormCategory(event.category || 'General');
    } else {
      setEditingEvent(null);
      setFormTitle('');
      setFormDescription('');
      setFormType(defaultType);
      setFormDate(selectedDate);
      setFormStartTime('10:00');
      setFormEndTime('11:00');
      setFormRepeat('once');
      setFormTargetDevice('desktop');
      setFormEnabled(true);
      setFormCategory(defaultType === 'calendar' ? 'Work' : defaultType === 'task' ? 'Core System' : 'Health');
    }
    setFormError('');
    setIsAlarmEditorOpen(true);
  };

  // Save Event / Alarm
  const handleSaveEvent = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formTitle.trim()) {
      setFormError('Title is required.');
      return;
    }

    const isAlarm = formType === 'alarm';
    const isMirrored = isAlarm && (formTargetDevice === 'both' || formTargetDevice === 'android');

    if (editingEvent) {
      setEvents((prev) =>
        prev.map((ev) =>
          ev.id === editingEvent.id
            ? {
                ...ev,
                title: formTitle.trim(),
                description: formDescription.trim() || undefined,
                type: formType,
                date: formDate,
                startTime: formStartTime,
                endTime: formEndTime,
                repeat: isAlarm ? formRepeat : undefined,
                targetDevice: isAlarm ? formTargetDevice : undefined,
                enabled: isAlarm ? formEnabled : true,
                mirroredToAndroid: isMirrored,
                category: formCategory,
              }
            : ev
        )
      );
    } else {
      const newEvent: ScheduleEvent = {
        id: `ev-${Date.now()}`,
        title: formTitle.trim(),
        description: formDescription.trim() || undefined,
        type: formType,
        date: formDate,
        startTime: formStartTime,
        endTime: formEndTime,
        repeat: isAlarm ? formRepeat : undefined,
        targetDevice: isAlarm ? formTargetDevice : undefined,
        enabled: isAlarm ? formEnabled : true,
        mirroredToAndroid: isMirrored,
        category: formCategory,
      };
      setEvents((prev) => [...prev, newEvent]);
    }

    setIsAlarmEditorOpen(false);
  };

  // Toggle Alarm Status directly from list/card
  const handleToggleAlarm = (id: string, e?: React.MouseEvent) => {
    e?.stopPropagation();
    setEvents((prev) =>
      prev.map((ev) => (ev.id === id ? { ...ev, enabled: !ev.enabled } : ev))
    );
  };

  // Confirm Delete
  const handleConfirmDelete = () => {
    if (!eventToDelete) return;
    setEvents((prev) => prev.filter((ev) => ev.id !== eventToDelete.id));
    setEventToDelete(null);
  };

  // Restrained Event Type Styling Helper
  const getTypeStyling = (type: ScheduleEventType) => {
    switch (type) {
      case 'alarm':
        return {
          icon: <AlarmClock className="w-3.5 h-3.5" />,
          label: 'Alarm',
          borderClass: 'border-sky-500/25 dark:border-sky-400/20',
          badgeClass: 'bg-sky-500/10 text-sky-600 dark:text-sky-400 border-sky-500/20',
          accentText: 'text-sky-600 dark:text-sky-400',
          indicatorBg: 'bg-sky-500',
        };
      case 'task':
        return {
          icon: <CheckSquare className="w-3.5 h-3.5" />,
          label: 'Task',
          borderClass: 'border-indigo-500/25 dark:border-indigo-400/20',
          badgeClass: 'bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border-indigo-500/20',
          accentText: 'text-indigo-600 dark:text-indigo-400',
          indicatorBg: 'bg-indigo-500',
        };
      case 'reminder':
        return {
          icon: <Bell className="w-3.5 h-3.5" />,
          label: 'Reminder',
          borderClass: 'border-amber-500/25 dark:border-amber-400/20',
          badgeClass: 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/20',
          accentText: 'text-amber-600 dark:text-amber-400',
          indicatorBg: 'bg-amber-500',
        };
      case 'calendar':
        return {
          icon: <CalendarIcon className="w-3.5 h-3.5" />,
          label: 'Calendar',
          borderClass: 'border-teal-500/25 dark:border-teal-400/20',
          badgeClass: 'bg-teal-500/10 text-teal-600 dark:text-teal-400 border-teal-500/20',
          accentText: 'text-teal-600 dark:text-teal-400',
          indicatorBg: 'bg-teal-500',
        };
    }
  };

  // Day View Events sorted by time
  const dayEvents = useMemo(() => {
    return events
      .filter((e) => e.date === selectedDate)
      .sort((a, b) => a.startTime.localeCompare(b.startTime));
  }, [events, selectedDate]);

  // Agenda Grouped by Date
  const agendaDates = useMemo(() => {
    const dates = Array.from(new Set(events.map((e) => e.date))).sort();
    return dates;
  }, [events]);

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
              Schedule & Autonomous Timeline
            </h1>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Day, week, and agenda timeline orchestration with redundant on-device alarms.
            </p>
          </div>
        </div>

        {/* Quick Actions: New Alarm / New Event */}
        <div className="flex items-center gap-2 self-end sm:self-auto">
          <NeumorphicButton
            id="new-alarm-btn"
            size="sm"
            onClick={() => handleOpenAlarmEditor()}
            icon={<AlarmClock className="w-3.5 h-3.5 text-sky-500" />}
          >
            New Alarm
          </NeumorphicButton>

          <NeumorphicButton
            id="new-event-btn"
            variant="primary"
            size="sm"
            onClick={() => handleOpenEventEditor(undefined, 'calendar')}
            icon={<Plus className="w-3.5 h-3.5 text-white" />}
          >
            New Event
          </NeumorphicButton>
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

        {/* Date Selector / Navigation */}
        <div className="flex items-center justify-between sm:justify-end gap-2 text-xs font-medium">
          <button
            type="button"
            onClick={() => {
              const curIdx = WEEKDAYS.findIndex((w) => w.date === selectedDate);
              if (curIdx > 0) setSelectedDate(WEEKDAYS[curIdx - 1].date);
            }}
            className="p-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] cursor-pointer"
            title="Previous Day"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>

          <button
            type="button"
            onClick={() => setSelectedDate('2026-09-09')}
            className="px-3 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] cursor-pointer hover:border-[var(--color-accent)]/40"
          >
            {selectedDate === '2026-09-09' ? 'Today (Sep 9)' : selectedDate}
          </button>

          <button
            type="button"
            onClick={() => {
              const curIdx = WEEKDAYS.findIndex((w) => w.date === selectedDate);
              if (curIdx < WEEKDAYS.length - 1) setSelectedDate(WEEKDAYS[curIdx + 1].date);
            }}
            className="p-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] cursor-pointer"
            title="Next Day"
          >
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* 3. Event Types Summary Bar (Restrained Differences) */}
      <div className="flex flex-wrap items-center gap-2 text-xs">
        <span className="text-[11px] font-semibold text-[var(--color-text-muted)] uppercase tracking-wider mr-1">
          Active Pipeline:
        </span>
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-sky-500/10 text-sky-600 dark:text-sky-400 border border-sky-500/20 font-medium">
          <AlarmClock className="w-3 h-3" /> {eventCounts.alarms} Alarms
        </span>
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-teal-500/10 text-teal-600 dark:text-teal-400 border border-teal-500/20 font-medium">
          <CalendarIcon className="w-3 h-3" /> {eventCounts.calendar} Calendar
        </span>
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-500/20 font-medium">
          <CheckSquare className="w-3 h-3" /> {eventCounts.tasks} Tasks
        </span>
        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20 font-medium">
          <Bell className="w-3 h-3" /> {eventCounts.reminders} Reminders
        </span>
      </div>

      {/* 4. MAIN VIEW CONTENT: DAY, WEEK, OR AGENDA */}

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
                {selectedDate}
              </span>
            </h2>

            <span className="text-[11px] text-[var(--color-text-muted)] font-mono">
              {dayEvents.length} events scheduled
            </span>
          </div>

          {dayEvents.length === 0 ? (
            <div className="py-12 text-center text-xs text-[var(--color-text-muted)]">
              No events or alarms scheduled for {selectedDate}.
            </div>
          ) : (
            <div className="relative pl-6 sm:pl-8 space-y-4 before:absolute before:left-3 before:top-2 before:bottom-2 before:w-0.5 before:bg-[var(--color-border-subtle)]">
              {dayEvents.map((ev) => {
                const styling = getTypeStyling(ev.type);
                const isAlarm = ev.type === 'alarm';
                const isDisabledAlarm = isAlarm && ev.enabled === false;

                return (
                  <div key={ev.id} className="relative group">
                    {/* Node Dot */}
                    <div
                      className={`absolute -left-6 sm:-left-8 top-3 w-3.5 h-3.5 rounded-full border-2 border-[var(--color-app-bg)] shadow-xs ${
                        isDisabledAlarm ? 'bg-[var(--color-text-muted)]' : styling.indicatorBg
                      }`}
                    />

                    {/* Compact Event Container */}
                    <div
                      id={`day-event-${ev.id}`}
                      onClick={() => (isAlarm ? handleOpenAlarmEditor(ev) : handleOpenEventEditor(ev, ev.type))}
                      className={`p-3 sm:p-4 rounded-2xl surface-recessed border ${styling.borderClass} flex flex-col sm:flex-row sm:items-center justify-between gap-3 group-hover:border-[var(--color-accent)]/50 transition-all cursor-pointer ${
                        isDisabledAlarm ? 'opacity-60' : ''
                      }`}
                    >
                      {/* Left Details */}
                      <div className="flex items-start sm:items-center gap-3 min-w-0">
                        <div
                          className={`w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0 ${styling.badgeClass}`}
                        >
                          {styling.icon}
                        </div>

                        <div className="min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="font-mono text-xs font-bold text-[var(--color-text-primary)]">
                              {ev.startTime}
                              {ev.endTime ? ` - ${ev.endTime}` : ''}
                            </span>

                            <span
                              className={`text-[10px] font-semibold px-2 py-0.5 rounded-md uppercase tracking-wider ${styling.badgeClass}`}
                            >
                              {styling.label}
                            </span>

                            {isAlarm && ev.mirroredToAndroid && (
                              <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-1.5 py-0.5 rounded">
                                <ShieldCheck className="w-3 h-3" /> Android Mirrored
                              </span>
                            )}
                          </div>

                          <h3 className="text-sm font-bold text-[var(--color-text-primary)] mt-0.5 truncate">
                            {ev.title}
                          </h3>

                          {ev.description && (
                            <p className="text-xs text-[var(--color-text-secondary)] line-clamp-1 mt-0.5">
                              {ev.description}
                            </p>
                          )}
                        </div>
                      </div>

                      {/* Right Controls & Toggles */}
                      <div className="flex items-center gap-3 self-end sm:self-auto flex-shrink-0">
                        {isAlarm && (
                          <div className="flex items-center gap-2">
                            <span className="text-[11px] font-mono text-[var(--color-text-secondary)]">
                              {ev.enabled ? 'Active' : 'Off'}
                            </span>
                            <Toggle
                              checked={ev.enabled ?? true}
                              onChange={() => handleToggleAlarm(ev.id)}
                              size="sm"
                            />
                          </div>
                        )}

                        <div className="flex items-center gap-1 opacity-70 group-hover:opacity-100 transition-opacity">
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              isAlarm ? handleOpenAlarmEditor(ev) : handleOpenEventEditor(ev, ev.type);
                            }}
                            className="p-1.5 rounded-lg hover:bg-black/5 dark:hover:bg-white/5 text-[var(--color-text-secondary)] hover:text-[var(--color-accent)]"
                            title="Edit"
                          >
                            <Edit3 className="w-3.5 h-3.5" />
                          </button>

                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              setEventToDelete(ev);
                            }}
                            className="p-1.5 rounded-lg hover:bg-rose-500/10 text-[var(--color-text-secondary)] hover:text-rose-500"
                            title="Delete"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
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
              Week of September 7 - September 13, 2026
            </h2>
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              7 Days Active
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-2.5 min-w-[700px]">
            {WEEKDAYS.map((wd) => {
              const dayEvs = events
                .filter((e) => e.date === wd.date)
                .sort((a, b) => a.startTime.localeCompare(b.startTime));

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
                      ? 'surface-raised border-[var(--color-accent)]/50 shadow-sm'
                      : 'surface-recessed border-[var(--color-border-subtle)] hover:border-[var(--color-border-highlight)]'
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
                          wd.isToday ? 'text-[var(--color-accent)]' : 'text-[var(--color-text-primary)]'
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

                  {/* Compact Event Pills in Column */}
                  <div className="space-y-1.5 flex-1">
                    {dayEvs.length === 0 ? (
                      <span className="text-[10px] text-[var(--color-text-muted)] italic block pt-2">
                        No events
                      </span>
                    ) : (
                      dayEvs.map((ev) => {
                        const styling = getTypeStyling(ev.type);
                        return (
                          <div
                            key={ev.id}
                            onClick={(e) => {
                              e.stopPropagation();
                              ev.type === 'alarm' ? handleOpenAlarmEditor(ev) : handleOpenEventEditor(ev, ev.type);
                            }}
                            className={`p-1.5 rounded-lg border text-[11px] truncate flex items-center gap-1.5 transition-all hover:scale-[1.02] ${styling.badgeClass}`}
                          >
                            <span className="flex-shrink-0">{styling.icon}</span>
                            <span className="font-mono text-[10px] font-bold">{ev.startTime}</span>
                            <span className="truncate font-medium">{ev.title}</span>
                          </div>
                        );
                      })
                    )}
                  </div>

                  {/* Quick Add link */}
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
          {agendaDates.map((dateStr) => {
            const dateEvs = events
              .filter((e) => e.date === dateStr)
              .sort((a, b) => a.startTime.localeCompare(b.startTime));
            const isToday = dateStr === '2026-09-09';

            return (
              <div
                key={dateStr}
                className="p-4 sm:p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3"
              >
                {/* Date Heading */}
                <div className="flex items-center justify-between pb-2 border-b border-[var(--color-border-subtle)]">
                  <div className="flex items-center gap-2">
                    <CalendarIcon className="w-4 h-4 text-[var(--color-accent)]" />
                    <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
                      {isToday ? 'Today, September 9, 2026' : dateStr}
                    </h3>
                    {isToday && (
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[var(--color-accent)]/15 text-[var(--color-accent)]">
                        Current Day
                      </span>
                    )}
                  </div>

                  <span className="text-xs font-mono text-[var(--color-text-muted)]">
                    {dateEvs.length} items
                  </span>
                </div>

                {/* Items in this date */}
                <div className="space-y-2">
                  {dateEvs.map((ev) => {
                    const styling = getTypeStyling(ev.type);
                    const isAlarm = ev.type === 'alarm';

                    return (
                      <div
                        key={ev.id}
                        onClick={() => (isAlarm ? handleOpenAlarmEditor(ev) : handleOpenEventEditor(ev, ev.type))}
                        className={`p-3 rounded-2xl surface-recessed border ${styling.borderClass} flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:border-[var(--color-accent)]/40 transition-all cursor-pointer`}
                      >
                        <div className="flex items-center gap-3 min-w-0">
                          <div
                            className={`w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 ${styling.badgeClass}`}
                          >
                            {styling.icon}
                          </div>

                          <div className="min-w-0">
                            <div className="flex items-center gap-2">
                              <span className="font-mono text-xs font-bold text-[var(--color-text-primary)]">
                                {ev.startTime}
                              </span>
                              <span className="text-xs font-bold text-[var(--color-text-primary)] truncate">
                                {ev.title}
                              </span>
                            </div>

                            <div className="flex items-center gap-2 mt-0.5 text-[11px] text-[var(--color-text-muted)]">
                              <span className="capitalize">{styling.label}</span>
                              {ev.repeat && (
                                <>
                                  <span>•</span>
                                  <span className="inline-flex items-center gap-0.5">
                                    <Repeat className="w-2.5 h-2.5" /> {ev.repeat}
                                  </span>
                                </>
                              )}
                              {ev.targetDevice && (
                                <>
                                  <span>•</span>
                                  <span className="capitalize">Target: {ev.targetDevice}</span>
                                </>
                              )}
                            </div>
                          </div>
                        </div>

                        <div className="flex items-center gap-3 self-end sm:self-auto">
                          {isAlarm && (
                            <Toggle
                              checked={ev.enabled ?? true}
                              onChange={() => handleToggleAlarm(ev.id)}
                              size="sm"
                            />
                          )}

                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              setEventToDelete(ev);
                            }}
                            className="p-1 text-[var(--color-text-muted)] hover:text-rose-500"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* 5. ALARM EDITOR MODAL (Dedicated High-Polish Component with Redundancy Callout) */}
      <Modal
        isOpen={isAlarmEditorOpen}
        onClose={() => setIsAlarmEditorOpen(false)}
        title={editingEvent ? `Edit ${formType === 'alarm' ? 'Alarm' : 'Event'}` : 'Configure Alarm / Schedule Event'}
        description="Set time, repetition, hardware audio devices, and encrypted Android redundancy mirroring."
        maxWidth="md"
        footer={
          <>
            <NeumorphicButton
              id="alarm-cancel-btn"
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => setIsAlarmEditorOpen(false)}
            >
              Cancel
            </NeumorphicButton>

            <NeumorphicButton
              id="alarm-save-btn"
              type="button"
              variant="primary"
              size="sm"
              onClick={handleSaveEvent}
            >
              {editingEvent ? 'Save Changes' : 'Create Alarm'}
            </NeumorphicButton>
          </>
        }
      >
        <form onSubmit={handleSaveEvent} className="space-y-4">
          {formError && (
            <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-600 dark:text-rose-400 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span>{formError}</span>
            </div>
          )}

          {/* Type Selector (Alarm, Reminder, Task, Calendar) */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
              Schedule Entry Type
            </label>
            <div className="grid grid-cols-4 gap-1 p-1 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
              {(['alarm', 'calendar', 'task', 'reminder'] as ScheduleEventType[]).map((t) => {
                const isSelected = formType === t;
                const styling = getTypeStyling(t);
                return (
                  <button
                    key={t}
                    type="button"
                    onClick={() => setFormType(t)}
                    className={`py-1.5 rounded-xl text-xs font-semibold capitalize flex items-center justify-center gap-1.5 cursor-pointer select-none segmented-control-item ${
                      isSelected
                        ? 'segmented-control-item-active shadow-xs'
                        : 'segmented-control-item-inactive'
                    }`}
                  >
                    {styling.icon}
                    <span>{styling.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Title */}
          <div>
            <TextInput
              id="alarm-form-title"
              label="Title / Label *"
              value={formTitle}
              onChange={(e) => {
                setFormTitle(e.target.value);
                if (formError) setFormError('');
              }}
              placeholder={formType === 'alarm' ? 'e.g. Morning Briefing & Voice Synthesis Wakeup' : 'Event title...'}
              autoFocus
            />
          </div>

          {/* Date & Time Row */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <TextInput
                id="alarm-form-date"
                label="Date"
                type="date"
                value={formDate}
                onChange={(e) => setFormDate(e.target.value)}
              />
            </div>

            <div className="grid grid-cols-2 gap-2">
              <TextInput
                id="alarm-form-starttime"
                label="Start Time"
                type="time"
                value={formStartTime}
                onChange={(e) => setFormStartTime(e.target.value)}
              />
              <TextInput
                id="alarm-form-endtime"
                label="End Time"
                type="time"
                value={formEndTime}
                onChange={(e) => setFormEndTime(e.target.value)}
              />
            </div>
          </div>

          {/* If Alarm: Show Repeat, Target Devices, and Redundancy Callout */}
          {formType === 'alarm' && (
            <>
              {/* Repeat Selector */}
              <div className="flex flex-col gap-1.5">
                <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
                  Alarm Frequency / Repeat
                </label>
                <div className="grid grid-cols-4 gap-1 p-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
                  {(['once', 'daily', 'weekdays', 'weekends'] as AlarmRepeat[]).map((r) => {
                    const isRep = formRepeat === r;
                    return (
                      <button
                        key={r}
                        type="button"
                        onClick={() => setFormRepeat(r)}
                        className={`py-1.5 rounded-lg text-xs font-semibold capitalize cursor-pointer select-none segmented-control-item ${
                          isRep
                            ? 'segmented-control-item-active shadow-xs'
                            : 'segmented-control-item-inactive'
                        }`}
                      >
                        {r}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Target Devices (Desktop PC, Android Phone, Both) */}
              <div className="flex flex-col gap-1.5">
                <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
                  Target Playback Device(s)
                </label>
                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => setFormTargetDevice('desktop')}
                    className={`p-3 rounded-2xl border text-left transition-all cursor-pointer flex flex-col gap-1 ${
                      formTargetDevice === 'desktop'
                        ? 'surface-raised border-[var(--color-accent)] shadow-xs text-[var(--color-accent)]'
                        : 'surface-recessed border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                    }`}
                  >
                    <div className="flex items-center gap-1.5 font-bold text-xs">
                      <Monitor className="w-4 h-4" /> Desktop PC
                    </div>
                    <span className="text-[10px] text-[var(--color-text-muted)]">
                      Local spatial audio output
                    </span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setFormTargetDevice('android')}
                    className={`p-3 rounded-2xl border text-left transition-all cursor-pointer flex flex-col gap-1 ${
                      formTargetDevice === 'android'
                        ? 'surface-raised border-[var(--color-accent)] shadow-xs text-[var(--color-accent)]'
                        : 'surface-recessed border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                    }`}
                  >
                    <div className="flex items-center gap-1.5 font-bold text-xs">
                      <Smartphone className="w-4 h-4" /> Android Phone
                    </div>
                    <span className="text-[10px] text-[var(--color-text-muted)]">
                      Companion mesh bridge
                    </span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setFormTargetDevice('both')}
                    className={`p-3 rounded-2xl border text-left transition-all cursor-pointer flex flex-col gap-1 relative overflow-hidden ${
                      formTargetDevice === 'both'
                        ? 'surface-raised border-[var(--color-accent)] shadow-xs text-[var(--color-accent)] ring-1 ring-[var(--color-accent)]/30'
                        : 'surface-recessed border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                    }`}
                  >
                    <div className="flex items-center gap-1.5 font-bold text-xs">
                      <ShieldCheck className="w-4 h-4 text-emerald-500" /> Both (Mirrored)
                    </div>
                    <span className="text-[10px] text-emerald-600 dark:text-emerald-400 font-semibold">
                      Fail-Safe Redundancy
                    </span>
                  </button>
                </div>
              </div>

              {/* Visually communicate Android Redundancy Mirroring */}
              <div className="p-3.5 rounded-2xl surface-recessed border border-emerald-500/30 bg-emerald-500/[0.04] space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <ShieldCheck className="w-4 h-4 text-emerald-500" />
                    <h4 className="text-xs font-bold text-emerald-700 dark:text-emerald-300">
                      Android Redundancy Mesh Mirroring
                    </h4>
                  </div>
                  <span className="text-[10px] font-mono font-bold text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-full">
                    Mesh Link Ready
                  </span>
                </div>

                <p className="text-[11px] text-[var(--color-text-secondary)] leading-relaxed">
                  Important alarms synchronize automatically over local peer-to-peer encrypted Wi-Fi/Bluetooth.
                  If your workstation enters sleep or undergoes nighttime reboot, your Android Phone rings on schedule with zero cloud dependency.
                </p>

                <div className="flex items-center gap-2 pt-1 text-[10px] text-[var(--color-text-muted)] font-mono">
                  <Monitor className="w-3 h-3 text-[var(--color-accent)]" />
                  <span>Workstation Core</span>
                  <span>↔</span>
                  <Smartphone className="w-3 h-3 text-emerald-500" />
                  <span>Pixel 9 Pro (Local IP: 192.168.1.144)</span>
                </div>
              </div>

              {/* Alarm Active Status Toggle */}
              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between">
                <div>
                  <span className="text-xs font-bold text-[var(--color-text-primary)] block">
                    Alarm Status
                  </span>
                  <span className="text-[11px] text-[var(--color-text-muted)]">
                    Activate daemon schedule immediately upon saving.
                  </span>
                </div>
                <Toggle
                  checked={formEnabled}
                  onChange={setFormEnabled}
                  size="sm"
                />
              </div>
            </>
          )}

          {/* Description for all event types */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
              Notes & Context (Optional)
            </label>
            <textarea
              value={formDescription}
              onChange={(e) => setFormDescription(e.target.value)}
              placeholder="Add automated instructions or context..."
              rows={2}
              className="w-full px-3.5 py-2 text-sm rounded-xl surface-recessed border border-[var(--color-border-subtle)] focus:border-[var(--color-accent)] focus:outline-none focus:ring-1 focus:ring-[var(--color-accent)]/25 text-[var(--color-text-primary)] resize-none"
            />
          </div>
        </form>
      </Modal>

      {/* 6. Delete Confirmation Modal */}
      <Modal
        isOpen={Boolean(eventToDelete)}
        onClose={() => setEventToDelete(null)}
        title="Delete Schedule Entry"
        description="Are you sure you want to remove this scheduled item? Local alarms and sync daemons will be unlinked."
        maxWidth="sm"
        footer={
          <>
            <NeumorphicButton
              id="cancel-delete-event-btn"
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => setEventToDelete(null)}
            >
              Cancel
            </NeumorphicButton>

            <NeumorphicButton
              id="confirm-delete-event-btn"
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
        {eventToDelete && (
          <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-1 text-xs">
            <span className="font-semibold text-[var(--color-text-primary)] line-clamp-2">
              &quot;{eventToDelete.title}&quot;
            </span>
            <div className="text-[var(--color-text-muted)] flex items-center gap-2 font-mono">
              <span>{eventToDelete.startTime}</span>
              <span>•</span>
              <span className="capitalize">{eventToDelete.type}</span>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};
