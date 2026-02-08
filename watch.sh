#!/bin/bash

# Watch for file changes and rebuild
echo "Watching for changes..."

# Initial build
mage build

# Start the server in background with logging
./bin/livekit-server --dev 2>&1 | tee server.log &
SERVER_PID=$!

# Watch for go file changes
fswatch -o --exclude='.*_test\.go$' --exclude='mage_output_file\.go$' pkg/ cmd/ | while read change; do
    echo "Changes detected, rebuilding..."
    
    # Kill old server
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    
    # Rebuild
    mage build
    
    # Restart server with logging
    ./bin/livekit-server --dev 2>&1 | tee -a server.log &
    SERVER_PID=$!
done
