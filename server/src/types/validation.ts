/**
 * JSON Schema validation utilities - simple runtime validation
 * (AJV causes issues in Workers environment, so using manual validation)
 */

import { EventItemDTO, EventItemsResponse, EventType } from './eventItem.js';

// Valid event types
const validEventTypes = new Set<EventType>(['ASSIGNMENT', 'QUIZ', 'MIDTERM', 'FINAL', 'LAB', 'LECTURE', 'OTHER']);

// ISO8601 date regex (simplified)
const iso8601Regex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?(?:[+-]\d{2}:\d{2})?$/;

// Course code regex (letters + digits, allow separators)
const courseCodeRegex = /^[A-Z]{2,6}[A-Z0-9\s\-\*]{0,26}$/;

/**
 * Validates a single EventItem manually
 */
export function validateEventItem(data: unknown): boolean {
  if (!data || typeof data !== 'object') return false;
  
  const item = data as Record<string, unknown>;
  
  // Required fields
  if (!item.id || typeof item.id !== 'string' || item.id.length === 0) return false;
  if (!item.courseCode || typeof item.courseCode !== 'string' || item.courseCode.trim().length === 0 || !courseCodeRegex.test(item.courseCode.trim())) return false;
  if (!item.type || !validEventTypes.has(item.type as EventType)) return false;
  if (!item.title || typeof item.title !== 'string' || item.title.length === 0 || item.title.length > 200) return false;
  if (!item.start || typeof item.start !== 'string' || !iso8601Regex.test(item.start)) return false;
  
  // Optional fields validation
  // courseCode already validated
  if (item.end !== undefined && (typeof item.end !== 'string' || !iso8601Regex.test(item.end))) return false;
  if (item.allDay !== undefined && typeof item.allDay !== 'boolean') return false;
  if (item.location !== undefined && (typeof item.location !== 'string' || item.location.length > 100)) return false;
  if (item.notes !== undefined && (typeof item.notes !== 'string' || item.notes.length > 1000)) return false;
  if (item.recurrenceRule !== undefined && typeof item.recurrenceRule !== 'string') return false;
  if (item.reminderMinutes !== undefined && (typeof item.reminderMinutes !== 'number' || item.reminderMinutes < 0 || item.reminderMinutes > 43200)) return false;
  if (item.confidence !== undefined && (typeof item.confidence !== 'number' || item.confidence < 0 || item.confidence > 1)) return false;
  
  return true;
}

/**
 * Validates an array of EventItems
 */
export function validateEventItems(data: unknown): boolean {
  if (!Array.isArray(data)) return false;
  if (data.length > 100) return false; // Reasonable limit
  
  return data.every(item => validateEventItem(item));
}

/**
 * Validates a single EventItem and returns typed result
 */
export function isValidEventItem(data: unknown): data is EventItemDTO {
  return validateEventItem(data);
}

/**
 * Validates an array of EventItems and returns typed result
 */
export function isValidEventItems(data: unknown): data is EventItemsResponse {
  return validateEventItems(data);
}

/**
 * Validates and throws descriptive errors
 */
export function validateEventItemStrict(data: unknown): EventItemDTO {
  if (!validateEventItem(data)) {
    throw new Error(`EventItem validation failed: Invalid event item structure or field types`);
  }
  return data as EventItemDTO;
}

/**
 * Validates array and throws descriptive errors
 */
export function validateEventItemsStrict(data: unknown): EventItemsResponse {
  if (!validateEventItems(data)) {
    throw new Error(`EventItems validation failed: Invalid event items array or individual items`);
  }
  return data as EventItemsResponse;
}

/**
 * Helper to create a valid EventItem with defaults
 */
export function createEventItem(
  partial: Partial<EventItemDTO> & Pick<EventItemDTO, 'id' | 'courseCode' | 'type' | 'title' | 'start'>
): EventItemDTO {
  const eventItem: EventItemDTO = {
    allDay: false,
    confidence: 1.0,
    ...partial,
  };
  
  // Validate the created item
  return validateEventItemStrict(eventItem);
}
