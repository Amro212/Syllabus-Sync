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
  | 'OTHER';

export interface EventItemDTO {
  /** Unique identifier for the event */
  id: string;
  
  /** Identifier for the course this event belongs to */
  courseId: string;
  
  /** Optional course code (e.g., 'CS101') */
  courseCode?: string;
  
  /** Type of the event */
  type: EventType;
  
  /** Title of the event */
  title: string;
  
  /** Start date/time of the event in ISO8601 format */
  start: string;
  
  /** End date/time of the event in ISO8601 format */
  end?: string;
  
  /** Whether this is an all-day event */
  allDay?: boolean;
  
  /** Location where the event takes place */
  location?: string;
  
  /** Additional notes or description for the event */
  notes?: string;
  
  /** Minutes before the event to send a reminder (max 30 days) */
  reminderMinutes?: number;
  
  /** Confidence score from the parser (0-1) */
  confidence?: number;
}

/**
 * Array of EventItem DTOs - common response format
 */
export type EventItemsResponse = EventItemDTO[];

/**
 * Parse response from the server
 */
export interface ParseResponse {
  events: EventItemDTO[];
  confidence: number;
  diagnostics?: {
    source: 'heuristics' | 'openai';
    processingTimeMs: number;
    textLength: number;
    warnings?: string[];
  };
}
