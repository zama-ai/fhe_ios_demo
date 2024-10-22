#!/bin/bash
set -e

TASKS_DIR="tasks"
BIN_DIR="/build/bin"

# Create bin directory
mkdir -p "$BIN_DIR"

# Get the list of tasks (directories in tasks/)
TASKS=$(find "$TASKS_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n")

# Build each task
for task in $TASKS; do
    echo "Building task: $task"
    cd "/build/$TASKS_DIR/$task"

    # Build the task
    cargo build --release
    
    # Copy the binary to the bin directory
    BINARY_NAME="$task"
    cp "target/release/$BINARY_NAME" "$BIN_DIR/"
done
