#!/bin/bash

# Configuration
API_TOKEN="api-key-here"
FIREWALL_IDS=("firewall1_id" "firewall2_id" "firewall3_id")  # Array of up to 3
IPV4_FILE="/var/lib/crowdsec/data/bunnycdn_ipv4.txt"
IPV6_FILE="/var/lib/crowdsec/data/bunnycdn_ipv6.txt"
CHUNK_SIZE=100
MAX_IPS_PER_FW=499

# Check if files exist
if [ ! -f "$IPV4_FILE" ]; then
    echo "Error: IPv4 file '$IPV4_FILE' not found"
    exit 1
fi

if [ ! -f "$IPV6_FILE" ]; then
    echo "Error: IPv6 file '$IPV6_FILE' not found"
    exit 1
fi

# Read IPs from both files and combine
echo "Reading IP files..."
mapfile -t IPV4_IPS < <(grep -v '^$' "$IPV4_FILE")
mapfile -t IPV6_IPS < <(grep -v '^$' "$IPV6_FILE")

# Combine IPv4 and IPv6 into single array
ALL_IPS=("${IPV4_IPS[@]}" "${IPV6_IPS[@]}")

IPV4_COUNT=${#IPV4_IPS[@]}
IPV6_COUNT=${#IPV6_IPS[@]}
TOTAL_IPS=${#ALL_IPS[@]}

echo "IPv4 addresses: $IPV4_COUNT"
echo "IPv6 addresses: $IPV6_COUNT"
echo "Total IPs to process: $TOTAL_IPS"
echo "Firewalls available: ${#FIREWALL_IDS[@]}"
echo "Max capacity: $((MAX_IPS_PER_FW * ${#FIREWALL_IDS[@]})) IPs"

# Check if we have too many IPs
max_capacity=$((MAX_IPS_PER_FW * ${#FIREWALL_IDS[@]}))
if [ $TOTAL_IPS -gt $max_capacity ]; then
    echo "WARNING: Total IPs ($TOTAL_IPS) exceeds capacity ($max_capacity)"
    echo "Only first $max_capacity IPs will be processed"
fi

# Process each firewall
ip_offset=0

for fw_index in "${!FIREWALL_IDS[@]}"; do
    FIREWALL_ID="${FIREWALL_IDS[$fw_index]}"

    # Calculate how many IPs for this firewall
    remaining_ips=$((TOTAL_IPS - ip_offset))
    if [ $remaining_ips -le 0 ]; then
        echo "All IPs processed. Exiting."
        break
    fi

    ips_for_this_fw=$remaining_ips
    if [ $ips_for_this_fw -gt $MAX_IPS_PER_FW ]; then
        ips_for_this_fw=$MAX_IPS_PER_FW
    fi

    echo ""
    echo "=== Processing Firewall $((fw_index + 1)): $FIREWALL_ID ==="
    echo "Processing $ips_for_this_fw IPs (offset: $ip_offset)"

    # Get slice of IPs for this firewall
    fw_ips=("${ALL_IPS[@]:ip_offset:ips_for_this_fw}")

    # Build rules for this firewall
    rules="[]"

    # Port 80 rules
    for ((i=0; i<${#fw_ips[@]}; i+=CHUNK_SIZE)); do
        chunk=("${fw_ips[@]:i:CHUNK_SIZE}")
        chunk_json=$(printf '%s\n' "${chunk[@]}" | jq -R . | jq -s .)
        rules=$(echo "$rules" | jq \
            --argjson ips "$chunk_json" \
            '. += [{
                "direction": "in",
                "source_ips": $ips,
                "protocol": "tcp",
                "port": "80"
            }]')
    done

    # Port 443 rules
    for ((i=0; i<${#fw_ips[@]}; i+=CHUNK_SIZE)); do
        chunk=("${fw_ips[@]:i:CHUNK_SIZE}")
        chunk_json=$(printf '%s\n' "${chunk[@]}" | jq -R . | jq -s .)
        rules=$(echo "$rules" | jq \
            --argjson ips "$chunk_json" \
            '. += [{
                "direction": "in",
                "source_ips": $ips,
                "protocol": "tcp",
                "port": "443"
            }]')
    done

    rule_count=$(echo "$rules" | jq 'length')
    echo "Created $rule_count rules for this firewall"

    # Build request
    request_body=$(jq -n --argjson rules "$rules" '{rules: $rules}')

    # Make API call
    echo "Applying rules to firewall $FIREWALL_ID..."
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "https://api.hetzner.cloud/v1/firewalls/$FIREWALL_ID/actions/set_rules")

    # Check response
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "ERROR on firewall $FIREWALL_ID:"
        echo "$response" | jq '.error'
        exit 1
    else
        echo "✅ Successfully applied to firewall $FIREWALL_ID"
        action_id=$(echo "$response" | jq -r '.action.id')
        echo "Action ID: $action_id"
    fi

    # Move offset for next firewall
    ip_offset=$((ip_offset + ips_for_this_fw))
done

echo ""
echo "=== Complete ==="
echo "IPv4 processed: $IPV4_COUNT"
echo "IPv6 processed: $IPV6_COUNT"
echo "Total IPs processed: $ip_offset"
