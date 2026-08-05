#!/bin/bash
# Build the Workouts for Hevy app for the Venu 2 simulator.
set -e
SDK="$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0"
export PATH="$SDK/bin:$PATH"
cd "$(dirname "$0")"
mkdir -p bin
monkeyc -w -d venu2 -f monkey.jungle -o bin/HevyWorkout.prg -y developer_key.der "$@"
echo "OK -> bin/HevyWorkout.prg"
