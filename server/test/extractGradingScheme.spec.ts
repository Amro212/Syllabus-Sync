import { describe, it, expect } from 'vitest';
import {
  extractGradingScheme,
  formatGradingSchemeForPrompt,
} from '../src/utils/extractGradingScheme.js';

describe('extractGradingScheme', () => {
  it('extracts a simple grading breakdown', () => {
    const text = [
      'Course Description:',
      'This course covers algorithms.',
      '',
      'Evaluation Scheme:',
      'Assignments  30%',
      'Midterm      30%',
      'Final Exam   40%',
      '',
      'Schedule:',
      'Week 1: Intro',
    ].join('\n');

    const result = extractGradingScheme(text);
    expect(result.deliverables).toHaveLength(3);
    expect(result.deliverables[0].name).toBe('Assignments');
    expect(result.deliverables[0].weight).toBeCloseTo(0.3);
    expect(result.deliverables[0].type).toBe('ASSIGNMENT');
    expect(result.deliverables[1].type).toBe('MIDTERM');
    expect(result.deliverables[2].type).toBe('FINAL');
    expect(result.rawSection).toBeTruthy();
  });

  it('handles percentage with % sign', () => {
    const text = [
      'Grading Breakdown:',
      '- Labs: 25%',
      '- Final Exam: 40%',
      '- Participation: 35%',
    ].join('\n');

    const result = extractGradingScheme(text);
    expect(result.deliverables).toHaveLength(3);
    expect(result.deliverables[0].name).toBe('Labs');
    expect(result.deliverables[0].weight).toBeCloseTo(0.25);
    expect(result.deliverables[0].type).toBe('LAB');
  });

  it('returns empty when no grading section found', () => {
    const text = 'This syllabus has no grading info.\nJust course description.';
    const result = extractGradingScheme(text);
    expect(result.deliverables).toHaveLength(0);
    expect(result.rawSection).toBeNull();
  });

  it('handles reversed format (percentage first)', () => {
    const text = [
      'Evaluation:',
      '30% Assignments',
      '30% Midterm',
      '40% Final Exam',
    ].join('\n');

    const result = extractGradingScheme(text);
    expect(result.deliverables.length).toBeGreaterThanOrEqual(3);
  });

  it('correctly infers event types', () => {
    const text = [
      'Grading Scheme:',
      'Quiz 1: 10%',
      'Homework: 20%',
      'Lab Reports: 30%',
      'Final Exam: 40%',
    ].join('\n');

    const result = extractGradingScheme(text);
    const types = result.deliverables.map(d => d.type);
    expect(types).toContain('QUIZ');
    expect(types).toContain('ASSIGNMENT');
    expect(types).toContain('LAB');
    expect(types).toContain('FINAL');
  });

  it('stops extraction at an end-section heading', () => {
    const text = [
      'Grading Breakdown:',
      'Assignments: 50%',
      'Final Exam: 50%',
      '',
      'Academic Integrity:',
      'Cheating on exams is 100% not allowed.',
    ].join('\n');

    const result = extractGradingScheme(text);
    // Should NOT pick up the "100%" from the academic integrity section
    expect(result.deliverables).toHaveLength(2);
  });
});

describe('formatGradingSchemeForPrompt', () => {
  it('formats deliverables as bullet list', () => {
    const result = formatGradingSchemeForPrompt({
      deliverables: [
        { name: 'Assignments', weight: 0.3, type: 'ASSIGNMENT' },
        { name: 'Final Exam', weight: 0.4, type: 'FINAL' },
      ],
      rawSection: 'stuff',
    });

    expect(result).toContain('Assignments');
    expect(result).toContain('30%');
    expect(result).toContain('Final Exam');
    expect(result).toContain('40%');
  });

  it('returns null for empty deliverables', () => {
    const result = formatGradingSchemeForPrompt({
      deliverables: [],
      rawSection: null,
    });
    expect(result).toBeNull();
  });
});
