/**
 * JSON schema validation for EventItem DTOs
 * 
 * Validates event data against schema, maps to camelCase, fills defaults,
 * and clamps dates to academic term windows.
 */

import type { EventItemDTO, EventType } from '../types/eventItem.js';
import {
  formatUtcDateWithoutTimezone,
  parseFlexibleISODate,
  matchesAcceptedISOFormat,
  ACCEPTED_ISO_LOCAL_PATTERNS,
} from '../utils/date.js';

/**
 * Configuration for validation and processing
 */
export interface ValidationConfig {
  /** Academic term start date for date clamping */
  termStart?: Date;
  /** Academic term end date for date clamping */
  termEnd?: Date;
  /** Default course code if not provided */
  defaultCourseCode?: string;
  /** Whether to apply strict validation */
  strict?: boolean;
}

/**
 * Result of validation process
 */
export interface ValidationResult {
  /** Whether validation was successful */
  valid: boolean;
  /** Validated and processed events */
  events: EventItemDTO[];
  /** Validation errors if any */
  errors: string[];
  /** Warnings about data processing */
  warnings: string[];
  /** Statistics about validation */
  stats: {
    /** Total events processed */
    totalEvents: number;
    /** Events that passed validation */
    validEvents: number;
    /** Events that failed validation */
    invalidEvents: number;
    /** Events with dates clamped to term */
    clampedEvents: number;
    /** Events with defaults applied */
    defaultsApplied: number;
  };
}

/**
 * Manual validation schema for EventItemDTO
 * (Replaces AJV for Cloudflare Workers compatibility)
 */
const VALID_EVENT_TYPES: EventType[] = ['ASSIGNMENT', 'QUIZ', 'MIDTERM', 'FINAL', 'LAB', 'LECTURE', 'OTHER'];

/**
 * Validates an EventItemDTO manually against our schema
 */
function validateEventItemDTO(event: unknown): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  
  if (!event || typeof event !== 'object') {
    errors.push('Event must be an object');
    return { valid: false, errors };
  }
  
  const e = event as any;
  
  // Required fields
  if (!e.id || typeof e.id !== 'string' || e.id.trim().length === 0) {
    errors.push('id is required and must be a non-empty string');
  } else if (!/^[a-zA-Z0-9_-]+$/.test(e.id)) {
    errors.push('id must match pattern ^[a-zA-Z0-9_-]+$');
  }
  
  if (!e.courseCode || typeof e.courseCode !== 'string' || e.courseCode.trim().length === 0) {
    errors.push('courseCode is required and must be a non-empty string');
  }
  
  if (!e.type || !VALID_EVENT_TYPES.includes(e.type)) {
    errors.push(`type must be one of: ${VALID_EVENT_TYPES.join(', ')}`);
  }
  
  if (!e.title || typeof e.title !== 'string' || e.title.trim().length === 0) {
    errors.push('title is required and must be a non-empty string');
  } else if (e.title.length > 200) {
    errors.push('title must not exceed 200 characters');
  }
  
  if (!e.start || typeof e.start !== 'string') {
    errors.push('start is required and must be a string');
  } else if (!isValidISODate(e.start)) {
    errors.push('start must be a valid ISO 8601 date-time string');
  }
  
  // Optional fields
  // courseCode already validated above
  
  if (e.end !== undefined) {
    if (typeof e.end !== 'string') {
      errors.push('end must be a string');
    } else if (!isValidISODate(e.end)) {
      errors.push('end must be a valid ISO 8601 date-time string');
    }
  }
  
  if (e.allDay !== undefined && typeof e.allDay !== 'boolean') {
    errors.push('allDay must be a boolean');
  }
  
  if (e.location !== undefined) {
    if (typeof e.location !== 'string') {
      errors.push('location must be a string');
    } else if (e.location.length > 100) {
      errors.push('location must not exceed 100 characters');
    }
  }
  
  if (e.notes !== undefined) {
    if (typeof e.notes !== 'string') {
      errors.push('notes must be a string');
    } else if (e.notes.length > 1000) {
      errors.push('notes must not exceed 1000 characters');
    }
  }

  if (e.recurrenceRule !== undefined && typeof e.recurrenceRule !== 'string') {
    errors.push('recurrenceRule must be a string');
  }
  
  if (e.reminderMinutes !== undefined) {
    if (typeof e.reminderMinutes !== 'number') {
      errors.push('reminderMinutes must be a number');
    } else if (e.reminderMinutes < 0 || e.reminderMinutes > 43200) {
      errors.push('reminderMinutes must be between 0 and 43200 (30 days)');
    }
  }
  
  if (e.confidence !== undefined) {
    if (typeof e.confidence !== 'number') {
      errors.push('confidence must be a number');
    } else if (e.confidence < 0 || e.confidence > 1) {
      errors.push('confidence must be between 0 and 1');
    }
  }
  
  return { valid: errors.length === 0, errors };
}

/**
 * Validates event candidates and converts them to valid EventItemDTO objects
 * 
 * @param candidates Array of event candidates from parsing
 * @param config Validation configuration
 * @returns Validation result with valid events and diagnostics
 */
export function validateEvents(
  rawEvents: unknown[], 
  config: ValidationConfig = {}
): ValidationResult {
  const total = Array.isArray(rawEvents) ? rawEvents.length : 0;

  const result: ValidationResult = {
    valid: true,
    events: [],
    errors: [],
    warnings: [],
    stats: {
      totalEvents: total,
      validEvents: 0,
      invalidEvents: 0,
      clampedEvents: 0,
      defaultsApplied: 0
    }
  };

  if (!Array.isArray(rawEvents) || rawEvents.length === 0) {
    return result;
  }

  for (let i = 0; i < rawEvents.length; i++) {
    const raw = rawEvents[i];

    const validation = validateEventItemDTO(raw);
    if (!validation.valid) {
      result.stats.invalidEvents++;
      result.valid = false;
      validation.errors.forEach(err => result.errors.push(`Event ${i + 1}: ${err}`));
      continue;
    }

    try {
      const dto = { ...(raw as EventItemDTO) };
      const defaults = applyDefaults(dto, config);
      if (defaults.defaultsApplied) {
        result.stats.defaultsApplied++;
      }

      const clamped = clampDatesToTerm(defaults.event, config);
      if (clamped.wasClamped) {
        result.stats.clampedEvents++;
        const title = clamped.event.title;
        if (config.termStart || config.termEnd) {
          result.warnings.push(`Event "${title}" had dates clamped to term window`);
        } else {
          result.warnings.push(`Event "${title}" had invalid date range corrected`);
        }
      }

      result.stats.validEvents++;
      result.events.push(clamped.event);
    } catch (error) {
      result.stats.invalidEvents++;
      result.valid = false;
      result.errors.push(`Event ${i + 1}: ${(error as Error).message}`);
    }
  }

  if (result.events.length > 0) {
    result.events = normalizeEventData(result.events);
  }

  return result;
}

/**
 * Applies default values and processing rules
 */
function applyDefaults(dto: EventItemDTO, config: ValidationConfig): { event: EventItemDTO; defaultsApplied: boolean } {
  const result = { ...dto };
  let defaultsApplied = false;
  
  // Apply allDay default if no time specified and no end date
  if (result.allDay === undefined) {
    const hasDateTime = result.start.includes('T');
    const hasNonMidnightTime = hasDateTime && !/T00:00:00\.000(?:[+-]\d{2}:\d{2})?$/.test(result.start);
    result.allDay = hasDateTime ? !hasNonMidnightTime : true;
    defaultsApplied = true;
  }
  
  // Ensure title is not empty
  if (!result.title || result.title.trim().length === 0) {
    result.title = `${result.type.charAt(0) + result.type.slice(1).toLowerCase()}`;
    defaultsApplied = true;
  }
  
  // Trim and validate string fields
  result.title = result.title.trim();
  if (result.location) result.location = result.location.trim();
  if (result.notes) result.notes = result.notes.trim();
  if (result.courseCode) result.courseCode = result.courseCode.trim();
  
  // Ensure confidence is within bounds
  if (result.confidence !== undefined) {
    const clamped = Math.max(0, Math.min(1, result.confidence));
    if (clamped !== result.confidence) defaultsApplied = true;
    result.confidence = clamped;
  }
  
  return { event: result, defaultsApplied };
}

/**
 * Clamps event dates to academic term window
 */
function clampDatesToTerm(
  dto: EventItemDTO, 
  config: ValidationConfig
): { event: EventItemDTO; wasClamped: boolean } {
  let wasClamped = false;
  const result = { ...dto };
  
  const termStart = config.termStart;
  const termEnd = config.termEnd;
  
  if (!termStart && !termEnd) {
    return { event: result, wasClamped };
  }
  
  const startDate = parseFlexibleISODate(result.start);
  let endDate = result.end ? parseFlexibleISODate(result.end) : null;
  
  // Clamp start date
  if (termStart && startDate < termStart) {
    result.start = formatUtcDateWithoutTimezone(termStart);
    wasClamped = true;
  } else if (termEnd && startDate > termEnd) {
    result.start = formatUtcDateWithoutTimezone(termEnd);
    wasClamped = true;
  }
  
  // Clamp end date if present
  if (endDate) {
    if (termStart && endDate < termStart) {
      result.end = formatUtcDateWithoutTimezone(termStart);
      wasClamped = true;
    } else if (termEnd && endDate > termEnd) {
      result.end = formatUtcDateWithoutTimezone(termEnd);
      wasClamped = true;
    }
  }
  
  // Ensure end date is after start date (always check, not just when clamping)
  if (result.end) {
    const finalStart = parseFlexibleISODate(result.start);
    const finalEnd = parseFlexibleISODate(result.end);
    
    if (finalEnd <= finalStart) {
      // If end is not after start, remove end date or adjust it
      if (result.allDay) {
        delete result.end;
      } else {
        // Add 1 hour to start time
        const newEnd = new Date(finalStart.getTime() + 60 * 60 * 1000);
        result.end = formatUtcDateWithoutTimezone(newEnd);
      }
      wasClamped = true;
    }
  }
  
  return { event: result, wasClamped };
}

/**
 * Validates a single EventItemDTO against the schema
 * 
 * @param event Event to validate
 * @returns Validation result
 */
export function validateSingleEvent(event: unknown): {
  valid: boolean;
  errors: string[];
  event?: EventItemDTO;
} {
  const validation = validateEventItemDTO(event);
  
  if (validation.valid) {
    return {
      valid: true,
      errors: [],
      event: event as EventItemDTO
    };
  }
  
  return {
    valid: false,
    errors: validation.errors
  };
}

/**
 * Creates a term window configuration for academic semesters
 * 
 * @param year Academic year (e.g., 2025)
 * @param semester 'fall', 'spring', or 'summer'
 * @returns Term configuration with start/end dates
 */
export function createTermWindow(
  year: number, 
  semester: 'fall' | 'spring' | 'summer'
): Pick<ValidationConfig, 'termStart' | 'termEnd'> {
  switch (semester.toLowerCase()) {
    case 'fall':
      return {
        termStart: new Date(year, 7, 15), // August 15
        termEnd: new Date(year, 11, 20)   // December 20
      };
    case 'spring':
      return {
        termStart: new Date(year, 0, 10), // January 10
        termEnd: new Date(year, 4, 15)    // May 15
      };
    case 'summer':
      return {
        termStart: new Date(year, 4, 20), // May 20
        termEnd: new Date(year, 7, 10)    // August 10
      };
    default:
      throw new Error(`Invalid semester: ${semester}. Must be 'fall', 'spring', or 'summer'`);
  }
}

/**
 * Utility to check if a date string is valid ISO 8601
 * Accepts various ISO 8601 formats and validates actual date validity
 */
export function isValidISODate(dateString: string): boolean {
  try {
    if (!matchesAcceptedISOFormat(dateString)) {
      return false;
    }

    const parsed = parseFlexibleISODate(dateString);
    if (Number.isNaN(parsed.getTime())) {
      return false;
    }

    if (ACCEPTED_ISO_LOCAL_PATTERNS.ISO_LOCAL_WITH_MS.test(dateString)) {
      return formatUtcDateWithoutTimezone(parsed) === dateString;
    }

    if (ACCEPTED_ISO_LOCAL_PATTERNS.ISO_LOCAL_NO_MS.test(dateString)) {
      const formatted = formatUtcDateWithoutTimezone(parsed);
      return formatted.startsWith(`${dateString}.`);
    }

    if (ACCEPTED_ISO_LOCAL_PATTERNS.ISO_DATE_ONLY.test(dateString)) {
      const formatted = formatUtcDateWithoutTimezone(parsed);
      return formatted.startsWith(`${dateString}T`);
    }

    // Fallback for canonical ISO strings with timezone (e.g., heuristics historical values)
    return !Number.isNaN(parsed.getTime());
  } catch {
    return false;
  }
}

/**
 * Normalizes event data by ensuring consistent formatting
 */
export function normalizeEventData(events: EventItemDTO[]): EventItemDTO[] {
  return events.map(event => ({
    ...event,
    // Ensure consistent ISO date format
    start: /[+-]\d{2}:\d{2}$/.test(event.start)
      ? event.start
      : formatUtcDateWithoutTimezone(parseFlexibleISODate(event.start)),
    end: event.end
      ? (/[+-]\d{2}:\d{2}$/.test(event.end)
          ? event.end
          : formatUtcDateWithoutTimezone(parseFlexibleISODate(event.end)))
      : undefined,
    // Normalize string fields
    title: event.title.trim(),
    location: event.location?.trim(),
    notes: event.notes?.trim(),
    courseCode: event.courseCode?.trim(),
    recurrenceRule: event.recurrenceRule?.trim(),
    // Ensure confidence is properly bounded
    confidence: event.confidence !== undefined 
      ? Math.max(0, Math.min(1, event.confidence)) 
      : undefined
  }));
}
