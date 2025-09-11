/**
 * Tests for keyword classification utilities
 */

import { describe, it, expect } from 'vitest';
import { 
  classifyLine, 
  classifyLines, 
  analyzeClassificationResults,
  type ClassificationResult,
  type ClassificationStats 
} from '../src/parsing/keywordClassifier.js';

describe('Keyword Classification', () => {
  describe('classifyLine', () => {
    it('should handle null and undefined input', () => {
      expect(() => classifyLine(null as any)).toThrow(TypeError);
      expect(() => classifyLine(undefined as any)).toThrow(TypeError);
      expect(() => classifyLine(123 as any)).toThrow(TypeError);
    });

    it('should handle empty string', () => {
      const result = classifyLine('');
      expect(result.type).toBe('OTHER');
      expect(result.confidence).toBe(0);
      expect(result.matchedKeywords).toEqual([]);
    });

    describe('Assignment Classification', () => {
      it('should classify clear assignment indicators', () => {
        const tests = [
          'Assignment 1: Introduction to Programming',
          'Homework due Friday',
          'Project proposal submission',
          'Written assignment on data structures',
          'Individual project requirements',
          'Research paper guidelines'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('ASSIGNMENT');
          expect(result.confidence).toBeGreaterThan(0.5);
          expect(result.matchedKeywords.length).toBeGreaterThan(0);
        }
      });

      it('should handle assignment abbreviations', () => {
        const tests = [
          'HW 1 due Monday',
          'Assign #2 submission',
          'Proj requirements',
          'ASSGN 3 deadline'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('ASSIGNMENT');
          expect(result.confidence).toBeGreaterThan(0.4);
        }
      });

      it('should boost confidence for assignment context', () => {
        const withContext = classifyLine('Assignment 1 due Friday worth 10 points');
        const withoutContext = classifyLine('Assignment 1');
        
        expect(withContext.confidence).toBeGreaterThan(withoutContext.confidence);
        expect(withContext.context.hasDueDate).toBe(true);
        expect(withContext.context.hasWeight).toBe(true);
        expect(withContext.context.hasNumbering).toBe(true);
      });
    });

    describe('Quiz Classification', () => {
      it('should classify quiz indicators', () => {
        const tests = [
          'Quiz 1 on Monday',
          'Pop quiz this week',
          'Surprise quiz announcement',
          'Quick quiz on chapter 3',
          'Checkpoint assessment',
          'Knowledge check tomorrow'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('QUIZ');
          expect(result.confidence).toBeGreaterThan(0.5);
        }
      });

      it('should handle quiz variations', () => {
        const tests = [
          'QZ on Friday',
          'Mini quiz next class',
          'Reading quiz on chapter 3',
          'Concept check exercise'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('QUIZ');
          expect(result.confidence).toBeGreaterThan(0.4);
        }
      });
    });

    describe('Exam Classification', () => {
      it('should classify midterm exams', () => {
        const tests = [
          'Midterm exam on October 15',
          'Mid-term assessment next week',
          'Midterm evaluation schedule',
          'Mid semester exam',
          'Halfway exam announcement'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('MIDTERM');
          expect(result.confidence).toBeGreaterThan(0.7);
        }
      });

      it('should classify final exams', () => {
        const tests = [
          'Final exam December 18',
          'Comprehensive final',
          'Final assessment',
          'Cumulative final exam',
          'Course final evaluation'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('FINAL');
          expect(result.confidence).toBeGreaterThan(0.7);
        }
      });
    });

    describe('Lab Classification', () => {
      it('should classify lab activities', () => {
        const tests = [
          'Lab 1: Basic Programming',
          'Laboratory session on Tuesday',
          'Hands-on workshop',
          'Practical exercise',
          'Computer lab session',
          'Lab report submission'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('LAB');
          expect(result.confidence).toBeGreaterThan(0.5);
        }
      });

      it('should handle lab variations', () => {
        const tests = [
          'Wet lab session',
          'Virtual lab simulation', 
          'Coding lab exercise',
          'Lab demonstration'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('LAB');
          expect(result.confidence).toBeGreaterThan(0.4);
        }
      });
    });

    describe('Lecture Classification', () => {
      it('should classify lecture activities', () => {
        const tests = [
          'Lecture 1: Introduction',
          'Class session Monday',
          'Seminar on advanced topics',
          'Guest lecture announcement',
          'Video conference session',
          'Online webinar'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).toBe('LECTURE');
          expect(result.confidence).toBeGreaterThan(0.4);
        }
      });
    });

    describe('Contextual Analysis', () => {
      it('should detect due date indicators', () => {
        const tests = [
          'Assignment due Friday',
          'Submit by midnight',
          'Deadline is Monday',
          'Turn in your homework',
          'Upload by 11:59 PM'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.context.hasDueDate).toBe(true);
        }
      });

      it('should detect weight indicators', () => {
        const tests = [
          'Worth 20% of grade',
          'Assignment worth 50 points',
          'Weighted at 15%',
          'Counts for 10 pts',
          'Grade out of 100'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.context.hasWeight).toBe(true);
        }
      });

      it('should detect academic numbering', () => {
        const tests = [
          'Assignment 1',
          'Quiz #3',
          'Lab 2 report',
          'First assignment',
          'Second quiz',
          'Project three'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.context.hasNumbering).toBe(true);
        }
      });

      it('should handle negation properly', () => {
        const tests = [
          'No quiz this week',
          'Assignment cancelled',
          'Not having class today',
          'Skip the lab session',
          'Exam postponed'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.context.hasNegation).toBe(true);
          expect(result.confidence).toBeLessThan(0.5);
        }
      });

      it('should override negation with strong indicators', () => {
        const strongText = 'No quiz this week but Assignment 1 due Friday worth 20%';
        const result = classifyLine(strongText);
        
        // Should still classify as assignment despite negation
        expect(result.type).toBe('ASSIGNMENT');
        expect(result.confidence).toBeGreaterThan(0.3);
      });
    });

    describe('Edge Cases and Robustness', () => {
      it('should handle very short lines', () => {
        const tests = ['Quiz', 'HW', 'Lab', 'Test'];
        
        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.confidence).toBeLessThan(0.8); // Lower confidence for short lines
        }
      });

      it('should handle mixed case and punctuation', () => {
        const tests = [
          'ASSIGNMENT #1: Due FRIDAY!!!',
          'quiz...on...monday???',
          'Lab-Report-2',
          'Final_Exam_Schedule'
        ];

        for (const text of tests) {
          const result = classifyLine(text);
          expect(result.type).not.toBe('OTHER');
          expect(result.confidence).toBeGreaterThan(0.3);
        }
      });

      it('should prefer specific over general terms', () => {
        const specificResult = classifyLine('Midterm exam next week');
        const generalResult = classifyLine('Test next week');
        
        expect(specificResult.confidence).toBeGreaterThan(generalResult.confidence);
        expect(specificResult.type).toBe('MIDTERM');
      });
    });

    describe('Real Syllabus Examples', () => {
      it('should classify typical syllabus lines correctly', () => {
        const syllabusLines = [
          { text: 'Assignment 1: Hello World Program - Due September 15, 2025', expectedType: 'ASSIGNMENT' },
          { text: 'Quiz 1 on variables and data types (10% of grade)', expectedType: 'QUIZ' },
          { text: 'Midterm Exam: October 15, 2025 - Covers chapters 1-5', expectedType: 'MIDTERM' },
          { text: 'Final Project: Web application (30% of final grade)', expectedType: 'ASSIGNMENT' },
          { text: 'Lab 3: Database Design Workshop', expectedType: 'LAB' },
          { text: 'Lecture 8: Advanced Algorithms and Data Structures', expectedType: 'LECTURE' },
          { text: 'Final Exam: December 18, 2025 - Comprehensive', expectedType: 'FINAL' },
          { text: 'Pop quiz on reading assignment (unannounced)', expectedType: 'QUIZ' },
          { text: 'Group project presentation (worth 25 points)', expectedType: 'ASSIGNMENT' },
          { text: 'Computer lab session: Hands-on programming', expectedType: 'LAB' }
        ];

        for (const { text, expectedType } of syllabusLines) {
          const result = classifyLine(text);
          expect(result.type).toBe(expectedType);
          expect(result.confidence).toBeGreaterThan(0.5);
        }
      });

      it('should handle complex academic scheduling', () => {
        const complexLines = [
          'Week 3: Assignment 2 due Monday, Quiz 3 on Wednesday',
          'Midterm exam (October 15) worth 25% of final grade',
          'Lab report submission deadline: Friday 11:59 PM',
          'Final project proposal due two weeks before finals',
          'No class Monday - work on take-home assignment instead'
        ];

        for (const text of complexLines) {
          const result = classifyLine(text);
          expect(result.type).not.toBe('OTHER');
          expect(result.matchedKeywords.length).toBeGreaterThan(0);
        }
      });

      it('should classify course structure lines', () => {
        const structureLines = [
          { text: 'Assignments (40%): 4 individual programming assignments', expectedType: 'ASSIGNMENT' },
          { text: 'Quizzes (20%): Weekly online quizzes on reading material', expectedType: 'QUIZ' },
          { text: 'Midterm (20%): In-class examination on October 15', expectedType: 'MIDTERM' },
          { text: 'Final Project (20%): Capstone web application', expectedType: 'ASSIGNMENT' },
          { text: 'Lab Sessions: Weekly hands-on programming practice', expectedType: 'LAB' }
        ];

        for (const { text, expectedType } of structureLines) {
          const result = classifyLine(text);
          expect(result.type).toBe(expectedType);
          expect(result.context.hasWeight).toBe(true);
        }
      });
    });

    describe('Confidence Scoring', () => {
      it('should assign higher confidence to specific terms', () => {
        const specific = classifyLine('Midterm examination on advanced algorithms');
        const generic = classifyLine('Test on algorithms');
        
        expect(specific.confidence).toBeGreaterThan(generic.confidence);
      });

      it('should boost confidence with multiple indicators', () => {
        const multiple = classifyLine('Assignment 1 due Friday worth 15% of grade');
        const single = classifyLine('Assignment 1');
        
        expect(multiple.confidence).toBeGreaterThan(single.confidence);
        expect(multiple.context.hasDueDate).toBe(true);
        expect(multiple.context.hasWeight).toBe(true);
        expect(multiple.context.hasNumbering).toBe(true);
      });

      it('should penalize very short lines', () => {
        const longLine = classifyLine('Assignment 1: Comprehensive programming project');
        const shortLine = classifyLine('Assignment');
        
        expect(longLine.confidence).toBeGreaterThan(shortLine.confidence);
      });
    });
  });

  describe('classifyLines', () => {
    it('should classify multiple lines with line indices', () => {
      const lines = [
        'Course Introduction',
        'Assignment 1 due Monday',
        'Quiz on Friday',
        'Lab session Wednesday',
        'Final exam December 18'
      ];

      const results = classifyLines(lines);
      
      expect(results).toHaveLength(5);
      expect(results[0].lineIndex).toBe(0);
      expect(results[0].originalText).toBe('Course Introduction');
      
      expect(results[1].type).toBe('ASSIGNMENT');
      expect(results[2].type).toBe('QUIZ');
      expect(results[3].type).toBe('LAB');
      expect(results[4].type).toBe('FINAL');
    });

    it('should maintain correct line indexing', () => {
      const lines = ['Line 0', 'Line 1', 'Assignment 2', 'Line 3'];
      const results = classifyLines(lines);
      
      for (let i = 0; i < lines.length; i++) {
        expect(results[i].lineIndex).toBe(i);
        expect(results[i].originalText).toBe(lines[i]);
      }
    });
  });

  describe('analyzeClassificationResults', () => {
    it('should handle empty results', () => {
      const stats = analyzeClassificationResults([]);
      
      expect(stats.totalLines).toBe(0);
      expect(stats.averageConfidence).toBe(0);
      expect(stats.highConfidenceLines).toBe(0);
      expect(stats.lowConfidenceLines).toBe(0);
      expect(stats.topKeywords).toEqual([]);
    });

    it('should calculate comprehensive statistics', () => {
      const results: ClassificationResult[] = [
        {
          type: 'ASSIGNMENT',
          confidence: 0.8,
          matchedKeywords: ['assignment', 'due'],
          context: { hasDueDate: true, hasWeight: false, hasNegation: false, hasNumbering: true }
        },
        {
          type: 'QUIZ',
          confidence: 0.9,
          matchedKeywords: ['quiz', 'grade'],
          context: { hasDueDate: false, hasWeight: true, hasNegation: false, hasNumbering: false }
        },
        {
          type: 'ASSIGNMENT',
          confidence: 0.6,
          matchedKeywords: ['assignment', 'project'],
          context: { hasDueDate: false, hasWeight: false, hasNegation: false, hasNumbering: false }
        },
        {
          type: 'OTHER',
          confidence: 0.2,
          matchedKeywords: [],
          context: { hasDueDate: false, hasWeight: false, hasNegation: false, hasNumbering: false }
        }
      ];

      const stats = analyzeClassificationResults(results);
      
      expect(stats.totalLines).toBe(4);
      expect(stats.typeDistribution.ASSIGNMENT).toBe(2);
      expect(stats.typeDistribution.QUIZ).toBe(1);
      expect(stats.typeDistribution.OTHER).toBe(1);
      expect(stats.averageConfidence).toBeCloseTo(0.625, 3);
      expect(stats.highConfidenceLines).toBe(2); // >= 0.7
      expect(stats.lowConfidenceLines).toBe(1); // <= 0.3
      
      expect(stats.topKeywords).toContain({ keyword: 'assignment', count: 2 });
      expect(stats.topKeywords.length).toBeGreaterThan(0);
    });

    it('should rank keywords by frequency', () => {
      const results: ClassificationResult[] = [
        {
          type: 'ASSIGNMENT',
          confidence: 0.8,
          matchedKeywords: ['assignment', 'due', 'homework'],
          context: { hasDueDate: true, hasWeight: false, hasNegation: false, hasNumbering: false }
        },
        {
          type: 'ASSIGNMENT',
          confidence: 0.7,
          matchedKeywords: ['assignment', 'project'],
          context: { hasDueDate: false, hasWeight: false, hasNegation: false, hasNumbering: false }
        },
        {
          type: 'QUIZ',
          confidence: 0.9,
          matchedKeywords: ['assignment', 'quiz'], // 'assignment' appears in both types
          context: { hasDueDate: false, hasWeight: false, hasNegation: false, hasNumbering: false }
        }
      ];

      const stats = analyzeClassificationResults(results);
      
      // 'assignment' should be the top keyword (appears 3 times)
      expect(stats.topKeywords[0].keyword).toBe('assignment');
      expect(stats.topKeywords[0].count).toBe(3);
    });
  });

  describe('Integration and Performance Tests', () => {
    it('should handle large syllabus content efficiently', () => {
      const largeSyllabus = `
        CS 101 - Introduction to Computer Science
        Fall 2025 Semester
        
        Course Overview:
        This course introduces students to programming concepts and problem-solving techniques.
        
        Grading Breakdown:
        - Assignments (40%): 6 programming assignments throughout the semester
        - Quizzes (20%): Weekly online quizzes on reading material  
        - Midterm Exam (20%): In-class examination covering first half of course
        - Final Project (20%): Comprehensive capstone project
        
        Schedule:
        Week 1: Introduction to Programming
        Assignment 1: Hello World - Due September 8
        
        Week 2: Variables and Data Types
        Quiz 1: Basic Concepts - September 12
        
        Week 3: Control Structures
        Assignment 2: Calculator Program - Due September 22
        Lab 1: Debugging Workshop - September 20
        
        Week 4: Functions and Procedures  
        Quiz 2: Control Flow - September 26
        
        Week 5: Arrays and Lists
        Assignment 3: Data Processing - Due October 6
        
        Week 6: Object-Oriented Programming
        Quiz 3: Functions - October 10
        Lab 2: OOP Practice - October 11
        
        Week 7: Review and Midterm
        Midterm Exam: October 17 - Covers weeks 1-6
        
        Week 8: File I/O and Error Handling
        Assignment 4: File Processor - Due October 27
        
        Week 9: Recursion
        Quiz 4: File Operations - October 31
        Lab 3: Recursive Algorithms - November 1
        
        Week 10: Data Structures
        Assignment 5: Linked Lists - Due November 10
        
        Week 11: Algorithms and Complexity
        Quiz 5: Data Structures - November 14
        
        Week 12: Final Project Work
        Assignment 6: Algorithm Analysis - Due November 24
        
        Week 13: Project Presentations
        Final Project Presentations: December 5-7
        
        Week 14: Finals Week
        Final Project Submission: December 12
        No final exam - project serves as final assessment
      `;

      const lines = largeSyllabus.split('\n').map(line => line.trim()).filter(line => line.length > 0);
      const results = classifyLines(lines);
      
      expect(results.length).toBeGreaterThan(20);
      
      // Should find multiple assignments
      const assignments = results.filter(r => r.type === 'ASSIGNMENT');
      expect(assignments.length).toBeGreaterThan(5);
      
      // Should find multiple quizzes
      const quizzes = results.filter(r => r.type === 'QUIZ');
      expect(quizzes.length).toBeGreaterThan(3);
      
      // Should find midterm
      const midterms = results.filter(r => r.type === 'MIDTERM');
      expect(midterms.length).toBeGreaterThan(0);
      
      // Should find labs
      const labs = results.filter(r => r.type === 'LAB');
      expect(labs.length).toBeGreaterThan(0);
      
      // Most classifications should have reasonable confidence
      const highConfidence = results.filter(r => r.confidence >= 0.5);
      expect(highConfidence.length).toBeGreaterThan(results.length * 0.3); // At least 30% high confidence
    });

    it('should maintain consistent classification for similar content', () => {
      const similarLines = [
        'Assignment 1: Programming Basics',
        'Assignment 2: Data Structures',
        'Assignment 3: Algorithm Design',
        'Assignment 4: Web Development'
      ];

      const results = similarLines.map(line => classifyLine(line));
      
      // All should be classified as assignments with similar confidence
      expect(results.every(r => r.type === 'ASSIGNMENT')).toBe(true);
      
      const confidences = results.map(r => r.confidence);
      const avgConfidence = confidences.reduce((a, b) => a + b) / confidences.length;
      
      // All confidences should be within reasonable range of average
      expect(confidences.every(c => Math.abs(c - avgConfidence) < 0.2)).toBe(true);
    });
  });
});
