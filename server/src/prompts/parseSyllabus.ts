/**
 * Prompt builder for OpenAI JSON-mode parsing of syllabi -> EventItemDTO[]
 *
 * Two-pass architecture:
 *   Pass 0 (deterministic): extractGradingScheme() runs regex on the raw text.
 *   Pass 1 (this file):     Builds a constrained prompt that includes the
 *                            extracted grading scheme as a structured block
 *                            so the AI only creates events for confirmed
 *                            deliverables.
 *
 * Optimised for gpt-4.1-mini.
 */

import eventItemSchema from '../../schemas/eventItem.schema.json';
import { preprocessTextForAI } from '../utils/preprocessTextForAI.js';
import {
	type GradingSchemeResult,
	formatGradingSchemeForPrompt,
} from '../utils/extractGradingScheme.js';

// -- Public types --

export interface ParsePromptOptions {
	courseCode?: string;
	termStart?: string;
	termEnd?: string;
	timezone?: string;
	model?: string;
	/** Result of the deterministic grading-scheme extractor */
	gradingScheme?: GradingSchemeResult;
}

// -- JSON-Schema wrapper for response_format --

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

// -- System prompt --

const SYSTEM_PROMPT = (
	opts: Required<Pick<ParsePromptOptions, 'timezone'>>
) => `# SYLLABUS -> CALENDAR PARSER

You extract academic events from preprocessed syllabus text into structured JSON.

## 1 -- SOURCE OF TRUTH
The user message contains a **GRADING SCHEME** block extracted from the syllabus.
- If the block lists deliverables, ONLY create assessment events (assignments, quizzes, midterms, finals, labs) for items that appear in that block.
- If the block says "Not found", be conservative: create assessment events only when you are >= 70% confident they exist.
- Lectures, admin dates, and recurring sessions are NOT in the grading scheme -- create those from schedule information.

## 2 -- HALLUCINATION RULES
- Policy / boilerplate mentions of "exam", "midterm", "final" do NOT mean those events exist. Only the grading scheme or an explicit schedule entry counts.
- Never invent or redistribute weights. Use verbatim numbers from the syllabus.
- When in doubt, **omit** the event.
- Lines tagged \`[EVENT:*]\` are hints -- verify each against the grading scheme before creating an event.

## 3 -- JSON FORMAT
\`\`\`json
{
  "events": [
    {
      "id": "string (kebab-case, unique)",
      "courseCode": "string",
      "type": "ASSIGNMENT | QUIZ | MIDTERM | FINAL | LAB | LECTURE | OTHER",
      "title": "string",
      "start": "ISO 8601 datetime | null",
      "needsDate": true,
      "end": "ISO 8601 (optional)",
      "allDay": true,
      "location": "string (optional)",
      "recurrenceRule": "RRULE string (optional)",
      "notes": "string <= 200 chars (optional, include weight if present)",
      "confidence": 0.85,
      "dateSource": "exact syllabus quote or null"
    }
  ]
}
\`\`\`

### Type restriction
ASSIGNMENT | QUIZ | MIDTERM | FINAL | LAB | LECTURE | OTHER -- no other values.
Map: projects/homework -> ASSIGNMENT, exams -> MIDTERM or FINAL.

## 4 -- RECURRENCE (SPLIT MULTI-DAY)
Multi-day patterns MUST be split into separate single-day events:
- "TuTh 2:30 PM" -> Lecture (Tue) + Lecture (Thu), each with its own RRULE (BYDAY=TU / BYDAY=TH).
- Day codes: MO, TU, WE, TH, FR, SA, SU.

## 5 -- MULTIPLE SECTIONS
Create one event per section per day. Extract each section's exact time.

## 6 -- LAB RULES
- Lab **sessions** (recurring attendance) -> one recurring event per section.
- Lab **deliverables** (graded work with numbers like Lab 1, Lab 2) -> one event per deliverable, no recurrence.

## 7 -- MISSING DATES (needsDate)
When a deliverable has NO date, week number, or deadline:
- Set start: null, needsDate: true, dateSource: null.
- "TBD", "to be announced", "during midterm period" count as missing.

## 8 -- dateSource (EVIDENCE)
For every event cite the exact syllabus text used to determine the date (<= 100 chars). If inferred, cite the original text. If none -> null.

## 9 -- IGNORE
Office hours, seminars, tutorials, grading policies, generic info.

## 10 -- FINAL REMINDER
Re-read before outputting:
- Every assessment event must appear in the GRADING SCHEME block (or you must be >= 70% confident without one).
- Every event must have dateSource or needsDate: true + dateSource: null.
- Omit rather than hallucinate.

Current timezone: ${opts.timezone}
`;

// -- Few-shot examples (7 clean, consistent, with a negative case) --

const FEWSHOT: Array<{ role: 'user' | 'assistant'; content: string }> = [
	{ role: 'user' as const, content: `GRADING SCHEME:
- Assignments: 30%
- Final Exam: 30%
- Participation: 40%

Context: {"courseCode":"CS101","timezone":"America/New_York","termStart":"2025-09-02","termEnd":"2025-12-15"}
Syllabus Text:
Assignment 1 due Sept 12, 2025 at 11:59 PM. Submit on Canvas. Weight: 15%.
Assignment 2 due Oct 3, 2025. Weight: 15%.
Final Exam: December 10, 2025 2:00-4:00 PM in Hall A.` },
	{ role: 'assistant' as const, content: `{"events": [{"id": "assignment-1", "courseCode": "CS101", "type": "ASSIGNMENT", "title": "Assignment 1", "start": "2025-09-12T23:59:00.000-04:00", "allDay": false, "notes": "Submit on Canvas. Weight: 15%.", "confidence": 0.95, "dateSource": "Assignment 1 due Sept 12, 2025 at 11:59 PM"}, {"id": "assignment-2", "courseCode": "CS101", "type": "ASSIGNMENT", "title": "Assignment 2", "start": "2025-10-03T00:00:00.000-04:00", "allDay": true, "notes": "Weight: 15%.", "confidence": 0.95, "dateSource": "Assignment 2 due Oct 3, 2025"}, {"id": "final-exam", "courseCode": "CS101", "type": "FINAL", "title": "Final Exam", "start": "2025-12-10T14:00:00.000-05:00", "end": "2025-12-10T16:00:00.000-05:00", "allDay": false, "location": "Hall A", "notes": "Weight: 30%.", "confidence": 0.95, "dateSource": "Final Exam: December 10, 2025 2:00-4:00 PM in Hall A"}]}` },
	{ role: 'user' as const, content: `GRADING SCHEME:
Not found

Context: {"courseCode":"MATH101","timezone":"America/New_York","termStart":"2025-08-25","termEnd":"2025-12-15"}
Syllabus Text:
Classes meet Monday, Wednesday, Friday 2:00-2:50 PM in Lecture Hall A.` },
	{ role: 'assistant' as const, content: `{"events": [{"id": "lecture-mon", "courseCode": "MATH101", "type": "LECTURE", "title": "Lecture (Mon)", "start": "2025-08-25T14:00:00.000-04:00", "end": "2025-08-25T14:50:00.000-04:00", "allDay": false, "location": "Lecture Hall A", "recurrenceRule": "FREQ=WEEKLY;BYDAY=MO;UNTIL=2025-12-15", "confidence": 0.9, "dateSource": "Monday, Wednesday, Friday 2:00-2:50 PM"}, {"id": "lecture-wed", "courseCode": "MATH101", "type": "LECTURE", "title": "Lecture (Wed)", "start": "2025-08-27T14:00:00.000-04:00", "end": "2025-08-27T14:50:00.000-04:00", "allDay": false, "location": "Lecture Hall A", "recurrenceRule": "FREQ=WEEKLY;BYDAY=WE;UNTIL=2025-12-15", "confidence": 0.9, "dateSource": "Monday, Wednesday, Friday 2:00-2:50 PM"}, {"id": "lecture-fri", "courseCode": "MATH101", "type": "LECTURE", "title": "Lecture (Fri)", "start": "2025-08-29T14:00:00.000-04:00", "end": "2025-08-29T14:50:00.000-04:00", "allDay": false, "location": "Lecture Hall A", "recurrenceRule": "FREQ=WEEKLY;BYDAY=FR;UNTIL=2025-12-15", "confidence": 0.9, "dateSource": "Monday, Wednesday, Friday 2:00-2:50 PM"}]}` },
	{ role: 'user' as const, content: `GRADING SCHEME:
- Group Project: 25%
- Essay Draft: 15%
- Final Exam: 30%
- Participation: 30%

Context: {"courseCode":"BUS301","timezone":"America/New_York","termStart":"2025-09-02"}
Syllabus Text:
Grading: Group Project (25%), Essay Draft (15%), Final Exam Dec 10 at 2:00 PM (30%), Participation (30%).
The group project and essay draft deadlines will be announced in class.` },
	{ role: 'assistant' as const, content: `{"events": [{"id": "group-project", "courseCode": "BUS301", "type": "ASSIGNMENT", "title": "Group Project", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 25%. Deadline to be announced.", "confidence": 0.3, "dateSource": null}, {"id": "essay-draft", "courseCode": "BUS301", "type": "ASSIGNMENT", "title": "Essay Draft", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 15%. Deadline to be announced.", "confidence": 0.3, "dateSource": null}, {"id": "final-exam", "courseCode": "BUS301", "type": "FINAL", "title": "Final Exam", "start": "2025-12-10T14:00:00.000-05:00", "allDay": false, "notes": "Weight: 30%.", "confidence": 0.95, "dateSource": "Final Exam Dec 10 at 2:00 PM"}]}` },
	{ role: 'user' as const, content: `GRADING SCHEME:
- Labs: 25%
- Midterm: 35%
- Final Exam: 40%

Context: {"courseCode":"ENGG*4540","timezone":"America/Toronto","termStart":"2025-01-06","termEnd":"2025-04-18"}
Syllabus Text:
Lab Schedule:
| Day | Time | Location | Section |
| Monday | 11:30 AM - 1:20 PM | RICH 2531 | 01 |
| Wednesday | 12:30 PM - 2:20 PM | RICH 2531 | 02 |

Lab Topics: Lab 1: Benchmark, Lab 2: MARS/MIPS, Lab 3: Pipelining, Lab 4: DRAM, Lab 5: Execution.
Labs worth 25% total (5% each).
Midterm: February 20, 2025 during lecture. Final Exam: April 14, 2025 9:00-11:00 AM.` },
	{ role: 'assistant' as const, content: `{"events": [{"id": "lab-session-01", "courseCode": "ENGG*4540", "type": "LAB", "title": "Lab - Section 01", "start": "2025-01-06T11:30:00.000-05:00", "end": "2025-01-06T13:20:00.000-05:00", "allDay": false, "location": "RICH 2531", "recurrenceRule": "FREQ=WEEKLY;BYDAY=MO;UNTIL=2025-04-18", "notes": "Weekly session.", "confidence": 0.9, "dateSource": "Monday | 11:30 AM - 1:20 PM | RICH 2531 | 01"}, {"id": "lab-session-02", "courseCode": "ENGG*4540", "type": "LAB", "title": "Lab - Section 02", "start": "2025-01-08T12:30:00.000-05:00", "end": "2025-01-08T14:20:00.000-05:00", "allDay": false, "location": "RICH 2531", "recurrenceRule": "FREQ=WEEKLY;BYDAY=WE;UNTIL=2025-04-18", "notes": "Weekly session.", "confidence": 0.9, "dateSource": "Wednesday | 12:30 PM - 2:20 PM | RICH 2531 | 02"}, {"id": "lab-1", "courseCode": "ENGG*4540", "type": "LAB", "title": "Lab 1", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 5%. Topic: Benchmark.", "confidence": 0.3, "dateSource": null}, {"id": "lab-2", "courseCode": "ENGG*4540", "type": "LAB", "title": "Lab 2", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 5%. Topic: MARS/MIPS.", "confidence": 0.3, "dateSource": null}, {"id": "lab-3", "courseCode": "ENGG*4540", "type": "LAB", "title": "Lab 3", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 5%. Topic: Pipelining.", "confidence": 0.3, "dateSource": null}, {"id": "lab-4", "courseCode": "ENGG*4540", "type": "LAB", "title": "Lab 4", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 5%. Topic: DRAM.", "confidence": 0.3, "dateSource": null}, {"id": "lab-5", "courseCode": "ENGG*4540", "type": "LAB", "title": "Lab 5", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 5%. Topic: Execution.", "confidence": 0.3, "dateSource": null}, {"id": "midterm", "courseCode": "ENGG*4540", "type": "MIDTERM", "title": "Midterm", "start": "2025-02-20T00:00:00.000-05:00", "allDay": true, "notes": "Weight: 35%. During lecture.", "confidence": 0.85, "dateSource": "Midterm: February 20, 2025 during lecture"}, {"id": "final-exam", "courseCode": "ENGG*4540", "type": "FINAL", "title": "Final Exam", "start": "2025-04-14T09:00:00.000-04:00", "end": "2025-04-14T11:00:00.000-04:00", "allDay": false, "notes": "Weight: 40%.", "confidence": 0.95, "dateSource": "Final Exam: April 14, 2025 9:00-11:00 AM"}]}` },
	{ role: 'user' as const, content: `GRADING SCHEME:
Not found

Context: {"courseCode":"CIS*2750","timezone":"America/Toronto","termStart":"2025-01-06","termEnd":"2025-04-18"}
Syllabus Text:
Lecture Section 01
Instructor: Dr. D. Nikitenko
Tue/Thu 4:00-5:20 pm | MACN 105

Lecture Section 02
Instructor: Dr. J. McCuaig
Tue/Thu 8:30-9:50 am | MACN 105` },
	{ role: 'assistant' as const, content: `{"events": [{"id": "lecture-s01-tue", "courseCode": "CIS*2750", "type": "LECTURE", "title": "Lecture Section 01 (Tue)", "start": "2025-01-07T16:00:00.000-05:00", "end": "2025-01-07T17:20:00.000-05:00", "allDay": false, "location": "MACN 105", "recurrenceRule": "FREQ=WEEKLY;BYDAY=TU;UNTIL=2025-04-18", "notes": "Instructor: Dr. D. Nikitenko", "confidence": 0.95, "dateSource": "Tue/Thu 4:00-5:20 pm | MACN 105"}, {"id": "lecture-s01-thu", "courseCode": "CIS*2750", "type": "LECTURE", "title": "Lecture Section 01 (Thu)", "start": "2025-01-09T16:00:00.000-05:00", "end": "2025-01-09T17:20:00.000-05:00", "allDay": false, "location": "MACN 105", "recurrenceRule": "FREQ=WEEKLY;BYDAY=TH;UNTIL=2025-04-18", "notes": "Instructor: Dr. D. Nikitenko", "confidence": 0.95, "dateSource": "Tue/Thu 4:00-5:20 pm | MACN 105"}, {"id": "lecture-s02-tue", "courseCode": "CIS*2750", "type": "LECTURE", "title": "Lecture Section 02 (Tue)", "start": "2025-01-07T08:30:00.000-05:00", "end": "2025-01-07T09:50:00.000-05:00", "allDay": false, "location": "MACN 105", "recurrenceRule": "FREQ=WEEKLY;BYDAY=TU;UNTIL=2025-04-18", "notes": "Instructor: Dr. J. McCuaig", "confidence": 0.95, "dateSource": "Tue/Thu 8:30-9:50 am | MACN 105"}, {"id": "lecture-s02-thu", "courseCode": "CIS*2750", "type": "LECTURE", "title": "Lecture Section 02 (Thu)", "start": "2025-01-09T08:30:00.000-05:00", "end": "2025-01-09T09:50:00.000-05:00", "allDay": false, "location": "MACN 105", "recurrenceRule": "FREQ=WEEKLY;BYDAY=TH;UNTIL=2025-04-18", "notes": "Instructor: Dr. J. McCuaig", "confidence": 0.95, "dateSource": "Tue/Thu 8:30-9:50 am | MACN 105"}]}` },
	{ role: 'user' as const, content: `GRADING SCHEME:
- Assignments: 40%
- Final Exam: 60%

Context: {"courseCode":"BIO4944G","timezone":"America/Toronto","termStart":"2025-01-06","termEnd":"2025-04-18"}
Syllabus Text:
[EVENT:MIDTERM] If you miss the midterm exam, you must provide documentation within 48 hours.
[EVENT:EXAM] The final exam will cover all material from the semester.
Assignment 1 due Feb 5, 2025. Assignment 2 due Mar 12, 2025.
Final Exam: April 10, 2025 9:00 AM - 12:00 PM.
Academic Integrity: Plagiarism on any exam or assignment will result in a grade of zero.` },
	{ role: 'assistant' as const, content: `{"events": [{"id": "assignment-1", "courseCode": "BIO4944G", "type": "ASSIGNMENT", "title": "Assignment 1", "start": "2025-02-05T00:00:00.000-05:00", "allDay": true, "notes": "Weight: 20% (40% total for assignments).", "confidence": 0.9, "dateSource": "Assignment 1 due Feb 5, 2025"}, {"id": "assignment-2", "courseCode": "BIO4944G", "type": "ASSIGNMENT", "title": "Assignment 2", "start": "2025-03-12T00:00:00.000-05:00", "allDay": true, "notes": "Weight: 20% (40% total for assignments).", "confidence": 0.9, "dateSource": "Assignment 2 due Mar 12, 2025"}, {"id": "final-exam", "courseCode": "BIO4944G", "type": "FINAL", "title": "Final Exam", "start": "2025-04-10T09:00:00.000-04:00", "end": "2025-04-10T12:00:00.000-04:00", "allDay": false, "notes": "Weight: 60%.", "confidence": 0.95, "dateSource": "Final Exam: April 10, 2025 9:00 AM - 12:00 PM"}]}` },
	{ role: 'user' as const, content: `GRADING SCHEME:
- Research Paper: 50%
- Presentation: 30%
- Participation: 20%

Context: {"courseCode":"HIST400","timezone":"America/Chicago","termStart":"2025-08-25","termEnd":"2025-12-12"}
Syllabus Text:
The research paper is due near the end of the semester.
Presentations will be scheduled during the last two weeks of class.` },
	{ role: 'assistant' as const, content: `{"events": [{"id": "research-paper", "courseCode": "HIST400", "type": "ASSIGNMENT", "title": "Research Paper", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 50%. Due near end of semester.", "confidence": 0.3, "dateSource": null}, {"id": "presentation", "courseCode": "HIST400", "type": "ASSIGNMENT", "title": "Presentation", "start": null, "needsDate": true, "allDay": true, "notes": "Weight: 30%. Last two weeks of class.", "confidence": 0.3, "dateSource": null}]}` },
];

// -- Request builder --

export function buildParseSyllabusRequest(
	text: string,
	options: ParsePromptOptions = {}
) {
	const {
		courseCode,
		termStart,
		termEnd,
		timezone = 'UTC',
		model = 'gpt-4.1-mini',
		gradingScheme,
	} = options;

	const system = SYSTEM_PROMPT({ timezone });

	const contextBlock = JSON.stringify(
		{ courseCode, termStart, termEnd, timezone },
		null,
		0
	);

	const processedText = preprocessTextForAI(text);

	// Build the grading-scheme preamble
	const schemeLine = gradingScheme
		? formatGradingSchemeForPrompt(gradingScheme) ?? 'Not found'
		: 'Not found';

	const userContent = [
		'GRADING SCHEME:',
		schemeLine,
		'',
		`Context: ${contextBlock}`,
		'Syllabus Text:',
		processedText,
	].join('\n');

	const messages = [
		{ role: 'system' as const, content: system },
		...FEWSHOT,
		{ role: 'user' as const, content: userContent },
	];

	return {
		processedText,
		request: {
			model,
			temperature: 0,
			messages,
			response_format: {
				type: 'json_schema' as const,
				json_schema: {
					name: 'parse_syllabus_events',
					schema: eventItemsObjectSchema,
					strict: false,
				},
			},
		},
	};
}
