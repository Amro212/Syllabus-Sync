/**
 * Event builder utilities for syllabus parsing
 * 
 * Combines text normalization, date extraction, and keyword classification
 * to build structured EventItem candidates from raw syllabus text.
 */

import { normalizeText, splitIntoLines } from './textNormalization.js';
import { extractDates, type DateMatch } from './dateExtraction.js';
import { classifyLines, type ClassificationResult } from './keywordClassifier.js';
import type { EventType, EventItemDTO } from '../types/eventItem.js';
import { formatUtcDateWithoutTimezone } from '../utils/date.js';

/**
 * Represents a candidate event with parsing metadata
 */
export interface EventCandidate {
  /** Unique identifier for this candidate */
  id: string;
  /** Course code inferred for this event */
  courseCode?: string;
  /** Event type classification */
  type: EventType;
  /** Generated title */
  title: string;
  /** Start date/time */
  start: Date;
  /** End date/time (optional) */
  end?: Date;
  /** Whether this is an all-day event */
  allDay: boolean;
  /** Location if detected */
  location?: string;
  /** Additional notes */
  notes?: string;
  /** Overall confidence score (0-1) */
  confidence: number;
  /** Source line index in original text */
  sourceLineIndex: number;
  /** Original text that generated this event */
  sourceText: string;
  /** Keywords that contributed to classification */
  matchedKeywords: string[];
  /** Date matches that contributed to timing */
  dateMatches: DateMatch[];
}

/**
 * Configuration for the event builder
 */
export interface EventBuilderConfig {
  /** Course code for generated events */
  courseCode?: string;
  /** Default year to use when dates don't include year */
  defaultYear?: number;
  /** Minimum confidence threshold for including events */
  minConfidence?: number;
  /** Whether to deduplicate similar events */
  deduplicate?: boolean;
}

/**
 * Statistics about the event building process
 */
export interface EventBuildingStats {
  /** Total lines processed */
  totalLines: number;
  /** Lines with date matches */
  linesWithDates: number;
  /** Lines with type classifications */
  linesWithTypes: number;
  /** Total event candidates generated */
  candidatesGenerated: number;
  /** Candidates after deduplication */
  candidatesAfterDedup: number;
  /** Average confidence score */
  averageConfidence: number;
  /** Processing time in milliseconds */
  processingTimeMs: number;
  /** Warnings encountered during processing */
  warnings: string[];
}

/**
 * Builds structured event candidates from raw syllabus text
 * 
 * @param rawText Raw syllabus text input
 * @param config Optional configuration for event building
 * @returns Array of event candidates with metadata
 */
export function buildEvents(rawText: string, config: EventBuilderConfig = {}): {
  events: EventCandidate[];
  stats: EventBuildingStats;
} {
  const startTime = Date.now();
  const stats: EventBuildingStats = {
    totalLines: 0,
    linesWithDates: 0,
    linesWithTypes: 0,
    candidatesGenerated: 0,
    candidatesAfterDedup: 0,
    averageConfidence: 0,
    processingTimeMs: 0,
    warnings: []
  };

  if (typeof rawText !== 'string') {
    throw new TypeError('buildEvents expects a string input');
  }

  if (rawText.trim().length === 0) {
    stats.processingTimeMs = Date.now() - startTime;
    return { events: [], stats };
  }

  // Step 1: Normalize the text
  const normalizedText = normalizeText(rawText);
  const lines = splitIntoLines(normalizedText);
  stats.totalLines = lines.length;

  if (lines.length === 0) {
    stats.processingTimeMs = Date.now() - startTime;
    return { events: [], stats };
  }

  // Step 2: Extract dates from the entire text
  const allDates = extractDates(normalizedText, config.defaultYear);
  if (allDates.length > 0) {
    stats.linesWithDates = countLinesWithDates(lines, allDates);
  }

  // Step 3: Classify lines for event types
  const classifications = classifyLines(lines);
  stats.linesWithTypes = classifications.filter(c => c.type !== 'OTHER').length;

  // Step 4: Build event candidates by analyzing each line
  const candidates: EventCandidate[] = [];
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const classification = classifications[i];
    
    // Skip lines that don't look like events
    if (classification.type === 'OTHER' || classification.confidence < (config.minConfidence || 0.3)) {
      continue;
    }

    // Find dates that are relevant to this line
    const relevantDates = findRelevantDates(line, allDates, i, lines);
    
    if (relevantDates.length === 0) {
      // Try to find dates in nearby lines (context window)
      const contextDates = findContextDates(i, lines, allDates, 2);
      relevantDates.push(...contextDates);
    }

    // Generate event candidates for this line
    const lineCandidates = generateCandidatesForLine(
      line,
      i,
      classification,
      relevantDates,
      config
    );

    candidates.push(...lineCandidates);
  }

  stats.candidatesGenerated = candidates.length;

  // Step 5: Deduplicate similar events if requested
  let finalEvents = candidates;
  if (config.deduplicate !== false) {
    finalEvents = deduplicateEvents(candidates);
    stats.candidatesAfterDedup = finalEvents.length;
  } else {
    stats.candidatesAfterDedup = candidates.length;
  }

  // Step 6: Calculate final statistics
  if (finalEvents.length > 0) {
    stats.averageConfidence = finalEvents.reduce((sum, e) => sum + e.confidence, 0) / finalEvents.length;
  }

  stats.processingTimeMs = Date.now() - startTime;

  return { events: finalEvents, stats };
}

/**
 * Counts how many lines contain date references
 */
function countLinesWithDates(lines: string[], dates: DateMatch[]): number {
  let count = 0;
  
  for (const line of lines) {
    const hasDate = dates.some(date => 
      line.toLowerCase().includes(date.text.toLowerCase())
    );
    if (hasDate) count++;
  }
  
  return count;
}

/**
 * Finds date matches that are relevant to a specific line
 */
function findRelevantDates(line: string, allDates: DateMatch[], lineIndex: number, lines: string[]): DateMatch[] {
  const relevantDates: DateMatch[] = [];
  const lowerLine = line.toLowerCase();

  // First priority: dates that appear directly in this line
  for (const date of allDates) {
    if (lowerLine.includes(date.text.toLowerCase())) {
      relevantDates.push(date);
    }
  }

  return relevantDates;
}

/**
 * Finds dates in nearby lines (context window) when the current line has no dates
 */
function findContextDates(
  lineIndex: number, 
  lines: string[], 
  allDates: DateMatch[], 
  windowSize: number
): DateMatch[] {
  const contextDates: DateMatch[] = [];
  
  // Check lines before and after within the window
  const startIdx = Math.max(0, lineIndex - windowSize);
  const endIdx = Math.min(lines.length - 1, lineIndex + windowSize);
  
  for (let i = startIdx; i <= endIdx; i++) {
    if (i === lineIndex) continue; // Skip the current line
    
    const contextLine = lines[i].toLowerCase();
    for (const date of allDates) {
      if (contextLine.includes(date.text.toLowerCase()) && 
          !contextDates.some(d => d.text === date.text)) {
        contextDates.push(date);
      }
    }
  }
  
  return contextDates;
}

/**
 * Generates event candidates for a single line
 */
function generateCandidatesForLine(
  line: string,
  lineIndex: number,
  classification: ClassificationResult & { lineIndex: number; originalText: string },
  dates: DateMatch[],
  config: EventBuilderConfig
): EventCandidate[] {
  const candidates: EventCandidate[] = [];

  // If no dates found, skip this line (events need dates)
  if (dates.length === 0) {
    return candidates;
  }

  // Generate a candidate for each relevant date
  for (const dateMatch of dates) {
    if (!dateMatch.date) continue; // Skip invalid dates

    const candidate = createEventCandidate(
      line,
      lineIndex,
      classification,
      dateMatch,
      dates,
      config
    );

    if (candidate) {
      candidates.push(candidate);
    }
  }

  return candidates;
}

/**
 * Creates a single event candidate
 */
function createEventCandidate(
  line: string,
  lineIndex: number,
  classification: ClassificationResult & { lineIndex: number; originalText: string },
  primaryDate: DateMatch,
  allDates: DateMatch[],
  config: EventBuilderConfig
): EventCandidate | null {
  if (!primaryDate.date) return null;

  // Generate title
  const title = generateEventTitle(line, classification.type, classification.matchedKeywords);
  
  // Determine if it's all-day
  const allDay = isAllDayEvent(primaryDate, classification.type, line);
  
  // Handle date ranges
  let endDate: Date | undefined;
  if (primaryDate.endDate) {
    endDate = primaryDate.endDate;
  } else if (classification.type === 'LAB' || classification.type === 'LECTURE') {
    // Labs and lectures typically have duration
    endDate = new Date(primaryDate.date.getTime() + 90 * 60 * 1000); // 90 minutes default
  }

  // Extract location if present
  const location = extractLocation(line);

  // Calculate confidence score
  const confidence = calculateEventConfidence(
    classification,
    primaryDate,
    line
  );

  // Apply minimum confidence filter
  if (confidence < (config.minConfidence || 0.3)) {
    return null;
  }

  const candidate: EventCandidate = {
    id: generateEventId(),
    courseCode: config.courseCode,
    type: classification.type,
    title,
    start: primaryDate.date,
    end: endDate,
    allDay,
    location,
    notes: extractNotes(line, title),
    confidence,
    sourceLineIndex: lineIndex,
    sourceText: line,
    matchedKeywords: classification.matchedKeywords,
    dateMatches: [primaryDate]
  };

  return candidate;
}

/**
 * Generates a descriptive title for an event
 */
function generateEventTitle(line: string, type: EventType, keywords: string[]): string {
  // Try to extract a natural title from the line
  let title = line.trim();
  
  // Remove common prefixes
  title = title.replace(/^(due|deadline|submit|turn in|hand in)[\s:]+/i, '');
  
  // Clean up formatting
  title = title.replace(/\s*[-:]\s*due\s+.*/i, ''); // Remove "- due Friday" parts
  title = title.replace(/\s*\(.*?\)\s*/g, ' '); // Remove parenthetical content
  title = title.replace(/\s+/g, ' ').trim(); // Normalize whitespace
  
  // If the line is very short or doesn't contain the event type, generate a default
  if (title.length < 3 || !containsEventTypeKeywords(title, keywords)) {
    title = generateDefaultTitle(type, line);
  }
  
  // Limit title length
  if (title.length > 100) {
    title = title.substring(0, 97) + '...';
  }
  
  return title || `${type.charAt(0).toUpperCase() + type.slice(1).toLowerCase()}`;
}

/**
 * Checks if the title contains keywords related to the event type
 */
function containsEventTypeKeywords(title: string, keywords: string[]): boolean {
  const lowerTitle = title.toLowerCase();
  return keywords.some(keyword => lowerTitle.includes(keyword.toLowerCase()));
}

/**
 * Generates a default title when extraction fails
 */
function generateDefaultTitle(type: EventType, line: string): string {
  const typeWords = {
    ASSIGNMENT: 'Assignment',
    QUIZ: 'Quiz',
    MIDTERM: 'Midterm Exam',
    FINAL: 'Final Exam',
    LAB: 'Lab Session',
    LECTURE: 'Lecture',
    OTHER: 'Event'
  };
  
  // Try to extract a number or identifier
  const numberMatch = line.match(/\b(?:assignment|hw|quiz|lab|project|exam|test)\s*[#]?\s*(\d+|[ivx]+|[a-z])\b/i);
  if (numberMatch) {
    return `${typeWords[type]} ${numberMatch[1].toUpperCase()}`;
  }
  
  return typeWords[type];
}

/**
 * Determines if an event should be marked as all-day
 */
function isAllDayEvent(dateMatch: DateMatch, type: EventType, line: string): boolean {
  // Check both the date match text and the full line for time information
  const textToCheck = `${dateMatch.text} ${line}`.toLowerCase();
  
  // If the text has specific time information, it's not all-day
  if (textToCheck.match(/\b\d{1,2}:\d{2}\b/) || 
      textToCheck.match(/\b\d{1,2}\s*(am|pm)\b/i)) {
    return false;
  }
  
  // Assignments are typically all-day (due dates)
  if (type === 'ASSIGNMENT') {
    return true;
  }
  
  // For other types, default to all-day unless specific time is mentioned
  return true;
}

/**
 * Extracts location information from a line
 */
function extractLocation(line: string): string | undefined {
  // Common location patterns
  const locationPatterns = [
    /\b(?:room|classroom|hall|auditorium|lab|laboratory)\s+([a-z0-9\-\s]+)/i,
    /\b([a-z]+\s+\d+[a-z]?)\s*(?:room|hall)?/i,
    /\b(?:in|at|location:?)\s+([a-z0-9\-\s]+)/i
  ];
  
  for (const pattern of locationPatterns) {
    const match = line.match(pattern);
    if (match && match[1]) {
      const location = match[1].trim();
      // Validate it looks like a real location (not too long, has reasonable characters)
      if (location.length <= 50 && location.match(/^[a-z0-9\-\s]+$/i)) {
        return location;
      }
    }
  }
  
  return undefined;
}

/**
 * Extracts additional notes from the line, excluding the title
 */
function extractNotes(line: string, title: string): string | undefined {
  // Look for content after separators like " - ", " : ", etc.
  // Be more comprehensive in capturing content
  let separatorMatch = line.match(/[-:]\s*(.+)/i);
  if (separatorMatch && separatorMatch[1]) {
    let candidate = separatorMatch[1].trim();
    
    // Remove date information from the end
    candidate = candidate.replace(/\s*[-:]\s*due.*$/i, '');
    candidate = candidate.replace(/\s*[-:]\s*\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}.*$/i, '');
    candidate = candidate.replace(/\s*[-:]\s*\d{1,2}\/\d{1,2}\/\d{2,4}.*$/i, '');
    
    if (candidate.length > 3 && candidate.length < 200) {
      return candidate;
    }
  }
  
  // Alternative: look for content in parentheses or after keywords
  const parenthesesMatch = line.match(/\(([^)]+)\)/);
  if (parenthesesMatch && parenthesesMatch[1]) {
    const candidate = parenthesesMatch[1].trim();
    if (candidate.length > 3 && candidate.length < 100) {
      return candidate;
    }
  }
  
  // Look for content after "include", "with", "on", etc.
  const contextMatch = line.match(/\b(?:include|with|on|about|covering?s?)\s+(.+?)(?:\s*[-:]\s*due|\s*$)/i);
  if (contextMatch && contextMatch[1]) {
    const candidate = contextMatch[1].trim();
    if (candidate.length > 3 && candidate.length < 200) {
      return candidate;
    }
  }
  
  return undefined;
}

/**
 * Calculates overall confidence for an event candidate
 */
function calculateEventConfidence(
  classification: ClassificationResult,
  dateMatch: DateMatch,
  line: string
): number {
  let confidence = 0;
  
  // Base confidence from classification
  confidence += classification.confidence * 0.6;
  
  // Confidence from date match
  confidence += dateMatch.confidence * 0.3;
  
  // Bonus for having both strong type and date indicators
  if (classification.confidence > 0.7 && dateMatch.confidence > 0.7) {
    confidence += 0.1;
  }
  
  // Bonus for having contextual indicators
  if (classification.context.hasDueDate) confidence += 0.05;
  if (classification.context.hasWeight) confidence += 0.05;
  if (classification.context.hasNumbering) confidence += 0.05;
  
  // Penalty for very short lines (likely incomplete information)
  if (line.length < 20) {
    confidence *= 0.9;
  }
  
  // Penalty for negation
  if (classification.context.hasNegation) {
    confidence *= 0.5;
  }
  
  return Math.min(confidence, 1.0);
}

/**
 * Removes duplicate events based on similarity
 */
function deduplicateEvents(events: EventCandidate[]): EventCandidate[] {
  if (events.length <= 1) return events;
  
  const deduplicated: EventCandidate[] = [];
  
  for (const event of events) {
    const isDuplicate = deduplicated.some(existing => 
      eventsAreSimilar(event, existing)
    );
    
    if (!isDuplicate) {
      deduplicated.push(event);
    } else {
      // If it's a duplicate but has higher confidence, replace the existing one
      const existingIndex = deduplicated.findIndex(existing => 
        eventsAreSimilar(event, existing)
      );
      
      if (existingIndex !== -1 && event.confidence > deduplicated[existingIndex].confidence) {
        deduplicated[existingIndex] = event;
      }
    }
  }
  
  return deduplicated;
}

/**
 * Determines if two events are similar enough to be considered duplicates
 */
function eventsAreSimilar(event1: EventCandidate, event2: EventCandidate): boolean {
  // Same type
  if (event1.type !== event2.type) return false;

  const timeDiffMs = Math.abs(event1.start.getTime() - event2.start.getTime());
  const oneDayMs = 24 * 60 * 60 * 1000;
  const oneWeekMs = 7 * oneDayMs;

  const normalizedTitle1 = normalizeTitleForComparison(event1.title);
  const normalizedTitle2 = normalizeTitleForComparison(event2.title);

  // If source text is identical, treat as duplicates regardless of detected date variance
  if (event1.sourceText === event2.sourceText && normalizedTitle1 === normalizedTitle2) {
    return true;
  }

  // Exact/near-exact date match (within one day): fall through to fuzzy title compare
  if (timeDiffMs <= oneDayMs) {
    return titlesRoughlyMatch(event1, event2, true);
  }

  // Events with matching titles that fall within the same week window are usually
  // duplicate table entries (e.g. multiple lab sections). Collapse them.
  if (timeDiffMs <= oneWeekMs && normalizedTitle1 === normalizedTitle2) {
    return true;
  }

  // Otherwise only treat as same event if titles strongly match and share keywords
  if (timeDiffMs <= oneWeekMs) {
    return titlesRoughlyMatch(event1, event2, false);
  }

  return false;
}

function titlesRoughlyMatch(event1: EventCandidate, event2: EventCandidate, isExactDate: boolean): boolean {
  const similarityThreshold = isExactDate ? 0.5 : 0.85;
  const titleSimilarity = calculateStringSimilarity(event1.title, event2.title);

  if (titleSimilarity >= similarityThreshold) {
    return true;
  }

  const sharedKeywords = event1.matchedKeywords.filter(k1 =>
    event2.matchedKeywords.some(k2 => k1.toLowerCase() === k2.toLowerCase())
  );

  return sharedKeywords.length > 0;
}

function normalizeTitleForComparison(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Calculates string similarity using a simple algorithm
 */
function calculateStringSimilarity(str1: string, str2: string): number {
  const longer = str1.length > str2.length ? str1 : str2;
  const shorter = str1.length > str2.length ? str2 : str1;
  
  if (longer.length === 0) return 1.0;
  
  const editDistance = calculateEditDistance(longer, shorter);
  return (longer.length - editDistance) / longer.length;
}

/**
 * Calculates edit distance between two strings
 */
function calculateEditDistance(str1: string, str2: string): number {
  const matrix = Array(str2.length + 1)
    .fill(null)
    .map(() => Array(str1.length + 1).fill(null));
  
  for (let i = 0; i <= str1.length; i += 1) {
    matrix[0][i] = i;
  }
  
  for (let j = 0; j <= str2.length; j += 1) {
    matrix[j][0] = j;
  }
  
  for (let j = 1; j <= str2.length; j += 1) {
    for (let i = 1; i <= str1.length; i += 1) {
      const indicator = str1[i - 1] === str2[j - 1] ? 0 : 1;
      matrix[j][i] = Math.min(
        matrix[j][i - 1] + 1, // deletion
        matrix[j - 1][i] + 1, // insertion
        matrix[j - 1][i - 1] + indicator // substitution
      );
    }
  }
  
  return matrix[str2.length][str1.length];
}

/**
 * Generates a unique event ID
 */
function generateEventId(): string {
  const array = new Uint8Array(8);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Converts event candidates to EventItemDTO format
 * 
 * @param candidates Array of event candidates
 * @param config Configuration with course info
 * @returns Array of EventItemDTO objects
 */
export function candidatesToDTO(
  candidates: EventCandidate[], 
  config: EventBuilderConfig = {}
): EventItemDTO[] {
  return candidates.map(candidate => ({
    id: candidate.id,
    courseCode: candidate.courseCode ?? config.courseCode ?? '',
    type: candidate.type,
    title: candidate.title,
    start: formatUtcDateWithoutTimezone(candidate.start),
    end: candidate.end ? formatUtcDateWithoutTimezone(candidate.end) : undefined,
    allDay: candidate.allDay,
    location: candidate.location,
    notes: candidate.notes,
    confidence: candidate.confidence
  }));
}

/**
 * Analyzes event building results and returns statistics
 * 
 * @param events Array of event candidates
 * @param stats Building statistics
 * @returns Analysis results
 */
export function analyzeEventBuilding(events: EventCandidate[], stats: EventBuildingStats) {
  const analysis = {
    ...stats,
    typeDistribution: {} as Record<EventType, number>,
    confidenceDistribution: {
      high: 0, // >= 0.8
      medium: 0, // 0.5 - 0.8
      low: 0 // < 0.5
    },
    monthlyDistribution: {} as Record<string, number>,
    averageEventsPerLine: 0
  };

  // Calculate type distribution
  for (const type of ['ASSIGNMENT', 'QUIZ', 'MIDTERM', 'FINAL', 'LAB', 'LECTURE', 'OTHER'] as EventType[]) {
    analysis.typeDistribution[type] = events.filter(e => e.type === type).length;
  }

  // Calculate confidence distribution
  for (const event of events) {
    if (event.confidence >= 0.8) analysis.confidenceDistribution.high++;
    else if (event.confidence >= 0.5) analysis.confidenceDistribution.medium++;
    else analysis.confidenceDistribution.low++;
  }

  // Calculate monthly distribution
  for (const event of events) {
    const monthKey = event.start.toISOString().substring(0, 7); // YYYY-MM
    analysis.monthlyDistribution[monthKey] = (analysis.monthlyDistribution[monthKey] || 0) + 1;
  }

  // Calculate events per line ratio
  if (stats.totalLines > 0) {
    analysis.averageEventsPerLine = events.length / stats.totalLines;
  }

  return analysis;
}
