/**
 * Tests for date extraction utilities
 */

import { describe, it, expect } from 'vitest';
import { 
  extractDates, 
  parseRelativeDate, 
  analyzeDateExtraction,
  type DateMatch,
  type DateExtractionStats 
} from '../src/parsing/dateExtraction.js';

describe('Date Extraction', () => {
  describe('extractDates', () => {
    it('should handle null and undefined input', () => {
      expect(() => extractDates(null as any)).toThrow(TypeError);
      expect(() => extractDates(undefined as any)).toThrow(TypeError);
      expect(() => extractDates(123 as any)).toThrow(TypeError);
    });

    it('should handle empty string', () => {
      expect(extractDates('')).toEqual([]);
      expect(extractDates('   ')).toEqual([]);
      expect(extractDates('No dates here!')).toEqual([]);
    });

    describe('Full date formats', () => {
      it('should extract full month names with year', () => {
        const text = 'Assignment due September 15, 2025 and exam on December 10, 2025';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        
        expect(dates[0].text).toBe('September 15, 2025');
        expect(dates[0].type).toBe('full_date');
        expect(dates[0].date).toEqual(new Date(2025, 8, 15)); // September = month 8
        expect(dates[0].confidence).toBe(0.95);
        expect(dates[0].startIndex).toBe(15);
        expect(dates[0].endIndex).toBe(33);
        
        expect(dates[1].text).toBe('December 10, 2025');
        expect(dates[1].date).toEqual(new Date(2025, 11, 10)); // December = month 11
      });

      it('should handle ordinal numbers', () => {
        const text = 'Due October 1st, 2025 and November 22nd, 2025';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].date).toEqual(new Date(2025, 9, 1));
        expect(dates[1].date).toEqual(new Date(2025, 10, 22));
      });
    });

    describe('Short date formats', () => {
      it('should extract abbreviated month names', () => {
        const text = 'Quiz on Sept 15, 2025 and final on Dec 18, 2025';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].text).toBe('Sept 15, 2025');
        expect(dates[0].type).toBe('short_date');
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[0].confidence).toBe(0.90);
        
        expect(dates[1].text).toBe('Dec 18, 2025');
        expect(dates[1].date).toEqual(new Date(2025, 11, 18));
      });

      it('should handle month abbreviations with periods', () => {
        const text = 'Midterm on Oct. 15, 2025';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(1);
        expect(dates[0].date).toEqual(new Date(2025, 9, 15));
      });
    });

    describe('Numeric date formats', () => {
      it('should extract MM/DD/YYYY format', () => {
        const text = 'Assignment due 09/15/2025 and quiz on 12/03/2025';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].text).toBe('09/15/2025');
        expect(dates[0].type).toBe('numeric_date');
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[0].confidence).toBeCloseTo(0.72, 2); // 0.80 * 0.9 for ambiguity
        
        expect(dates[1].date).toEqual(new Date(2025, 11, 3));
      });

      it('should handle 2-digit years', () => {
        const text = 'Due 9/15/25 and exam 12/3/25';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[1].date).toEqual(new Date(2025, 11, 3));
      });

      it('should handle single digit months and days', () => {
        const text = 'Start date 1/5/2025';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(1);
        expect(dates[0].date).toEqual(new Date(2025, 0, 5)); // January 5
      });
    });

    describe('ISO date formats', () => {
      it('should extract ISO 8601 dates', () => {
        const text = 'Event on 2025-09-15 and deadline 2025-12-10';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].text).toBe('2025-09-15');
        expect(dates[0].type).toBe('iso_date');
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[0].confidence).toBe(0.95);
        
        expect(dates[1].date).toEqual(new Date(2025, 11, 10));
      });
    });

    describe('Weekday + date formats', () => {
      it('should extract weekday with full month', () => {
        // September 15, 2025 is actually a Monday
        const text = 'Due Monday, September 15 and quiz Friday, September 19';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].text).toBe('Monday, September 15');
        expect(dates[0].type).toBe('weekday_date');
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        
        // Check if Friday, September 19, 2025 is actually a Friday
        const sept19 = new Date(2025, 8, 19);
        expect(sept19.getDay()).toBe(5); // Friday = 5
        expect(dates[1].confidence).toBe(0.85); // Should be high confidence since weekday matches
      });

      it('should prefer higher confidence patterns over weekday mismatches', () => {
        // September 15, 2025 is a Monday, not Tuesday
        // The full_date pattern should be preferred over weekday_date due to higher confidence
        const text = 'Due Tuesday, September 15, 2025';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(1);
        expect(dates[0].type).toBe('full_date'); // Higher confidence pattern is preferred
        expect(dates[0].confidence).toBe(0.95); // Full date confidence
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
      });

      it('should lower confidence for mismatched weekdays when year is not specified', () => {
        // Test weekday mismatch without year to avoid full_date pattern interference
        // September 15, 2025 is a Monday, not Tuesday
        const text = 'Due Tuesday, September 15';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(1);
        expect(dates[0].type).toBe('month_day'); // Falls back to month_day since weekday doesn't match
        expect(dates[0].confidence).toBeCloseTo(0.63, 2); // 0.70 * 0.9 for month_day without year
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
      });

      it('should handle abbreviated weekdays and months', () => {
        const text = 'Quiz Mon, Sept 15 and exam Fri, Dec 19';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[1].date).toEqual(new Date(2025, 11, 19));
      });
    });

    describe('Month-day only formats', () => {
      it('should extract month and day without year', () => {
        const text = 'Assignment due September 15 and quiz October 22';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].text).toBe('September 15');
        expect(dates[0].type).toBe('month_day');
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[0].confidence).toBe(0.63); // 0.70 * 0.9 for missing year
        
        expect(dates[1].date).toEqual(new Date(2025, 9, 22));
      });

      it('should handle abbreviated months without year', () => {
        const text = 'Due Sept 15th and final Dec 18th';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[1].date).toEqual(new Date(2025, 11, 18));
      });
    });

    describe('Week of formats', () => {
      it('should extract "week of" patterns', () => {
        const text = 'Finals week of December 15 and spring break week of March 10';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].text).toBe('week of December 15');
        expect(dates[0].type).toBe('week_of');
        expect(dates[0].date).toEqual(new Date(2025, 11, 15));
        expect(dates[0].confidence).toBe(0.75);
        
        expect(dates[1].date).toEqual(new Date(2025, 2, 10));
      });
    });

    describe('Date range formats', () => {
      it('should extract same-month ranges', () => {
        const text = 'Finals September 15-22 and registration October 1-15';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].text).toBe('September 15-22');
        expect(dates[0].type).toBe('date_range');
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[0].endDate).toEqual(new Date(2025, 8, 22));
        expect(dates[0].isRange).toBe(true);
        expect(dates[0].confidence).toBe(0.80);
        
        expect(dates[1].isRange).toBe(true);
        expect(dates[1].endDate).toEqual(new Date(2025, 9, 15));
      });

      it('should extract cross-month ranges', () => {
        const text = 'Winter break December 15 - January 20';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(1);
        expect(dates[0].type).toBe('date_range');
        expect(dates[0].date).toEqual(new Date(2025, 11, 15));
        expect(dates[0].endDate).toEqual(new Date(2025, 0, 20)); // January of next year cycle
        expect(dates[0].isRange).toBe(true);
      });

      it('should handle different dash types in ranges', () => {
        const text = 'Event Sept 15–22 and conference Oct 1—15';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(2);
        expect(dates[0].type).toBe('date_range');
        expect(dates[1].type).toBe('date_range');
      });
    });

    describe('Invalid dates and edge cases', () => {
      it('should reject invalid dates', () => {
        const text = 'Invalid February 30, 2025 and April 31, 2025';
        const dates = extractDates(text, 2025);
        
        // These should not match or should be filtered out
        expect(dates.every(d => d.date !== null)).toBe(true);
      });

      it('should handle leap years correctly', () => {
        const text = 'Leap day February 29, 2024 is valid but February 30, 2024 is invalid';
        const dates = extractDates(text, 2024);
        
        const validDates = dates.filter(d => d.date !== null);
        // Feb 29, 2024 should be valid (leap year), Feb 30 should be invalid
        expect(validDates).toHaveLength(1);
        expect(validDates[0].date).toEqual(new Date(2024, 1, 29));
        expect(validDates[0].text).toBe('February 29, 2024');
      });

      it('should handle empty matches gracefully', () => {
        const text = 'Some text with no valid date patterns';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(0);
      });
    });

    describe('Overlapping matches and deduplication', () => {
      it('should prefer higher confidence matches', () => {
        const text = 'Event on September 15, 2025'; // This could match both full_date and month_day patterns
        const dates = extractDates(text, 2025);
        
        // Should only have one match with the highest confidence (full_date)
        expect(dates).toHaveLength(1);
        expect(dates[0].type).toBe('full_date');
        expect(dates[0].confidence).toBe(0.95);
      });

      it('should handle multiple non-overlapping dates', () => {
        const text = 'First assignment September 15, 2025, second October 22, 2025, and final December 18, 2025';
        const dates = extractDates(text, 2025);
        
        expect(dates).toHaveLength(3);
        expect(dates[0].date).toEqual(new Date(2025, 8, 15));
        expect(dates[1].date).toEqual(new Date(2025, 9, 22));
        expect(dates[2].date).toEqual(new Date(2025, 11, 18));
      });
    });

    describe('Real syllabus examples', () => {
      it('should extract dates from typical syllabus text', () => {
        const syllabusText = `
          CS 101 - Fall 2025 Semester
          
          Important Dates:
          - Classes begin: August 25, 2025
          - Labor Day (no class): Monday, September 1
          - Midterm exam: Week of October 15
          - Thanksgiving break: November 25-29
          - Final exam: December 18, 2025
          
          Assignment Schedule:
          Assignment 1: Due Sept 15, 2025
          Assignment 2: Due 10/6/25
          Project proposal: Due Friday, October 31st
          Final project: Due 12/18/2025
        `;
        
        const dates = extractDates(syllabusText, 2025);
        
        // Should find multiple dates
        expect(dates.length).toBeGreaterThan(5);
        
        // Check for specific important dates
        const importantDates = dates.filter(d => d.date !== null).map(d => d.date!);
        const dateStrings = importantDates.map(d => d.toDateString());
        
        expect(dateStrings).toContain(new Date(2025, 7, 25).toDateString()); // August 25
        expect(dateStrings).toContain(new Date(2025, 8, 15).toDateString()); // Sept 15
        expect(dateStrings).toContain(new Date(2025, 11, 18).toDateString()); // Dec 18
      });

      it('should handle mixed format syllabus', () => {
        const mixedText = `
          Course deadlines:
          1. Research paper due 2025-10-15
          2. Presentation on Oct 22nd, 2025
          3. Group project: 11/15/25
          4. Finals week: December 8-12
        `;
        
        const dates = extractDates(mixedText, 2025);
        
        expect(dates.length).toBeGreaterThan(3);
        
        // Should handle ISO date
        const isoDate = dates.find(d => d.type === 'iso_date');
        expect(isoDate).toBeDefined();
        expect(isoDate?.date).toEqual(new Date(2025, 9, 15));
        
        // Should handle range
        const rangeDate = dates.find(d => d.isRange);
        expect(rangeDate).toBeDefined();
      });
    });
  });

  describe('parseRelativeDate', () => {
    const baseDate = new Date(2025, 8, 15); // Monday, September 15, 2025

    it('should parse "next" weekday references', () => {
      const nextMonday = parseRelativeDate(baseDate, 'next Monday');
      expect(nextMonday).toEqual(new Date(2025, 8, 22)); // September 22, 2025
      
      const nextFriday = parseRelativeDate(baseDate, 'next Friday');
      expect(nextFriday).toEqual(new Date(2025, 8, 19)); // September 19, 2025
    });

    it('should parse "this" weekday references', () => {
      const thisFriday = parseRelativeDate(baseDate, 'this Friday');
      expect(thisFriday).toEqual(new Date(2025, 8, 19)); // September 19, 2025
      
      const thisMonday = parseRelativeDate(baseDate, 'this Monday');
      expect(thisMonday).toEqual(new Date(2025, 8, 15)); // Same day
    });

    it('should handle abbreviated weekday names', () => {
      const nextMon = parseRelativeDate(baseDate, 'next Mon');
      expect(nextMon).toEqual(new Date(2025, 8, 22));
      
      const thisFri = parseRelativeDate(baseDate, 'this Fri');
      expect(thisFri).toEqual(new Date(2025, 8, 19));
    });

    it('should return null for unparseable text', () => {
      expect(parseRelativeDate(baseDate, 'invalid date')).toBeNull();
      expect(parseRelativeDate(baseDate, 'next someday')).toBeNull();
      expect(parseRelativeDate(baseDate, '')).toBeNull();
    });
  });

  describe('analyzeDateExtraction', () => {
    it('should handle empty results', () => {
      const stats = analyzeDateExtraction([]);
      
      expect(stats.totalDates).toBe(0);
      expect(stats.ranges).toBe(0);
      expect(stats.averageConfidence).toBe(0);
      expect(stats.typeDistribution).toEqual({});
      expect(stats.earliestDate).toBeUndefined();
      expect(stats.latestDate).toBeUndefined();
    });

    it('should analyze comprehensive date extraction results', () => {
      const matches: DateMatch[] = [
        {
          text: 'September 15, 2025',
          startIndex: 0,
          endIndex: 18,
          date: new Date(2025, 8, 15),
          confidence: 0.95,
          type: 'full_date',
          isRange: false
        },
        {
          text: 'Oct 20-25',
          startIndex: 30,
          endIndex: 39,
          date: new Date(2025, 9, 20),
          endDate: new Date(2025, 9, 25),
          confidence: 0.80,
          type: 'date_range',
          isRange: true
        },
        {
          text: '12/18/25',
          startIndex: 50,
          endIndex: 58,
          date: new Date(2025, 11, 18),
          confidence: 0.72,
          type: 'numeric_date',
          isRange: false
        }
      ];
      
      const stats = analyzeDateExtraction(matches);
      
      expect(stats.totalDates).toBe(3);
      expect(stats.ranges).toBe(1);
      expect(stats.averageConfidence).toBeCloseTo(0.823, 3);
      
      expect(stats.typeDistribution.full_date).toBe(1);
      expect(stats.typeDistribution.date_range).toBe(1);
      expect(stats.typeDistribution.numeric_date).toBe(1);
      
      expect(stats.earliestDate).toEqual(new Date(2025, 8, 15));
      expect(stats.latestDate).toEqual(new Date(2025, 11, 18));
    });

    it('should calculate correct statistics for ranges', () => {
      const matches: DateMatch[] = [
        {
          text: 'Sept 15-22',
          startIndex: 0,
          endIndex: 10,
          date: new Date(2025, 8, 15),
          endDate: new Date(2025, 8, 22),
          confidence: 0.80,
          type: 'date_range',
          isRange: true
        },
        {
          text: 'Oct 1-15',
          startIndex: 20,
          endIndex: 28,
          date: new Date(2025, 9, 1),
          endDate: new Date(2025, 9, 15),
          confidence: 0.80,
          type: 'date_range',
          isRange: true
        }
      ];
      
      const stats = analyzeDateExtraction(matches);
      
      expect(stats.totalDates).toBe(2);
      expect(stats.ranges).toBe(2);
      expect(stats.typeDistribution.date_range).toBe(2);
    });
  });

  describe('Integration with text normalization', () => {
    it('should work with normalized text input', () => {
      // This would typically come from normalizeText()
      const normalizedText = 'Assignment 1: Hello World\nDue: September 15, 2025\n\nAssignment 2: Variables and Control Flow\nDue: October 22, 2025';
      
      const dates = extractDates(normalizedText, 2025);
      
      expect(dates).toHaveLength(2);
      expect(dates[0].date).toEqual(new Date(2025, 8, 15));
      expect(dates[1].date).toEqual(new Date(2025, 9, 22));
    });
  });
});
