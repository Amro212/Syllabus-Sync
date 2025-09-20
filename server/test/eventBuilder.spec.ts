/**
 * Tests for event builder utilities
 */

import { describe, it, expect } from 'vitest';
import { 
  buildEvents, 
  candidatesToDTO,
  analyzeEventBuilding,
  type EventCandidate,
  type EventBuilderConfig,
  type EventBuildingStats
} from '../src/parsing/eventBuilder.js';
import type { EventType } from '../src/types/eventItem.js';

describe('Event Builder', () => {
  describe('buildEvents', () => {
    it('should handle null and undefined input', () => {
      expect(() => buildEvents(null as any)).toThrow(TypeError);
      expect(() => buildEvents(undefined as any)).toThrow(TypeError);
      expect(() => buildEvents(123 as any)).toThrow(TypeError);
    });

    it('should handle empty string', () => {
      const result = buildEvents('');
      expect(result.events).toEqual([]);
      expect(result.stats.totalLines).toBe(0);
      expect(result.stats.candidatesGenerated).toBe(0);
    });

    it('should handle text with no events', () => {
      const text = `
        Course Information
        Instructor: Dr. Smith
        Office Hours: Monday 2-4 PM
        Textbook: Introduction to Programming
      `;
      
      const result = buildEvents(text);
      expect(result.events).toEqual([]);
      expect(result.stats.totalLines).toBeGreaterThan(0);
      expect(result.stats.candidatesGenerated).toBe(0);
    });

    describe('Single Event Detection', () => {
      it('should detect a simple assignment with due date', () => {
        const text = 'Assignment 1: Hello World - Due September 15, 2025';
        const result = buildEvents(text, { defaultYear: 2025 });
        
        expect(result.events).toHaveLength(1);
        
        const event = result.events[0];
        expect(event.type).toBe('ASSIGNMENT');
        expect(event.title).toContain('Assignment 1');
        expect(event.start).toEqual(new Date(2025, 8, 15)); // September 15
        expect(event.allDay).toBe(true);
        expect(event.confidence).toBeGreaterThan(0.5);
      });

      it('should detect a quiz with specific time', () => {
        const text = 'Quiz 1 on variables - Monday 10:00 AM September 20, 2025';
        const result = buildEvents(text, { defaultYear: 2025 });
        
        expect(result.events).toHaveLength(1);
        
        const event = result.events[0];
        expect(event.type).toBe('QUIZ');
        expect(event.title).toContain('Quiz 1');
        expect(event.allDay).toBe(false); // Has specific time
        expect(event.confidence).toBeGreaterThan(0.5);
      });

      it('should detect midterm exam', () => {
        const text = 'Midterm Exam: October 15, 2025 - Covers chapters 1-5';
        const result = buildEvents(text, { defaultYear: 2025 });
        
        expect(result.events).toHaveLength(1);
        
        const event = result.events[0];
        expect(event.type).toBe('MIDTERM');
        expect(event.title).toContain('Midterm');
        expect(event.start).toEqual(new Date(2025, 9, 15)); // October 15
        expect(event.notes).toContain('Covers chapters 1-5');
      });

      it('should detect lab session with duration', () => {
        const text = 'Lab 3: Database Design Workshop - Thursday 2:00 PM October 10, 2025';
        const result = buildEvents(text, { defaultYear: 2025 });
        
        expect(result.events).toHaveLength(1);
        
        const event = result.events[0];
        expect(event.type).toBe('LAB');
        expect(event.title).toContain('Lab 3');
        expect(event.end).toBeDefined(); // Labs should have end time
        expect(event.allDay).toBe(false);
      });

      it('should detect final exam', () => {
        const text = 'Final Exam: December 18, 2025 - Comprehensive';
        const result = buildEvents(text, { defaultYear: 2025 });
        
        expect(result.events).toHaveLength(1);
        
        const event = result.events[0];
        expect(event.type).toBe('FINAL');
        expect(event.title).toContain('Final');
        expect(event.start).toEqual(new Date(2025, 11, 18)); // December 18
      });
    });

    describe('Multiple Event Detection', () => {
      it('should detect multiple events in a syllabus', () => {
        const syllabus = `
          CS 101 - Introduction to Programming
          Fall 2025 Semester
          
          Assignment 1: Hello World - Due September 15, 2025
          Quiz 1: Variables and Data Types - September 20, 2025
          Assignment 2: Calculator Program - Due September 30, 2025
          Midterm Exam: October 15, 2025
          Final Project: Web Application - Due December 10, 2025
          Final Exam: December 18, 2025
        `;
        
        const result = buildEvents(syllabus, { defaultYear: 2025 });
        
        expect(result.events.length).toBeGreaterThan(4);
        
        // Check for different event types
        const types = result.events.map(e => e.type);
        expect(types).toContain('ASSIGNMENT');
        expect(types).toContain('QUIZ');
        expect(types).toContain('MIDTERM');
        expect(types).toContain('FINAL');
        
        // Events should be in chronological order when parsed
        const assignments = result.events.filter(e => e.type === 'ASSIGNMENT');
        expect(assignments.length).toBeGreaterThanOrEqual(2);
      });

      it('should handle events with context dates', () => {
        const syllabus = `
          Week 3 - September 15-20, 2025
          Assignment 2: Data Structures
          Quiz on Friday
          
          Week 4 - September 22-27, 2025  
          Lab session on Wednesday
        `;
        
        const result = buildEvents(syllabus, { defaultYear: 2025 });
        
        // Should find events even when dates are in context
        expect(result.events.length).toBeGreaterThan(0);
        
        // Events should have reasonable dates within the specified weeks
        for (const event of result.events) {
          expect(event.start.getMonth()).toBe(8); // September (0-indexed)
          expect(event.start.getDate()).toBeGreaterThanOrEqual(15);
          expect(event.start.getDate()).toBeLessThanOrEqual(27);
        }
      });
    });

    describe('Title Generation', () => {
      it('should generate descriptive titles', () => {
        const tests = [
          { text: 'Assignment 1: Introduction to Programming', expected: /Assignment.*1.*Introduction/ },
          { text: 'HW 2 due Friday', expected: /Assignment.*2|HW.*2/ },
          { text: 'Quiz on Chapter 3 concepts', expected: /Quiz.*Chapter.*3/ },
          { text: 'Final Project: Build a web application', expected: /Final Project.*web application/ }
        ];
        
        for (const test of tests) {
          const result = buildEvents(test.text + ' - September 15, 2025', { defaultYear: 2025 });
          if (result.events.length > 0) {
            expect(result.events[0].title).toMatch(test.expected);
          }
        }
      });

      it('should generate default titles when extraction fails', () => {
        const text = 'Due Friday September 15, 2025'; // No clear type or title
        const result = buildEvents(text, { defaultYear: 2025 });
        
        if (result.events.length > 0) {
          expect(result.events[0].title).toBeDefined();
          expect(result.events[0].title.length).toBeGreaterThan(0);
        }
      });

      it('should limit title length', () => {
        const longText = 'Assignment 1: This is a very long assignment title that goes on and on with lots of details about what students need to do and includes multiple requirements and specifications that make it extremely verbose - Due September 15, 2025';
        const result = buildEvents(longText, { defaultYear: 2025 });
        
        if (result.events.length > 0) {
          expect(result.events[0].title.length).toBeLessThanOrEqual(100);
        }
      });
    });

    describe('Context Detection', () => {
      it('should detect location information', () => {
        const tests = [
          'Lab 1 in Room 204 - September 15, 2025',
          'Exam in Thompson Hall - October 10, 2025',
          'Class at Engineering Building Room B105 - September 20, 2025'
        ];
        
        for (const text of tests) {
          const result = buildEvents(text, { defaultYear: 2025 });
          if (result.events.length > 0) {
            expect(result.events[0].location).toBeDefined();
          }
        }
      });

      it('should extract notes from event descriptions', () => {
        const text = 'Assignment 1: Build a calculator - Due September 15, 2025 - Include unit tests and documentation';
        const result = buildEvents(text, { defaultYear: 2025 });
        
        if (result.events.length > 0) {
          const notes = result.events[0].notes;
          if (notes) {
            expect(notes).toContain('unit tests');
          }
        }
      });

      it('should handle all-day vs timed events correctly', () => {
        const tests = [
          { text: 'Assignment due September 15, 2025', expectedAllDay: true },
          { text: 'Exam at 10:00 AM September 15, 2025', expectedAllDay: false },
          { text: 'Quiz on Friday 2:00 PM September 15, 2025', expectedAllDay: false },
          { text: 'Final project due September 15, 2025', expectedAllDay: true }
        ];
        
        for (const test of tests) {
          const result = buildEvents(test.text, { defaultYear: 2025 });
          if (result.events.length > 0) {
            expect(result.events[0].allDay).toBe(test.expectedAllDay);
          }
        }
      });
    });

    describe('Deduplication', () => {
      it('should remove duplicate events', () => {
        const syllabus = `
          Assignment 1: Programming Basics - Due September 15, 2025
          Assignment 1 due September 15, 2025
          Programming Basics Assignment - September 15, 2025
          Different Assignment - September 20, 2025
        `;
        
        const result = buildEvents(syllabus, { 
          defaultYear: 2025, 
          deduplicate: true 
        });
        
        // Should have fewer events after deduplication
        expect(result.events.length).toBeLessThan(4);
        expect(result.events.length).toBeGreaterThanOrEqual(2);
        
        // Should keep the highest confidence version
        const sept15Events = result.events.filter(e => 
          e.start.getMonth() === 8 && e.start.getDate() === 15
        );
        expect(sept15Events.length).toBe(1);
      });

      it('should not deduplicate when disabled', () => {
        const syllabus = `
          Assignment 1 due September 15, 2025
          Assignment 1 due September 15, 2025
        `;
        
        const result = buildEvents(syllabus, { 
          defaultYear: 2025, 
          deduplicate: false 
        });
        
        // Should have duplicates when deduplication is disabled
        expect(result.events.length).toBeGreaterThanOrEqual(2);
      });
    });

    describe('Confidence Scoring', () => {
      it('should assign higher confidence to clear, specific events', () => {
        const clearEvent = 'Assignment 1: Programming Basics due Friday September 15, 2025 worth 10%';
        const vagueEvent = 'Something due sometime';
        
        const clearResult = buildEvents(clearEvent, { defaultYear: 2025 });
        const vagueResult = buildEvents(vagueEvent, { defaultYear: 2025 });
        
        if (clearResult.events.length > 0 && vagueResult.events.length > 0) {
          expect(clearResult.events[0].confidence).toBeGreaterThan(vagueResult.events[0].confidence);
        }
      });

      it('should filter out low confidence events', () => {
        const text = 'Maybe something due sometime';
        const result = buildEvents(text, { 
          defaultYear: 2025, 
          minConfidence: 0.7 
        });
        
        // Low confidence events should be filtered out
        expect(result.events.every(e => e.confidence >= 0.7)).toBe(true);
      });

      it('should boost confidence for events with contextual indicators', () => {
        const withContext = 'Assignment 1 due Friday September 15, 2025 worth 15% of grade';
        const withoutContext = 'Assignment 1 September 15, 2025';
        
        const contextResult = buildEvents(withContext, { defaultYear: 2025 });
        const noContextResult = buildEvents(withoutContext, { defaultYear: 2025 });
        
        if (contextResult.events.length > 0 && noContextResult.events.length > 0) {
          expect(contextResult.events[0].confidence).toBeGreaterThanOrEqual(noContextResult.events[0].confidence);
        }
      });
    });

    describe('Configuration Options', () => {
      it('should use provided courseCode', () => {
        const text = 'Assignment 1 due September 15, 2025';
        const config: EventBuilderConfig = {
          courseCode: 'CS 101',
          defaultYear: 2025
        };
        
        const result = buildEvents(text, config);
        const dtos = candidatesToDTO(result.events, config);
        
        if (dtos.length > 0) {
          expect(dtos[0].courseCode).toBe('CS 101');
        }
      });

      it('should apply minimum confidence threshold', () => {
        const text = 'Assignment 1 due September 15, 2025';
        const highThreshold = buildEvents(text, { 
          defaultYear: 2025, 
          minConfidence: 0.9 
        });
        const lowThreshold = buildEvents(text, { 
          defaultYear: 2025, 
          minConfidence: 0.1 
        });
        
        expect(lowThreshold.events.length).toBeGreaterThanOrEqual(highThreshold.events.length);
      });

      it('should use default year when dates lack year', () => {
        const text = 'Assignment 1 due September 15';
        const result = buildEvents(text, { defaultYear: 2025 });
        
        if (result.events.length > 0) {
          expect(result.events[0].start.getFullYear()).toBe(2025);
        }
      });
    });

    describe('Statistics and Analysis', () => {
      it('should provide comprehensive statistics', () => {
        const syllabus = `
          CS 101 - Introduction to Programming
          Assignment 1 due September 15, 2025
          Quiz 1 on September 20, 2025
          No class on September 25
          Midterm exam October 15, 2025
        `;
        
        const result = buildEvents(syllabus, { defaultYear: 2025 });
        
        expect(result.stats.totalLines).toBeGreaterThan(0);
        expect(result.stats.candidatesGenerated).toBeDefined();
        expect(result.stats.processingTimeMs).toBeGreaterThan(0);
        expect(result.stats.averageConfidence).toBeGreaterThanOrEqual(0);
        expect(result.stats.warnings).toBeDefined();
      });

      it('should track lines with dates and types', () => {
        const syllabus = `
          CS 101 Introduction
          Assignment 1 due September 15, 2025
          Quiz on Friday September 20, 2025
          Office hours Monday 2-4 PM
        `;
        
        const result = buildEvents(syllabus, { defaultYear: 2025 });
        
        expect(result.stats.linesWithDates).toBeGreaterThan(0);
        expect(result.stats.linesWithTypes).toBeGreaterThan(0);
        expect(result.stats.linesWithDates).toBeLessThanOrEqual(result.stats.totalLines);
        expect(result.stats.linesWithTypes).toBeLessThanOrEqual(result.stats.totalLines);
      });
    });

    describe('Error Handling and Edge Cases', () => {
      it('should handle malformed dates gracefully', () => {
        const text = 'Assignment 1 due February 30, 2025'; // Invalid date
        const result = buildEvents(text, { defaultYear: 2025 });
        
        // Should not crash, may have fewer events
        expect(result.events).toBeDefined();
        expect(result.stats).toBeDefined();
      });

      it('should handle mixed event types on same line', () => {
        const text = 'Assignment 1 due Monday, Quiz 2 on Wednesday September 15, 2025';
        const result = buildEvents(text, { defaultYear: 2025 });
        
        // Should handle this gracefully (may pick dominant type)
        expect(result.events).toBeDefined();
        if (result.events.length > 0) {
          expect(result.events[0].type).not.toBe('OTHER');
        }
      });

      it('should handle very long text efficiently', () => {
        const longSyllabus = Array(100).fill('Assignment due September 15, 2025').join('\n');
        const startTime = Date.now();
        
        const result = buildEvents(longSyllabus, { defaultYear: 2025 });
        const endTime = Date.now();
        
        expect(endTime - startTime).toBeLessThan(5000); // Should complete in < 5 seconds
        expect(result.events).toBeDefined();
        expect(result.stats.processingTimeMs).toBeGreaterThan(0);
      });

      it('should handle empty lines and whitespace', () => {
        const text = `
        
          Assignment 1 due September 15, 2025
          
          
          Quiz 1 on September 20, 2025
          
        `;
        
        const result = buildEvents(text, { defaultYear: 2025 });
        
        expect(result.events.length).toBeGreaterThan(0);
        expect(result.stats.totalLines).toBeGreaterThan(2);
      });
    });
  });

  describe('candidatesToDTO', () => {
    it('should convert candidates to DTO format', () => {
      const candidates: EventCandidate[] = [{
        id: 'test-id',
        type: 'ASSIGNMENT',
        title: 'Test Assignment',
        start: new Date(2025, 8, 15),
        end: undefined,
        allDay: true,
        confidence: 0.85,
        sourceLineIndex: 0,
        sourceText: 'Test assignment',
        matchedKeywords: ['assignment'],
        dateMatches: []
      }];
      
      const config: EventBuilderConfig = {
        courseCode: 'CS 101'
      };
      
      const dtos = candidatesToDTO(candidates, config);
      
      expect(dtos).toHaveLength(1);
      expect(dtos[0].id).toBe('test-id');
      expect(dtos[0].courseCode).toBe('CS 101');
      expect(dtos[0].type).toBe('ASSIGNMENT');
      expect(dtos[0].title).toBe('Test Assignment');
      expect(dtos[0].start).toBe('2025-09-15T00:00:00.000');
      expect(dtos[0].allDay).toBe(true);
      expect(dtos[0].confidence).toBe(0.85);
    });

    it('should handle missing config values', () => {
      const candidates: EventCandidate[] = [{
        id: 'test-id',
        type: 'QUIZ',
        title: 'Test Quiz',
        start: new Date(2025, 8, 20),
        allDay: false,
        confidence: 0.75,
        sourceLineIndex: 0,
        sourceText: 'Test quiz',
        matchedKeywords: ['quiz'],
        dateMatches: []
      }];
      
      const dtos = candidatesToDTO(candidates);
      
      expect(dtos).toHaveLength(1);
      expect(dtos[0].courseCode).toBe('');
    });
  });

  describe('analyzeEventBuilding', () => {
    it('should provide comprehensive analysis', () => {
      const events: EventCandidate[] = [
        {
          id: '1', type: 'ASSIGNMENT', title: 'Assignment 1', start: new Date(2025, 8, 15),
          allDay: true, confidence: 0.9, sourceLineIndex: 0, sourceText: '', matchedKeywords: [], dateMatches: []
        },
        {
          id: '2', type: 'QUIZ', title: 'Quiz 1', start: new Date(2025, 8, 20),
          allDay: false, confidence: 0.7, sourceLineIndex: 1, sourceText: '', matchedKeywords: [], dateMatches: []
        },
        {
          id: '3', type: 'ASSIGNMENT', title: 'Assignment 2', start: new Date(2025, 9, 1),
          allDay: true, confidence: 0.4, sourceLineIndex: 2, sourceText: '', matchedKeywords: [], dateMatches: []
        }
      ];
      
      const stats: EventBuildingStats = {
        totalLines: 10,
        linesWithDates: 5,
        linesWithTypes: 7,
        candidatesGenerated: 3,
        candidatesAfterDedup: 3,
        averageConfidence: 0.7,
        processingTimeMs: 100,
        warnings: []
      };
      
      const analysis = analyzeEventBuilding(events, stats);
      
      expect(analysis.typeDistribution.ASSIGNMENT).toBe(2);
      expect(analysis.typeDistribution.QUIZ).toBe(1);
      expect(analysis.confidenceDistribution.high).toBe(1); // >= 0.8
      expect(analysis.confidenceDistribution.medium).toBe(1); // 0.5-0.8
      expect(analysis.confidenceDistribution.low).toBe(1); // < 0.5
      expect(analysis.monthlyDistribution['2025-09']).toBe(2); // September events
      expect(analysis.monthlyDistribution['2025-10']).toBe(1); // October events
      expect(analysis.averageEventsPerLine).toBe(0.3); // 3 events / 10 lines
    });
  });

  describe('Real-World Integration Tests', () => {
    it('should handle a comprehensive CS course syllabus', () => {
      const syllabus = `
        CS 101 - Introduction to Computer Science
        Fall 2025 Semester
        
        Course Schedule:
        
        Week 1 (August 25-29, 2025):
        Introduction to Programming
        
        Week 2 (September 1-5, 2025):
        Assignment 1: Hello World Program - Due September 8, 2025
        
        Week 3 (September 8-12, 2025):
        Variables and Data Types
        Quiz 1: Basic Concepts - September 12, 2025 at 10:00 AM
        
        Week 4 (September 15-19, 2025):
        Control Structures
        Assignment 2: Calculator Program - Due September 22, 2025
        
        Week 5 (September 22-26, 2025):
        Functions and Methods
        Lab 1: Debugging Workshop - September 25, 2025 2:00 PM in Room 204
        
        Week 6 (September 29 - October 3, 2025):
        Arrays and Lists
        Quiz 2: Control Flow - October 3, 2025
        
        Week 7 (October 6-10, 2025):
        Midterm Review
        Assignment 3: Data Processing - Due October 10, 2025
        
        Week 8 (October 13-17, 2025):
        Midterm Exam: October 15, 2025 at 2:00 PM - Comprehensive
        
        Week 9 (October 20-24, 2025):
        Object-Oriented Programming
        
        Week 10 (October 27-31, 2025):
        Assignment 4: OOP Project - Due November 1, 2025
        Lab 2: Design Patterns - October 30, 2025
        
        Finals Week (December 15-19, 2025):
        Final Project Presentations: December 17, 2025
        Final Exam: December 19, 2025 at 1:00 PM - Comprehensive
      `;
      
      const result = buildEvents(syllabus, {
        defaultYear: 2025,
        courseCode: 'CS 101',
        minConfidence: 0.4
      });
      
      // Should detect multiple events
      expect(result.events.length).toBeGreaterThan(8);
      
      // Should have various event types
      const types = [...new Set(result.events.map(e => e.type))];
      expect(types).toContain('ASSIGNMENT');
      expect(types).toContain('QUIZ');
      expect(types).toContain('MIDTERM');
      expect(types).toContain('FINAL');
      expect(types).toContain('LAB');
      
      // Events should be in chronological order
      const dates = result.events.map(e => e.start.getTime());
      const sortedDates = [...dates].sort((a, b) => a - b);
      expect(dates).toEqual(sortedDates);
      
      // Should have reasonable confidence scores
      const avgConfidence = result.events.reduce((sum, e) => sum + e.confidence, 0) / result.events.length;
      expect(avgConfidence).toBeGreaterThan(0.5);
      
      // Should detect location for lab
      const labEvents = result.events.filter(e => e.type === 'LAB');
      if (labEvents.length > 0) {
        expect(labEvents.some(e => e.location)).toBe(true);
      }
      
      // Should have appropriate all-day settings
      const assignments = result.events.filter(e => e.type === 'ASSIGNMENT');
      const exams = result.events.filter(e => e.type === 'MIDTERM' || e.type === 'FINAL');
      
      expect(assignments.every(e => e.allDay)).toBe(true);
      expect(exams.some(e => !e.allDay)).toBe(true); // Some exams have specific times
      
      // Statistics should be reasonable
      expect(result.stats.totalLines).toBeGreaterThan(20);
      expect(result.stats.linesWithDates).toBeGreaterThan(5);
      expect(result.stats.linesWithTypes).toBeGreaterThan(8);
      expect(result.stats.candidatesGenerated).toBeGreaterThanOrEqual(result.events.length);
      expect(result.stats.processingTimeMs).toBeGreaterThan(0);
    });

    it('should handle mathematics course with different terminology', () => {
      const syllabus = `
        MATH 201 - Calculus II
        Spring 2025
        
        Problem Sets:
        Problem Set 1: Integration Techniques - Due February 10, 2025
        Problem Set 2: Applications of Integration - Due February 24, 2025
        
        Examinations:
        First Exam: March 5, 2025 - Covers chapters 6-7
        Second Exam: April 2, 2025 - Covers chapters 8-9
        Final Examination: May 8, 2025 - Cumulative
        
        Weekly Recitations:
        Recitation Session: Every Friday 3:00 PM in Math Building Room 105
      `;
      
      const result = buildEvents(syllabus, { defaultYear: 2025 });
      
      // Should detect problem sets as assignments
      const assignments = result.events.filter(e => 
        e.title.toLowerCase().includes('problem set') || e.type === 'ASSIGNMENT'
      );
      expect(assignments.length).toBeGreaterThanOrEqual(2);
      
      // Should detect exams
      const exams = result.events.filter(e => 
        e.type === 'MIDTERM' || e.type === 'FINAL' || 
        e.title.toLowerCase().includes('exam')
      );
      expect(exams.length).toBeGreaterThanOrEqual(2);
      
      // Should have reasonable total events
      expect(result.events.length).toBeGreaterThan(3);
    });

    it('should handle mixed format syllabus with bullets and tables', () => {
      const syllabus = `
        Course: BIO 150 - Introduction to Biology
        
        • Assignment 1: Cell Structure Essay - Due 9/15/25
        • Lab Report 1: Microscopy - Due 9/22/25  
        • Quiz 1: Cell Biology - 9/25/25
        
        Exam Schedule:
        - Midterm 1: October 8, 2025 (Chapters 1-4)
        - Midterm 2: November 12, 2025 (Chapters 5-8)
        - Final: December 15, 2025 (Comprehensive)
        
        Weekly Labs:
        Lab sessions every Wednesday 1:00-4:00 PM
      `;
      
      const result = buildEvents(syllabus, { defaultYear: 2025 });
      
      // Should parse events from bulleted lists
      expect(result.events.length).toBeGreaterThan(3);
      
      // Should handle short date formats
      const sept15Events = result.events.filter(e => 
        e.start.getMonth() === 8 && e.start.getDate() === 15
      );
      expect(sept15Events.length).toBeGreaterThanOrEqual(1);
      
      // Should detect lab reports as assignments
      const labReports = result.events.filter(e => 
        e.title.toLowerCase().includes('lab report')
      );
      expect(labReports.length).toBeGreaterThanOrEqual(1);
    });
  });
});
