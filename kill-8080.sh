#!/bin/bash
# Kill process using port 8080

PORT=8080

echo "Checking for processes using port $PORT..."

# Find the process using the port
PID=$(lsof -ti:$PORT 2>/dev/null)

if [ -n "$PID" ]; then
    # Skip system processes
    if [ "$PID" -le 4 ]; then
        echo "Port is used by system process (PID: $PID), cannot kill"
        exit 1
    fi

    # Get process name
    PROCESS_NAME=$(ps -p "$PID" -o comm= 2>/dev/null)

    if [ -n "$PROCESS_NAME" ]; then
        echo "Found process: $PROCESS_NAME (PID: $PID)"
        echo "Killing process..."

        kill -9 "$PID"

        # Small delay to allow kill to complete
        sleep 0.5

        # Verify the process is killed
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Failed to kill process"
            exit 1
        else
            echo "Process killed successfully"
        fi
    else
        echo "Could not find process details"
        exit 1
    fi
else
    echo "No process is using port $PORT"
fi
