# Token Parsing Fix Summary

## Problem
The ClaudeCodeLogParser was returning 0 tokens even though the log files contained valid token data. The ccost app was able to parse the same logs correctly.

## Root Cause
The parser was looking for the wrong JSON structure. The actual Claude Code log format has tokens inside `message.usage` with snake_case field names:

```json
{
  "timestamp": "2025-06-03T21:55:26.847Z",
  "version": "1.0.10",
  "message": {
    "model": "claude-sonnet-4-20250514",
    "usage": {
      "input_tokens": 4,
      "output_tokens": 2,
      "cache_creation_input_tokens": 6755,
      "cache_read_input_tokens": 10177
    }
  },
  "costUSD": 0.123
}
```

## Changes Made

### 1. Updated ClaudeCodeLogParser.swift
- Fixed the log line filtering to check for `message.usage` structure
- Updated `parseClaudeCodeFormat` to match the actual log structure
- Added support for cache tokens (cache_creation_input_tokens, cache_read_input_tokens)
- Added support for costUSD field

### 2. Updated ClaudeUsageData.swift (ClaudeLogEntry model)
- Added `cacheCreationTokens: Int?` field
- Added `cacheReadTokens: Int?` field  
- Added `costUSD: Double?` field
- Updated Codable implementation to handle these new fields
- Updated convenience initializer with default parameters

### 3. Updated ClaudeDailyUsage aggregate properties
- Added `totalCacheCreationTokens` computed property
- Added `totalCacheReadTokens` computed property
- Updated `totalTokens` to include cache tokens

## Key Differences from Previous Implementation
1. The parser was looking for camelCase field names (inputTokens) instead of snake_case (input_tokens)
2. The parser wasn't looking in the correct nested structure (message.usage)
3. The model didn't support cache tokens or costUSD fields that are present in the logs

## Testing
The fix should now correctly parse:
- Regular input/output tokens
- Cache creation tokens
- Cache read tokens  
- Cost USD field
- Model information

All token counts should now match what ccost reports.

## Cache Invalidation
The fix includes automatic cache invalidation to ensure old cached data is cleared when the parser format changes:

- Added `currentCacheVersion = 2` in ClaudeLogManager
- Cache is automatically cleared on app startup if the version is outdated
- This ensures users will see the correct token counts immediately after updating
- The cache versioning system prevents stale data from being shown after parser updates