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
) => `# SYLLABUS TO CALENDAR PARSER

You are a specialized AI that extracts academic events from syllabus text and converts them to structured JSON calendar events.

## CORE MISSION
Extract ONLY weighted academic events, important dates, and recurring lecture times from syllabus text.
Return ONLY strict JSON matching the provided schema. No extra text.

---

## EVENT EXTRACTION HIERARCHY

### MUST INCLUDE (never skip)
- **FINAL EXAMS and MIDTERMS**: Maximum accuracy required, include even if details are missing
- **All weighted Assignments and Projects**: Including "Mini Project", "Final Project", "Term Project", "Group Project", "Research Project", "Capstone Project"
- **All weighted Labs**: Individual lab events with specific due dates and distributed weights

### SECONDARY
- **Recurring lectures**: Class meeting times (always recurring, never individual instances)
- **Administrative dates**: "Important Dates" section, Drop/add deadlines, withdrawal deadlines, holidays, breaks

### IGNORE
- Office hours, optional labs, seminars, workshops, tutorials
- Discussion sections (unless they're the main lecture)
- Generic info not tied to specific dates

---

## JSON OUTPUT FORMAT

### Required Structure
\`\`\`json
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
\`\`\`

### Field Requirements
- **id**: Short slug from title, lowercase, alnum+dashes only, unique
- **courseCode**: Extract exactly as written in syllabus (e.g., "ENGG*3390", "CS 101", "MATH-151")
- **type**: Use exact enum values: ASSIGNMENT, QUIZ, MIDTERM, FINAL, LAB, LECTURE, OTHER
- **title**: Concise, human-friendly (e.g., "Assignment 1", "Midterm", "Mini Project")
- **confidence**: 0-1 indicating extraction confidence

---

## DATETIME HANDLING

### ISO8601 Format
- **Required format**: \`YYYY-MM-DDTHH:MM:SS.000±HH:MM\`
- **Example**: \`"2025-09-12T23:59:00.000-05:00"\`
- **Timezone**: Use provided timezone offset, never use trailing "Z"
- **Default**: If timezone is "UTC" or missing, use "+00:00"

### Time Extraction Rules
- **Explicit times**: "Due: October 10, 2025 at 11:59 PM" → \`23:59:00.000\`
- **No time given**: Use \`00:00:00.000\` and set \`allDay: true\`
- **End time unknown**: Omit the \`end\` field entirely
- **Relative references**: "Week 5 Friday" → calculate using termStart

---

## WEIGHT EXTRACTION

### Weight Patterns to Find
- "worth 10%", "10 points", "10% of grade"
- "weighted 15%", "counts for 20%", "20% of total grade"

### Weight Handling
- **Always include** weight info in notes field when available
- **Generic weights**: Distribute total among individual events
- **Projects**: Be especially vigilant for project weights - mark as ASSIGNMENT type
- **Labs**: Include weight and mark as LAB type
- **Lectures**: Do NOT include weight (not graded)

### Weight Format in Notes
- "Weight: 10%", "Worth 15 points", "7% of grade"
- For distributed weights: "Weight: 5% (25% total for 5 labs)"

---

## LECTURE EXTRACTION

### What to Look For
- **Sections**: "Schedule", "Class Times", "Meeting Times", "Lecture Schedule"
- **Patterns**: "Classes meet TuTh 10:00-11:20 AM", "T/Th 1:00-2:15 PM"
- **Day codes**: "TuTh", "TTh", "MWF", "MW", "TuesThurs", "MonWedFri"

### Recurrence Rules
- **RRULE format**: \`"FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-12-12"\`
- **Day codes**: MO,TU,WE,TH,FR,SA,SU
- **Start/end times**: Correspond to first occurrence (based on termStart)
- **Incomplete info**: Still output without recurrenceRule

### Section Filtering
- **ONLY report LECTURE sections**, not lab sections
- **IGNORE**: Seminars, workshops, discussion sections

---

## ADDITIONAL RULES

### General Guidelines
- **Notes**: Max 200 chars, include weight or submission method
- **Relative dates**: Convert "Week 5 Friday" using termStart
- **Ignore**: Office hours, grading policies, generic info
- **Confidence**: 0-1 scale based on extraction certainty

### Course Code Extraction
- **Traditional**: "ENGG*3390", "CS 101", "MATH-151"
- **Full names**: "PHYSICS 201", "MATHEMATICS 101"
- **Department codes**: "DSB424", "ENG 3390", "CIS 200"
- **Never invent or omit** the course code

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
      'Example 8 — Projects and weighted events only.\n' +
      'Context: courseCode=ENGL102, timezone=America/New_York, termStart=2025-08-26.\n' +
      'Text:\n' +
      'Course Requirements: Participation (10%), Reading Responses (20% - 8 responses), Essays (40% - 3 essays), Final Project (30%).\n' +
      'Reading Response 1 due Week 2 (Sept 5). Reading Response 2 due Week 4 (Sept 19).\n' +
      'Essay 1 due October 3. Essay 2 due November 7. Essay 3 due December 5.\n' +
      'Final Project proposal due November 15. Final Project due December 12.\n' +
      'Class meets T/Th 2:00-3:15 PM. No class on Thanksgiving week (Nov 25-29).\n' +
      'Late work policy: 10% deduction per day, no work accepted after 3 days late.'
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
          start: '2025-08-27T14:00:00.000-04:00',
          end: '2025-08-27T15:15:00.000-04:00',
          allDay: false,
          recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-12-12',
          notes: 'No class Thanksgiving week (Nov 25-29)',
          confidence: 0.9
        },
        {
          id: 'reading-response-1',
          courseCode: 'ENGL102',
          type: 'ASSIGNMENT',
          title: 'Reading Response 1',
          start: '2025-09-05T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 2.5% (20% total for 8 responses)',
          confidence: 0.9
        },
        {
          id: 'reading-response-2',
          courseCode: 'ENGL102',
          type: 'ASSIGNMENT',
          title: 'Reading Response 2',
          start: '2025-09-19T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 2.5% (20% total for 8 responses)',
          confidence: 0.9
        },
        {
          id: 'essay-1',
          courseCode: 'ENGL102',
          type: 'ASSIGNMENT',
          title: 'Essay 1',
          start: '2025-10-03T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 13.3% (40% total for 3 essays)',
          confidence: 0.95
        },
        {
          id: 'essay-2',
          courseCode: 'ENGL102',
          type: 'ASSIGNMENT',
          title: 'Essay 2',
          start: '2025-11-07T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 13.3% (40% total for 3 essays)',
          confidence: 0.95
        },
        {
          id: 'essay-3',
          courseCode: 'ENGL102',
          type: 'ASSIGNMENT',
          title: 'Essay 3',
          start: '2025-12-05T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 13.3% (40% total for 3 essays)',
          confidence: 0.95
        },
        {
          id: 'final-project-proposal',
          courseCode: 'ENGL102',
          type: 'ASSIGNMENT',
          title: 'Final Project Proposal',
          start: '2025-11-15T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 15% (30% total for final project)',
          confidence: 0.9
        },
        {
          id: 'final-project',
          courseCode: 'ENGL102',
          type: 'ASSIGNMENT',
          title: 'Final Project',
          start: '2025-12-12T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 15% (30% total for final project)',
          confidence: 0.95
        },
        {
          id: 'thanksgiving-break',
          courseCode: 'ENGL102',
          type: 'OTHER',
          title: 'Thanksgiving Break',
          start: '2025-11-25T00:00:00.000-05:00',
          end: '2025-11-29T23:59:59.000-05:00',
          allDay: true,
          notes: 'No class this week',
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
      'Example 10 — Labs with explicit schedule and weights.\n' +
      'Context: courseCode=ENGG*3390, timezone=America/Toronto, termStart=2025-09-03.\n' +
      'Text:\n' +
      'Marking Schemes: Labs (25%), Midterm Exam (30%), Final Exam (45%).\n' +
      'Lab Schedule:\n' +
      'Mon, Sep 8 - Fri, Sep 12: Safety training, group formation and lab kit assignment\n' +
      'Mon, Sep 15 - Fri, Sep 19: Lab 1: Digital Signal Processing\n' +
      'Mon, Sep 22 - Fri, Sep 26: Lab 1: Follow-up Hour(s)\n' +
      'Mon, Sep 29 - Fri, Oct 3: Lab 2: Convolution\n' +
      'Mon, Oct 6 - Fri, Oct 10: Lab 2: Follow-up Hour(s)\n' +
      'Mon, Oct 20 - Fri, Oct 24: Lab 3: Filtering and Frequency Response\n' +
      'Mon, Oct 27 - Fri, Oct 31: Lab 3: Follow-up Hour(s)\n' +
      'Mon, Nov 3 - Fri, Nov 7: Lab 4: FIR and IIR Filter Design\n' +
      'Mon, Nov 10 - Fri, Nov 14: Lab 4: Follow-up Hour(s)\n' +
      'Mon, Nov 17 - Fri, Nov 21: Lab 5: Frequency Domain Filtering\n' +
      'Mon, Nov 24 - Fri, Nov 28: Lab 5: Follow-up Hour(s)\n' +
      'Lab Reports: Five labs will be held. Reports for labs 1-4 are due before the start of the following lab. The report for lab 5 is due at 5:30 pm 7 days after the lab.'
  },
  {
    role: 'assistant' as const,
    content: JSON.stringify({
      events: [
        {
          id: 'lab-1-report',
          courseCode: 'ENGG*3390',
          type: 'LAB',
          title: 'Lab 1 Report: Digital Signal Processing',
          start: '2025-09-19T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 5% (25% total for 5 labs). Due before Lab 2 starts.',
          confidence: 0.9
        },
        {
          id: 'lab-2-report',
          courseCode: 'ENGG*3390',
          type: 'LAB',
          title: 'Lab 2 Report: Convolution',
          start: '2025-10-03T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 5% (25% total for 5 labs). Due before Lab 3 starts.',
          confidence: 0.9
        },
        {
          id: 'lab-3-report',
          courseCode: 'ENGG*3390',
          type: 'LAB',
          title: 'Lab 3 Report: Filtering and Frequency Response',
          start: '2025-10-31T00:00:00.000-04:00',
          allDay: true,
          notes: 'Weight: 5% (25% total for 5 labs). Due before Lab 4 starts.',
          confidence: 0.9
        },
        {
          id: 'lab-4-report',
          courseCode: 'ENGG*3390',
          type: 'LAB',
          title: 'Lab 4 Report: FIR and IIR Filter Design',
          start: '2025-11-14T00:00:00.000-05:00',
          allDay: true,
          notes: 'Weight: 5% (25% total for 5 labs). Due before Lab 5 starts.',
          confidence: 0.9
        },
        {
          id: 'lab-5-report',
          courseCode: 'ENGG*3390',
          type: 'LAB',
          title: 'Lab 5 Report: Frequency Domain Filtering',
          start: '2025-11-28T17:30:00.000-05:00',
          allDay: false,
          notes: 'Weight: 5% (25% total for 5 labs). Due 7 days after lab at 5:30 PM.',
          confidence: 0.9
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
    model = 'gpt-5-mini'
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
  };
}
