import { describe, it, expect } from 'vitest';
import { preprocessTextForAI } from '../src/utils/preprocessTextForAI.js';

describe('preprocessTextForAI', () => {
  it('tags assignment lines', () => {
    const result = preprocessTextForAI('Assignment 1 due Sept 12');
    expect(result).toContain('[EVENT:ASSIGNMENT]');
  });

  it('tags final exam lines', () => {
    const result = preprocessTextForAI('Final Exam: December 10, 2025');
    expect(result).toContain('[EVENT:FINAL]');
  });

  it('tags midterm lines', () => {
    const result = preprocessTextForAI('Midterm: October 15, 2025');
    expect(result).toContain('[EVENT:MIDTERM]');
  });

  it('does NOT tag bare "final" without "exam"', () => {
    const result = preprocessTextForAI('The final grade will be calculated as follows');
    // Should NOT contain [EVENT:FINAL]
    expect(result).not.toContain('[EVENT:FINAL]');
  });

  it('strips boilerplate lines entirely from output', () => {
    const text = [
      'Academic Integrity:',
      'If you miss the midterm exam, you must provide documentation.',
      'Plagiarism on any exam will result in a grade of zero.',
    ].join('\n');

    const result = preprocessTextForAI(text);
    // Boilerplate body lines must be completely absent — not just untagged.
    // An empty output is correct here: zero schedule information == zero output.
    expect(result).not.toContain('midterm exam');
    expect(result).not.toContain('Plagiarism');
    expect(result).not.toContain('[EVENT:MIDTERM]');
    expect(result).not.toContain('[EVENT:EXAM]');
  });

  it('resumes tagging after a content section heading', () => {
    const text = [
      'Academic Integrity:',
      'Plagiarism will not be tolerated.',
      '',
      'Course Schedule:',
      'Midterm: October 15, 2025',
    ].join('\n');

    const result = preprocessTextForAI(text);
    // Boilerplate body must be gone
    expect(result).not.toContain('Plagiarism');
    // Midterm after the content heading must be tagged
    const lines = result.split('\n');
    expect(lines.some(l => l.includes('[EVENT:MIDTERM]'))).toBe(true);
  });

  it('preserves blank lines', () => {
    const text = 'Line 1\n\nLine 3';
    const result = preprocessTextForAI(text);
    expect(result).toBe('Line 1\n\nLine 3');
  });

  it('does not double-tag lines', () => {
    const result = preprocessTextForAI('Assignment 1 midterm study guide');
    // Should only have one [EVENT:*] tag at the start
    const tags = result.match(/\[EVENT:[A-Z]+\]/g) || [];
    expect(tags.length).toBe(1);
  });

  it('handles lecture detection', () => {
    const result = preprocessTextForAI('Lectures: Monday, Wednesday, Friday 2:00 PM');
    expect(result).toContain('[EVENT:LECTURE]');
  });

  it('handles project detection', () => {
    const result = preprocessTextForAI('Mini-Project due November 1');
    expect(result).toContain('[EVENT:PROJECT]');
  });
});
