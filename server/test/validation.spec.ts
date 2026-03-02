/**
 * Tests for EventItem validation (consolidated into eventValidation.ts)
 */

import { describe, it, expect } from 'vitest';
import {
  validateSingleEvent,
  validateEvents,
  createEventItem,
  groundEventsAgainstScheme,
} from '../src/validation/eventValidation.js';
import type { EventItemDTO } from '../src/types/eventItem.js';
import type { GradingEntry } from '../src/utils/extractGradingScheme.js';

describe('EventItem Validation (types)', () => {
  const validEventItem: EventItemDTO = {
    id: 'event-123',
    courseCode: 'CS101',
    type: 'ASSIGNMENT',
    title: 'Homework 1',
    start: '2025-09-15T23:59:00.000-04:00',
    end: '2025-09-15T23:59:00.000-04:00',
    allDay: false,
    location: 'Online',
    notes: 'Submit via Canvas',
    reminderMinutes: 1440,
    confidence: 0.95,
  };

  describe('validateSingleEvent', () => {
    it('should validate a complete valid event item', () => {
      const result = validateSingleEvent(validEventItem);
      expect(result.valid).toBe(true);
    });

    it('should validate a minimal valid event item', () => {
      const minimal = {
        id: 'event-123',
        courseCode: 'CS101',
        type: 'QUIZ',
        title: 'Quiz 1',
        start: '2025-09-15T10:00:00.000-04:00',
      };
      expect(validateSingleEvent(minimal).valid).toBe(true);
    });

    it('should reject event item missing required fields', () => {
      const invalid = { ...validEventItem };
      delete (invalid as any).id;
      expect(validateSingleEvent(invalid).valid).toBe(false);
    });

    it('should reject event item with invalid type', () => {
      const invalid = { ...validEventItem, type: 'INVALID_TYPE' };
      expect(validateSingleEvent(invalid).valid).toBe(false);
    });

    it('should reject event item with invalid date format', () => {
      const invalid = { ...validEventItem, start: 'not-a-date' };
      expect(validateSingleEvent(invalid).valid).toBe(false);
    });

    it('should reject event item with invalid confidence range', () => {
      const invalid1 = { ...validEventItem, confidence: -0.1 };
      const invalid2 = { ...validEventItem, confidence: 1.1 };
      expect(validateSingleEvent(invalid1).valid).toBe(false);
      expect(validateSingleEvent(invalid2).valid).toBe(false);
    });

    it('should reject event item with title too long', () => {
      const invalid = { ...validEventItem, title: 'a'.repeat(201) };
      expect(validateSingleEvent(invalid).valid).toBe(false);
    });

    it('should accept flexible course code formats', () => {
      const withAsterisk = { ...validEventItem, courseCode: 'ENGG*3390' };
      const withSpace = { ...validEventItem, courseCode: 'CS 101' };
      expect(validateSingleEvent(withAsterisk).valid).toBe(true);
      expect(validateSingleEvent(withSpace).valid).toBe(true);
    });
  });

  describe('createEventItem', () => {
    it('should create valid event item with defaults', () => {
      const result = createEventItem({
        id: 'event-123',
        courseCode: 'CS101',
        type: 'ASSIGNMENT' as const,
        title: 'Test Assignment',
        start: '2025-09-15T23:59:00.000-04:00',
      });
      expect(result.allDay).toBe(false);
      expect(result.confidence).toBe(1.0);
      expect(validateSingleEvent(result).valid).toBe(true);
    });

    it('should override defaults when provided', () => {
      const result = createEventItem({
        id: 'event-123',
        courseCode: 'CS101',
        type: 'QUIZ' as const,
        title: 'Test Quiz',
        start: '2025-09-15T10:00:00.000-04:00',
        allDay: true,
        confidence: 0.8,
      });
      expect(result.allDay).toBe(true);
      expect(result.confidence).toBe(0.8);
    });

    it('should throw error for invalid created item', () => {
      expect(() => createEventItem({
        id: '',
        courseCode: 'CS101',
        type: 'ASSIGNMENT' as const,
        title: 'Test',
        start: '2025-09-15T23:59:00.000-04:00',
      })).toThrow(/validation failed/i);
    });

    it('should set needsDate when start is null', () => {
      const item = createEventItem({
        id: 'no-date',
        courseCode: 'CS101',
        type: 'ASSIGNMENT',
        title: 'TBD Assignment',
      });
      expect(item.needsDate).toBe(true);
      expect(item.start).toBeNull();
    });
  });

  describe('groundEventsAgainstScheme', () => {
    const scheme: GradingEntry[] = [
      { name: 'Assignments', weight: 40, type: 'ASSIGNMENT' },
      { name: 'Final Exam', weight: 60, type: 'FINAL' },
    ];

    it('should pass through events that match the scheme', () => {
      const events: EventItemDTO[] = [
        createEventItem({
          id: 'a1', courseCode: 'CS101', type: 'ASSIGNMENT',
          title: 'Assignment 1', start: '2025-09-15T00:00:00.000', confidence: 0.9,
        }),
        createEventItem({
          id: 'final', courseCode: 'CS101', type: 'FINAL',
          title: 'Final Exam', start: '2025-12-10T09:00:00.000', confidence: 0.95,
        }),
      ];

      const result = groundEventsAgainstScheme(events, scheme);
      expect(result.warnings).toHaveLength(0);
      expect(result.events[0].confidence).toBe(0.9);
      expect(result.events[1].confidence).toBe(0.95);
    });

    it('should reduce confidence for ungrounded assessment events', () => {
      const events: EventItemDTO[] = [
        createEventItem({
          id: 'mid', courseCode: 'CS101', type: 'MIDTERM',
          title: 'Midterm Exam', start: '2025-10-15T00:00:00.000', confidence: 0.85,
        }),
      ];

      const result = groundEventsAgainstScheme(events, scheme);
      expect(result.warnings).toHaveLength(1);
      expect(result.warnings[0]).toContain('Midterm Exam');
      expect(result.events[0].confidence).toBe(0.3);
    });

    it('should pass through LECTURE events regardless of scheme', () => {
      const events: EventItemDTO[] = [
        createEventItem({
          id: 'lec', courseCode: 'CS101', type: 'LECTURE',
          title: 'Monday Lecture', start: '2025-09-01T10:00:00.000', confidence: 0.9,
        }),
      ];

      const result = groundEventsAgainstScheme(events, scheme);
      expect(result.warnings).toHaveLength(0);
      expect(result.events[0].confidence).toBe(0.9);
    });

    it('should return events unchanged when scheme is empty', () => {
      const events: EventItemDTO[] = [
        createEventItem({
          id: 'mid', courseCode: 'CS101', type: 'MIDTERM',
          title: 'Midterm Exam', start: '2025-10-15T00:00:00.000', confidence: 0.85,
        }),
      ];

      const result = groundEventsAgainstScheme(events, []);
      expect(result.warnings).toHaveLength(0);
      expect(result.events[0].confidence).toBe(0.85);
    });
  });
});
