import { describe, it, expect } from 'vitest';
import {
  validateEvents,
  validateSingleEvent,
  createTermWindow,
  isValidISODate,
  normalizeEventData,
  groundEventsAgainstScheme,
  ensureSchemeCoverage,
  type ValidationConfig
} from '../src/validation/eventValidation.js';
import type { EventItemDTO } from '../src/types/eventItem.js';
import type { GradingEntry } from '../src/utils/extractGradingScheme.js';
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

  describe('ensureSchemeCoverage', () => {
    const scheme: GradingEntry[] = [
      { name: 'Midterm 1', weight: 0.15, type: 'MIDTERM' },
      { name: 'Midterm 2', weight: 0.15, type: 'MIDTERM' },
      { name: 'Final Exam', weight: 0.30, type: 'FINAL' },
      { name: 'Participation', weight: 0.40, type: 'OTHER' },
    ];

    it('does not inject when all deliverables are covered', () => {
      const events: EventItemDTO[] = [
        { id: 'midterm-1', courseCode: 'CS101', type: 'MIDTERM', title: 'Midterm 1', start: '2025-10-15T00:00:00.000', allDay: true, confidence: 0.9 },
        { id: 'midterm-2', courseCode: 'CS101', type: 'MIDTERM', title: 'Midterm 2', start: '2025-11-10T00:00:00.000', allDay: true, confidence: 0.9 },
        { id: 'final', courseCode: 'CS101', type: 'FINAL', title: 'Final Exam', start: '2025-12-10T09:00:00.000', allDay: false, confidence: 0.95 },
      ];

      const result = ensureSchemeCoverage(events, scheme, 'CS101');
      expect(result.injected).toHaveLength(0);
      expect(result.events).toHaveLength(3); // Participation (OTHER) is skipped
    });

    it('injects missing deliverables as needsDate placeholders', () => {
      // AI only produced Midterm 1, missing Midterm 2 and Final Exam
      const events: EventItemDTO[] = [
        { id: 'midterm-1', courseCode: 'CS101', type: 'MIDTERM', title: 'Midterm 1', start: '2025-10-15T00:00:00.000', allDay: true, confidence: 0.9 },
      ];

      const result = ensureSchemeCoverage(events, scheme, 'CS101');
      expect(result.injected).toContain('Midterm 2');
      expect(result.injected).toContain('Final Exam');
      expect(result.events).toHaveLength(3);

      const injectedMidterm2 = result.events.find(e => e.title === 'Midterm 2');
      expect(injectedMidterm2).toBeDefined();
      expect(injectedMidterm2!.needsDate).toBe(true);
      expect(injectedMidterm2!.start).toBeNull();
      expect(injectedMidterm2!.type).toBe('MIDTERM');
      expect(injectedMidterm2!.notes).toContain('15%');

      const injectedFinal = result.events.find(e => e.title === 'Final Exam');
      expect(injectedFinal).toBeDefined();
      expect(injectedFinal!.type).toBe('FINAL');
    });

    it('skips OTHER-type entries like Participation', () => {
      // Even with zero AI events, Participation should NOT be injected
      const result = ensureSchemeCoverage([], scheme, 'CS101');
      const titles = result.events.map(e => e.title);
      expect(titles).not.toContain('Participation');
    });

    it('matches by substring containment', () => {
      // AI title "Midterm Exam 1" should match scheme "Midterm 1" via containment
      const events: EventItemDTO[] = [
        { id: 'm1', courseCode: 'CS101', type: 'MIDTERM', title: 'Midterm 1 Exam', start: null, needsDate: true, allDay: true, confidence: 0.8 },
        { id: 'm2', courseCode: 'CS101', type: 'MIDTERM', title: 'Midterm 2', start: null, needsDate: true, allDay: true, confidence: 0.8 },
        { id: 'f', courseCode: 'CS101', type: 'FINAL', title: 'Final Exam', start: null, needsDate: true, allDay: true, confidence: 0.8 },
      ];

      const result = ensureSchemeCoverage(events, scheme, 'CS101');
      expect(result.injected).toHaveLength(0);
    });

    it('avoids duplicate IDs when injecting', () => {
      const events: EventItemDTO[] = [
        { id: 'final-exam', courseCode: 'CS101', type: 'MIDTERM', title: 'Midterm 1', start: null, needsDate: true, allDay: true, confidence: 0.8 },
      ];

      const smallScheme: GradingEntry[] = [
        { name: 'Midterm 1', weight: 0.40, type: 'MIDTERM' },
        { name: 'Final Exam', weight: 0.60, type: 'FINAL' },
      ];

      const result = ensureSchemeCoverage(events, smallScheme, 'CS101');
      const ids = result.events.map(e => e.id);
      // "final-exam" already exists, so the injected one should get a suffix
      expect(ids).toContain('final-exam');
      expect(ids.some(id => id.startsWith('final-exam-'))).toBe(true);
      // All IDs should be unique
      expect(new Set(ids).size).toBe(ids.length);
    });

    it('returns empty injections when scheme is empty', () => {
      const events: EventItemDTO[] = [
        { id: 'test', courseCode: 'CS101', type: 'ASSIGNMENT', title: 'Test', start: null, needsDate: true, allDay: true, confidence: 0.8 },
      ];

      const result = ensureSchemeCoverage(events, [], 'CS101');
      expect(result.injected).toHaveLength(0);
      expect(result.events).toHaveLength(1);
    });
  });
});
