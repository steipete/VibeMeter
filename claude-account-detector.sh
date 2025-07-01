#!/bin/bash
# Claude Code Account Detection Script
# This script attempts to detect which account is currently logged in to Claude Code

echo "Claude Code Account Detection"
echo "============================"
echo ""

# Method 1: Check if Claude is outputting logs to stdout/stderr
echo "Method 1: Checking Claude process output..."
CLAUDE_PIDS=$(ps aux | grep "claude" | grep -v grep | awk '{print $2}')

if [ -n "$CLAUDE_PIDS" ]; then
    echo "Found Claude processes: $CLAUDE_PIDS"
    
    # Try to sample output using dtrace (requires sudo on macOS)
    echo ""
    echo "To capture Claude output, run:"
    echo "sudo dtrace -p <PID> -n 'syscall::write:entry /pid == \$target/ { printf(\"%s\", copyinstr(arg1)); }'"
    echo ""
fi

# Method 2: Check for any temporary files
echo "Method 2: Checking temporary files..."
TEMP_FILES=$(find /tmp /var/tmp ~/Library/Caches -name "*claude*" -type f 2>/dev/null | head -10)

if [ -n "$TEMP_FILES" ]; then
    echo "Found temporary files:"
    echo "$TEMP_FILES"
    echo ""
    echo "Searching for email patterns..."
    for file in $TEMP_FILES; do
        if [ -r "$file" ]; then
            EMAILS=$(grep -E -o '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b' "$file" 2>/dev/null | sort -u)
            if [ -n "$EMAILS" ]; then
                echo "Found in $file:"
                echo "$EMAILS"
            fi
        fi
    done
fi

# Method 3: Create a monitoring wrapper
echo ""
echo "Method 3: Creating monitoring wrapper..."

WRAPPER_DIR="$HOME/.local/bin"
mkdir -p "$WRAPPER_DIR"

cat > "$WRAPPER_DIR/claude-monitor" << 'EOF'
#!/bin/bash
# Claude Code monitoring wrapper
# This captures startup output to detect the logged-in user

CLAUDE_CMD="${CLAUDE_CMD:-claude}"
LOG_DIR="/tmp/claude-monitor"
mkdir -p "$LOG_DIR"

# Generate unique log file for this session
SESSION_ID="$$-$(date +%s)"
LOG_FILE="$LOG_DIR/session-$SESSION_ID.log"
USER_FILE="$LOG_DIR/current-user.txt"

echo "Starting Claude monitor (session: $SESSION_ID)" >&2
echo "Log file: $LOG_FILE" >&2

# Start Claude with output capture
{
    # Run Claude and capture all output
    $CLAUDE_CMD "$@" 2>&1 | tee "$LOG_FILE"
} &
CLAUDE_PID=$!

# Monitor the log file for user information
{
    sleep 2  # Give Claude time to start
    
    # Continuously monitor for email patterns
    tail -f "$LOG_FILE" 2>/dev/null | while read line; do
        # Look for email patterns
        EMAIL=$(echo "$line" | grep -E -o '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b' | head -1)
        if [ -n "$EMAIL" ]; then
            echo "$EMAIL" > "$USER_FILE"
            echo "Detected user: $EMAIL" >&2
            break
        fi
        
        # Also look for "user": "email" patterns in JSON
        JSON_EMAIL=$(echo "$line" | grep -E -o '"user"\s*:\s*"([^"]+@[^"]+)"' | sed -E 's/.*"user"\s*:\s*"([^"]+)"/\1/')
        if [ -n "$JSON_EMAIL" ]; then
            echo "$JSON_EMAIL" > "$USER_FILE"
            echo "Detected user: $JSON_EMAIL" >&2
            break
        fi
    done
} &
MONITOR_PID=$!

# Wait for Claude to finish
wait $CLAUDE_PID
EXIT_CODE=$?

# Clean up monitor
kill $MONITOR_PID 2>/dev/null

# Show detected user if found
if [ -f "$USER_FILE" ]; then
    echo ""
    echo "Detected Claude user: $(cat $USER_FILE)" >&2
fi

exit $EXIT_CODE
EOF

chmod +x "$WRAPPER_DIR/claude-monitor"

echo "Monitoring wrapper created at: $WRAPPER_DIR/claude-monitor"
echo ""
echo "To use it:"
echo "1. Add to your shell configuration:"
echo "   export PATH=\"$WRAPPER_DIR:\$PATH\""
echo "   alias claude='claude-monitor'"
echo ""
echo "2. Or run directly:"
echo "   $WRAPPER_DIR/claude-monitor"
echo ""
echo "The wrapper will detect and save the current user to:"
echo "   /tmp/claude-monitor/current-user.txt"
echo ""

# Method 4: Check if we can intercept network requests
echo "Method 4: Network monitoring suggestion..."
echo "You could also monitor network traffic to claude.ai to see authentication headers:"
echo "   sudo tcpdump -i any -A 'host claude.ai and port 443'"
echo ""
echo "Note: This requires root access and may show sensitive data."

# Method 5: Direct detection attempt
echo ""
echo "Method 5: Attempting direct detection..."

# Try to trigger Claude to output something that might contain user info
CLAUDE_VERSION=$(claude --version 2>&1)
echo "Claude version output: $CLAUDE_VERSION"

# Check if there are any environment variables that might contain user info
echo ""
echo "Checking environment variables..."
env | grep -i "claude\|anthropic\|user\|email" | grep -v "PATH"

echo ""
echo "Detection complete."
echo ""
echo "Best approach: Use the monitoring wrapper (Method 3) for future Claude sessions."