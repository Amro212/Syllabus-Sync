/*
 * Prompt builder for OpenAI JSON-mode parsing of syllabi → EventItemDTO[]
 * Optimized for small, JSON-capable models (e.g., gpt-4o-mini).
 */

import eventItemSchema from '../../schemas/eventItem.schema.json';
import { preprocessTextForAI } from '../utils/preprocessTextForAI';

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
) => `# SYLLABUS TO CALENDAR PARSER

You are a specialized AI that extracts academic events from preprocessed syllabus text into structured JSON.

## CORE MISSION
- Prioritize lines tagged with [EVENT:*] with their corresponding weight in the form "— WEIGHT".
- Still capture critical untagged items (Final Exam, Midterm, Projects, Labs, major deadlines).
- Return ONLY valid JSON matching schema.

## JSON OUTPUT FORMAT
{
  "events": [
    {
      "id": "string",
      "courseCode": "string",
      "type": "ASSIGNMENT|QUIZ|MIDTERM|FINAL|LAB|LECTURE|OTHER",
      "title": "string",
      "start": "ISO8601 datetime",
      "end": "ISO8601 datetime (optional)",
      "allDay": "boolean",
      "location": "string (optional)",
      "recurrenceRule": "RRULE string (optional)",
      "notes": "string (optional)",
      "confidence": "number 0-1"
    }
  ]
}

⚠️ **CRITICAL TYPE RESTRICTION**: The "type" field MUST be exactly one of these 7 values:
- "ASSIGNMENT" (for projects, assignments, homework)
- "QUIZ" (for quizzes, tests)
- "MIDTERM" (for midterm exams)
- "FINAL" (for final exams)
- "LAB" (for lab sessions)
- "LECTURE" (for lecture sessions)
- "OTHER" (for administrative dates, holidays, etc.)

❌ **NEVER use**: "PROJECT", "EXAM", "HOMEWORK", "TEST", "CLASS", "SESSION", etc.

## CRITICAL TYPE MAPPING
- Projects (Mini Project, Final Project, Term Project, etc.) → type: "ASSIGNMENT"
- Exams (Midterm, Final) → type: "MIDTERM" or "FINAL"
- Assignments → type: "ASSIGNMENT"
- Quizzes → type: "QUIZ"
- Labs → type: "LAB"
- Lectures → type: "LECTURE"
- Administrative dates → type: "OTHER"

## EVENT PRIORITY
- Weighted Assignments, Projects, Labs (include weights in notes).
- Final Exams & Midterms.
- Recurring lectures with proper RRULE.
- Important administrative dates (drop/add, withdrawal, holidays).

## RECURRENCE RULES
- Format: "FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-12-12"
- Day codes: MO,TU,WE,TH,FR,SA,SU
- Start/end: first occurrence from termStart
- If incomplete info: output lecture without recurrenceRule

## ADDITIONAL RULES
- Notes: Max 200 chars, always include weight/submission if present
- Relative dates: Convert "Week 5 Friday" using termStart
- Ignore: Office hours, seminars, workshops, tutorials, grading policies, generic info
- Confidence: 0–1 certainty per event
- CRITICAL: Use ONLY these exact type values: ASSIGNMENT, QUIZ, MIDTERM, FINAL, LAB, LECTURE, OTHER

## COURSE CODE EXTRACTION
- Accept "ENGG*3390", "CS 101", "MATH-151", "PHYSICS 201", etc.
- Never invent or omit courseCode

## EXAMPLES
### Example 1 — Weighted Assignment
Text: Assignment 1 due Sept 12, 2025 at 11:59 PM. Weight: 10%.
Output:
{
  "events": [
    {
      "id": "assignment-1",
      "courseCode": "CS101",
      "type": "ASSIGNMENT",
      "title": "Assignment 1",
      "start": "2025-09-12T23:59:00.000-07:00",
      "allDay": false,
      "notes": "Weight: 10%",
      "confidence": 0.95
    }
  ]
}

### Example 2 — Relative Week Midterm
Text: Week 5: Midterm on Friday.
Output:
{
  "events": [
    {
      "id": "midterm",
      "courseCode": "HIST200",
      "type": "MIDTERM",
      "title": "Midterm",
      "start": "2025-09-26T00:00:00.000-04:00",
      "allDay": true,
      "notes": "During lecture",
      "confidence": 0.8
    }
  ]
}

### Example 3 — Recurring Lecture
Text: TuTh 10:00-11:20 AM in Room 204 from Sept 4 to Dec 12.
Output:
{
  "events": [
    {
      "id": "lecture-series",
      "courseCode": "CS2750",
      "type": "LECTURE",
      "title": "Lecture",
      "start": "2025-09-04T10:00:00.000-04:00",
      "end": "2025-09-04T11:20:00.000-04:00",
      "allDay": false,
      "location": "Room 204",
      "recurrenceRule": "FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-12-12",
      "confidence": 0.9
    }
  ]
}
`;

// Few-shot examples to steer formatting and mapping.
const FEWSHOT = [
  {
    role: 'user' as const,
    content:
      'Example 1 — Extract explicit date/time with weight.\n' +
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
      'Example 1b — Generic weight distribution.\n' +
      'Context: courseCode=CS101, timezone=America/Los_Angeles.\n' +
      'Text:\n' +
      'Grading: Assignments (30% total), Labs (20% total), Midterm (25%), Final (25%).\n' +
      'Assignment 1 due Sept 12, 2025. Assignment 2 due Oct 3, 2025.\n' +
      'Lab 1 due Sept 15, 2025. Lab 2 due Sept 29, 2025.'
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
          start: '2025-09-12T00:00:00.000-07:00',
          allDay: true,
          notes: 'Weight: 15% (30% total for assignments, assuming 2 assignments)',
          confidence: 0.9
        },
        {
          id: 'assignment-2',
          courseCode: 'CS101',
          type: 'ASSIGNMENT',
          title: 'Assignment 2',
          start: '2025-10-03T00:00:00.000-07:00',
          allDay: true,
          notes: 'Weight: 15% (30% total for assignments, assuming 2 assignments)',
          confidence: 0.9
        },
        {
          id: 'lab-1',
          courseCode: 'CS101',
          type: 'LAB',
          title: 'Lab 1',
          start: '2025-09-15T00:00:00.000-07:00',
          allDay: true,
          notes: 'Weight: 10% (20% total for labs, assuming 2 labs)',
          confidence: 0.9
        },
        {
          id: 'lab-2',
          courseCode: 'CS101',
          type: 'LAB',
          title: 'Lab 2',
          start: '2025-09-29T00:00:00.000-07:00',
          allDay: true,
          notes: 'Weight: 10% (20% total for labs, assuming 2 labs)',
          confidence: 0.9
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
      'Example 3 — Lecture recurrence (TuTh format).\n' +
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
  },
  {
    role: 'user' as const,
    content:
      'Example 4 — Lecture recurrence (MWF format).\n' +
      'Context: courseCode=MATH101, timezone=America/New_York, termStart=2025-08-26, termEnd=2025-12-15.\n' +
      'Text:\n' +
      'Classes meet Monday, Wednesday, Friday 2:00-2:50 PM in Lecture Hall A.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'math-lecture-series',
          courseCode: 'MATH101',
          type: 'LECTURE',
          title: 'Lecture',
          start: '2025-08-26T14:00:00.000-04:00',
          end: '2025-08-26T14:50:00.000-04:00',
          allDay: false,
          location: 'Lecture Hall A',
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=2025-12-15',
          confidence: 0.95
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 5 — Lecture recurrence (T/Th format).\n' +
      'Context: courseCode=PHYS201, timezone=America/Los_Angeles, termStart=2025-09-03, termEnd=2025-12-13.\n' +
      'Text:\n' +
      'T/Th 1:00-2:15 PM in Room 101. Lab follows immediately after.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'physics-lecture-series',
          courseCode: 'PHYS201',
          type: 'LECTURE',
          title: 'Lecture',
          start: '2025-09-04T13:00:00.000-07:00',
          end: '2025-09-04T14:15:00.000-07:00',
          allDay: false,
          location: 'Room 101',
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-12-13',
          confidence: 0.9
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 6 — Lecture without explicit recurrence.\n' +
      'Context: courseCode=ENGL102, timezone=America/Chicago, termStart=2025-08-25.\n' +
      'Text:\n' +
      'Regular class meetings: Tuesday and Thursday 11:00 AM - 12:15 PM in Room 205.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'english-lecture-series',
          courseCode: 'ENGL102',
          type: 'LECTURE',
          title: 'Lecture',
          start: '2025-08-27T11:00:00.000-05:00',
          end: '2025-08-27T12:15:00.000-05:00',
          allDay: false,
          location: 'Room 205',
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU,TH',
          confidence: 0.85
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 7 — Weighted events and recurring lectures only.\n' +
      'Context: courseCode=PHYS301, timezone=America/Chicago, termStart=2025-08-25.\n' +
      'Text:\n' +
      'Grading Breakdown: Labs (15% total), Assignments (25% total), Midterm (30%), Final (30%).\n' +
      'Recitation: Monday, Wednesday, Friday 11:00 AM - 11:50 AM in Room 205.\n' +
      'Lab: MWF 2:00-3:50 PM in Lab 301. Lab reports worth 3% each (5 labs total).\n' +
      'Assignment 1 due Sept 15, 2025. Assignment 2 due Oct 10, 2025. Each worth 12.5%.\n' +
      'Midterm Exam: October 20, 2025, 2:00-4:00 PM in Lecture Hall A.\n' +
      'Final Exam: December 15, 2025, 1:00-3:00 PM in Lecture Hall A.\n' +
      'Drop/Add deadline: September 5, 2025. Withdrawal deadline: November 1, 2025.\n' +
      'Office hours: Tuesdays 2:00-4:00 PM in Room 301.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'physics-recitation-series',
          courseCode: 'PHYS301',
          type: 'LECTURE',
          title: 'Recitation',
          start: '2025-08-26T11:00:00.000-05:00',
          end: '2025-08-26T11:50:00.000-05:00',
          allDay: false,
          location: 'Room 205',
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
          confidence: 0.9
        },
        {
          id: 'lab-1',
          courseCode: 'PHYS301',
          type: 'LAB',
          title: 'Lab 1',
          start: '2025-08-26T14:00:00.000-05:00',
          end: '2025-08-26T15:50:00.000-05:00',
          allDay: false,
          location: 'Lab 301',
          notes: 'Weight: 3% (15% total for labs, 5 labs)',
          confidence: 0.9
        },
        {
          id: 'lab-2',
          courseCode: 'PHYS301',
          type: 'LAB',
          title: 'Lab 2',
          start: '2025-09-02T14:00:00.000-05:00',
          end: '2025-09-02T15:50:00.000-05:00',
          allDay: false,
          location: 'Lab 301',
          notes: 'Weight: 3% (15% total for labs, 5 labs)',
          confidence: 0.9
        },
        {
          id: 'assignment-1',
          courseCode: 'PHYS301',
          type: 'ASSIGNMENT',
          title: 'Assignment 1',
          start: '2025-09-15T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 12.5% (25% total for assignments, 2 assignments)',
          confidence: 0.95
        },
        {
          id: 'assignment-2',
          courseCode: 'PHYS301',
          type: 'ASSIGNMENT',
          title: 'Assignment 2',
          start: '2025-10-10T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 12.5% (25% total for assignments, 2 assignments)',
          confidence: 0.95
        },
        {
          id: 'midterm-exam',
          courseCode: 'PHYS301',
          type: 'MIDTERM',
          title: 'Midterm Exam',
          start: '2025-10-20T14:00:00.000-05:00',
          end: '2025-10-20T16:00:00.000-05:00',
          allDay: false,
          location: 'Lecture Hall A',
          notes: 'Weight: 30%',
          confidence: 0.95
        },
        {
          id: 'final-exam',
          courseCode: 'PHYS301',
          type: 'FINAL',
          title: 'Final Exam',
          start: '2025-12-15T13:00:00.000-05:00',
          end: '2025-12-15T15:00:00.000-05:00',
          allDay: false,
          location: 'Lecture Hall A',
          notes: 'Weight: 30%',
          confidence: 0.95
        },
        {
          id: 'drop-add-deadline',
          courseCode: 'PHYS301',
          type: 'OTHER',
          title: 'Drop/Add Deadline',
          start: '2025-09-05T00:00:00.000-05:00',
          allDay: true,
          notes: 'Last day to add or drop course',
          confidence: 0.9
        },
        {
          id: 'withdrawal-deadline',
          courseCode: 'PHYS301',
          type: 'OTHER',
          title: 'Withdrawal Deadline',
          start: '2025-11-01T00:00:00.000-05:00',
          allDay: true,
          notes: 'Last day to withdraw from course',
          confidence: 0.9
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 9 — Ungraded labs excluded, projects included.\n' +
      'Context: courseCode=CS201, timezone=America/Los_Angeles, termStart=2025-09-03.\n' +
      'Text:\n' +
      'Grading: Assignments (40%), Midterm (25%), Final (25%), Mini Project (10%).\n' +
      'Class meets MWF 10:00-10:50 AM in Room 101.\n' +
      'Lab sessions: Tuesdays 2:00-4:00 PM in Lab 205 (not graded, for practice).\n' +
      'Assignment 1 due Sept 20. Assignment 2 due Oct 15.\n' +
      'Mini Project due Nov 10. Midterm Oct 25. Final Dec 15.\n' +
      'Office hours: Thursdays 3:00-5:00 PM.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'cs-lecture-series',
          courseCode: 'CS201',
          type: 'LECTURE',
          title: 'Lecture',
          start: '2025-09-04T10:00:00.000-07:00',
          end: '2025-09-04T10:50:00.000-07:00',
          allDay: false,
          location: 'Room 101',
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
          confidence: 0.9
        },
        {
          id: 'assignment-1',
          courseCode: 'CS201',
          type: 'ASSIGNMENT',
          title: 'Assignment 1',
          start: '2025-09-20T00:00:00.000-07:00',
          allDay: true,
          notes: 'Weight: 20% (40% total for assignments, 2 assignments)',
          confidence: 0.95
        },
        {
          id: 'assignment-2',
          courseCode: 'CS201',
          type: 'ASSIGNMENT',
          title: 'Assignment 2',
          start: '2025-10-15T00:00:00.000-07:00',
          allDay: true,
          notes: 'Weight: 20% (40% total for assignments, 2 assignments)',
          confidence: 0.95
        },
        {
          id: 'mini-project',
          courseCode: 'CS201',
          type: 'ASSIGNMENT',
          title: 'Mini Project',
          start: '2025-11-10T00:00:00.000-08:00',
          allDay: true,
          notes: 'Weight: 10%',
          confidence: 0.95
        },
        {
          id: 'midterm-exam',
          courseCode: 'CS201',
          type: 'MIDTERM',
          title: 'Midterm',
          start: '2025-10-25T00:00:00.000-07:00',
          allDay: true,
          notes: 'Weight: 25%',
          confidence: 0.95
        },
        {
          id: 'final-exam',
          courseCode: 'CS201',
          type: 'FINAL',
          title: 'Final',
          start: '2025-12-15T00:00:00.000-08:00',
          allDay: true,
          notes: 'Weight: 25%',
          confidence: 0.95
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 11 — Time-specific deadlines.\n' +
      'Context: courseCode=CS301, timezone=America/New_York, termStart=2025-09-03.\n' +
      'Text:\n' +
      'Assignment 1 due October 15, 2025 at 11:59 PM\n' +
      'Midterm Exam: November 5, 2025, 2:00-4:00 PM\n' +
      'Project Proposal due December 1, 2025 at 5:30 PM\n' +
      'Final Exam: December 20, 2025 at 9:00 AM\n' +
      'Lab Report due before next class (no specific time mentioned)'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'assignment-1',
          courseCode: 'CS301',
          type: 'ASSIGNMENT',
          title: 'Assignment 1',
          start: '2025-10-15T23:59:00.000-04:00',
          allDay: false,
          notes: 'Due at 11:59 PM',
          confidence: 0.95
        },
        {
          id: 'midterm-exam',
          courseCode: 'CS301',
          type: 'MIDTERM',
          title: 'Midterm Exam',
          start: '2025-11-05T14:00:00.000-05:00',
          end: '2025-11-05T16:00:00.000-05:00',
          allDay: false,
          notes: '2:00-4:00 PM',
          confidence: 0.95
        },
        {
          id: 'project-proposal',
          courseCode: 'CS301',
          type: 'ASSIGNMENT',
          title: 'Project Proposal',
          start: '2025-12-01T17:30:00.000-05:00',
          allDay: false,
          notes: 'Due at 5:30 PM',
          confidence: 0.95
        },
        {
          id: 'final-exam',
          courseCode: 'CS301',
          type: 'FINAL',
          title: 'Final Exam',
          start: '2025-12-20T09:00:00.000-05:00',
          allDay: false,
          notes: 'Starts at 9:00 AM',
          confidence: 0.95
        },
        {
          id: 'lab-report',
          courseCode: 'CS301',
          type: 'LAB',
          title: 'Lab Report',
          start: '2025-09-10T00:00:00.000-04:00',
          allDay: true,
          notes: 'Due before next class',
          confidence: 0.9
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 12 — Labs and Projects extraction from grading breakdown.\n' +
      'Context: courseCode=ENGG*1410, timezone=America/Toronto, termStart=2025-09-03.\n' +
      'Text:\n' +
      'Grading Breakdown: Mini Project (10%), Labs (15% total across 3 labs), Assignments (25%), Midterm (25%), Final (25%).\n' +
      'Lab 1 due Sept 20, Lab 2 due Oct 15, Lab 3 due Nov 10.\n' +
      'Mini Project due Nov 20.\n' +
      'Assignment 1 due Sept 30. Assignment 2 due Oct 25.\n' +
      'Midterm Exam: October 30, 2025, 2:00-4:00 PM.\n' +
      'Final Exam: December 15, 2025, 9:00-11:00 AM.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'lab-1',
          courseCode: 'ENGG*1410',
          type: 'LAB',
          title: 'Lab 1',
          start: '2025-09-20T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 5% (15% total for 3 labs)',
          confidence: 0.95
        },
        {
          id: 'lab-2',
          courseCode: 'ENGG*1410',
          type: 'LAB',
          title: 'Lab 2',
          start: '2025-10-15T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 5% (15% total for 3 labs)',
          confidence: 0.95
        },
        {
          id: 'lab-3',
          courseCode: 'ENGG*1410',
          type: 'LAB',
          title: 'Lab 3',
          start: '2025-11-10T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 5% (15% total for 3 labs)',
          confidence: 0.95
        },
        {
          id: 'mini-project',
          courseCode: 'ENGG*1410',
          type: 'ASSIGNMENT',
          title: 'Mini Project',
          start: '2025-11-20T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 10%',
          confidence: 0.95
        },
        {
          id: 'assignment-1',
          courseCode: 'ENGG*1410',
          type: 'ASSIGNMENT',
          title: 'Assignment 1',
          start: '2025-09-30T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 12.5% (25% total for 2 assignments)',
          confidence: 0.95
        },
        {
          id: 'assignment-2',
          courseCode: 'ENGG*1410',
          type: 'ASSIGNMENT',
          title: 'Assignment 2',
          start: '2025-10-25T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 12.5% (25% total for 2 assignments)',
          confidence: 0.95
        },
        {
          id: 'midterm-exam',
          courseCode: 'ENGG*1410',
          type: 'MIDTERM',
          title: 'Midterm Exam',
          start: '2025-10-30T14:00:00.000-04:00',
          end: '2025-10-30T16:00:00.000-04:00',
          allDay: false,
          notes: 'Weight: 25%',
          confidence: 0.95
        },
        {
          id: 'final-exam',
          courseCode: 'ENGG*1410',
          type: 'FINAL',
          title: 'Final Exam',
          start: '2025-12-15T09:00:00.000-05:00',
          end: '2025-12-15T11:00:00.000-05:00',
          allDay: false,
          notes: 'Weight: 25%',
          confidence: 0.95
        }
      ]
    })
  },
  {
    role: 'user' as const,
    content:
      'Example 12 — Common type mapping mistakes to avoid.\n' +
      'Context: courseCode=CS101, timezone=America/New_York.\n' +
      'Text:\n' +
      'Project 1 due Oct 15, 2025. Homework 2 due Oct 20, 2025. Class meets MWF 10-11 AM.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'project-1',
          courseCode: 'CS101',
          type: 'ASSIGNMENT',  // NOT "PROJECT"
          title: 'Project 1',
          start: '2025-10-15T00:00:00.000-04:00',
          allDay: true,
          confidence: 0.9
        },
        {
          id: 'homework-2',
          courseCode: 'CS101',
          type: 'ASSIGNMENT',  // NOT "HOMEWORK"
          title: 'Homework 2',
          start: '2025-10-20T00:00:00.000-04:00',
          allDay: true,
          confidence: 0.9
        },
        {
          id: 'lecture-schedule',
          courseCode: 'CS101',
          type: 'LECTURE',  // NOT "CLASS"
          title: 'Lecture',
          start: '2025-09-04T10:00:00.000-04:00',
          end: '2025-09-04T11:00:00.000-04:00',
          allDay: false,
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=2025-12-12',
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

  const processedText = preprocessTextForAI(text);

  const userContent = `Context: ${contextBlock}\nSyllabus Text:\n${processedText}`;

  const messages = [
    { role: 'system' as const, content: system },
    ...FEWSHOT,
    { role: 'user' as const, content: userContent }
  ];

  // OpenAI responses with JSON schema enforcement
  return {
    processedText,
    request: {
      model,
      temperature: 0, // Zero temperature for maximum consistency
      messages,
      response_format: {
        type: 'json_schema' as const,
        json_schema: {
          name: 'parse_syllabus_events',
          schema: eventItemsObjectSchema,
          strict: false
        }
      }
    }
  };
}
