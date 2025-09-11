/**
 * Keyword classification utilities for syllabus parsing
 * 
 * Classifies text lines based on academic event types using comprehensive
 * keyword matching and contextual analysis to minimize AI usage.
 */

import type { EventType } from '../types/eventItem.js';

/**
 * Classification result for a line of text
 */
export interface ClassificationResult {
  /** The predicted event type */
  type: EventType;
  /** Confidence score 0-1 (higher = more certain) */
  confidence: number;
  /** Keywords that contributed to this classification */
  matchedKeywords: string[];
  /** Additional context information */
  context: {
    /** Whether due date indicators were found */
    hasDueDate: boolean;
    /** Whether weight/grading indicators were found */
    hasWeight: boolean;
    /** Whether negation was detected */
    hasNegation: boolean;
    /** Academic numbering detected (e.g., "1", "2", "#3") */
    hasNumbering: boolean;
  };
}

/**
 * Keyword sets for different event types with confidence weights
 */
const EVENT_KEYWORDS = {
  ASSIGNMENT: {
    primary: [
      // Core terms
      'assignment', 'homework', 'hw', 'project', 'paper', 'essay', 'report',
      'case study', 'problem set', 'problem sets', 'pset', 'exercise', 'task', 'work',
      
      // Academic variations
      'coursework', 'classwork', 'written assignment', 'take-home', 'takehome',
      'individual project', 'group project', 'team project', 'final project',
      'research paper', 'term paper', 'research project', 'thesis',
      
      // Common abbreviations
      'assgn', 'assn', 'assign', 'proj', 'hmwk'
    ],
    secondary: [
      'deliverable', 'submission', 'writeup', 'write-up', 'analysis',
      'reflection', 'response', 'review', 'summary', 'critique',
      'portfolio', 'journal', 'blog post', 'discussion post'
    ],
    weight: 0.9
  },
  
  QUIZ: {
    primary: [
      // Core terms
      'quiz', 'pop quiz', 'surprise quiz', 'quick quiz', 'mini quiz',
      'checkpoint', 'check', 'evaluation', 'review',
      
      // Variations
      'quiz bowl', 'knowledge check', 'comprehension check', 'quick check',
      'spot quiz', 'unannounced quiz', 'reading quiz', 'concept check',
      
      // Common abbreviations and slang
      'qz', 'q', 'pop-quiz'
    ],
    secondary: [
      'short test', 'mini test', 'brief assessment', 'quick assessment',
      'participation check', 'attendance quiz', 'prep quiz'
    ],
    weight: 0.88
  },
  
  MIDTERM: {
    primary: [
      // Core terms
      'midterm', 'mid-term', 'mid term', 'midterm exam', 'midterm test',
      'middle exam', 'halfway exam', 'semester exam', 'mid-semester exam',
      
      // Variations
      'midterm assessment', 'midterm evaluation', 'interim exam',
      'mid-quarter exam', 'mid-session exam', 'progress exam'
    ],
    secondary: [
      'comprehensive exam', 'major test', 'significant assessment'
    ],
    weight: 0.95
  },
  
  FINAL: {
    primary: [
      // Core terms
      'final', 'final exam', 'final test', 'final assessment',
      'final evaluation', 'comprehensive final', 'cumulative final',
      
      // Variations
      'end-of-term exam', 'semester final', 'course final',
      'final examination', 'terminal exam', 'culminating exam',
      'capstone exam', 'exit exam'
    ],
    secondary: [
      'comprehensive exam', 'cumulative test', 'course conclusion',
      'end assessment', 'closing exam'
    ],
    weight: 0.95
  },
  
  LAB: {
    primary: [
      // Core terms
      'lab', 'laboratory', 'lab session', 'lab work', 'lab report',
      'lab exercise', 'practical', 'practicum',
      
      // Variations
      'hands-on', 'hands on', 'workshop', 'studio', 'fieldwork',
      'field work', 'experiment', 'demonstration', 'demo',
      'computer lab', 'coding lab', 'programming lab',
      
      // Subject-specific
      'wet lab', 'dry lab', 'virtual lab', 'simulation'
    ],
    secondary: [
      'practice session', 'applied work', 'implementation',
      'technical session', 'skill building'
    ],
    weight: 0.85
  },
  
  LECTURE: {
    primary: [
      // Core terms
      'lecture', 'class', 'meeting', 'seminar',
      'presentation', 'lesson', 'instruction', 'teaching',
      
      // Variations  
      'class session', 'course meeting', 'academic session',
      'educational session', 'learning session', 'study session',
      'discussion', 'symposium', 'colloquium',
      
      // Online variations
      'webinar', 'online session', 'virtual class', 'zoom session',
      'video conference', 'live stream'
    ],
    secondary: [
      'tutorial', 'review session', 'office hours', 'consultation',
      'guest speaker', 'guest lecture', 'special session'
    ],
    weight: 0.75
  }
};

/**
 * Contextual keywords that modify classification confidence
 */
const CONTEXTUAL_KEYWORDS = {
  due_date: [
    // Due date indicators
    'due', 'deadline', 'submit', 'submission', 'turn in', 'hand in',
    'deliver', 'complete by', 'finish by', 'must be completed',
    'expected', 'required by', 'needed by', 'should be submitted',
    'upload by', 'post by', 'send by', 'email by'
  ],
  
  weight: [
    // Grading/weight indicators
    'worth', 'weight', 'weighted', 'percent', '%', 'points', 'pts',
    'grade', 'graded', 'scored', 'marks', 'credit', 'credits',
    'counts for', 'contributes', 'portion', 'percentage',
    'out of', 'total points', 'possible points'
  ],
  
  negation: [
    // Negation indicators
    'no', 'not', 'cancel', 'cancelled', 'postpone', 'postponed',
    'skip', 'skipped', 'omit', 'omitted', 'exclude', 'excluded',
    'except', 'unless', 'without', 'instead of', 'rather than'
  ],
  
  academic_terms: [
    // Academic context
    'course', 'class', 'subject', 'module', 'unit', 'chapter',
    'section', 'part', 'week', 'day', 'semester', 'quarter',
    'term', 'session', 'period', 'schedule', 'calendar',
    'syllabus', 'curriculum', 'program', 'study', 'academic'
  ]
};

/**
 * Academic numbering patterns (Assignment 1, Quiz #3, etc.)
 */
const NUMBERING_PATTERNS = [
  /\b(?:assignment|homework|hw|quiz|lab|project|paper|exam|test)\s*[#]?\s*(\d+|[ivx]+|[a-z])\b/gi,
  /\b(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\s+(?:assignment|homework|quiz|lab|project|exam|test)\b/gi,
  /\b(?:assignment|homework|quiz|lab|project|exam|test)\s+(one|two|three|four|five|six|seven|eight|nine|ten)\b/gi
];

/**
 * Classifies a line of text and returns the most likely event type with confidence
 * 
 * @param line The text line to classify (should be normalized)
 * @returns Classification result with type, confidence, and context
 */
export function classifyLine(line: string): ClassificationResult {
  if (typeof line !== 'string') {
    throw new TypeError('classifyLine expects a string input');
  }

  const normalizedLine = line.toLowerCase().trim();
  if (normalizedLine.length === 0) {
    return createEmptyResult();
  }

  // Check for negation first
  const hasNegation = CONTEXTUAL_KEYWORDS.negation.some(neg => 
    new RegExp(`\\b${escapeRegex(neg)}\\b`, 'i').test(normalizedLine)
  );

  // Get contextual indicators
  const context = analyzeContext(normalizedLine);
  context.hasNegation = hasNegation;

  // If negation is strong, return low confidence
  if (hasNegation && !hasStrongIndicators(normalizedLine)) {
    return {
      type: 'OTHER',
      confidence: 0.1,
      matchedKeywords: [],
      context
    };
  }

  // Score each event type
  const scores = scoreEventTypes(normalizedLine, context);
  
  // Find the best match
  const bestMatch = Object.entries(scores).reduce((best, [type, score]) => 
    score.confidence > best.confidence ? { type: type as EventType, ...score } : best,
    { type: 'OTHER' as EventType, confidence: 0, matchedKeywords: [] as string[] }
  );

  // Apply contextual bonuses
  const finalConfidence = applyContextualBonuses(bestMatch.confidence, context, normalizedLine);

  return {
    type: bestMatch.type,
    confidence: Math.min(finalConfidence, 1.0), // Cap at 1.0
    matchedKeywords: bestMatch.matchedKeywords,
    context
  };
}

/**
 * Scores all event types for a given line
 */
function scoreEventTypes(line: string, context: any): Record<string, { confidence: number; matchedKeywords: string[] }> {
  const scores: Record<string, { confidence: number; matchedKeywords: string[] }> = {};

  for (const [eventType, keywords] of Object.entries(EVENT_KEYWORDS)) {
    const result = scoreEventType(line, keywords);
    scores[eventType] = result;
  }

  return scores;
}

/**
 * Scores a specific event type against a line
 */
function scoreEventType(line: string, keywords: any): { confidence: number; matchedKeywords: string[] } {
  const matchedKeywords: string[] = [];
  let score = 0;
  let maxSingleScore = 0;

  // Check primary keywords (higher weight)
  for (const keyword of keywords.primary) {
    if (matchesKeyword(line, keyword)) {
      matchedKeywords.push(keyword);
      const keywordScore = calculateKeywordScore(keyword, line) * keywords.weight;
      score += keywordScore;
      maxSingleScore = Math.max(maxSingleScore, keywordScore);
    }
  }

  // Check secondary keywords (lower weight)
  for (const keyword of keywords.secondary || []) {
    if (matchesKeyword(line, keyword)) {
      matchedKeywords.push(keyword);
      const keywordScore = calculateKeywordScore(keyword, line) * keywords.weight * 0.7;
      score += keywordScore * 0.5; // Secondary keywords have less impact
    }
  }

  // Normalize score (prevent over-scoring from multiple keywords)
  // Give more weight to the best single match, but still reward multiple matches
  const confidence = Math.min(maxSingleScore + (score - maxSingleScore) * 0.3, 1.0);

  return { confidence, matchedKeywords };
}

/**
 * Checks if a keyword matches in the line (with word boundaries)
 */
function matchesKeyword(line: string, keyword: string): boolean {
  const lowerLine = line.toLowerCase();
  const lowerKeyword = keyword.toLowerCase();
  
  // Handle multi-word keywords
  if (keyword.includes(' ') || keyword.includes('-')) {
    // For multi-word phrases, be more flexible with spacing/punctuation
    const pattern = lowerKeyword.replace(/[-\s]+/g, '[-\\s]*');
    return new RegExp(`\\b${escapeRegex(pattern)}\\b`, 'i').test(lowerLine);
  }
  
  // Single word keywords - use word boundaries
  return new RegExp(`\\b${escapeRegex(lowerKeyword)}\\b`, 'i').test(lowerLine);
}

/**
 * Calculates score for a specific keyword based on length and context
 */
function calculateKeywordScore(keyword: string, line: string): number {
  let score = 0.6; // Higher base score
  
  // Longer, more specific keywords get higher scores
  if (keyword.length > 8) score += 0.3;
  else if (keyword.length > 5) score += 0.2;
  else if (keyword.length > 3) score += 0.1;

  // Multi-word keywords (more specific) get bonus
  if (keyword.includes(' ') || keyword.includes('-')) {
    score += 0.2;
  }

  // Keywords at the beginning of the line get slight bonus
  const wordBoundaryPattern = new RegExp(`^\\s*\\b${escapeRegex(keyword)}\\b`, 'i');
  if (wordBoundaryPattern.test(line)) {
    score += 0.1;
  }

  return Math.min(score, 1.0);
}

/**
 * Analyzes contextual indicators in the line
 */
function analyzeContext(line: string): ClassificationResult['context'] {
  const lowerLine = line.toLowerCase();
  const context = {
    hasDueDate: false,
    hasWeight: false,
    hasNegation: false,
    hasNumbering: false
  };

  // Check for due date indicators with simpler matching
  context.hasDueDate = CONTEXTUAL_KEYWORDS.due_date.some(keyword => 
    lowerLine.includes(keyword.toLowerCase())
  );

  // Check for weight indicators
  context.hasWeight = CONTEXTUAL_KEYWORDS.weight.some(keyword => 
    lowerLine.includes(keyword.toLowerCase()) || 
    new RegExp(`\\b${escapeRegex(keyword)}\\b`, 'i').test(line)
  );

  // Check for academic numbering with simpler patterns first
  const simpleNumberPatterns = [
    /\b(?:assignment|homework|hw|quiz|lab|project|paper|exam|test)\s*[#]?\s*\d+\b/gi,
    /\b(?:assignment|homework|quiz|lab|project|exam|test)\s+\d+\b/gi
  ];
  
  context.hasNumbering = simpleNumberPatterns.some(pattern => pattern.test(line)) ||
    NUMBERING_PATTERNS.some(pattern => {
      pattern.lastIndex = 0; // Reset regex state
      return pattern.test(line);
    });

  return context;
}

/**
 * Applies contextual bonuses to the base confidence score
 */
function applyContextualBonuses(baseConfidence: number, context: ClassificationResult['context'], line: string): number {
  let confidence = baseConfidence;

  // Due date indicators boost confidence (suggests actionable item)
  if (context.hasDueDate) {
    confidence += 0.15;
  }

  // Weight indicators boost confidence (suggests graded item)
  if (context.hasWeight) {
    confidence += 0.1;
  }

  // Academic numbering boosts confidence
  if (context.hasNumbering) {
    confidence += 0.1;
  }

  // Line length penalties for very short lines (likely incomplete info)
  if (line.length < 10) {
    confidence *= 0.8;
  } else if (line.length < 5) {
    confidence *= 0.5;
  }

  return confidence;
}

/**
 * Checks if the line has strong enough indicators to override negation
 */
function hasStrongIndicators(line: string): boolean {
  // Look for very specific academic terms that suggest legitimate content
  const strongPatterns = [
    /\b(?:assignment|quiz|exam|test|lab)\s*[#]?\s*\d+\b/i,
    /\bdue\s+(?:date|by|on)\b/i,
    /\bworth\s+\d+(?:%|percent|points)\b/i
  ];

  return strongPatterns.some(pattern => pattern.test(line));
}

/**
 * Creates an empty/default classification result
 */
function createEmptyResult(): ClassificationResult {
  return {
    type: 'OTHER',
    confidence: 0,
    matchedKeywords: [],
    context: {
      hasDueDate: false,
      hasWeight: false,
      hasNegation: false,
      hasNumbering: false
    }
  };
}

/**
 * Escapes special regex characters
 */
function escapeRegex(string: string): string {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Classifies multiple lines and returns results with line numbers
 * 
 * @param lines Array of text lines to classify
 * @returns Array of classification results with line indices
 */
export function classifyLines(lines: string[]): Array<ClassificationResult & { lineIndex: number; originalText: string }> {
  return lines.map((line, index) => ({
    ...classifyLine(line),
    lineIndex: index,
    originalText: line
  }));
}

/**
 * Statistics about classification results
 */
export interface ClassificationStats {
  /** Total lines classified */
  totalLines: number;
  /** Lines classified as each type */
  typeDistribution: Record<EventType, number>;
  /** Average confidence score */
  averageConfidence: number;
  /** Lines with high confidence (>= 0.7) */
  highConfidenceLines: number;
  /** Lines with low confidence (<= 0.3) */
  lowConfidenceLines: number;
  /** Most common keywords found */
  topKeywords: Array<{ keyword: string; count: number }>;
}

/**
 * Analyzes classification results and returns statistics
 * 
 * @param results Array of classification results
 * @returns Statistical analysis of the classifications
 */
export function analyzeClassificationResults(results: ClassificationResult[]): ClassificationStats {
  const stats: ClassificationStats = {
    totalLines: results.length,
    typeDistribution: {
      ASSIGNMENT: 0,
      QUIZ: 0,
      MIDTERM: 0,
      FINAL: 0,
      LAB: 0,
      LECTURE: 0,
      OTHER: 0
    },
    averageConfidence: 0,
    highConfidenceLines: 0,
    lowConfidenceLines: 0,
    topKeywords: []
  };

  if (results.length === 0) {
    return stats;
  }

  // Count by type and calculate confidence stats
  let totalConfidence = 0;
  const keywordCounts = new Map<string, number>();

  for (const result of results) {
    stats.typeDistribution[result.type]++;
    totalConfidence += result.confidence;

    if (result.confidence >= 0.7) stats.highConfidenceLines++;
    if (result.confidence <= 0.3) stats.lowConfidenceLines++;

    // Count keywords
    for (const keyword of result.matchedKeywords) {
      keywordCounts.set(keyword, (keywordCounts.get(keyword) || 0) + 1);
    }
  }

  stats.averageConfidence = totalConfidence / results.length;

  // Get top keywords
  stats.topKeywords = Array.from(keywordCounts.entries())
    .map(([keyword, count]) => ({ keyword, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 10);

  return stats;
}
