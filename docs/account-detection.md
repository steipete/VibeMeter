# Claude Code Account Detection

This document describes the investigation and solutions developed for detecting which user account is currently logged into Claude Code when using the Entropic Max subscription with multiple email addresses.

## Investigation Summary

### Key Findings

1. **No Direct User Storage**: Claude Code doesn't store user email addresses in easily accessible configuration files or standard logs.

2. **Session Management**: Claude uses anonymous session IDs stored in `~/.claude/statsig/`, but these don't contain user identifiers.

3. **Runtime Detection Required**: User information is only available in Claude's runtime output during authentication or startup.

### Locations Investigated

- `~/.config/claude/` - Contains MCP server configurations, no user data
- `~/.claude/` - Contains project data, todos, and anonymous session IDs
- `~/.claude/statsig/` - Session tracking with anonymous IDs only
- `~/Library/Logs/` - No Claude Code specific logs found
- Keychain - No Claude credentials stored
- Environment variables - No user information exposed
- Process memory - Would require elevated permissions to access

## Detection Solutions

### 1. Monitoring Wrapper Script

Created a wrapper script that intercepts Claude Code's output to detect user information.

**Location**: `~/.local/bin/claude-monitor`

**How it works**:
- Wraps the Claude command and captures all output
- Monitors for email patterns in the output stream
- Saves detected user to `/tmp/claude-monitor/current-user.txt`
- Runs Claude normally while capturing output in the background

**Installation**:
```bash
# Add to your shell configuration (.zshrc or .bashrc)
export PATH="$HOME/.local/bin:$PATH"
alias claude='claude-monitor'
```

### 2. Detection Script

Created a comprehensive detection script that provides multiple methods for finding the current user.

**Location**: `/Users/steipete/Projects/VibeMeter/claude-account-detector.sh`

**Methods**:
1. Process output monitoring using dtrace (requires sudo)
2. Temporary file scanning for email patterns
3. Monitoring wrapper installation
4. Network traffic analysis suggestions
5. Direct detection attempts

### 3. Swift Integration (Started)

Began implementing `MultiAccountDetector.swift` to integrate account detection into VibeMeter:
- Process monitoring to find running Claude instances
- Pattern matching for email addresses in process output
- Temporary file scanning for session data
- Continuous monitoring capabilities

## Implementation Details

### Monitoring Wrapper Features

The wrapper script:
- Captures both stdout and stderr from Claude
- Uses pattern matching for email addresses
- Monitors JSON output for `"user": "email"` patterns
- Cleans up temporary files after Claude exits
- Maintains the original Claude exit code

### Pattern Detection

Email patterns searched:
- Standard email regex: `\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b`
- JSON user fields: `"user"\s*:\s*"([^"]+@[^"]+)"`

### Integration with VibeMeter

VibeMeter already has:
- `MultiAccountDetector` class for session detection based on usage patterns
- `ClaudeSessionTracker` for tracking Claude sessions
- UI components (`MultiAccountSessionsView`) for displaying multiple sessions

The new detection capabilities would enhance this by:
- Providing actual user email addresses instead of just session fingerprints
- Enabling automatic account switching suggestions
- Improving multi-account usage tracking

## Recommendations

### For Immediate Use

1. **Use the monitoring wrapper** for all new Claude sessions:
   ```bash
   claude-monitor  # Instead of claude
   ```

2. **Check detected user**:
   ```bash
   cat /tmp/claude-monitor/current-user.txt
   ```

### For Future Development

1. **Enhance VibeMeter** to read from `/tmp/claude-monitor/current-user.txt`
2. **Implement process monitoring** in Swift for real-time detection
3. **Add account name labels** to detected sessions in the UI
4. **Create automated account switching** suggestions based on usage limits

## Technical Challenges

1. **No persistent user storage**: Claude Code doesn't maintain user information between sessions
2. **Process isolation**: Cannot easily read output from already-running Claude processes
3. **Security restrictions**: macOS security prevents reading other process memory without elevated permissions
4. **Dynamic detection**: Must capture information during Claude startup/authentication

## Conclusion

While Claude Code doesn't provide direct access to the logged-in user information, the monitoring wrapper approach provides a practical solution for detecting which account is active. This enables VibeMeter to track multi-account usage and provide better insights for users managing multiple Claude subscriptions.