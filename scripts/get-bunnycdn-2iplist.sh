#!/bin/bash

# Download Bunny CDN IP lists with safety checks and CIDR notation
# Creates two separate files: IPv4 with /32 and IPv6 with /128

set -e

IPV4_FILE="/var/lib/crowdsec/data/bunnycdn_ipv4.txt"
IPV6_FILE="/var/lib/crowdsec/data/bunnycdn_ipv6.txt"

IPV4_URL="https://bunnycdn.com/api/system/edgeserverlist/plain"
IPV6_URL="https://bunnycdn.com/api/system/edgeserverlist/IPv6/plain"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Downloading Bunny CDN IP lists..."
echo ""

# Temporary files
IPV4_TMP="${IPV4_FILE}.tmp"
IPV6_TMP="${IPV6_FILE}.tmp"

# Function to safely download and validate with CIDR notation
download_and_validate() {
    local url="$1"
    local temp_file="$2"
    local final_file="$3"
    local ip_type="$4"
    local cidr_suffix="$5"

    echo "Downloading $ip_type IPs..."

    # Download to temp file with HTTP status check
    http_code=$(curl -s -w "%{http_code}" -o "$temp_file" "$url")

    if [ "$http_code" != "200" ]; then
        echo -e "${RED}✗ Download failed (HTTP $http_code)${NC}"
        rm -f "$temp_file"
        return 1
    fi

    # Check if file is not empty
    if [ ! -s "$temp_file" ]; then
        echo -e "${RED}✗ Downloaded file is empty${NC}"
        rm -f "$temp_file"
        return 1
    fi

    # Check if file contains at least some valid IPs
    line_count=$(wc -l < "$temp_file")
    if [ "$line_count" -lt 10 ]; then
        echo -e "${RED}✗ Downloaded file has too few lines ($line_count)${NC}"
        rm -f "$temp_file"
        return 1
    fi

    # Strip Windows line endings
    tr -d '\r' < "$temp_file" > "${temp_file}.clean"
    mv "${temp_file}.clean" "$temp_file"

    # Add CIDR notation to each IP
    awk -v suffix="$cidr_suffix" '{if ($0 != "") print $0 suffix}' "$temp_file" > "${temp_file}.cidr"
    mv "${temp_file}.cidr" "$temp_file"

    # Get new line count
    line_count=$(wc -l < "$temp_file")

    # Backup existing file if it exists
    if [ -f "$final_file" ]; then
        backup_file="${final_file}.backup"
        cp "$final_file" "$backup_file"
        echo -e "${YELLOW}  Backed up to: $backup_file${NC}"
    fi

    # Move temp file to final location
    mv "$temp_file" "$final_file"

    echo -e "${GREEN}✓ $ip_type: $line_count IPs downloaded (with CIDR notation)${NC}"
    return 0
}

# Download IPv4 and add /32
if ! download_and_validate "$IPV4_URL" "$IPV4_TMP" "$IPV4_FILE" "IPv4" "/32"; then
    echo -e "${RED}Failed to download IPv4 list - keeping existing file${NC}"
    IPV4_FAILED=1
fi


# Download IPv6 and add /128
if ! download_and_validate "$IPV6_URL" "$IPV6_TMP" "$IPV6_FILE" "IPv6" "/128"; then
    echo -e "${RED}Failed to download IPv6 list - keeping existing file${NC}"
    IPV6_FAILED=1
fi

echo "Adding IP addresses to cscli allowlist..."
#cscli allowlists add bunnycdn $(cat "$IPV4_FILE" "$IPV6_FILE" | tr '\n' ' ') -d "Bunny CDN Edge Servers"
echo "✓ Complete!"
#cscli allowlists list

# Summary
if [ -z "$IPV4_FAILED" ] && [ -z "$IPV6_FAILED" ]; then
    echo -e "${GREEN}✓ All IP lists updated successfully!${NC}"
    echo "Output files:"
    echo "  IPv4: $IPV4_FILE"
    echo "  IPv6: $IPV6_FILE"
    exit 0
elif [ -n "$IPV4_FAILED" ] && [ -n "$IPV6_FAILED" ]; then
    echo -e "${RED}✗ Both downloads failed - no files updated${NC}"
    exit 1
else
    echo -e "${YELLOW}⚠ Partial success - some lists updated${NC}"
    exit 0
fi
