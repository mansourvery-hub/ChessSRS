#!/bin/bash
# Chess Repertoire SRS - Beta Testing Startup Script
# Usage: ./start.sh [debug|profile|release|web] [device_id]

set -e

# Default values
MODE="${1:-debug}"
DEVICE_ID="${2:-}"
FLUTTER_CMD="flutter"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if flutter is available
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        # Check FVM
        if [ -d "$HOME/fvm/default/bin" ]; then
            export PATH="$HOME/fvm/default/bin:$PATH"
            FLUTTER_CMD="flutter"
            log_info "Using Flutter from FVM: $($FLUTTER_CMD --version | head -1)"
        else
            log_error "Flutter not found in PATH and FVM not found at ~/fvm/default/bin"
            exit 1
        fi
    else
        FLUTTER_CMD="flutter"
        log_info "Using Flutter from PATH: \$($FLUTTER_CMD --version | head -1)"
    fi
}

# Check if we're in the right directory
check_project() {
    if [ ! -f "pubspec.yaml" ]; then
        log_error "pubspec.yaml not found. Run this script from the project root."
        exit 1
    fi
    log_info "Project found: $(grep '^name:' pubspec.yaml | cut -d' ' -f2)"
}

# Check for required system dependencies
check_dependencies() {
    # Skip dependency check for web mode
    if [ "$MODE" = "web" ]; then
        return 0
    fi
    
    local missing_deps=()
    
    # Check for CMake (required for Linux desktop)
    if ! command -v cmake &> /dev/null; then
        missing_deps+=("cmake")
    fi
    
    # Check for ninja (recommended for faster builds)
    if ! command -v ninja &> /dev/null; then
        missing_deps+=("ninja")
    fi
    
    # Check for GTK3 development libraries (Linux desktop)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if ! pkg-config --exists gtk+-3.0 2>/dev/null; then
            missing_deps+=("gtk3 development libraries (libgtk-3-dev / gtk3)")
        fi
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warn "Missing system dependencies: ${missing_deps[*]}"
        log_warn "Install them with your package manager:"
        log_warn "  Ubuntu/Debian: sudo apt install ${missing_deps[*]}"
        log_warn "  Arch: sudo pacman -S ${missing_deps[*]}"
        log_warn "  Fedora: sudo dnf install ${missing_deps[*]}"
        echo
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check if we're in the right directory
check_project() {
    if [ ! -f "pubspec.yaml" ]; then
        log_error "pubspec.yaml not found. Run this script from the project root."
        exit 1
    fi
    log_info "Project found: $(grep '^name:' pubspec.yaml | cut -d' ' -f2)"
}

# Get available devices
get_devices() {
    log_info "Detecting available devices..."
    $FLUTTER_CMD devices 2>/dev/null || true
}

# Select device
select_device() {
    if [ -n "$DEVICE_ID" ]; then
        log_info "Using specified device: $DEVICE_ID"
        return
    fi

    # Try to auto-detect a suitable device
    DEVICES=$($FLUTTER_CMD devices --machine 2>/dev/null | jq -r '.[] | select(.emulator==false) | "\(.id)|\(.name)|\(.platform)"' 2>/dev/null || true)

    if [ -z "$DEVICES" ]; then
        log_warn "No physical devices found. Checking for emulators..."
        DEVICES=$($FLUTTER_CMD devices --machine 2>/dev/null | jq -r '.[] | select(.emulator==true) | "\(.id)|\(.name)|\(.platform)"' 2>/dev/null || true)
    fi

    if [ -z "$DEVICES" ]; then
        log_error "No devices found. Please connect a device or start an emulator."
        log_info "Available devices:"
        $FLUTTER_CMD devices
        exit 1
    fi

    # Pick first available device
    DEVICE_ID=$(echo "$DEVICES" | head -1 | cut -d'|' -f1)
    DEVICE_NAME=$(echo "$DEVICES" | head -1 | cut -d'|' -f2)
    DEVICE_PLATFORM=$(echo "$DEVICES" | head -1 | cut -d'|' -f3)
    log_info "Auto-selected device: $DEVICE_NAME ($DEVICE_PLATFORM) [$DEVICE_ID]"
}

# Run flutter doctor to check setup
check_doctor() {
    log_info "Running flutter doctor..."
    $FLUTTER_CMD doctor -v 2>&1 | head -30
}

# Clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    $FLUTTER_CMD clean > /dev/null 2>&1
    $FLUTTER_CMD pub get > /dev/null 2>&1
    log_success "Build artifacts cleaned"
}

# Build and run
run_app() {
    log_info "Building and running in $MODE mode on $DEVICE_NAME ($DEVICE_PLATFORM)..."

    case $MODE in
        debug)
            $FLUTTER_CMD run -d "$DEVICE_ID" --debug
            ;;
        profile)
            $FLUTTER_CMD run -d "$DEVICE_ID" --profile
            ;;
        release)
            $FLUTTER_CMD run -d "$DEVICE_ID" --release
            ;;
        web)
            $FLUTTER_CMD run -d chrome
            ;;
        *)
            log_error "Unknown mode: $MODE. Use debug, profile, release, or web."
            exit 1
            ;;
    esac
}

# Show usage
usage() {
    cat << EOF
Usage: ./start.sh [MODE] [DEVICE_ID]

Modes:
  debug    - Debug mode (default, hot reload enabled)
  profile  - Profile mode (performance profiling)
  release  - Release mode (optimized, no debug info)
  web      - Run in Chrome (web)

Examples:
  ./start.sh                    # Debug mode, auto-detect device
  ./start.sh profile           # Profile mode, auto-detect device
  ./start.sh release           # Release mode, auto-detect device
  ./start.sh web               # Run in Chrome (web)
  ./start.sh debug <device_id> # Debug mode on specific device

Environment variables:
  FVM_FLUTTER_VERSION  - Flutter version to use with FVM
  FLUTTER_CHANNEL      - Flutter channel (stable, beta, dev, master)

EOF
}

# Check if flutter is available
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        # Check FVM
        if [ -d "$HOME/fvm/default/bin" ]; then
            export PATH="$HOME/fvm/default/bin:$PATH"
            FLUTTER_CMD="flutter"
            log_info "Using Flutter from FVM: $($FLUTTER_CMD --version | head -1)"
        else
            log_error "Flutter not found in PATH and FVM not found at ~/fvm/default/bin"
            exit 1
        fi
    else
        FLUTTER_CMD="flutter"
        log_info "Using Flutter from PATH: \$($FLUTTER_CMD --version | head -1)"
    fi
}

# Check if we're in the right directory
check_project() {
    if [ ! -f "pubspec.yaml" ]; then
        log_error "pubspec.yaml not found. Run this script from the project root."
        exit 1
    fi
    log_info "Project found: $(grep '^name:' pubspec.yaml | cut -d' ' -f2)"
}

# Get available devices
get_devices() {
    log_info "Detecting available devices..."
    $FLUTTER_CMD devices 2>/dev/null || true
}

# Select device
select_device() {
    if [ -n "$DEVICE_ID" ]; then
        log_info "Using specified device: $DEVICE_ID"
        return
    fi

    # Try to auto-detect a suitable device
    DEVICES=$($FLUTTER_CMD devices --machine 2>/dev/null | jq -r '.[] | select(.emulator==false) | "\(.id)|\(.name)|\(.platform)"' 2>/dev/null || true)

    if [ -z "$DEVICES" ]; then
        log_warn "No physical devices found. Checking for emulators..."
        DEVICES=$($FLUTTER_CMD devices --machine 2>/dev/null | jq -r '.[] | select(.emulator==true) | "\(.id)|\(.name)|\(.platform)"' 2>/dev/null || true)
    fi

    if [ -z "$DEVICES" ]; then
        log_error "No devices found. Please connect a device or start an emulator."
        log_info "Available devices:"
        $FLUTTER_CMD devices
        exit 1
    fi

    # Pick first available device
    DEVICE_ID=$(echo "$DEVICES" | head -1 | cut -d'|' -f1)
    DEVICE_NAME=$(echo "$DEVICES" | head -1 | cut -d'|' -f2)
    DEVICE_PLATFORM=$(echo "$DEVICES" | head -1 | cut -d'|' -f3)
    log_info "Auto-selected device: $DEVICE_NAME ($DEVICE_PLATFORM) [$DEVICE_ID]"
}

# Run flutter doctor to check setup
check_doctor() {
    log_info "Running flutter doctor..."
    $FLUTTER_CMD doctor -v 2>&1 | head -30
}

# Clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    $FLUTTER_CMD clean > /dev/null 2>&1
    $FLUTTER_CMD pub get > /dev/null 2>&1
    log_success "Build artifacts cleaned"
}

# Build and run
run_app() {
    log_info "Building and running in $MODE mode on $DEVICE_NAME ($DEVICE_PLATFORM)..."

    case $MODE in
        debug)
            $FLUTTER_CMD run -d "$DEVICE_ID" --debug
            ;;
        profile)
            $FLUTTER_CMD run -d "$DEVICE_ID" --profile
            ;;
        release)
            $FLUTTER_CMD run -d "$DEVICE_ID" --release
            ;;
        web)
            $FLUTTER_CMD run -d chrome
            ;;
        *)
            log_error "Unknown mode: $MODE. Use debug, profile, release, or web."
            exit 1
            ;;
    esac
}

# Show usage
usage() {
    cat << EOF
Usage: ./start.sh [MODE] [DEVICE_ID]

Modes:
  debug    - Debug mode (default, hot reload enabled)
  profile  - Profile mode (performance profiling)
  release  - Release mode (optimized, no debug info)
  web      - Run in Chrome (web)

Examples:
  ./start.sh                    # Debug mode, auto-detect device
  ./start.sh profile           # Profile mode, auto-detect device
  ./start.sh release           # Release mode, auto-detect device
  ./start.sh web               # Run in Chrome (web)
  ./start.sh debug <device_id> # Debug mode on specific device

Environment variables:
  FVM_FLUTTER_VERSION  - Flutter version to use with FVM
  FLUTTER_CHANNEL      - Flutter channel (stable, beta, dev, master)

EOF
}

# Main execution
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
   _____ _                 _ _____ _           
  / ____| |               | |_   _| |          
 | (___ | |_ _ __ ___  ___| |_| | | |__   ___  
  \___ \| __| '__/ _ \/ _ \ |_| | | '_ \ / _ \ 
  ____) | |_| | |  __/  __/ |_| | |_) | (_ ) |
 |_____/ \__|_|  \___|\___|_|_|_|_.__/ \___/ 
                                             
   Chess Repertoire SRS - Beta Testing Launcher
EOF
    echo -e "${NC}"

    # Handle help
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    check_flutter
    check_project
    check_dependencies
    get_devices
    select_device
    
    # Optional: run flutter doctor first time
    if [ "$1" == "doctor" ]; then
        check_doctor
        exit 0
    fi

    # Optional clean
    if [ "$1" == "clean" ]; then
        clean_build
        exit 0
    fi

    run_app
    log_success "App finished"
}

# Run main
main "$@"