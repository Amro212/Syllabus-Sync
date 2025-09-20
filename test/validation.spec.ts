/**
 * Tests for EventItem validation
 */

import { describe, it, expect } from 'vitest';
import { 
  isValidEventItem, 
  isValidEventItems, 
  validateEventItemStrict,
  validateEventItemsStrict,
  createEventItem 
} from '../src/types/validation.js';
import type { EventItemDTO } from '../src/types/eventItem.js';

describe('EventItem Validation', () => {
  const validEventItem: EventItemDTO = {
    id: 'event-123',
    courseCode: 'course-456',
    courseCode: 'CS101',
    type: 'ASSIGNMENT',
    title: 'Homework 1',
    start: '2025-09-15T23:59:00.000Z',
    end: '2025-09-15T23:59:00.000Z',
    allDay: false,
    location: 'Online',
    notes: 'Submit via Canvas',
    reminderMinutes: 1440, // 1 day
    confidence: 0.95,
  };

  describe('isValidEventItem', () => {
    it('should validate a complete valid event item', () => {
      expect(isValidEventItem(validEventItem)).toBe(true);
    });

    it('should validate a minimal valid event item', () => {
      const minimal: EventItemDTO = {
        id: 'event-123',
        courseCode: 'course-456',
        type: 'QUIZ',
        title: 'Quiz 1',
        start: '2025-09-15T10:00:00.000Z',
      };
      expect(isValidEventItem(minimal)).toBe(true);
    });

    it('should reject event item missing required fields', () => {
      const invalid = { ...validEventItem };
      delete (invalid as any).id;
      expect(isValidEventItem(invalid)).toBe(false);
    });

    it('should reject event item with invalid type', () => {
      const invalid = { ...validEventItem, type: 'INVALID_TYPE' };
      expect(isValidEventItem(invalid)).toBe(false);
    });

    it('should reject event item with invalid date format', () => {
      const invalid = { ...validEventItem, start: 'not-a-date' };
      expect(isValidEventItem(invalid)).toBe(false);
    });

    it('should reject event item with invalid confidence range', () => {
      const invalid1 = { ...validEventItem, confidence: -0.1 };
      const invalid2 = { ...validEventItem, confidence: 1.1 };
      expect(isValidEventItem(invalid1)).toBe(false);
      expect(isValidEventItem(invalid2)).toBe(false);
    });

    it('should reject event item with title too long', () => {
      const invalid = { ...validEventItem, title: 'a'.repeat(201) };
      expect(isValidEventItem(invalid)).toBe(false);
    });

    it('should reject event item with invalid course code format', () => {
      const invalid = { ...validEventItem, courseCode: 'invalid-format' };
      expect(isValidEventItem(invalid)).toBe(false);
    });
  });

  describe('isValidEventItems', () => {
    it('should validate array of valid event items', () => {
      const events = [validEventItem, { ...validEventItem, id: 'event-456' }];
      expect(isValidEventItems(events)).toBe(true);
    });

    it('should validate empty array', () => {
      expect(isValidEventItems([])).toBe(true);
    });

    it('should reject array with invalid items', () => {
      const invalid = [validEventItem, { invalid: 'item' }];
      expect(isValidEventItems(invalid)).toBe(false);
    });

    it('should reject non-array input', () => {
      expect(isValidEventItems(validEventItem)).toBe(false);
      expect(isValidEventItems('not an array')).toBe(false);
    });
  });

  describe('validateEventItemStrict', () => {
    it('should return valid event item', () => {
      const result = validateEventItemStrict(validEventItem);
      expect(result).toEqual(validEventItem);
    });

    it('should throw descriptive error for invalid item', () => {
      const invalid = { ...validEventItem };
      delete (invalid as any).title;
      
      expect(() => validateEventItemStrict(invalid)).toThrow(/validation failed/);
    });
  });

  describe('validateEventItemsStrict', () => {
    it('should return valid event items array', () => {
      const events = [validEventItem];
      const result = validateEventItemsStrict(events);
      expect(result).toEqual(events);
    });

    it('should throw descriptive error for invalid array', () => {
      const invalid = [{ invalid: 'item' }];
      expect(() => validateEventItemsStrict(invalid)).toThrow(/validation failed/);
    });
  });

  describe('createEventItem', () => {
    it('should create valid event item with defaults', () => {
      const partial = {
        id: 'event-123',
        courseCode: 'course-456',
        type: 'ASSIGNMENT' as const,
        title: 'Test Assignment',
        start: '2025-09-15T23:59:00.000Z',
      };

      const result = createEventItem(partial);
      expect(result.allDay).toBe(false);
      expect(result.confidence).toBe(1.0);
      expect(isValidEventItem(result)).toBe(true);
    });

    it('should override defaults when provided', () => {
      const partial = {
        id: 'event-123',
        courseCode: 'course-456',
        type: 'QUIZ' as const,
        title: 'Test Quiz',
        start: '2025-09-15T10:00:00.000Z',
        allDay: true,
        confidence: 0.8,
      };

      const result = createEventItem(partial);
      expect(result.allDay).toBe(true);
      expect(result.confidence).toBe(0.8);
    });

    it('should throw error for invalid created item', () => {
      const invalid = {
        id: '', // Invalid: empty string
        courseCode: 'course-456',
        type: 'ASSIGNMENT' as const,
        title: 'Test',
        start: '2025-09-15T23:59:00.000Z',
      };

      expect(() => createEventItem(invalid)).toThrow(/validation failed/);
    });
  });
});
