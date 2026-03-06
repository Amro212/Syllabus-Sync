export type EventMarkerType =
	| 'ASSIGNMENT'
	| 'PROJECT'
	| 'MIDTERM'
	| 'FINAL'
	| 'EXAM'
	| 'IMPORTANT'
	| 'LECTURE'
	| 'TUTORIAL'
	| 'OFFICE_HOURS';

const MARKER_PATTERNS: Array<{ type: EventMarkerType; regex: RegExp }> = [
	{ type: 'IMPORTANT', regex: /\bimportant\s+dates\b/i },
	{ type: 'IMPORTANT', regex: /\b(?:last|final)\s+(?:day|date)\s+to\s+(?:drop|withdraw|add)\b/i },
	{ type: 'IMPORTANT', regex: /\bdrop\s+deadline\b/i },
	{ type: 'IMPORTANT', regex: /\bwithdrawal\s+deadline\b/i },
	{ type: 'IMPORTANT', regex: /\breading\s+week\b/i },
	{ type: 'IMPORTANT', regex: /\b(?:fall|winter|spring|study)\s+break\b/i },
	{ type: 'IMPORTANT', regex: /\bno\s+class(?:es)?\b/i },
	{ type: 'IMPORTANT', regex: /\bholiday\b/i },
	{ type: 'FINAL', regex: /\bfinal\s+exam\b/i },
	{ type: 'MIDTERM', regex: /\bmidterm\b/i },
	{ type: 'PROJECT', regex: /\bmini[-\s]?project\b/i },
	{ type: 'PROJECT', regex: /\bproject\b/i },
	{ type: 'ASSIGNMENT', regex: /\bassignment\b/i },
	{ type: 'TUTORIAL', regex: /\btutorials?\b/i },
	{ type: 'TUTORIAL', regex: /\bseminars?\b/i },
	{ type: 'OFFICE_HOURS', regex: /\boffice\s+hours?\b/i },
	{ type: 'LECTURE', regex: /\blectures?\b/i },
	{ type: 'LECTURE', regex: /\bclass(?:es)?\s+meet(?:ings)?\b/i },
	{ type: 'LECTURE', regex: /\bmeeting\s+times?\b/i },
	{ type: 'EXAM', regex: /\bexam\b/i },
];

// ── Section-awareness: detect boilerplate vs. content sections ──

/** Headings that introduce policy / boilerplate text (should NOT be tagged). */
const BOILERPLATE_SECTION_PATTERNS: RegExp[] = [
	/\bacademic\s+(integrity|misconduct|dishonesty|policy)\b/i,
	/\bplagiarism\b/i,
	/\baccommodation\b/i,
	/\baccessibility\b/i,
	/\bwellness\b/i,
	/\bmental\s+health\b/i,
	/\bcounseling\b/i,
	/\bdisability\b/i,
	/\buniversity\s+policies?\b/i,
	/\bcampus\s+resources?\b/i,
	/\bcourse\s+policies?\b/i,
	/\bgrading\s+policies?\b/i,
	/\battendance\s+polic(?:y|ies)\b/i,
	/\bcopyright\b/i,
	/\blearning\s+outcomes?\b/i,
	/\bcourse\s+objectives?\b/i,
	/\bcourse\s+description\b/i,
	/\btextbook\b/i,
	/\brequired\s+materials?\b/i,
	/\bcode\s+of\s+conduct\b/i,
	/\bcollaboration\s+polic(?:y|ies)\b/i,
	/\blate\s+polic(?:y|ies)\b/i,
	/\bregulat(?:ion|ory)\b/i,
	/\binstructor\s+information\b/i,
	/\bcontact\s+information\b/i,
	/\bteaching\s+assistant\b/i,
	/\bcommunication\s+polic(?:y|ies)\b/i,
	/\bemail\s+polic(?:y|ies)\b/i,
];

/** Headings that introduce real schedule / deliverable content (resume tagging). */
const CONTENT_SECTION_PATTERNS: RegExp[] = [
	/\bschedule\b/i,
	/\bcalendar\b/i,
	/\bimportant\s+dates\b/i,
	/\bevaluation\s+(scheme|breakdown|criteria)\b/i,
	/\bgrading\s+(scheme|breakdown)\b/i,
	/\bassessment\s+(schedule|breakdown|overview)\b/i,
	/\bdeliver(?:able|y)\b/i,
	/\bdue\s+dates?\b/i,
	/\bcourse\s+schedule\b/i,
	/\bweekly\s+schedule\b/i,
	/\btentative\s+schedule\b/i,
	/\btopic(?:s)?\s+(?:and\s+)?schedule\b/i,
	/\bassignment(?:s)?\s+(?:and\s+)?schedule\b/i,
	/\blab\s+schedule\b/i,
	/\btutorial\s+schedule\b/i,
	/\boffice\s+hours?\b/i,
	/\bkey\s+dates\b/i,
	/\bacademic\s+dates\b/i,
];

/**
 * Simple heuristic: is this line likely a section heading?
 * (All-caps, ends with colon, or very short and bold-looking.)
 */
function looksLikeHeading(line: string): boolean {
	const trimmed = line.trim();
	if (!trimmed) return false;
	// Ends with ':'
	if (/^[^:]{3,80}:\s*$/.test(trimmed)) return true;
	// ALL-CAPS line (>= 4 alpha chars, >80% uppercase)
	const alphaChars = trimmed.replace(/[^a-zA-Z]/g, '');
	if (alphaChars.length >= 4) {
		const upperCount = (trimmed.match(/[A-Z]/g) || []).length;
		if (upperCount / alphaChars.length > 0.8) return true;
	}
	// Very short line (likely a title)
	if (trimmed.length <= 60 && /^[\w\s&/,()-]+$/.test(trimmed)) return true;
	return false;
}

/**
 * Detect whether a heading line matches a boilerplate or content section.
 * Returns 'boilerplate' | 'content' | null.
 */
function classifyHeading(line: string): 'boilerplate' | 'content' | null {
	for (const re of CONTENT_SECTION_PATTERNS) {
		if (re.test(line)) return 'content';
	}
	for (const re of BOILERPLATE_SECTION_PATTERNS) {
		if (re.test(line)) return 'boilerplate';
	}
	return null;
}

export function preprocessTextForAI(text: string): string {
	let inBoilerplate = false;

	return text
		.split(/\r?\n/)
		.map((line) => {
			// Check for section transitions on heading-like lines
			if (looksLikeHeading(line)) {
				const kind = classifyHeading(line);
				if (kind === 'boilerplate') {
					inBoilerplate = true;
				} else if (kind === 'content') {
					inBoilerplate = false;
				}
				// Unknown headings don't change state — conservative approach
			}

			return processLine(line, inBoilerplate);
		})
		.join('\n');
}

function processLine(line: string, suppressTags: boolean): string {
	if (!line) {
		return line;
	}

	// When inside a boilerplate section, skip tagging
	if (suppressTags) {
		return line;
	}

	const marker = findMarker(line);
	return marker ? `${marker} ${line}` : line;
}

function findMarker(line: string): string | undefined {
	for (const { type, regex } of MARKER_PATTERNS) {
		if (regex.test(line)) {
			return `[EVENT:${type}]`;
		}
	}

	return undefined;
}
