import { describe, it, expect } from 'vitest';
import { splitMultiDayRecurrence } from '../src/utils/splitMultiDayRecurrence.js';

describe('splitMultiDayRecurrence', () => {
  it('splits a TuTh event into two single-day events', () => {
    const events = [{
      id: 'lecture',
      title: 'Lecture',
      start: '2025-01-06T14:00:00.000-05:00', // Monday
      end: '2025-01-06T15:00:00.000-05:00',
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-04-18',
    }];

    const result = splitMultiDayRecurrence(events);
    expect(result).toHaveLength(2);

    expect(result[0].id).toBe('lecture-tu');
    expect(result[0].title).toBe('Lecture (Tue)');
    expect(result[0].recurrenceRule).toContain('BYDAY=TU');
    expect(result[0].recurrenceRule).not.toContain('BYDAY=TU,TH');

    expect(result[1].id).toBe('lecture-th');
    expect(result[1].title).toBe('Lecture (Thu)');
    expect(result[1].recurrenceRule).toContain('BYDAY=TH');
  });

  it('splits MWF into three events', () => {
    const events = [{
      id: 'class',
      title: 'Class',
      start: '2025-01-06T10:00:00.000-05:00', // Monday
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=2025-04-18',
    }];

    const result = splitMultiDayRecurrence(events);
    expect(result).toHaveLength(3);
    expect(result.map(e => e.id)).toEqual(['class-mo', 'class-we', 'class-fr']);
  });

  it('does not split single-day events', () => {
    const events = [{
      id: 'lecture-mon',
      title: 'Lecture (Mon)',
      start: '2025-01-06T14:00:00.000-05:00',
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO;UNTIL=2025-04-18',
    }];

    const result = splitMultiDayRecurrence(events);
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('lecture-mon');
  });

  it('passes through events without recurrence', () => {
    const events = [{
      id: 'assignment-1',
      title: 'Assignment 1',
      start: '2025-09-15T23:59:00.000-04:00',
    }];

    const result = splitMultiDayRecurrence(events);
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual(events[0]);
  });

  it('passes through events with null start (needsDate)', () => {
    const events = [{
      id: 'tbd',
      title: 'TBD Assignment',
      start: null as any,
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,WE',
    }];

    const result = splitMultiDayRecurrence(events);
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('tbd');
  });

  it('adjusts start dates to correct day of week', () => {
    // Start is Monday Jan 6, split to TU and TH
    const events = [{
      id: 'lec',
      title: 'Lecture',
      start: '2025-01-06T14:00:00.000-05:00', // Monday
      end: '2025-01-06T15:20:00.000-05:00',
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU,TH',
    }];

    const result = splitMultiDayRecurrence(events);
    // Tuesday should be +1 day from Monday
    expect(result[0].start).toBe('2025-01-07T14:00:00.000-05:00');
    expect(result[0].end).toBe('2025-01-07T15:20:00.000-05:00');
    // Thursday should be +3 days from Monday
    expect(result[1].start).toBe('2025-01-09T14:00:00.000-05:00');
    expect(result[1].end).toBe('2025-01-09T15:20:00.000-05:00');
  });

  it('preserves additional event properties', () => {
    const events = [{
      id: 'lec',
      title: 'Lecture',
      start: '2025-01-06T14:00:00.000-05:00',
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,WE',
      courseCode: 'CS101',
      type: 'LECTURE',
      location: 'Room 101',
    }];

    const result = splitMultiDayRecurrence(events);
    expect(result[0].courseCode).toBe('CS101');
    expect(result[0].location).toBe('Room 101');
    expect(result[1].courseCode).toBe('CS101');
    expect(result[1].location).toBe('Room 101');
  });
});
