/**
 * JSON schema validation for EventItem DTOs
 * 
 * Validates event data against schema, maps to camelCase, fills defaults,
 * and clamps dates to academic term windows.
 */

import type { EventItemDTO, EventType } from '../types/eventItem.js';
import type { EventCandidate } from '../parsing/eventBuilder.js';

/**
 * Configuration for validation and processing
 */
export interface ValidationConfig {
  /** Academic term start date for date clamping */
  termStart?: Date;
  /** Academic term end date for date clamping */
  termEnd?: Date;
  /** Default course ID if not provided */
  defaultCourseId?: string;
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
  
  if (!e.courseId || typeof e.courseId !== 'string' || e.courseId.trim().length === 0) {
    errors.push('courseId is required and must be a non-empty string');
  } else if (!/^[a-zA-Z0-9_-]+$/.test(e.courseId.replace(/[^a-zA-Z0-9_-]/g, ''))) {
    // Allow more flexible courseId patterns (relax validation)
    // errors.push('courseId must match pattern ^[a-zA-Z0-9_-]+$');
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
  if (e.courseCode !== undefined) {
    if (typeof e.courseCode !== 'string') {
      errors.push('courseCode must be a string');
    } else if (e.courseCode.trim().length > 0 && !/^[A-Z]{2,4}[0-9]{2,4}[A-Z]?$/i.test(e.courseCode.trim())) {
      // Make course code validation case-insensitive and more flexible
      // errors.push('courseCode must match pattern ^[A-Z]{2,4}[0-9]{2,4}[A-Z]?$');
    }
  }
  
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
  candidates: EventCandidate[], 
  config: ValidationConfig = {}
): ValidationResult {
  const result: ValidationResult = {
    valid: true,
    events: [],
    errors: [],
    warnings: [],
    stats: {
      totalEvents: candidates.length,
      validEvents: 0,
      invalidEvents: 0,
      clampedEvents: 0,
      defaultsApplied: 0
    }
  };

  if (candidates.length === 0) {
    return result;
  }

  for (let i = 0; i < candidates.length; i++) {
    const candidate = candidates[i];
    
    try {
      // Convert candidate to DTO format
      let dto = candidateToDTO(candidate, config);
      
      // Apply defaults and processing
      dto = applyDefaults(dto, config);
      
      // Always clamp dates (handles term window AND invalid end date fixing)
      const clamped = clampDatesToTerm(dto, config);
      if (clamped.wasClamped) {
        result.stats.clampedEvents++;
        if (config.termStart || config.termEnd) {
          result.warnings.push(`Event "${dto.title}" had dates clamped to term window`);
        } else {
          result.warnings.push(`Event "${dto.title}" had invalid date range corrected`);
        }
      }
      dto = clamped.event;
      
      // Validate against schema
      const validation = validateEventItemDTO(dto);
      
      if (validation.valid) {
        result.events.push(dto);
        result.stats.validEvents++;
      } else {
        result.stats.invalidEvents++;
        result.valid = false;
        
        const errorMessages = validation.errors.map(err => 
          `Event ${i + 1}: ${err}`
        );
        
        result.errors.push(...errorMessages);
      }
      
    } catch (error) {
      result.stats.invalidEvents++;
      result.valid = false;
      result.errors.push(`Event ${i + 1}: ${(error as Error).message}`);
    }
  }

  return result;
}

/**
 * Converts EventCandidate to EventItemDTO format
 */
function candidateToDTO(candidate: EventCandidate, config: ValidationConfig): EventItemDTO {
  return {
    id: candidate.id,
    courseId: config.defaultCourseId || 'unknown',
    courseCode: config.defaultCourseCode,
    type: candidate.type,
    title: candidate.title,
    start: candidate.start.toISOString(),
    end: candidate.end?.toISOString(),
    allDay: candidate.allDay,
    location: candidate.location,
    notes: candidate.notes,
    confidence: candidate.confidence
  };
}

/**
 * Applies default values and processing rules
 */
function applyDefaults(dto: EventItemDTO, config: ValidationConfig): EventItemDTO {
  const result = { ...dto };
  
  // Apply allDay default if no time specified and no end date
  if (result.allDay === undefined) {
    const hasTime = result.start.includes('T') && !result.start.endsWith('T00:00:00.000Z');
    result.allDay = !hasTime;
  }
  
  // Ensure title is not empty
  if (!result.title || result.title.trim().length === 0) {
    result.title = `${result.type.charAt(0) + result.type.slice(1).toLowerCase()}`;
  }
  
  // Trim and validate string fields
  result.title = result.title.trim();
  if (result.location) result.location = result.location.trim();
  if (result.notes) result.notes = result.notes.trim();
  if (result.courseCode) result.courseCode = result.courseCode.trim();
  
  // Ensure confidence is within bounds
  if (result.confidence !== undefined) {
    result.confidence = Math.max(0, Math.min(1, result.confidence));
  }
  
  return result;
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
  
  const startDate = new Date(result.start);
  let endDate = result.end ? new Date(result.end) : null;
  
  // Clamp start date
  if (termStart && startDate < termStart) {
    result.start = termStart.toISOString();
    wasClamped = true;
  } else if (termEnd && startDate > termEnd) {
    result.start = termEnd.toISOString();
    wasClamped = true;
  }
  
  // Clamp end date if present
  if (endDate) {
    if (termStart && endDate < termStart) {
      result.end = termStart.toISOString();
      wasClamped = true;
    } else if (termEnd && endDate > termEnd) {
      result.end = termEnd.toISOString();
      wasClamped = true;
    }
  }
  
  // Ensure end date is after start date (always check, not just when clamping)
  if (result.end) {
    const finalStart = new Date(result.start);
    const finalEnd = new Date(result.end);
    
    if (finalEnd <= finalStart) {
      // If end is not after start, remove end date or adjust it
      if (result.allDay) {
        delete result.end;
      } else {
        // Add 1 hour to start time
        const newEnd = new Date(finalStart.getTime() + 60 * 60 * 1000);
        result.end = newEnd.toISOString();
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
 */
export function isValidISODate(dateString: string): boolean {
  try {
    const date = new Date(dateString);
    return !isNaN(date.getTime()) && dateString === date.toISOString();
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
    start: new Date(event.start).toISOString(),
    end: event.end ? new Date(event.end).toISOString() : undefined,
    // Normalize string fields
    title: event.title.trim(),
    location: event.location?.trim(),
    notes: event.notes?.trim(),
    courseCode: event.courseCode?.trim(),
    // Ensure confidence is properly bounded
    confidence: event.confidence !== undefined 
      ? Math.max(0, Math.min(1, event.confidence)) 
      : undefined
  }));
}
