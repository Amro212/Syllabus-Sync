/**
 * Date and time extraction utilities for syllabus parsing
 * 
 * Extracts dates from normalized text using pattern matching and context analysis.
 * Handles various date formats commonly found in academic syllabi.
 */

/**
 * Represents a date found in text with context and confidence
 */
export interface DateMatch {
  /** The original text that matched */
  text: string;
  /** Start index in the original text */
  startIndex: number;
  /** End index in the original text */
  endIndex: number;
  /** Parsed Date object (null if parsing failed) */
  date: Date | null;
  /** Confidence score 0-1 (higher = more certain) */
  confidence: number;
  /** Type of date pattern matched */
  type: DatePatternType;
  /** Additional context if this is part of a range */
  isRange?: boolean;
  /** For ranges, the end date if different from main date */
  endDate?: Date | null;
}

/**
 * Types of date patterns we can recognize
 */
export type DatePatternType = 
  | 'full_date'        // "September 15, 2025"
  | 'short_date'       // "Sept 15, 2025"
  | 'numeric_date'     // "09/15/25", "9/15/2025"
  | 'weekday_date'     // "Monday, September 15"
  | 'month_day'        // "September 15" (no year)
  | 'week_of'          // "Week of September 15"
  | 'relative_date'    // "Next Monday", "This Friday"
  | 'ordinal_date'     // "September 15th", "Oct 1st"
  | 'date_range'       // "Sept 15-22", "Oct 1 - Nov 15"
  | 'iso_date';        // "2025-09-15"

/**
 * Month name mappings (full and abbreviated)
 */
const MONTH_NAMES = new Map<string, number>([
  // Full month names
  ['january', 0], ['february', 1], ['march', 2], ['april', 3],
  ['may', 4], ['june', 5], ['july', 6], ['august', 7],
  ['september', 8], ['october', 9], ['november', 10], ['december', 11],
  
  // Common abbreviations
  ['jan', 0], ['feb', 1], ['mar', 2], ['apr', 3],
  ['may', 4], ['jun', 5], ['jul', 6], ['aug', 7],
  ['sep', 8], ['sept', 8], ['oct', 9], ['nov', 10], ['dec', 11]
]);

/**
 * Weekday name mappings
 */
const WEEKDAY_NAMES = new Map<string, number>([
  ['sunday', 0], ['monday', 1], ['tuesday', 2], ['wednesday', 3],
  ['thursday', 4], ['friday', 5], ['saturday', 6],
  ['sun', 0], ['mon', 1], ['tue', 2], ['wed', 3],
  ['thu', 4], ['fri', 5], ['sat', 6]
]);

/**
 * Regular expressions for different date patterns
 */
const DATE_PATTERNS = [
  // Full date: "September 15, 2025" or "September 15th, 2025"
  {
    pattern: /\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b/gi,
    type: 'full_date' as DatePatternType,
    confidence: 0.95
  },
  
  // Short date: "Sept 15, 2025" or "Oct 1st, 2025"
  {
    pattern: /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b/gi,
    type: 'short_date' as DatePatternType,
    confidence: 0.90
  },
  
  // Numeric date: "09/15/25", "9/15/2025", "2025-09-15"
  {
    pattern: /\b(\d{1,2})\/(\d{1,2})\/(\d{2,4})\b/g,
    type: 'numeric_date' as DatePatternType,
    confidence: 0.80
  },
  
  // ISO date: "2025-09-15"
  {
    pattern: /\b(\d{4})-(\d{1,2})-(\d{1,2})\b/g,
    type: 'iso_date' as DatePatternType,
    confidence: 0.95
  },
  
  // Weekday + date: "Monday, September 15" or "Friday, Sept 15th"
  {
    pattern: /\b(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat),?\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b/gi,
    type: 'weekday_date' as DatePatternType,
    confidence: 0.85
  },
  
  // Month and day only: "September 15" or "Sept 15th"
  {
    pattern: /\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b/gi,
    type: 'month_day' as DatePatternType,
    confidence: 0.70
  },
  
  // Week of: "Week of September 15" or "Week of Sept 15th"
  {
    pattern: /\bweek\s+of\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b/gi,
    type: 'week_of' as DatePatternType,
    confidence: 0.75
  },
  
  // Date ranges: "Sept 15-22" or "October 1 - November 15"
  {
    pattern: /\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?\s*[-–—]\s*(?:(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\.?\s+)?(\d{1,2})(?:st|nd|rd|th)?\b/gi,
    type: 'date_range' as DatePatternType,
    confidence: 0.80
  }
];

/**
 * Extracts all date references from the given text
 * 
 * @param text The text to search for dates (should be normalized)
 * @param currentYear Optional current year for context (defaults to current year)
 * @returns Array of DateMatch objects with found dates and metadata
 */
export function extractDates(text: string, currentYear?: number): DateMatch[] {
  if (typeof text !== 'string') {
    throw new TypeError('extractDates expects a string input');
  }

  const year = currentYear ?? new Date().getFullYear();
  const matches: DateMatch[] = [];
  const usedRanges = new Set<string>(); // Track used text ranges to avoid duplicates

  for (const { pattern, type, confidence } of DATE_PATTERNS) {
    let match;
    
    // Reset regex lastIndex for global patterns
    pattern.lastIndex = 0;
    
    while ((match = pattern.exec(text)) !== null) {
      const matchText = match[0];
      const startIndex = match.index;
      const endIndex = startIndex + matchText.length;
      
      // Skip if we've already processed this text range
      const rangeKey = `${startIndex}-${endIndex}`;
      if (usedRanges.has(rangeKey)) {
        continue;
      }
      
      const dateMatch = parseMatchedDate(match, type, confidence, year);
      if (dateMatch) {
        dateMatch.text = matchText;
        dateMatch.startIndex = startIndex;
        dateMatch.endIndex = endIndex;
        matches.push(dateMatch);
        usedRanges.add(rangeKey);
      }
    }
  }

  // Sort by position in text and filter overlapping matches
  return deduplicateMatches(matches.sort((a, b) => a.startIndex - b.startIndex));
}

/**
 * Parses a regex match into a DateMatch object
 */
function parseMatchedDate(
  match: RegExpExecArray, 
  type: DatePatternType, 
  confidence: number, 
  currentYear: number
): DateMatch | null {
  try {
    switch (type) {
      case 'full_date':
      case 'short_date':
      case 'month_day':
      case 'week_of': {
        const monthStr = match[1].toLowerCase();
        const day = parseInt(match[2], 10);
        const year = match[3] ? parseInt(match[3], 10) : currentYear;
        
        const monthIndex = MONTH_NAMES.get(monthStr);
        if (monthIndex === undefined || day < 1 || day > 31) {
          return null;
        }
        
        const date = new Date(year, monthIndex, day);
        if (date.getDate() !== day || date.getMonth() !== monthIndex) {
          return null; // Invalid date (e.g., Feb 30)
        }
        
        return {
          text: '',
          startIndex: 0,
          endIndex: 0,
          date,
          confidence: type === 'month_day' ? confidence * 0.9 : confidence, // Lower confidence for dates without year
          type,
          isRange: false
        };
      }
      
      case 'weekday_date': {
        const weekdayStr = match[1].toLowerCase();
        const monthStr = match[2].toLowerCase();
        const day = parseInt(match[3], 10);
        
        const monthIndex = MONTH_NAMES.get(monthStr);
        const weekdayIndex = WEEKDAY_NAMES.get(weekdayStr);
        
        if (monthIndex === undefined || weekdayIndex === undefined || day < 1 || day > 31) {
          return null;
        }
        
        const date = new Date(currentYear, monthIndex, day);
        if (date.getDate() !== day || date.getMonth() !== monthIndex) {
          return null;
        }
        
        // Verify weekday matches (boost confidence if it does)
        const actualWeekday = date.getDay();
        const weekdayMatches = actualWeekday === weekdayIndex;
        
        return {
          text: '',
          startIndex: 0,
          endIndex: 0,
          date,
          confidence: weekdayMatches ? confidence : confidence * 0.7,
          type,
          isRange: false
        };
      }
      
      case 'numeric_date': {
        const part1 = parseInt(match[1], 10);
        const part2 = parseInt(match[2], 10);
        let part3 = parseInt(match[3], 10);
        
        // Handle 2-digit years (assume 20xx for now)
        if (part3 < 100) {
          part3 += part3 < 50 ? 2000 : 1900;
        }
        
        // Try both MM/DD/YYYY and DD/MM/YYYY interpretations
        const dates = [
          new Date(part3, part1 - 1, part2), // MM/DD/YYYY
          new Date(part3, part2 - 1, part1)  // DD/MM/YYYY
        ];
        
        // Use the first valid date, prefer MM/DD for US context
        for (const date of dates) {
          if (!isNaN(date.getTime()) && date.getFullYear() === part3) {
            return {
              text: '',
              startIndex: 0,
              endIndex: 0,
              date,
              confidence: confidence * 0.9, // Lower confidence due to ambiguity
              type,
              isRange: false
            };
          }
        }
        
        return null;
      }
      
      case 'iso_date': {
        const year = parseInt(match[1], 10);
        const month = parseInt(match[2], 10);
        const day = parseInt(match[3], 10);
        
        const date = new Date(year, month - 1, day);
        if (date.getDate() !== day || date.getMonth() !== month - 1 || date.getFullYear() !== year) {
          return null;
        }
        
        return {
          text: '',
          startIndex: 0,
          endIndex: 0,
          date,
          confidence,
          type,
          isRange: false
        };
      }
      
      case 'date_range': {
        const startMonthStr = match[1].toLowerCase();
        const startDay = parseInt(match[2], 10);
        const endMonthStr = match[3]?.toLowerCase() || startMonthStr; // Same month if not specified
        const endDay = parseInt(match[4], 10);
        
        const startMonthIndex = MONTH_NAMES.get(startMonthStr);
        const endMonthIndex = MONTH_NAMES.get(endMonthStr);
        
        if (startMonthIndex === undefined || endMonthIndex === undefined) {
          return null;
        }
        
        const startDate = new Date(currentYear, startMonthIndex, startDay);
        const endDate = new Date(currentYear, endMonthIndex, endDay);
        
        if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
          return null;
        }
        
        return {
          text: '',
          startIndex: 0,
          endIndex: 0,
          date: startDate,
          endDate,
          confidence,
          type,
          isRange: true
        };
      }
      
      default:
        return null;
    }
  } catch (error) {
    // If parsing fails, return null
    return null;
  }
}

/**
 * Removes duplicate and overlapping matches, keeping the highest confidence ones
 */
function deduplicateMatches(matches: DateMatch[]): DateMatch[] {
  const result: DateMatch[] = [];
  
  for (let i = 0; i < matches.length; i++) {
    const current = matches[i];
    let isOverlapping = false;
    
    // Check if this match overlaps with any already accepted match
    for (const accepted of result) {
      if (rangesOverlap(current.startIndex, current.endIndex, accepted.startIndex, accepted.endIndex)) {
        // Keep the one with higher confidence
        if (current.confidence > accepted.confidence) {
          // Remove the lower confidence match and add current
          const index = result.indexOf(accepted);
          result.splice(index, 1);
          result.push(current);
        }
        isOverlapping = true;
        break;
      }
    }
    
    if (!isOverlapping) {
      result.push(current);
    }
  }
  
  return result.sort((a, b) => a.startIndex - b.startIndex);
}

/**
 * Checks if two ranges overlap
 */
function rangesOverlap(start1: number, end1: number, start2: number, end2: number): boolean {
  return start1 < end2 && start2 < end1;
}

/**
 * Utility function to get relative dates (for future enhancement)
 * 
 * @param baseDate The reference date
 * @param text The relative date text (e.g., "next Monday", "this Friday")
 * @returns Date object or null if not parseable
 */
export function parseRelativeDate(baseDate: Date, text: string): Date | null {
  const lowerText = text.toLowerCase().trim();
  
  // Simple relative date patterns
  const nextWeekdayMatch = lowerText.match(/^next\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat)$/);
  const thisWeekdayMatch = lowerText.match(/^this\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat)$/);
  
  if (nextWeekdayMatch) {
    const weekdayName = nextWeekdayMatch[1];
    const targetWeekday = WEEKDAY_NAMES.get(weekdayName);
    if (targetWeekday !== undefined) {
      const result = new Date(baseDate);
      const currentWeekday = result.getDay();
      let daysToAdd = targetWeekday - currentWeekday;
      if (daysToAdd <= 0) daysToAdd += 7; // Next week
      result.setDate(result.getDate() + daysToAdd);
      return result;
    }
  }
  
  if (thisWeekdayMatch) {
    const weekdayName = thisWeekdayMatch[1];
    const targetWeekday = WEEKDAY_NAMES.get(weekdayName);
    if (targetWeekday !== undefined) {
      const result = new Date(baseDate);
      const currentWeekday = result.getDay();
      let daysToAdd = targetWeekday - currentWeekday;
      if (daysToAdd < 0) daysToAdd += 7; // This week (or next if already passed)
      result.setDate(result.getDate() + daysToAdd);
      return result;
    }
  }
  
  return null;
}

/**
 * Statistics about date extraction results
 */
export interface DateExtractionStats {
  /** Total number of dates found */
  totalDates: number;
  /** Number of date ranges found */
  ranges: number;
  /** Average confidence score */
  averageConfidence: number;
  /** Count by date pattern type */
  typeDistribution: Record<DatePatternType, number>;
  /** Earliest date found */
  earliestDate?: Date;
  /** Latest date found */
  latestDate?: Date;
}

/**
 * Analyzes date extraction results and returns statistics
 * 
 * @param matches Array of DateMatch objects
 * @returns Statistics about the extracted dates
 */
export function analyzeDateExtraction(matches: DateMatch[]): DateExtractionStats {
  const stats: DateExtractionStats = {
    totalDates: matches.length,
    ranges: matches.filter(m => m.isRange).length,
    averageConfidence: 0,
    typeDistribution: {} as Record<DatePatternType, number>
  };
  
  if (matches.length === 0) {
    return stats;
  }
  
  // Calculate average confidence
  stats.averageConfidence = matches.reduce((sum, m) => sum + m.confidence, 0) / matches.length;
  
  // Count by type
  for (const match of matches) {
    stats.typeDistribution[match.type] = (stats.typeDistribution[match.type] || 0) + 1;
  }
  
  // Find date range
  const validDates = matches.filter(m => m.date !== null).map(m => m.date!);
  if (validDates.length > 0) {
    stats.earliestDate = new Date(Math.min(...validDates.map(d => d.getTime())));
    stats.latestDate = new Date(Math.max(...validDates.map(d => d.getTime())));
  }
  
  return stats;
}
