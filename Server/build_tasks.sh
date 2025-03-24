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
        cp -r "target/release/$BINARY_NAME" "$BIN_DIR/"

        # echo "Testing $task Python module"
        # maturin develop --release --manifest-path tasks/$task/Cargo.toml

    # Python task
    elif ls src/*.py >/dev/null 2>&1; then
        for python_file in src/*.py; do
            filename=$(basename "$python_file" .py)
            echo "Python task: $task.$filename"
            # Make the Python file executable
            chmod +x "$python_file"
            # Copy the binary to the bin directory
            cp "$python_file" "$BIN_DIR/$filename.py"
        done
    else
        echo "Unknown task type for: $task. Skipping."
    fi
done
