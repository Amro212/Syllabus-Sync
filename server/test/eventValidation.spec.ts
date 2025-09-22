import { describe, it, expect } from 'vitest';
import {
  validateEvents,
  validateSingleEvent,
  createTermWindow,
  isValidISODate,
  normalizeEventData,
  type ValidationConfig
} from '../src/validation/eventValidation.js';
import type { EventItemDTO } from '../src/types/eventItem.js';
import { parseFlexibleISODate } from '../src/utils/date.js';

describe('Event Validation', () => {
  describe('validateEvents', () => {
    const baseEvent: EventItemDTO = {
      id: 'test-123',
      courseCode: 'CS101',
      type: 'ASSIGNMENT',
      title: 'Assignment 1',
      start: '2025-09-15T23:59:00.000-04:00',
      allDay: false,
      confidence: 0.85
    };

    it('handles empty event array', () => {
      const result = validateEvents([], {});
      expect(result.valid).toBe(true);
      expect(result.events).toEqual([]);
      expect(result.stats.totalEvents).toBe(0);
    });

    it('validates a simple event', () => {
      const config: ValidationConfig = {
        defaultCourseCode: 'CS101'
      };

      const result = validateEvents([baseEvent], config);
      expect(result.valid).toBe(true);
      expect(result.errors).toEqual([]);
      expect(result.events).toHaveLength(1);
      expect(result.events[0].title).toBe('Assignment 1');
      expect(result.events[0].allDay).toBe(false);
    });

    it('applies defaults and clamps dates', () => {
      const events: EventItemDTO[] = [
        {
          ...baseEvent,
          id: 'defaults',
          title: '',
          allDay: undefined
        }
      ];
      const config: ValidationConfig = {
        defaultCourseCode: 'CS101',
        termStart: new Date('2025-09-01'),
        termEnd: new Date('2025-12-15')
      };

      const result = validateEvents(events, config);
      expect(result.valid).toBe(true);
      expect(result.stats.defaultsApplied).toBeGreaterThan(0);
      expect(result.events[0].title).toBe('Assignment');
      expect(result.events[0].allDay).toBe(true);
    });

    it('collects validation errors', () => {
      const invalidEvents: EventItemDTO[] = [
        {
          ...baseEvent,
          id: '',
          courseCode: '',
          start: 'invalid-date'
        }
      ];

      const result = validateEvents(invalidEvents, {});
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
      expect(result.events).toHaveLength(0);
    });
  });

  describe('validateSingleEvent', () => {
    it('returns validated event', () => {
      const event: EventItemDTO = {
        id: 'single',
        courseCode: 'CS101',
        type: 'ASSIGNMENT',
        title: 'Assignment 1',
        start: '2025-09-15T23:59:00.000-04:00'
      };

      const result = validateSingleEvent(event);
      expect(result.valid).toBe(true);
      expect(result.event?.id).toBe('single');
    });

    it('captures validation failures', () => {
      const result = validateSingleEvent({ id: '', start: 'bad' });
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });
  });

  describe('createTermWindow', () => {
    it('creates fall window', () => {
      const termConfig = createTermWindow(2025, 'fall');
      expect(termConfig.termStart).toEqual(new Date(2025, 7, 15));
      expect(termConfig.termEnd).toEqual(new Date(2025, 11, 20));
    });
  });

  describe('isValidISODate', () => {
    it('accepts allowed ISO strings', () => {
      expect(isValidISODate('2025-09-15T23:59:59.000-04:00')).toBe(true);
      expect(isValidISODate('2025-09-15T23:59:59.000')).toBe(true);
      expect(isValidISODate('2025-09-15')).toBe(true);
    });

    it('rejects invalid ISO strings', () => {
      expect(isValidISODate('invalid-date')).toBe(false);
      expect(isValidISODate('2025-13-01T00:00:00.000')).toBe(false);
    });
  });

  describe('normalizeEventData', () => {
    it('normalizes strings and clamps confidence', () => {
      const events: EventItemDTO[] = [{
        id: 'n1',
        courseCode: ' cs101 ',
        type: 'ASSIGNMENT',
        title: '  Assignment 1  ',
        start: '2025-09-15T23:59:59.000-04:00',
        location: '  Room 204  ',
        notes: '  Important  ',
        confidence: 2
      }];

      const normalized = normalizeEventData(events);
      expect(normalized[0].courseCode).toBe('cs101');
      expect(normalized[0].location).toBe('Room 204');
      expect(normalized[0].confidence).toBe(1);
    });
  });

  describe('parseFlexibleISODate helper', () => {
    it('parses offsets correctly', () => {
      const date = parseFlexibleISODate('2025-09-15T10:00:00.000-04:00');
      expect(date.getFullYear()).toBe(2025);
    });
  });
});
