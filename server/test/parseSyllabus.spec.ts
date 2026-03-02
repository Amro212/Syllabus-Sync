import { describe, it, expect } from 'vitest';
import { buildParseSyllabusRequest, type ParsePromptOptions } from '../src/prompts/parseSyllabus.js';
import type { GradingSchemeResult } from '../src/utils/extractGradingScheme.js';

describe('buildParseSyllabusRequest', () => {
  const baseText = 'Assignment 1 due Sept 12, 2025.';

  it('returns a well-formed OpenAI request', () => {
    const { request } = buildParseSyllabusRequest(baseText, {
      courseCode: 'CS101',
      timezone: 'America/New_York',
    });

    expect(request.model).toBe('gpt-4.1-mini');
    expect(request.temperature).toBe(0);
    expect(request.response_format.type).toBe('json_schema');
    expect(request.messages.length).toBeGreaterThan(2); // system + fewshots + user
  });

  it('includes system prompt with timezone', () => {
    const { request } = buildParseSyllabusRequest(baseText, {
      timezone: 'America/Chicago',
    });

    const system = request.messages[0];
    expect(system.role).toBe('system');
    expect(system.content).toContain('America/Chicago');
  });

  it('includes GRADING SCHEME in user message when provided', () => {
    const gradingScheme: GradingSchemeResult = {
      deliverables: [
        { name: 'Assignments', weight: 0.4, type: 'ASSIGNMENT' },
        { name: 'Final Exam', weight: 0.6, type: 'FINAL' },
      ],
      rawSection: 'Assignments 40%\nFinal Exam 60%',
    };

    const { request } = buildParseSyllabusRequest(baseText, {
      courseCode: 'CS101',
      gradingScheme,
    });

    const userMsg = request.messages[request.messages.length - 1];
    expect(userMsg.content).toContain('GRADING SCHEME:');
    expect(userMsg.content).toContain('Assignments');
    expect(userMsg.content).toContain('40%');
  });

  it('shows "Not found" when no grading scheme provided', () => {
    const { request } = buildParseSyllabusRequest(baseText);

    const userMsg = request.messages[request.messages.length - 1];
    expect(userMsg.content).toContain('GRADING SCHEME:');
    expect(userMsg.content).toContain('Not found');
  });

  it('includes context block with course code and term dates', () => {
    const { request } = buildParseSyllabusRequest(baseText, {
      courseCode: 'CS101',
      termStart: '2025-09-02',
      termEnd: '2025-12-15',
      timezone: 'America/New_York',
    });

    const userMsg = request.messages[request.messages.length - 1];
    expect(userMsg.content).toContain('CS101');
    expect(userMsg.content).toContain('2025-09-02');
    expect(userMsg.content).toContain('2025-12-15');
  });

  it('uses custom model when specified', () => {
    const { request } = buildParseSyllabusRequest(baseText, {
      model: 'gpt-4o',
    });
    expect(request.model).toBe('gpt-4o');
  });

  it('includes preprocessed text in user message', () => {
    const { request, processedText } = buildParseSyllabusRequest(baseText);

    const userMsg = request.messages[request.messages.length - 1];
    expect(userMsg.content).toContain('Syllabus Text:');
    expect(userMsg.content).toContain(processedText);
  });

  it('has correct number of few-shot messages', () => {
    const { request } = buildParseSyllabusRequest(baseText);
    // 1 system + 14 fewshot (7 pairs) + 1 user = 16
    expect(request.messages).toHaveLength(16);
    expect(request.messages[0].role).toBe('system');
    expect(request.messages[1].role).toBe('user');
    expect(request.messages[2].role).toBe('assistant');
    expect(request.messages[request.messages.length - 1].role).toBe('user');
  });

  it('system prompt includes hallucination rules', () => {
    const { request } = buildParseSyllabusRequest(baseText);
    const systemContent = request.messages[0].content;
    expect(systemContent).toContain('HALLUCINATION');
    expect(systemContent).toContain('SOURCE OF TRUTH');
    expect(systemContent).toContain('GRADING SCHEME');
  });
});
