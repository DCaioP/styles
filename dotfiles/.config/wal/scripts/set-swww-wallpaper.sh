#!/bin/bash

# Script to set wallpaper using swww based on pywal's cache
# This script is meant to be called with: wal -i <image> -o ~/.config/wal/scripts/set-swww-wallpaper.sh

# Exit on error
set -e

# Check if swww is installed
if ! command -v swww &> /dev/null; then
    echo "Error: swww is not installed. Please install it first."
    exit 1
fi

# Check if swww daemon is running
if ! pgrep -x "swww-daemon" > /dev/null; then
    echo "Starting swww daemon..."
    swww init || {
        echo "Failed to start swww daemon. Please check if your Wayland compositor is running."
        exit 1
    }
fi

# Wait a moment for daemon to initialize
sleep 0.5

# Get the wallpaper path from wal cache
WAL_CACHE_FILE="$HOME/.cache/wal/wal"

if [ ! -f "$WAL_CACHE_FILE" ]; then
    echo "Error: Wal cache file not found at $WAL_CACHE_FILE"
    exit 1
fi

# Read the wallpaper path from the cache file
WALLPAPER=$(cat "$WAL_CACHE_FILE")

if [ -z "$WALLPAPER" ]; then
    echo "Error: Could not find wallpaper path in $WAL_CACHE_FILE"
    exit 1
fi

if [ ! -f "$WALLPAPER" ]; then
    echo "Error: Wallpaper file does not exist: $WALLPAPER"
    exit 1
fi

echo "Setting wallpaper to: $WALLPAPER"

# Set the wallpaper using swww
swww img "$WALLPAPER" \
    --transition-type grow \
    --transition-pos center \
    --transition-duration 1.5

echo "Wallpaper set successfully!"
exit 0

