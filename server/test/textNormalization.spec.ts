/**
 * Tests for text normalization utilities
 */

import { describe, it, expect } from 'vitest';
import { 
  normalizeText, 
  splitIntoLines, 
  extractTextBlocks, 
  analyzeText,
  type TextStats 
} from '../src/parsing/textNormalization.js';

describe('Text Normalization', () => {
  describe('normalizeText', () => {
    it('should handle null and undefined input', () => {
      expect(() => normalizeText(null as any)).toThrow(TypeError);
      expect(() => normalizeText(undefined as any)).toThrow(TypeError);
      expect(() => normalizeText(123 as any)).toThrow(TypeError);
    });

    it('should handle empty string', () => {
      expect(normalizeText('')).toBe('');
      expect(normalizeText('   ')).toBe('');
      expect(normalizeText('\n\n\n')).toBe('');
    });

    it('should trim leading and trailing whitespace', () => {
      expect(normalizeText('  hello world  ')).toBe('hello world');
      expect(normalizeText('\n\n  Assignment 1  \n\n')).toBe('Assignment 1');
    });

    it('should collapse multiple spaces into single spaces', () => {
      expect(normalizeText('hello    world')).toBe('hello world');
      expect(normalizeText('Assignment  1   due    Friday')).toBe('Assignment 1 due Friday');
      expect(normalizeText('Multiple\t\ttabs\t\there')).toBe('Multiple tabs here');
    });

    it('should normalize different line endings', () => {
      expect(normalizeText('line1\r\nline2')).toBe('line1\nline2');
      expect(normalizeText('line1\rline2')).toBe('line1\nline2');
      expect(normalizeText('line1\nline2')).toBe('line1\nline2');
    });

    it('should merge broken words from PDF extraction', () => {
      // Hyphenated words broken across lines
      expect(normalizeText('assign-\nment')).toBe('assignment');
      expect(normalizeText('mid-\nterm')).toBe('midterm');
      
      // Words broken without hyphen
      expect(normalizeText('assign\nment')).toBe('assignment');
      expect(normalizeText('home\nwork')).toBe('homework');
    });

    it('should merge broken sentences', () => {
      expect(normalizeText('This is a sentence\nthat continues here')).toBe('This is a sentence that continues here');
      expect(normalizeText('Assignment 1\nis due Friday')).toBe('Assignment 1 is due Friday');
    });

    it('should preserve intentional line breaks', () => {
      // Should not merge lines that end with punctuation
      expect(normalizeText('Sentence one.\nSentence two.')).toBe('Sentence one.\nSentence two.');
      expect(normalizeText('Question?\nAnswer here.')).toBe('Question?\nAnswer here.');
      
      // Should not merge when next line starts with capital
      expect(normalizeText('First line\nSecond Line')).toBe('First line\nSecond Line');
    });

    it('should collapse excessive blank lines while preserving paragraph breaks', () => {
      expect(normalizeText('Para 1\n\n\n\n\nPara 2')).toBe('Para 1\n\nPara 2');
      expect(normalizeText('Line 1\n\nLine 2\n\n\n\n\nLine 3')).toBe('Line 1\n\nLine 2\n\nLine 3');
    });

    it('should handle Unicode normalization', () => {
      // NFC normalization should handle decomposed characters
      const decomposed = 'cafe\u0301'; // cafe + combining acute accent
      const composed = 'café'; // single character
      expect(normalizeText(decomposed)).toBe(composed);
      
      // Handle various Unicode characters
      expect(normalizeText('naïve résumé')).toBe('naïve résumé');
    });

    it('should clean whitespace around line breaks', () => {
      expect(normalizeText('line1   \n   line2')).toBe('line1\nline2');
      expect(normalizeText('line1\t\n\tline2')).toBe('line1\nline2');
    });

    it('should handle real PDF extraction scenarios', () => {
      const pdfText = `
        Course:   CS  101    Introduction   to
        Programming

        Assignment   1:   Hello   World
        Due:   September   15,   2025

        Assignment   2:   Variables   and
        Control   Flow
        Due:   September   22,   2025


        Midterm   Exam:   October   1,   2025
      `;
      
      const normalized = normalizeText(pdfText);
      const lines = splitIntoLines(normalized);
      
      expect(lines).toContain('Course: CS 101 Introduction to Programming');
      expect(lines).toContain('Assignment 1: Hello World');
      expect(lines).toContain('Due: September 15, 2025');
      expect(lines).toContain('Assignment 2: Variables and Control Flow');
      expect(lines).toContain('Due: September 22, 2025');
      expect(lines).toContain('Midterm Exam: October 1, 2025');
    });

    it('should handle complex broken line scenarios', () => {
      const complexText = `Week 1: Introduc-
tion to Programming
Basic concepts and syn-
tax overview

Week 2: Variables
and Data Types
Understanding prim-
itive types`;

      const normalized = normalizeText(complexText);
      expect(normalized).toContain('Introduction to Programming');
      expect(normalized).toContain('syntax overview');
      expect(normalized).toContain('primitive types');
    });
  });

  describe('splitIntoLines', () => {
    it('should split text into non-empty lines', () => {
      const text = 'Line 1\nLine 2\n\nLine 3\n';
      expect(splitIntoLines(text)).toEqual(['Line 1', 'Line 2', 'Line 3']);
    });

    it('should trim whitespace from each line', () => {
      const text = '  Line 1  \n  Line 2  \n  Line 3  ';
      expect(splitIntoLines(text)).toEqual(['Line 1', 'Line 2', 'Line 3']);
    });

    it('should handle empty string', () => {
      expect(splitIntoLines('')).toEqual([]);
      expect(splitIntoLines('\n\n\n')).toEqual([]);
    });
  });

  describe('extractTextBlocks', () => {
    it('should extract blocks separated by blank lines', () => {
      const text = `Block 1
Line 2 of block 1

Block 2
Line 2 of block 2

Block 3`;
      
      const blocks = extractTextBlocks(text);
      expect(blocks).toHaveLength(3);
      expect(blocks[0]).toBe('Block 1\nLine 2 of block 1');
      expect(blocks[1]).toBe('Block 2\nLine 2 of block 2');
      expect(blocks[2]).toBe('Block 3');
    });

    it('should handle single block', () => {
      const text = 'Single block of text\nwith multiple lines';
      const blocks = extractTextBlocks(text);
      expect(blocks).toHaveLength(1);
      expect(blocks[0]).toBe('Single block of text\nwith multiple lines');
    });

    it('should filter out empty blocks', () => {
      const text = 'Block 1\n\n\n\nBlock 2\n\n\n';
      const blocks = extractTextBlocks(text);
      expect(blocks).toHaveLength(2);
      expect(blocks[0]).toBe('Block 1');
      expect(blocks[1]).toBe('Block 2');
    });
  });

  describe('analyzeText', () => {
    it('should provide basic text statistics', () => {
      const text = 'Line 1\nLine 2\nLine 3';
      const stats = analyzeText(text);
      
      expect(stats.characterCount).toBe(20);
      expect(stats.lineCount).toBe(3);
      expect(stats.blockCount).toBe(1);
      expect(stats.avgCharsPerLine).toBeCloseTo(6.67, 2);
      expect(stats.complexity).toBe('low');
    });

    it('should calculate complexity correctly', () => {
      // Low complexity: short lines
      const lowText = 'Short\nlines\nhere';
      expect(analyzeText(lowText).complexity).toBe('low');
      
      // Medium complexity: medium lines
      const mediumText = 'This is a medium length line that should be\nclassified as medium complexity text content';
      expect(analyzeText(mediumText).complexity).toBe('medium');
      
      // High complexity: long lines
      const highText = 'This is a very long line that contains a substantial amount of text and should be classified as high complexity due to its length and density of information';
      expect(analyzeText(highText).complexity).toBe('high');
    });

    it('should handle empty text', () => {
      const stats = analyzeText('');
      expect(stats.characterCount).toBe(0);
      expect(stats.lineCount).toBe(0);
      expect(stats.blockCount).toBe(0);
      expect(stats.avgCharsPerLine).toBe(0);
      expect(stats.complexity).toBe('low');
    });

    it('should handle realistic syllabus content', () => {
      const syllabusText = normalizeText(`
CS 101 - Introduction to Programming
Fall 2025

Course Description:
This course introduces students to programming concepts
using Python. Topics include variables, control flow,
functions, and basic data structures.

Assignments:
Assignment 1: Hello World - Due Sept 15
Assignment 2: Variables - Due Sept 22
Assignment 3: Functions - Due Sept 29

Exams:
Midterm: October 15
Final: December 10
      `);
      
      const stats = analyzeText(syllabusText);
      expect(stats.characterCount).toBeGreaterThan(100);
      expect(stats.lineCount).toBeGreaterThan(5);
      expect(stats.blockCount).toBeGreaterThan(1);
      expect(stats.avgCharsPerLine).toBeGreaterThan(0);
      expect(['low', 'medium', 'high']).toContain(stats.complexity);
    });
  });

  describe('Integration tests with sample syllabus data', () => {
    it('should handle typical PDF extraction artifacts', () => {
      const messyPdfText = `
      CS    101  -   Computer    Science    I

      Fall    2025        Semester


      Course   Objectives:
      Students  will  learn  program-
      ming  fundamentals  including:
      •  Variables  and  data  types
      •  Control  structures  (if/else,
      loops)
      •  Functions  and  procedures

      Assignment  Schedule:
      Assignment  1:  Basic  I/O
      Due:  September  15th,  2025
      Worth:  10%  of  final  grade

      Assignment  2:  Control  Flow
      Due:  September  22nd,  2025  
      Worth:  15%  of  final  grade

      Midterm  Exam:  October  15th
      Final  Exam:  December  12th
      `;

      const normalized = normalizeText(messyPdfText);
      const lines = splitIntoLines(normalized);
      const blocks = extractTextBlocks(normalized);
      const stats = analyzeText(normalized);

      // Verify spacing is cleaned up
      expect(normalized).toContain('CS 101 - Computer Science I');
      expect(normalized).toContain('Fall 2025 Semester');
      
      // Verify broken words are merged
      expect(normalized).toContain('programming fundamentals');
      
      // Verify lines are properly structured
      expect(lines.some(line => line.includes('Assignment 1: Basic I/O'))).toBe(true);
      expect(lines.some(line => line.includes('Due: September 15th, 2025'))).toBe(true);
      
      // Verify blocks are identified
      expect(blocks.length).toBeGreaterThan(1);
      
      // Verify stats are reasonable
      expect(stats.lineCount).toBeGreaterThan(5);
      expect(stats.characterCount).toBeGreaterThan(200);
    });

    it('should preserve important formatting while cleaning', () => {
      const syllabusWithFormatting = `
COURSE: CS 201 - Data Structures
INSTRUCTOR: Dr. Smith
EMAIL: smith@university.edu

SCHEDULE:
Monday, Wednesday, Friday: 10:00 AM - 11:00 AM
Room: Science Building 101

GRADING:
Assignments: 40%
Midterm: 25%
Final: 35%

IMPORTANT DATES:
• Drop deadline: September 30
• Midterm exam: October 20
• Final exam: December 15
      `;

      const normalized = normalizeText(syllabusWithFormatting);
      
      // Should preserve the structured information
      expect(normalized).toContain('COURSE: CS 201 - Data Structures');
      expect(normalized).toContain('Monday, Wednesday, Friday: 10:00 AM - 11:00 AM');
      expect(normalized).toContain('Assignments: 40%');
      expect(normalized).toContain('• Drop deadline: September 30');
      
      // Should clean up excessive whitespace
      expect(normalized).not.toMatch(/\s{3,}/); // No 3+ consecutive spaces
      expect(normalized).not.toMatch(/\n{3,}/); // No 3+ consecutive newlines
    });
  });
});
