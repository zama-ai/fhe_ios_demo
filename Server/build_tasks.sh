#!/bin/bash
set -e

TASKS_DIR="tasks"
BIN_DIR="/build/bin"

# Create bin directory
mkdir -p "$BIN_DIR"

# Get the list of tasks (directories in tasks/)
TASKS=$(find "$TASKS_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n")

echo "=============="
echo -e "Tasks list:\n$TASKS"
echo "=============="

# Build each task
for task in $TASKS; do
    cd "/build/$TASKS_DIR/$task"

    # Rust task
    if [ -f "Cargo.toml" ]; then

        echo "Building Rust task: $task"

        # Build the Rust task
        cargo build --release

        # Determine binary name from the task directory name
        BINARY_NAME="$task"
        
        # Copy the binary to the bin directory
        cp "target/release/$BINARY_NAME" "$BIN_DIR/"
        
    # Python task
    elif [ -f "src/main.py" ]; then
       
        echo "Python task: $task"

        # Make the Python file executable
        PYTHON_FILE="src/main.py"
        chmod +x "$PYTHON_FILE"

        # Copy the binary to the bin directory
        cp "$PYTHON_FILE" "$BIN_DIR/$task.py"
    else
        echo "Unknown task type for: $task. Skipping."
    fi
    
done
