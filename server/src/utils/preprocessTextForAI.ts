export type EventMarkerType =
	| 'ASSIGNMENT'
	| 'PROJECT'
	| 'MIDTERM'
	| 'FINAL'
	| 'EXAM'
	| 'IMPORTANT'
	| 'LECTURE';

const MARKER_PATTERNS: Array<{ type: EventMarkerType; regex: RegExp }> = [
	{ type: 'IMPORTANT', regex: /\bimportant\s+dates\b/i },
	{ type: 'FINAL', regex: /\bfinal\s+exam\b/i },
	{ type: 'FINAL', regex: /\bfinals?\b/i },
	{ type: 'MIDTERM', regex: /\bmidterm\b/i },
	{ type: 'PROJECT', regex: /\bmini[-\s]?project\b/i },
	{ type: 'PROJECT', regex: /\bproject\b/i },
	{ type: 'ASSIGNMENT', regex: /\bassignment\b/i },
	{ type: 'LECTURE', regex: /\blectures?\b/i },
	{ type: 'LECTURE', regex: /\bclass(?:es)?\s+meet(?:ings)?\b/i },
	{ type: 'LECTURE', regex: /\bmeeting\s+times?\b/i },
	{ type: 'EXAM', regex: /\bexam\b/i }
];

const WEIGHT_SUFFIX = ' — WEIGHT';

export function preprocessTextForAI(text: string): string {
	return text
		.split(/\r?\n/)
		.map((line) => processLine(line))
		.join('\n');
}

function processLine(line: string): string {
	if (!line) {
		return line;
	}

	const marker = findMarker(line);
	let result = marker ? `${marker} ${line}` : line;

	const percentIndex = result.indexOf('%');
	if (percentIndex !== -1) {
		const afterPercent = result.slice(percentIndex + 1, percentIndex + 1 + WEIGHT_SUFFIX.length);
		if (afterPercent !== WEIGHT_SUFFIX) {
			result = `${result.slice(0, percentIndex + 1)}${WEIGHT_SUFFIX}${result.slice(percentIndex + 1)}`;
		}
	}

	return result;
}

function findMarker(line: string): string | undefined {
	for (const { type, regex } of MARKER_PATTERNS) {
		if (regex.test(line)) {
			return `[EVENT:${type}]`;
		}
	}

	return undefined;
}
