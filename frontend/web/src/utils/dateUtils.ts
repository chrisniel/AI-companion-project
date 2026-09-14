/**
 * Browser-local date & time utilities for Tasks and Schedule.
 * 
 * Strict truthfulness principles:
 * - Operates entirely in browser-local timezone (no hardcoded UTC or local region bias).
 * - Dynamically derives current date from JavaScript Date clock (no hardcoded dates).
 * - Converts browser-local input to/from ISO-8601 strings for backend compatibility.
 */

export const getLocalDateString = (d: Date = new Date()): string => {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

export const getLocalTimeString = (d: Date = new Date()): string => {
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
};

export const formatLocalTime = (d: Date): string => {
  return d.toLocaleTimeString(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  });
};

export const formatLocalDate = (d: Date): string => {
  return d.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
};

export const formatShortDate = (d: Date): string => {
  return d.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
  });
};

/**
 * Split an ISO-8601 string into browser-local YYYY-MM-DD and HH:mm strings.
 */
export const parseIsoToLocal = (
  isoString: string
): { dateStr: string; timeStr: string } => {
  const d = new Date(isoString);
  if (isNaN(d.getTime())) {
    return { dateStr: '', timeStr: '' };
  }
  return {
    dateStr: getLocalDateString(d),
    timeStr: getLocalTimeString(d),
  };
};

/**
 * Combine browser-local YYYY-MM-DD and HH:mm into an ISO-8601 string.
 */
export const combineLocalDateAndTimeToIso = (
  dateStr: string,
  timeStr: string
): string => {
  const [y, m, d] = dateStr.split('-').map(Number);
  const [h, min] = timeStr.split(':').map(Number);
  const localDate = new Date(y, m - 1, d, h || 0, min || 0, 0);
  return localDate.toISOString();
};

/**
 * Check if a task is overdue:
 * - status is 'pending' or 'in_progress'
 * - due_date exists and its timestamp is strictly before the current timestamp.
 */
export const isOverdue = (
  dueDateIso: string | null | undefined,
  status: string
): boolean => {
  if (!dueDateIso) return false;
  if (status !== 'pending' && status !== 'in_progress') return false;
  const dueTime = new Date(dueDateIso).getTime();
  return !isNaN(dueTime) && dueTime < Date.now();
};

/**
 * Human-readable label for reminder_minutes_before.
 * Exact representation without rounding.
 */
export const getReminderLabel = (
  minutesBefore: number | null | undefined
): string | null => {
  if (minutesBefore === null || minutesBefore === undefined || minutesBefore < 0) return null;
  if (minutesBefore === 0) return 'At due time';
  if (minutesBefore % 1440 === 0) {
    const days = minutesBefore / 1440;
    return `${days} day${days > 1 ? 's' : ''} before`;
  }
  if (minutesBefore % 60 === 0) {
    const hours = minutesBefore / 60;
    return `${hours} hour${hours > 1 ? 's' : ''} before`;
  }
  return `${minutesBefore} min before`;
};


export interface WeekDayInfo {
  day: string; // e.g. 'Mon'
  date: string; // YYYY-MM-DD
  full: string; // e.g. 'September 14'
  isToday: boolean;
}

/**
 * Dynamically derive the 7-day week (Monday to Sunday) containing baseDate.
 */
export const getWeekDays = (baseDate: Date = new Date()): WeekDayInfo[] => {
  const d = new Date(baseDate);
  const dayOfWeek = d.getDay(); // 0 is Sunday, 1 is Monday...
  const diffToMonday = (dayOfWeek + 6) % 7; // Monday is 0, Sunday is 6
  const monday = new Date(d);
  monday.setDate(d.getDate() - diffToMonday);
  monday.setHours(0, 0, 0, 0);

  const days: WeekDayInfo[] = [];
  const todayStr = getLocalDateString(new Date());

  for (let i = 0; i < 7; i++) {
    const cur = new Date(monday);
    cur.setDate(monday.getDate() + i);
    const dateStr = getLocalDateString(cur);
    days.push({
      day: cur.toLocaleDateString(undefined, { weekday: 'short' }),
      date: dateStr,
      full: cur.toLocaleDateString(undefined, { month: 'long', day: 'numeric' }),
      isToday: dateStr === todayStr,
    });
  }

  return days;
};

/**
 * Add or subtract days from a YYYY-MM-DD string.
 */
export const addDays = (dateStr: string, days: number): string => {
  const [y, m, d] = dateStr.split('-').map(Number);
  const cur = new Date(y, m - 1, d);
  cur.setDate(cur.getDate() + days);
  return getLocalDateString(cur);
};
