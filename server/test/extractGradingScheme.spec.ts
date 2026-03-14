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

  it('removes parent entries when children sum to the same weight', () => {
    const text = [
      'Evaluation Scheme:',
      'Midterm 1  15%',
      'Midterm 2  15%',
      'Final Exam  30%',
      'Exams  60%',
      'Participation  40%',
    ].join('\n');

    const result = extractGradingScheme(text);
    // "Exams 60%" is a parent of the three exam items (15+15+30=60).
    // It should be removed, leaving 4 entries totaling 100%.
    const names = result.deliverables.map(d => d.name.toLowerCase());
    expect(names).not.toContain('exams');
    const total = result.deliverables.reduce((s, d) => s + (d.weight ?? 0), 0);
    expect(total).toBeCloseTo(1.0);
  });

  it('keeps all entries when total is at or below 100%', () => {
    const text = [
      'Grading Breakdown:',
      'Assignments  30%',
      'Midterm  30%',
      'Final  40%',
    ].join('\n');

    const result = extractGradingScheme(text);
    expect(result.deliverables).toHaveLength(3);
    const total = result.deliverables.reduce((s, d) => s + (d.weight ?? 0), 0);
    expect(total).toBeCloseTo(1.0);
  });

  it('never removes specific items whose weight coincidentally sums to another', () => {
    // Regression: "Final Exam 30%" must NOT be removed because
    // "Midterm 1 (15%) + Midterm 2 (15%) = 30%".
    // Only umbrella names like "Exams" should be removal candidates.
    const text = [
      'Evaluation Scheme:',
      'Midterm 1  15%',
      'Midterm 2  15%',
      'Final Exam  30%',
      'Assignments  40%',
      'Exams  60%',
      'Homework  40%',
    ].join('\n');

    const result = extractGradingScheme(text);
    const names = result.deliverables.map(d => d.name.toLowerCase());
    // "Exams" and "Homework" are umbrella names and can be removed
    // "Final Exam" is a specific assessment and must be kept
    expect(names).toContain('final exam');
    expect(names).toContain('midterm 1');
    expect(names).toContain('midterm 2');
    expect(names).toContain('assignments');
  });

  it('does not remove "Final Exam" even when two midterms sum to its weight', () => {
    const text = [
      'Grading Breakdown:',
      'Midterm 1  15%',
      'Midterm 2  15%',
      'Final Exam  30%',
      'Participation  40%',
      'Exams  60%',
    ].join('\n');

    const result = extractGradingScheme(text);
    const names = result.deliverables.map(d => d.name.toLowerCase());
    expect(names).toContain('final exam');
    expect(names).toContain('midterm 1');
    expect(names).toContain('midterm 2');
    expect(names).toContain('participation');
    expect(names).not.toContain('exams');
    const total = result.deliverables.reduce((s, d) => s + (d.weight ?? 0), 0);
    expect(total).toBeCloseTo(1.0);
  });

  it('removes multiple umbrella parents when needed', () => {
    const text = [
      'Evaluation Scheme:',
      'Assignment 1  10%',
      'Assignment 2  10%',
      'Assignment 3  10%',
      'Assignments  30%',
      'Midterm  30%',
      'Final Exam  40%',
      'Exams  70%',
    ].join('\n');

    const result = extractGradingScheme(text);
    const names = result.deliverables.map(d => d.name.toLowerCase());
    expect(names).not.toContain('assignments');
    expect(names).not.toContain('exams');
    expect(names).toContain('assignment 1');
    expect(names).toContain('assignment 2');
    expect(names).toContain('assignment 3');
    expect(names).toContain('midterm');
    expect(names).toContain('final exam');
    const total = result.deliverables.reduce((s, d) => s + (d.weight ?? 0), 0);
    expect(total).toBeCloseTo(1.0);
  });

  it('keeps non-umbrella entries untouched even with >100% total when no umbrella matches', () => {
    // If total > 100% but no entry is an umbrella name, nothing is removed.
    // This is intentional: we return the raw data and let the AI handle it.
    const text = [
      'Grading Breakdown:',
      'Research Paper  40%',
      'Group Project  35%',
      'Class Presentation  30%',
    ].join('\n');

    const result = extractGradingScheme(text);
    expect(result.deliverables).toHaveLength(3);
    const total = result.deliverables.reduce((s, d) => s + (d.weight ?? 0), 0);
    // 105% — all specific items, no umbrella to remove
    expect(total).toBeCloseTo(1.05);
  });

  it('keeps singular deliverables even when other weights add up to the same value', () => {
    const text = [
      'Grading Breakdown:',
      'Project  30%',
      'Midterm  15%',
      'Final Exam  15%',
      'Essay  40%',
      'Participation  20%',
    ].join('\n');

    const result = extractGradingScheme(text);
    const names = result.deliverables.map(d => d.name.toLowerCase());

    expect(names).toContain('project');
    expect(names).toContain('midterm');
    expect(names).toContain('final exam');
    expect(result.deliverables).toHaveLength(5);
  });

  it('handles CIS*2750-style syllabus: tab-separated tables, colons in names, blocks false positives', () => {
    // Regression: The extractor must handle real OCR tab-separated table rows
    // where assignment names contain colons (e.g. "AO: Unit testing...")
    // and special chars (e.g. "(C + Python)"), and must not pick up
    // "component (60%)" from the Final Grade Calculation policy paragraph.
    const text = [
      'CIS*2750 Software Systems Development and Integration',
      'Class Time / Location: ue/Thu 4:00-5:20 pm | MACN 105',
      '',
      'Assessments and Grade Calculation',
      'Exams',
      'Item\tWeight\tDue / Date',
      'Midterm 1\t15%\tSaturday, Feb 7',
      'Midterm 2\t15%\tSaturday, Mar 14',
      'Final exam\t30%\tApril 14, 11:30 am - 1:30 pm',
      'Assignments',
      'Item\tWeight\tDue / Date',
      'AO: Unit testing a provided C library\t5%\tJan 16 @11:59 pm',
      'A1: C library creation following API\t10%\tFeb 6 @11:59 pm',
      'A2: Python CLI, Integration (C + Python)\t10%\tMar 6 @11:59 pm',
      'A3: Text-based UI, Persistence, Modularity, Demo\t15%\tMar 27 @11:59 pm',
      'Assignment Alignment with Learning Outcomes',
      'LO5',
      'Assignment Policies',
      'Submissions must be made via GitLab.',
      '',
      'Final Grade Calculation',
      'Your final course grade is normally the sum of the assignment component (40%) and the exam',
      'component (60%).',
    ].join('\n');

    const result = extractGradingScheme(text);
    const names = result.deliverables.map(d => d.name.toLowerCase());

    // Must find all 7 real deliverables (3 exams + 4 assignments)
    expect(result.deliverables.length).toBe(7);
    expect(names).toContain('midterm 1');
    expect(names).toContain('midterm 2');
    expect(names).toContain('final exam');
    // Assignment names include the colon prefix from OCR
    expect(names.some(n => n.includes('unit testing'))).toBe(true);
    expect(names.some(n => n.includes('c library creation'))).toBe(true);
    expect(names.some(n => n.includes('python cli'))).toBe(true);
    expect(names.some(n => n.includes('text-based ui'))).toBe(true);

    // Must NOT contain false positives from policy sections
    expect(names.some(n => n.includes('component'))).toBe(false);
    expect(names.some(n => n.includes('coursework'))).toBe(false);

    // Total should be 100%
    const total = result.deliverables.reduce((s, d) => s + (d.weight ?? 0), 0);
    expect(total).toBeCloseTo(1.0);

    // Should have identified a raw section (not fallback full-doc scan)
    expect(result.rawSection).toBeTruthy();
  });

  it('blocks blacklisted names like "grade", "total", "score"', () => {
    const text = [
      'Evaluation Scheme:',
      'Assignments  40%',
      'Final Exam   30%',
      'Participation  30%',
      'Total  100%',
      'Grade  100%',
    ].join('\n');

    const result = extractGradingScheme(text);
    const names = result.deliverables.map(d => d.name.toLowerCase());
    expect(names).not.toContain('total');
    expect(names).not.toContain('grade');
    expect(result.deliverables).toHaveLength(3);
  });

  it('handles ENGG*3100-style syllabus: asterisk in names, inline (%) format in Assessment Details', () => {
    // Regression: "Interim Design Report*" and "Final Design Report*" were
    // missed because the * character was not in the name character class.
    // The grading table uses bare numbers without %, but the Assessment Details
    // section has inline (20%) format which should be matched.
    const text = [
      'ENGG*3100 Engineering and Design III',
      '',
      '6 Assessments',
      '6.1 Marking Schemes & Distributions',
      'Name\tScheme A (%)',
      'Course Learning Activities\t10',
      'Design Process Reviews\t10',
      'Design Proposal\t10',
      'Interim Design Report*\t20',
      'Technical Memo\t10',
      'Cost Memo\t5',
      'Design Presentation\t10',
      'Final Design Report*\t25',
      'Total\t100',
      '6.2 Assessment Details',
      'Course Learning Activities (10%)',
      'Date: Mon, Jan 7 - Fri, Apr 5, In weekly lectures and design labs',
      'Design Process Reviews including Project Management (10%)',
      'Date: Mon, Jan 14 - Fri, Apr 5, In weekly design labs',
      'Team and Project Selection (0%)',
      'Date: Sun, Jan 20, 10:00 PM',
      'Design Proposal (10%)',
      'Date: Sun, Jan 27, 10:00 PM',
      'Interim Design Report* (20%)',
      'Date: Thu, Feb 14, 10:00 PM',
      'Interim Design Reflection (0%)',
      'Date: Sun, Feb 17, 10:00 PM',
      'Technical Memo (10%)',
      'Date: Thu, Mar 7, 10:00 PM',
      'Cost Memo (5%)',
      'Date: Thu, Mar 14, 10:00 PM',
      'Design Presentation (10%)',
      'Date: Mon, Mar 18 - Fri, Mar 22',
      'Final Design Report* (25%)',
      'Date: Sat, Apr 6, 10:00 PM',
      'Final Design Reflection (0%)',
      'Date: Sun, Apr 7, 10:00 PM',
      '',
      '7 Course Statements',
      'Passing Grade: In order to pass the course, a student must obtain a final grade of 50% or higher.',
    ].join('\n');

    const result = extractGradingScheme(text);
    const names = result.deliverables.map(d => d.name.toLowerCase());

    // Must find all 8 real deliverables (0% items are filtered out by pct > 0)
    expect(result.deliverables.length).toBe(8);
    expect(names).toContain('course learning activities');
    expect(names.some(n => n.includes('design process reviews'))).toBe(true);
    expect(names).toContain('design proposal');
    expect(names.some(n => n.includes('interim design report'))).toBe(true);
    expect(names).toContain('technical memo');
    expect(names).toContain('cost memo');
    expect(names).toContain('design presentation');
    expect(names.some(n => n.includes('final design report'))).toBe(true);

    // Total should be 100%
    const total = result.deliverables.reduce((s, d) => s + (d.weight ?? 0), 0);
    expect(total).toBeCloseTo(1.0);

    // Must NOT include 0% items or "Total" or "grade"
    expect(names.some(n => n.includes('reflection'))).toBe(false);
    expect(names.some(n => n.includes('team and project'))).toBe(false);
    expect(names).not.toContain('total');

    // Should have identified a raw section
    expect(result.rawSection).toBeTruthy();
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
