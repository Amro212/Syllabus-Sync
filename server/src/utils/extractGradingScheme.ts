/**
 * Deterministic grading-scheme extractor.
 *
 * Scans syllabus text for evaluation / grading-breakdown sections,
 * then extracts deliverable names and weights using regex.
 * This is purely heuristic — no AI involved — so it runs in < 1 ms
 * and provides a reliable source of truth the AI prompt can reference.
 */

import type { EventType } from '../types/eventItem.js';

// ── Public types ────────────────────────────────────────────────

export interface GradingEntry {
	/** Raw name as it appears in the syllabus (e.g. "Mini Project") */
	name: string;
	/** Weight as a decimal 0-1 (10 % → 0.10). null if no % found. */
	weight: number | null;
	/** Best-guess event type based on the name */
	type: EventType;
}

export interface GradingSchemeResult {
	/** Extracted deliverables (may be empty) */
	deliverables: GradingEntry[];
	/** The raw section text that was identified, or null */
	rawSection: string | null;
}

// ── Section detection ───────────────────────────────────────────

/** Headings that introduce a grading / evaluation table. */
const GRADING_SECTION_RX: RegExp[] = [
	/\bgrading\s+(scheme|breakdown|criteria|summary|policy)\b/i,
	/\bevaluation\s*(scheme|breakdown|criteria|summary|method)?\s*:?\s*$/i,
	/\bassessment\s+(breakdown|overview|schedule|summary)\b/i,
	/\bcourse\s+(evaluation|assessment|grading)\b/i,
	/\bgrade\s+(distribution|breakdown|allocation)\b/i,
	/\bmarks?\s+(distribution|breakdown|allocation)\b/i,
	/\bweighting\s+of\s+(grades?|marks?|components?)\b/i,
	/\bassessments?\s+and\s+grad/i,
	/\bmarking\s+schemes?\b/i,
	/\bassessment\s+details?\b/i,
];

/** Headings that clearly end the grading section. */
const END_SECTION_RX: RegExp[] = [
	/\bacademic\s+(integrity|misconduct|dishonesty)\b/i,
	/\bschedule\b/i,
	/\bcourse\s+policies?\b/i,
	/\battendance\b/i,
	/\btextbook\b/i,
	/\brequired\s+materials?\b/i,
	/\blearning\s+outcomes?\b/i,
	/\bcourse\s+description\b/i,
	/\bcourse\s+objectives?\b/i,
	/\baccommodation\b/i,
	/\binstructor\s+information\b/i,
	/\boffice\s+hours?\b/i,
	/\bassignment\s+details?\b/i,
	/\blab\s+schedule\b/i,
	/\blecture\s+schedule\b/i,
	/\bfinal\s+grade\b/i,
	/\bassignment\s+polic/i,
	/\bassignment\s+alignment\b/i,
	/\bassignment\s+grading\b/i,
];

// ── Blacklisted names (false-positive suppression) ──────────────

/**
 * Names that should never appear as standalone deliverables.
 * These are generic terms that leak from policy/formula sections
 * (e.g. "exam component (60%)" in a Final Grade Calculation paragraph).
 */
const BLACKLISTED_NAMES_RX: RegExp[] = [
	/^component$/i,
	/^exam\s+component$/i,
	/^grade$/i,
	/^final\s+grade$/i,
	/^total$/i,
	/^total\s+grade$/i,
	/^course\s+grade$/i,
	/^overall$/i,
	/^weight$/i,
	/^percentage$/i,
	/^marks?$/i,
	/^score$/i,
	/^grading$/i,
];

function isBlacklistedName(name: string): boolean {
	const trimmed = name.trim();
	return BLACKLISTED_NAMES_RX.some((rx) => rx.test(trimmed));
}

// ── Line-level extraction ───────────────────────────────────────

/**
 * Matches lines like:
 *   "Assignments  30%"
 *   "Final Exam .......... 25 %"
 *   "Labs (15% total)"
 *   "Mini-Project: 10%"
 *   "| Midterm | 20% |"
 *   "- Quizzes: 15%"
 *
 * Leading bullets (-, *, •) and list markers are stripped.
 * Separator can be punctuation OR 2+ spaces.
 */
const WEIGHT_LINE_RX =
	/^[-*•|>\s]*(?<name>[A-Za-z][A-Za-z0-9 /&,()':.+*-]{1,60}?)\s*(?:[|:.…–—\-\t]+\s*|\s{2,})(?<pct>\d{1,3})\s*%/;

/**
 * Fallback: percentage appears after name with colon/parenthesis.
 *   "Participation (10%)"
 *   "Labs: 15% total across 3 labs"
 *   "- Labs: 25%"
 */
const WEIGHT_INLINE_RX =
	/^[-*•|>\s]*(?<name>[A-Za-z][A-Za-z0-9 /&,()':.+*-]{1,60}?)\s*[:(]\s*(?<pct>\d{1,3})\s*%/;

/**
 * Simple terminal pattern:
 *   "Final Exam 100%"
 *   "Assignment 1 10%"
 */
const WEIGHT_SIMPLE_RX =
	/^[-*•|>\s]*(?<name>[A-Za-z][A-Za-z0-9 /&,()':.+*-]{1,60}?)\s+(?<pct>\d{1,3})\s*%$/;

/**
 * Reverse pattern: "30% — Assignments" or "30% Final Exam"
 */
const WEIGHT_REVERSE_RX =
	/^[-*•|>\s]*(?<pct>\d{1,3})\s*%\s*[—\-–:|\s]+\s*(?<name>[A-Za-z][A-Za-z0-9 /&,()':.+*-]{1,60})/;

// ── Type inference ──────────────────────────────────────────────

const TYPE_MAP: Array<{ regex: RegExp; type: EventType }> = [
	{ regex: /\bfinal\s*(exam)?\b/i, type: 'FINAL' },
	{ regex: /\bmidterm\b/i, type: 'MIDTERM' },
	{ regex: /\bquiz/i, type: 'QUIZ' },
	{ regex: /\blab/i, type: 'LAB' },
	{ regex: /\blecture/i, type: 'LECTURE' },
	{ regex: /\btutorial|seminar/i, type: 'TUTORIAL' },
	{ regex: /\bparticipation|attendance\b/i, type: 'OTHER' },
	// Everything else (assignment, project, homework, essay, report, etc.)
];

function inferType(name: string): EventType {
	for (const { regex, type } of TYPE_MAP) {
		if (regex.test(name)) return type;
	}
	return 'ASSIGNMENT';
}

// ── Helpers ─────────────────────────────────────────────────────

function looksLikeHeading(line: string): boolean {
	const t = line.trim();
	if (!t || t.length > 120) return false;
	if (/^[^:]{3,80}:\s*$/.test(t)) return true;
	const alpha = t.replace(/[^a-zA-Z]/g, '');
	if (alpha.length >= 4) {
		const upper = (t.match(/[A-Z]/g) || []).length;
		if (upper / alpha.length > 0.8) return true;
	}
	if (t.length <= 60 && /^[\w\s&/,()'.*-]+$/.test(t)) return true;
	return false;
}

function matchesAny(line: string, patterns: RegExp[]): boolean {
	return patterns.some((rx) => rx.test(line));
}

function cleanName(raw: string): string {
	return raw
		.replace(/[|:.…–—\-]+$/, '')    // trailing punctuation
		.replace(/\s+/g, ' ')            // collapse whitespace
		.trim();
}

/** Deduplicate by normalised lowercase name, keeping the first occurrence. */
function dedup(entries: GradingEntry[]): GradingEntry[] {
	const seen = new Set<string>();
	return entries.filter((e) => {
		const key = e.name.toLowerCase().replace(/\s+/g, ' ');
		if (seen.has(key)) return false;
		seen.add(key);
		return true;
	});
}

// ── Umbrella / parent-entry detection ────────────────────────────

/**
 * Generic umbrella-category names that a syllabus might use to group
 * individual deliverables.  Only entries matching one of these patterns
 * are eligible for removal by `removeParentEntries`.
 *
 * This prevents specific assessment items like "Final Exam" or
 * "Midterm 1" from being accidentally removed just because their
 * weight happens to equal the sum of other entries.
 */
const UMBRELLA_NAME_RX: RegExp[] = [
	/^exams?$/i,
	/^tests?$/i,
	/^examinations?$/i,
	/^assignments?$/i,
	/^homework$/i,
	/^labs?$/i,
	/^laborator(?:y|ies)$/i,
	/^quizzes?$/i,
	/^tutorials?$/i,
	/^projects$/i,
	/^reports$/i,
	/^written\s+work$/i,
	/^oral\s+(?:work|presentations?)$/i,
	/^presentations$/i,
	/^coursework$/i,
	/^assessments?$/i,
	/^deliverables$/i,
	/^(?:in[- ]?class\s+)?exercises?$/i,
];

function isUmbrellaName(name: string): boolean {
	const trimmed = name.trim();
	return UMBRELLA_NAME_RX.some((rx) => rx.test(trimmed));
}

/**
 * Remove parent/umbrella entries that overlap with their children.
 *
 * When a syllabus lists both a category ("Exams: 60%") and individual
 * items ("Midterm 1: 15%, Midterm 2: 15%, Final: 30%"), the total
 * exceeds 100%.  This function detects entries whose weight equals
 * the sum of some subset of other entries (within ±2.5 pp tolerance)
 * and removes those parent entries.
 *
 * **Safety guard:** only entries whose name matches a known umbrella
 * pattern (e.g. "Exams", "Assignments", "Labs") are eligible for
 * removal.  Specific items like "Final Exam" or "Midterm 1" are
 * never removed, even if their weight coincidentally equals a sum
 * of other entries.
 *
 * Processes candidates largest-weight-first and stops as soon as
 * the remaining total is ≤ 100%.
 *
 * Only runs when the raw total exceeds 1.0 (100%).
 */
function removeParentEntries(entries: GradingEntry[]): GradingEntry[] {
	const withWeight = entries.filter((e) => e.weight != null && e.weight > 0);
	let totalWeight = withWeight.reduce((s, e) => s + (e.weight ?? 0), 0);

	// If total is ≤ 1.0, nothing to fix
	if (totalWeight <= 1.02) return entries;

	const tolerance = 0.025; // 2.5 percentage-point tolerance

	// Process largest-first so we preferentially remove umbrella categories
	const sorted = [...withWeight].sort(
		(a, b) => (b.weight ?? 0) - (a.weight ?? 0)
	);
	const parentNames = new Set<string>();

	for (const candidate of sorted) {
		// Stop once total is at or below 100%
		if (totalWeight <= 1.02) break;

		// ── Safety: only umbrella-named entries can be removed ──
		if (!isUmbrellaName(candidate.name)) continue;

		const target = candidate.weight!;
		// Exclude the candidate AND any already-flagged parents from the pool
		const others = withWeight.filter(
			(e) =>
				e !== candidate &&
				!parentNames.has(e.name.toLowerCase().replace(/\s+/g, ' '))
		);

		if (others.length < 2) continue;

		if (hasSubsetSum(others.map((o) => o.weight!), target, tolerance)) {
			parentNames.add(
				candidate.name.toLowerCase().replace(/\s+/g, ' ')
			);
			totalWeight -= target;
		}
	}

	if (parentNames.size === 0) return entries;

	return entries.filter(
		(e) => !parentNames.has(e.name.toLowerCase().replace(/\s+/g, ' '))
	);
}

/**
 * Check whether any subset of `weights` (with at least 2 elements)
 * sums to `target` ± `tolerance`.
 *
 * Tracks sums reachable with exactly 1 item (`dp1`) separately from
 * sums reachable with ≥ 2 items (`dp2plus`).  This prevents a single
 * item whose weight equals `target` from masking a genuine multi-item
 * subset that also reaches the same sum.
 *
 * Weights are percentages 0-1 scaled by 1000 to get integer arithmetic.
 */
function hasSubsetSum(
	weights: number[],
	target: number,
	tolerance: number
): boolean {
	if (weights.length < 2) return false;

	const scale = 1000;
	const targetInt = Math.round(target * scale);
	const tolInt = Math.round(tolerance * scale);

	// dp1: sums reachable with exactly 1 item
	// dp2plus: sums reachable with >= 2 items
	const dp1 = new Set<number>();
	const dp2plus = new Set<number>();

	for (const w of weights) {
		const wInt = Math.round(w * scale);

		// Snapshot current state before mutation
		const snap1 = [...dp1];
		const snap2 = [...dp2plus];

		// Extending a 2+-item sum by one more item → still 2+
		for (const s of snap2) {
			dp2plus.add(s + wInt);
		}
		// Extending a 1-item sum by one more item → now 2 items
		for (const s of snap1) {
			dp2plus.add(s + wInt);
		}

		// This single item is a 1-item sum
		dp1.add(wInt);
	}

	for (let t = targetInt - tolInt; t <= targetInt + tolInt; t++) {
		if (dp2plus.has(t)) return true;
	}

	return false;
}

// ── Main export ─────────────────────────────────────────────────

export function extractGradingScheme(text: string): GradingSchemeResult {
	const lines = text.split(/\r?\n/);

	// 1) Find the grading section
	let sectionStart = -1;
	let sectionEnd = lines.length;

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		if (sectionStart === -1) {
			if (looksLikeHeading(line) && matchesAny(line, GRADING_SECTION_RX)) {
				sectionStart = i;
			}
			continue;
		}
		// We're inside the section — look for the end
		if (looksLikeHeading(line) && matchesAny(line, END_SECTION_RX)) {
			sectionEnd = i;
			break;
		}
	}

	// 2) If no section found, scan the entire text as a fallback
	const searchStart = sectionStart === -1 ? 0 : sectionStart;
	const searchEnd = sectionStart === -1 ? lines.length : sectionEnd;

	const rawSection =
		sectionStart !== -1
			? lines.slice(sectionStart, sectionEnd).join('\n')
			: null;

	// 3) Extract deliverables from the search window
	const entries: GradingEntry[] = [];

	for (let i = searchStart; i < searchEnd; i++) {
		const line = lines[i].trim();
		if (!line) continue;

		let name: string | null = null;
		let pct: number | null = null;

		// Try each pattern in priority order
		let m = WEIGHT_LINE_RX.exec(line);
		if (m?.groups) {
			name = m.groups.name;
			pct = Number.parseInt(m.groups.pct, 10);
		}

		if (!name) {
			m = WEIGHT_INLINE_RX.exec(line);
			if (m?.groups) {
				name = m.groups.name;
				pct = Number.parseInt(m.groups.pct, 10);
			}
		}

		if (!name) {
			m = WEIGHT_SIMPLE_RX.exec(line);
			if (m?.groups) {
				name = m.groups.name;
				pct = Number.parseInt(m.groups.pct, 10);
			}
		}

		if (!name) {
			m = WEIGHT_REVERSE_RX.exec(line);
			if (m?.groups) {
				name = m.groups.name;
				pct = Number.parseInt(m.groups.pct, 10);
			}
		}

		if (name && pct != null && pct > 0 && pct <= 100) {
			const cleaned = cleanName(name);
			if (cleaned.length >= 2 && !isBlacklistedName(cleaned)) {
				entries.push({
					name: cleaned,
					weight: pct / 100,
					type: inferType(cleaned),
				});
			}
		}
	}

	return {
		deliverables: removeParentEntries(dedup(entries)),
		rawSection,
	};
}

/**
 * Format the extracted scheme into a plain-text block the AI prompt can consume.
 * Returns null when we have no deliverables.
 */
export function formatGradingSchemeForPrompt(
	result: GradingSchemeResult
): string | null {
	if (result.deliverables.length === 0) return null;

	const lines = result.deliverables.map(
		(d) =>
			`- ${d.name}: ${d.weight != null ? `${Math.round(d.weight * 100)}%` : 'weight unknown'}`
	);
	return lines.join('\n');
}
