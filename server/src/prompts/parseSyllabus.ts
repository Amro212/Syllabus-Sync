/*
 * Prompt builder for OpenAI JSON-mode parsing of syllabi → EventItemDTO[]
 * Optimized for small, JSON-capable models (e.g., gpt-4o-mini).
 */

import eventItemSchema from '../../schemas/eventItem.schema.json';

export type ParsePromptOptions = {
  courseCode?: string;
  termStart?: string; // ISO date string, e.g., 2025-08-26
  termEnd?: string;   // ISO date string
  timezone?: string;  // IANA tz, e.g., "America/Los_Angeles"
  model?: string;     // default provided by env/client
};

// Build the response schema (object with events array of EventItem)
const eventItemsObjectSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['events'],
  properties: {
    events: {
      type: 'array',
      items: eventItemSchema,
    },
  },
} as const;

const SYSTEM_PROMPT = (
  opts: Required<Pick<ParsePromptOptions, 'timezone'>>
) => `You are a syllabus-to-calendar JSON parser.
Return ONLY strict JSON matching the provided schema. No extra text.

Goal: Extract a concise array of course events (assignments, quizzes, midterms, finals, labs, lectures, other important dates) from the input syllabus text.

Rules:
- Output must be a JSON object of the form { "events": [EventItemDTO, ...] } and match the JSON Schema.
- Do not include explanations, comments, markdown, or keys not in the schema.
- ALWAYS use full ISO8601 datetime format with local offset and milliseconds: YYYY-MM-DDTHH:MM:SS.000±HH:MM (e.g., "2025-09-12T23:59:00.000-05:00"). Never use a trailing "Z".
- If no explicit time given, use 00:00:00.000 (with local offset) for the start time and set allDay=true.
- If end time/date is not known, omit the end field entirely.
- id: short slug from title, lowercase, alnum+dashes only, unique per output (add numeric suffix if needed).
- courseCode: Extract the precise course code from the syllabus (e.g., "ENGG*3390", "CS 101"); never invent or omit it.
- type: use one of ASSIGNMENT, QUIZ, MIDTERM, FINAL, LAB, LECTURE, OTHER.
- title: concise, human-friendly, derived from the line/block (e.g., "Assignment 1", "Midterm"), not a full sentence.
- Lectures are critical: never skip them. If the syllabus describes a repeating lecture schedule (e.g., "TuTh 10:00–11:20 from Sept 4 to Dec 12"), emit a single event with "recurrenceRule" in RRULE format (Example: "FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-12-12"). Start/end must correspond to the first occurrence (based on termStart if provided).
- If recurrence information is incomplete, still output individual lecture events without a recurrenceRule.
- confidence: 0..1 indicating extraction confidence.
- Notes may include short details like weight or submission method; max 200 chars.
- Convert relative references like "Week 5 Friday" using the provided termStart if present. Week 1 starts on the week of termStart.
- Ignore office hours, grading policies, and generic info not tied to a date.

`;

// Few-shot examples to steer formatting and mapping.
const FEWSHOT = [
  {
    role: 'user' as const,
    content:
      'Example 1 — Extract explicit date/time to JSON array.\n' +
      'Context: courseCode=CS101, timezone=America/Los_Angeles.\n' +
      'Text:\n' +
      'Assignment 1 due Sept 12, 2025 at 11:59 PM PST. Submit on Canvas. Weight: 10%.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'assignment-1',
          courseCode: 'CS101',
          type: 'ASSIGNMENT',
          title: 'Assignment 1',
          start: '2025-09-12T23:59:00.000-07:00',
          allDay: false,
          notes: 'Submit on Canvas. Weight: 10%.',
          confidence: 0.95
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 2 — Relative week reference.\n' +
      'Context: courseCode=HIST200, timezone=America/New_York, termStart=2025-08-26.\n' +
      'Text:\n' +
      'Week 5: Midterm on Friday during lecture.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'midterm',
          courseCode: 'HIST200',
          type: 'MIDTERM',
          title: 'Midterm',
          // Week mapping example only; model determines exact date based on termStart
          start: '2025-09-26T00:00:00.000-04:00',
          allDay: true,
          notes: 'During lecture.',
          confidence: 0.7
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 3 — Lecture recurrence.\n' +
      'Context: courseCode=CS2750, timezone=America/Toronto, termStart=2025-09-04, termEnd=2025-12-12.\n' +
      'Text:\n' +
      'Lecture: TuTh 10:00-11:20 AM in Room 204 from Sept 4 through Dec 12.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'lecture-series',
          courseCode: 'CS2750',
          type: 'LECTURE',
          title: 'Lecture',
          start: '2025-09-04T10:00:00.000-04:00',
          end: '2025-09-04T11:20:00.000-04:00',
          allDay: false,
          location: 'Room 204',
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-12-12',
          confidence: 0.9
        }
      ]
    })
  }
];

export function buildParseSyllabusRequest(
  text: string,
  options: ParsePromptOptions = {}
) {
  const {
    courseCode,
    termStart,
    termEnd,
    timezone = 'UTC',
    model = 'gpt-4o-mini'
  } = options;

  const system = SYSTEM_PROMPT({ timezone });

  const contextBlock = JSON.stringify(
    {
      courseCode,
      termStart,
      termEnd,
      timezone
    },
    null,
    0
  );

  const userContent = `Context: ${contextBlock}\nSyllabus Text:\n${text}`;

  const messages = [
    { role: 'system' as const, content: system },
    ...FEWSHOT,
    { role: 'user' as const, content: userContent }
  ];

  // OpenAI responses with JSON schema enforcement
  return {
    model,
    temperature: 0.1, // Low temperature for consistent structured output
    messages,
    response_format: {
      type: 'json_schema' as const,
      json_schema: {
        name: 'parse_syllabus_events',
        schema: eventItemsObjectSchema,
        strict: false
      }
    }
  };
}
