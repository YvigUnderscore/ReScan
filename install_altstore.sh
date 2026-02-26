#!/bin/bash

# Configuration
ALTSERVER_URL="https://github.com/NyaMisty/AltServer-Linux/releases/download/v0.0.5/AltServer-x86_64"
ALTSERVER_SHA256="0be7c3adc69ec1177a15032b3b8e37c5d0e4fefb47c9c439cd62c238b3ea17fb"
INSTALL_DIR=$(pwd)
ALTSERVER_BIN="$INSTALL_DIR/AltServer"
IPA_PATH=""

# USE A KNOWN PUBLIC ANISETTE SERVER TO FIX 502 ERRORS
export ALTSERVER_ANISETTE_SERVER="https://ani.sidestore.io"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== DIET Capture AltStore Installer ===${NC}"
echo "This script will download AltServer-Linux and guide you through the setup."
echo ""

# 1. Update & Install Dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

# Function to check if a command exists
check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

MISSING_DEPS=0

# Check binaries
if ! check_cmd idevicepair; then echo "Missing: libimobiledevice-utils"; MISSING_DEPS=1; fi
if ! check_cmd usbmuxd; then echo "Missing: usbmuxd"; MISSING_DEPS=1; fi
if ! check_cmd curl && ! check_cmd wget; then echo "Missing: curl/wget"; MISSING_DEPS=1; fi
if ! check_cmd unzip; then echo "Missing: unzip"; MISSING_DEPS=1; fi 
if ! check_cmd zip; then echo "Missing: zip"; MISSING_DEPS=1; fi
if ! check_cmd sha256sum; then echo "Missing: sha256sum (coreutils)"; MISSING_DEPS=1; fi

# Check for libdns_sd.so (Avahi compatibility) required by AltServer
if ! ldconfig -p | grep -q libdns_sd.so && [ ! -f "/usr/lib/x86_64-linux-gnu/libdns_sd.so.1" ] && [ ! -f "/usr/lib/libdns_sd.so" ]; then
    echo "Missing: libavahi-compat-libdnssd-dev (libdns_sd.so)"
    MISSING_DEPS=1
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo -e "${YELLOW}Missing Critical Dependencies. Installing...${NC}"
    
    if check_cmd apt-get; then
        sudo apt-get update
        sudo apt-get install -y libimobiledevice-utils usbmuxd curl wget libavahi-compat-libdnssd-dev zip unzip
    elif check_cmd dnf; then
        sudo dnf install -y libimobiledevice-utils usbmuxd curl wget avahi-compat-libdns_sd-devel zip unzip
    elif check_cmd pacman; then
        sudo pacman -S --noconfirm libimobiledevice usbmuxd curl wget nss-mdns zip unzip
        echo "Note for Arch: ensure nss-mdns is configured in /etc/nsswitch.conf"
    else
        echo -e "${RED}Could not detect package manager. Please manually install: libimobiledevice-utils usbmuxd curl wget libavahi-compat-libdnssd-dev zip unzip${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Dependencies found.${NC}"
fi

# 2. Download AltServer
if [ ! -f "$ALTSERVER_BIN" ]; then
    echo -e "${YELLOW}Downloading AltServer...${NC}"
    if check_cmd curl; then
        curl -L -o "$ALTSERVER_BIN" "$ALTSERVER_URL"
    else
        wget -O "$ALTSERVER_BIN" "$ALTSERVER_URL"
    fi

    echo -e "${YELLOW}Verifying AltServer checksum...${NC}"
    echo "$ALTSERVER_SHA256  $ALTSERVER_BIN" | sha256sum -c - > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Checksum verification failed! The downloaded file may be corrupted or compromised.${NC}"
        rm -f "$ALTSERVER_BIN"
        exit 1
    else
        echo -e "${GREEN}Checksum verification passed.${NC}"
    fi

    chmod +x "$ALTSERVER_BIN"
    echo -e "${GREEN}AltServer downloaded.${NC}"
else
    echo -e "${GREEN}AltServer already exists. Skipping download.${NC}"
fi

# 3. Instructions & pairing
echo ""
echo -e "${GREEN}=== Setup Instructions ===${NC}"
echo "1. Connect your iPhone via USB."
echo "2. Unlock your iPhone (screen must be ON)."
echo "3. Run 'idevicepair pair' if you haven't already."
echo ""
echo -e "${YELLOW}Running 'idevicepair pair' now...${NC}"
idevicepair pair

# 4. Find IPA
# Look for ipa in current directory, parent directory, or Desktop
IPA_FILES=$(find . .. ~/Bureau -maxdepth 1 -name "*.ipa" 2>/dev/null | head -n 1)

if [ ! -z "$IPA_FILES" ]; then
    IPA_PATH="$IPA_FILES"
    echo -e "${GREEN}Found IPA:${NC} $IPA_PATH"
else
    IPA_PATH=""
    echo -e "${YELLOW}No IPA file found directly.${NC}"
fi

echo ""
echo -e "${BLUE}By default, we try to install the app directly via USB.${NC}"
echo -e "${BLUE}If that fails, we can start 'Server Mode' to let you install from AltStore on your phone.${NC}"
echo ""
echo "Choose mode:"
echo "1) Install DIRECTLY via USB (Try this first)"
echo "2) Start AltServer ONLY (Choose if you want to install from your Phone)"
read -p "Selection [1]: " MODE
MODE=${MODE:-1}

echo ""
echo "You will need your Apple ID and Password (use an App-Specific Password)."
echo -n "Enter Apple ID (email): "
read APPLE_ID
echo -n "Enter Apple Password: "
read -s APPLE_PASSWORD
echo ""

# Get UDID
UDID=$(idevice_id -l | head -n 1)
if [ -z "$UDID" ]; then
    echo -e "${RED}No device found via USB. Please connect and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}Device detected:${NC} $UDID"

echo -e "${YELLOW}Starting AltServer...${NC}"

ADB_ARGS="-u $UDID -a $APPLE_ID -p $APPLE_PASSWORD"

if [ "$MODE" == "1" ] && [ ! -z "$IPA_PATH" ]; then
    echo "Installing App: $IPA_PATH"
    echo "Please keep your device UNLOCKED."
    sudo ALTSERVER_ANISETTE_SERVER=$ALTSERVER_ANISETTE_SERVER "$ALTSERVER_BIN" $ADB_ARGS "$IPA_PATH"
elif [ "$MODE" == "1" ] && [ -z "$IPA_PATH" ]; then
    echo -e "${RED}Cannot install directly: No IPA file found.${NC}"
    echo "Switching to Server Mode..."
    sudo ALTSERVER_ANISETTE_SERVER=$ALTSERVER_ANISETTE_SERVER "$ALTSERVER_BIN" $ADB_ARGS
else
    echo "Starting Server Mode..."
    echo "Keep this window open. On your iPhone, open AltStore -> My Apps -> + -> Select the IPA."
    sudo ALTSERVER_ANISETTE_SERVER=$ALTSERVER_ANISETTE_SERVER "$ALTSERVER_BIN" $ADB_ARGS
fi

echo ""
echo -e "${GREEN}Done.${NC}"
