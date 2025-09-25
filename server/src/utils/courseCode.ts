const COURSE_CODE_PATTERNS: RegExp[] = [
  /\b([A-Z]{2,4}\s?[\*\-]?\s?\d{3,4}[A-Z]?)\b/g, // CS101, ENGG*3990, MATH-151
  /\b([A-Z]{2,4}\s?\d{2}[A-Z]?\s?\d{2})\b/g,      // ENGG 33 90 style
  /\b([A-Z]{2,4}\s?[A-Z]{1}\s?\d{3})\b/g,         // e.g., PS YC 101 (with extra letter)
  /\b([A-Z]{6,12}\s+\d{1,2}[A-Z]{1,2}\d{1,2})\b/g // COMMERCE 4BB3, MATHEMATICS 101A, PSYCHOLOGY 200B
];

function sanitizeMatch(match: string): string {
  return match
    .replace(/\s+/g, ' ')
    .replace(/\s*([\*\-])\s*/g, '$1')
    .toUpperCase()
    .trim();
}

export function detectCourseCode(text: string): string | undefined {
  if (!text) return undefined;

  const candidates = new Map<string, number>();

  for (const pattern of COURSE_CODE_PATTERNS) {
    pattern.lastIndex = 0;
    let match: RegExpExecArray | null;
    while ((match = pattern.exec(text)) !== null) {
      const value = sanitizeMatch(match[1]);
      if (value.length < 2) continue;
      const firstIndex = candidates.get(value) ?? match.index;
      candidates.set(value, Math.min(firstIndex, match.index));
    }
  }

  if (candidates.size === 0) {
    return undefined;
  }

  return [...candidates.entries()].sort((a, b) => a[1] - b[1])[0][0];
}
