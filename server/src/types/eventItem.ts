/**
 * TypeScript types for EventItem DTO
 * 
 * These types are derived from schemas/eventItem.schema.json
 * and shared between client and server for consistency.
 */

export type EventType = 
  | 'ASSIGNMENT' 
  | 'QUIZ' 
  | 'MIDTERM' 
  | 'FINAL' 
  | 'LAB' 
  | 'LECTURE' 
  | 'TUTORIAL'
  | 'OFFICE_HOURS'
  | 'IMPORTANT_DATE'
  | 'OTHER';

export interface EventItemDTO {
  /** Unique identifier for the event */
  id: string;
  
  /** Course code (e.g., 'CS101') */
  courseCode: string;
  
  /** Type of the event */
  type: EventType;
  
  /** Title of the event */
  title: string;
  
  /** Start date/time of the event in ISO8601 format. Null when no date is mentioned in the syllabus. */
  start: string | null;
  
  /** True when the syllabus text does not contain an explicit date for this event */
  needsDate?: boolean;
  
  /** End date/time of the event in ISO8601 format */
  end?: string;
  
  /** Whether this is an all-day event */
  allDay?: boolean;
  
  /** Location where the event takes place */
  location?: string;
  
  /** Additional notes or description for the event */
  notes?: string;
  
  /** Recurrence rule in iCalendar RRULE format */
  recurrenceRule?: string;
  
  /** Minutes before the event to send a reminder (max 30 days) */
  reminderMinutes?: number;
  
  /** Confidence score from the parser (0-1) */
  confidence?: number;

  /** Exact syllabus text used to determine the date. Null when no evidence found. */
  dateSource?: string | null;
}

/**
 * Array of EventItem DTOs - common response format
 */
export type EventItemsResponse = EventItemDTO[];

/**
 * A grading scheme entry surfaced to the client.
 */
export interface GradingSchemeEntryDTO {
  /** Raw name as it appears in the syllabus (e.g. "Mini Project") */
  name: string;
  /** Weight as a decimal 0-1 (10% → 0.10). Null if no percentage found. */
  weight: number | null;
  /** Best-guess event type based on the name */
  type: EventType;
}

/**
 * Parse response from the server
 */
export interface ParseResponse {
  events: EventItemDTO[];
  confidence: number;
  gradingScheme?: GradingSchemeEntryDTO[];
  diagnostics?: {
    source: 'openai';
    processingTimeMs: number;
    textLength: number;
    warnings?: string[];
    validation?: {
      totalEvents: number;
      validEvents: number;
      invalidEvents: number;
      clampedEvents: number;
      defaultsApplied: number;
    };
    openai?: {
      processingTimeMs?: number;
      usedModel?: string;
    };
  };
}
