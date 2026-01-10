/**
 * Post-processing utility to split multi-day recurrence events into separate single-day events.
 * 
 * This handles AI output that combines multiple days (e.g., BYDAY=TU,TH) by splitting
 * them into separate events (one for Tuesday, one for Thursday).
 */

interface EventWithRecurrence {
    id: string;
    title: string;
    start: string;
    end?: string;
    recurrenceRule?: string;
    [key: string]: unknown;
}

const DAY_CODE_TO_NAME: Record<string, string> = {
    MO: 'Mon',
    TU: 'Tue',
    WE: 'Wed',
    TH: 'Thu',
    FR: 'Fri',
    SA: 'Sat',
    SU: 'Sun',
};

const DAY_CODE_TO_OFFSET: Record<string, number> = {
    SU: 0,
    MO: 1,
    TU: 2,
    WE: 3,
    TH: 4,
    FR: 5,
    SA: 6,
};

/**
 * Add days to an ISO date string while preserving the time and timezone offset.
 * This avoids UTC conversion issues that occur with Date object manipulation.
 * 
 * Example: 
 * addDaysToIsoString("2026-01-06T14:30:00.000-05:00", 2) => "2026-01-08T14:30:00.000-05:00"
 */
function addDaysToIsoString(isoString: string, days: number): string {
    // Parse the date portion (YYYY-MM-DD)
    const dateMatch = isoString.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (!dateMatch) return isoString;

    const year = parseInt(dateMatch[1], 10);
    const month = parseInt(dateMatch[2], 10) - 1; // JS months are 0-indexed
    const day = parseInt(dateMatch[3], 10);

    // Create a date object just for day arithmetic (in local time, doesn't matter)
    const tempDate = new Date(year, month, day);
    tempDate.setDate(tempDate.getDate() + days);

    // Format back to YYYY-MM-DD
    const newYear = tempDate.getFullYear();
    const newMonth = String(tempDate.getMonth() + 1).padStart(2, '0');
    const newDay = String(tempDate.getDate()).padStart(2, '0');

    // Replace just the date portion, keeping time and timezone
    return isoString.replace(/^\d{4}-\d{2}-\d{2}/, `${newYear}-${newMonth}-${newDay}`);
}

/**
 * Splits events with multi-day BYDAY rules into separate single-day events.
 * 
 * Example:
 * Input: { recurrenceRule: "FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2026-04-21" }
 * Output: Two events, one with BYDAY=TU, one with BYDAY=TH
 */
export function splitMultiDayRecurrence<T extends { id: string; title: string; start: string; end?: string; recurrenceRule?: string }>(events: T[]): T[] {
    const result: T[] = [];

    for (const event of events) {
        const rule = event.recurrenceRule;

        // If no recurrence rule, or it's not a multi-day rule, keep as-is
        if (!rule || !rule.includes('BYDAY=')) {
            result.push(event);
            continue;
        }

        // Extract BYDAY value
        const byDayMatch = rule.match(/BYDAY=([A-Z,]+)/);
        if (!byDayMatch) {
            result.push(event);
            continue;
        }

        const days = byDayMatch[1].split(',').filter(d => d.length > 0);

        // If only one day, keep as-is
        if (days.length <= 1) {
            result.push(event);
            continue;
        }

        // Split into multiple events, one per day
        // Derive weekday from the date portion to respect the event's own offset.
        const dateMatch = event.start.match(/^(\d{4})-(\d{2})-(\d{2})/);
        const startDayOfWeek = dateMatch
            ? new Date(Date.UTC(Number(dateMatch[1]), Number(dateMatch[2]) - 1, Number(dateMatch[3]))).getUTCDay() // 0=Sun, 1=Mon, etc.
            : new Date(event.start).getUTCDay();

        for (const dayCode of days) {
            const dayName = DAY_CODE_TO_NAME[dayCode] || dayCode;
            const targetDayOfWeek = DAY_CODE_TO_OFFSET[dayCode];

            if (targetDayOfWeek === undefined) {
                // Unknown day code, skip
                continue;
            }

            // Calculate the offset from startDate to the target day
            let dayOffset = targetDayOfWeek - startDayOfWeek;
            if (dayOffset < 0) {
                dayOffset += 7; // Move to next week
            }

            // Preserve original timezone by manipulating the date string directly
            // Add days to start date while preserving time and timezone
            const newStartStr = addDaysToIsoString(event.start, dayOffset);
            let newEndStr: string | undefined;
            if (event.end) {
                newEndStr = addDaysToIsoString(event.end, dayOffset);
            }

            // Create new recurrence rule with single day
            const newRule = rule.replace(/BYDAY=[A-Z,]+/, `BYDAY=${dayCode}`);

            // Create the split event
            const splitEvent: T = {
                ...event,
                id: `${event.id}-${dayCode.toLowerCase()}`,
                title: `${event.title} (${dayName})`,
                start: newStartStr,
                ...(newEndStr && { end: newEndStr }),
                recurrenceRule: newRule,
            };

            result.push(splitEvent);
        }
    }

    return result;
}
