/**
 * Text normalization utilities for syllabus parsing
 * 
 * Provides text cleaning functions to prepare raw syllabus text
 * for consistent parsing by downstream heuristics and AI models.
 */

/**
 * Normalizes text by cleaning whitespace, Unicode normalization,
 * and merging broken lines from PDF extraction.
 * 
 * Performs the following transformations:
 * 1. Unicode normalization (NFC) for consistent character encoding
 * 2. Trim leading/trailing whitespace from the entire text
 * 3. Collapse multiple consecutive spaces into single spaces
 * 4. Merge broken lines that were split during PDF extraction
 * 5. Normalize line endings to \n
 * 
 * @param text Raw text input from PDF extraction or user input
 * @returns Cleaned and normalized text ready for parsing
 */
export function normalizeText(text: string): string {
  if (typeof text !== 'string') {
    throw new TypeError('normalizeText expects a string input');
  }

  // Step 1: Unicode normalization (NFC - Canonical Decomposition followed by Canonical Composition)
  // This ensures consistent encoding for accented characters, ligatures, etc.
  let normalized = text.normalize('NFC');

  // Step 2: Normalize line endings to \n (handle Windows \r\n and old Mac \r)
  normalized = normalized.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

  // Step 3: Handle broken lines from PDF extraction
  // Apply these patterns in a specific order to avoid conflicts
  
  // 1. Merge hyphenated words that are broken across lines (highest priority)
  // Pattern: word ending with hyphen + newline + word starting with lowercase
  normalized = normalized.replace(/([a-zA-Z])-\s*\n\s*([a-z])/g, '$1$2');
  
  // 2. Merge words that appear to be broken in the middle (like "assign\nment")
  // Look for word boundaries to be more precise, but avoid merging complete words
  normalized = normalized.replace(/\b([a-z]{2,})\s*\n\s*([a-z]{2,})\b/g, (match, first, second) => {
    // Only merge if it looks like a broken word, not two separate words
    // Heuristics: combined length reasonable, and at least one part is not a common word
    const combinedLength = first.length + second.length;
    if (combinedLength <= 15 && combinedLength >= 6) {
      // Avoid merging common word combinations like "sentence that"
      const commonWords = new Set(['the', 'that', 'this', 'and', 'but', 'for', 'with', 'from', 'are', 'were', 'was', 'has', 'have', 'can', 'will', 'may', 'should', 'could', 'would', 'here', 'there', 'when', 'where', 'what', 'how', 'why', 'who']);
      if (commonWords.has(second.toLowerCase())) {
        return match; // Don't merge if second part is a common word
      }
      return first + second;
    }
    return match;
  });
  
  // 3. Merge sentence continuations (lowest priority)
  // First handle cases where line ends with preposition/article and next starts with capital
  normalized = normalized.replace(/\b(to|the|a|an|in|on|at|of|for|with|from|by|and|or)\s*\n\s*([A-Z]\S*)/g, '$1 $2');
  
  // Then handle regular sentence continuations (next line starts with lowercase)
  normalized = normalized.replace(/(\S+)\s*\n\s*([a-z]\S*)/g, (match, lastWord, nextWord) => {
    // Don't merge if both parts look like separate identifiers/labels
    // e.g., "line1" and "line2", "item1" and "item2"
    if (lastWord.match(/^[a-z]+[0-9]+$/i) && nextWord.match(/^[a-z]+[0-9]*$/)) {
      return match;
    }
    
    // For other cases, merge with a space
    return lastWord + ' ' + nextWord;
  });

  // Step 4: Collapse multiple consecutive whitespace characters
  // Replace sequences of spaces, tabs, and other whitespace with single space
  normalized = normalized.replace(/[ \t]+/g, ' ');
  
  // Step 5: Collapse multiple consecutive newlines (but preserve paragraph breaks)
  // Keep maximum of 2 consecutive newlines to preserve intentional paragraph breaks
  normalized = normalized.replace(/\n{3,}/g, '\n\n');

  // Step 6: Clean up whitespace around newlines
  // Remove trailing spaces at end of lines
  normalized = normalized.replace(/[ \t]+\n/g, '\n');
  // Remove leading spaces at beginning of lines (except for intended indentation)
  normalized = normalized.replace(/\n[ \t]+/g, '\n');

  // Step 7: Final trim of leading and trailing whitespace
  normalized = normalized.trim();

  return normalized;
}

/**
 * Splits normalized text into clean lines, removing empty lines
 * and providing consistent line-by-line processing.
 * 
 * @param text Normalized text (typically output from normalizeText)
 * @returns Array of non-empty, trimmed lines
 */
export function splitIntoLines(text: string): string[] {
  return text
    .split('\n')
    .map(line => line.trim())
    .filter(line => line.length > 0);
}

/**
 * Extracts text blocks separated by blank lines, useful for
 * identifying course sections, assignment blocks, etc.
 * 
 * @param text Normalized text
 * @returns Array of text blocks (paragraphs/sections)
 */
export function extractTextBlocks(text: string): string[] {
  return text
    .split(/\n\s*\n/)
    .map(block => block.trim())
    .filter(block => block.length > 0);
}

/**
 * Statistics about the normalized text, useful for diagnostics
 * and quality assessment.
 */
export interface TextStats {
  /** Total character count */
  characterCount: number;
  /** Number of lines */
  lineCount: number;
  /** Number of text blocks/paragraphs */
  blockCount: number;
  /** Average characters per line */
  avgCharsPerLine: number;
  /** Estimated reading complexity (simple heuristic) */
  complexity: 'low' | 'medium' | 'high';
}

/**
 * Analyzes normalized text and returns statistics for diagnostics.
 * 
 * @param text Normalized text
 * @returns Statistical analysis of the text
 */
export function analyzeText(text: string): TextStats {
  const lines = splitIntoLines(text);
  const blocks = extractTextBlocks(text);
  const characterCount = text.length;
  const lineCount = lines.length;
  const blockCount = blocks.length;
  const avgCharsPerLine = lineCount > 0 ? characterCount / lineCount : 0;
  
  // Simple complexity heuristic based on average line length
  let complexity: 'low' | 'medium' | 'high';
  if (avgCharsPerLine < 40) {
    complexity = 'low';
  } else if (avgCharsPerLine < 80) {
    complexity = 'medium';
  } else {
    complexity = 'high';
  }

  return {
    characterCount,
    lineCount,
    blockCount,
    avgCharsPerLine: Math.round(avgCharsPerLine * 100) / 100, // Round to 2 decimals
    complexity,
  };
}
