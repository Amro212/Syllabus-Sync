/**
 * Shared date formatting helpers to align server output with AI prompt guidance.
 */

const ISO_LOCAL_WITH_MS = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$/;
const ISO_LOCAL_NO_MS = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/;
const ISO_DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;
const ISO_WITH_OFFSET = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?[+-]\d{2}:\d{2}$/;

function pad(number: number, length = 2): string {
  return number.toString().padStart(length, '0');
}

/**
 * Formats a date using UTC components without a timezone designator ("Z").
 *
 * Output example: `2025-09-12T23:59:00.000`
 */
export function formatUtcDateWithoutTimezone(date: Date): string {
  const year = date.getFullYear();
  const month = pad(date.getMonth() + 1);
  const day = pad(date.getDate());
  const hours = pad(date.getHours());
  const minutes = pad(date.getMinutes());
  const seconds = pad(date.getSeconds());
  const milliseconds = pad(date.getMilliseconds(), 3);

  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}.${milliseconds}`;
}

/**
 * Attempts to parse a date string that may omit timezone information.
 * Strings that match the local ISO pattern (without timezone) are assumed to be UTC.
 */
export function parseFlexibleISODate(dateString: string): Date {
  if (ISO_WITH_OFFSET.test(dateString)) {
    return new Date(dateString);
  }

  if (ISO_LOCAL_WITH_MS.test(dateString)) {
    return new Date(dateString);
  }

  if (ISO_LOCAL_NO_MS.test(dateString)) {
    return new Date(dateString);
  }

  if (ISO_DATE_ONLY.test(dateString)) {
    return new Date(`${dateString}T00:00:00.000`);
  }

  return new Date(dateString);
}

/**
 * Checks whether the provided string conforms to one of the accepted ISO formats.
 */
export function matchesAcceptedISOFormat(dateString: string): boolean {
  return (
    ISO_WITH_OFFSET.test(dateString) ||
    ISO_LOCAL_WITH_MS.test(dateString) ||
    ISO_LOCAL_NO_MS.test(dateString) ||
    ISO_DATE_ONLY.test(dateString) ||
    /Z$/.test(dateString)
  );
}

export const ACCEPTED_ISO_LOCAL_PATTERNS = {
  ISO_LOCAL_WITH_MS,
  ISO_LOCAL_NO_MS,
  ISO_DATE_ONLY,
  ISO_WITH_OFFSET,
};
