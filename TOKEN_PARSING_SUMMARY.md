# Claude Token Parsing in VibeMeter

## Overview

VibeMeter parses Claude Code usage logs to track token consumption. The app expects JSONL (JSON Lines) format files located in the `.claude/projects` directory.

## Token Parsing Architecture

### 1. **ClaudeLogManager** (Main Orchestrator)
- Manages access to Claude log files via security-scoped bookmarks
- Coordinates the scanning and parsing process
- Caches parsed results for 5 minutes to improve performance
- Uses SHA-256 hashing to detect file changes

### 2. **ClaudeLogFileScanner**
- Scans the `.claude/projects` directory for JSONL files
- Filters out files older than 30 days based on filename dates or modification time
- Returns files sorted by modification date (newest first)

### 3. **ClaudeCodeLogParser**
- The core parsing logic that supports multiple log formats
- Uses 4 different parsing strategies in order:
  1. Standard nested format (`message.usage`)
  2. Top-level usage format
  3. Claude Code specific formats
  4. Regex-based extraction as fallback

### 4. **ClaudeLogProcessor** (Background Actor)
- Processes files asynchronously for better performance
- Uses memory-mapped files for efficient reading
- Processes data in 64KB chunks to manage memory
- Skips files smaller than 100 bytes

## Supported Log Formats

### 1. Standard Nested Format (Original Claude API)
```json
{
  "timestamp": "2025-01-06T10:30:00.000Z",
  "model": "claude-3-5-sonnet",
  "message": {
    "usage": {
      "input_tokens": 100,
      "output_tokens": 50
    }
  }
}
```

### 2. Top-Level Usage Format
```json
{
  "timestamp": "2025-01-06T10:30:00.000Z",
  "model": "claude-3-5-sonnet",
  "usage": {
    "input_tokens": 100,
    "output_tokens": 50
  }
}
```

### 3. Claude Code Format with CamelCase
```json
{
  "timestamp": "2025-01-06T10:30:00.000Z",
  "model": "claude-3-5-sonnet",
  "message": {
    "usage": {
      "inputTokens": 100,
      "outputTokens": 50
    }
  }
}
```

### 4. Mixed Formats
The parser can handle:
- Both `input_tokens`/`output_tokens` and `inputTokens`/`outputTokens`
- Usage data at top level or nested in `message.usage`
- Additional fields that are ignored (type, event, metadata, etc.)

## Data Structure

### ClaudeLogEntry
```swift
struct ClaudeLogEntry {
    let timestamp: Date
    let model: String?
    let inputTokens: Int
    let outputTokens: Int
}
```

## Parsing Process

1. **File Discovery**
   - Looks for JSONL files in `~/.claude/projects/`
   - Filters files by age (30-day cutoff)
   - Sorts by modification date

2. **Line-by-Line Processing**
   - Each JSONL file contains one JSON object per line
   - Lines are processed individually
   - Non-relevant lines are skipped early (summary, user messages, etc.)

3. **Token Extraction**
   - First attempts structured JSON parsing
   - Falls back to regex extraction for malformed JSON
   - Supports multiple field name variations

4. **Filtering Rules**
   - Skip lines containing: `"type":"summary"`, `"type":"user"`, `leafUuid`, `sessionId`, `parentUuid`
   - Only process lines containing "tokens" or "Tokens"

## Performance Optimizations

1. **Caching**: 5-minute cache with SHA-256 file hashing
2. **Memory-mapped files**: For efficient large file reading
3. **Chunk processing**: 64KB chunks with autoreleasepool
4. **Early filtering**: Skip small files and non-token lines
5. **Parallel processing**: Background actor for async operations

## Error Handling

- Invalid JSON lines are skipped silently
- Missing token fields result in line being skipped
- Malformed timestamps use current date as fallback
- File access errors are logged but don't stop processing

## Usage in UI

The parsed data is:
- Grouped by day
- Used to calculate costs based on token pricing
- Displayed in the Claude Usage Report view
- Used for 5-hour window calculations for Pro/Max tiers