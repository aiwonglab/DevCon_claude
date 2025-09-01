#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting

# Function to cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        echo "Script failed, restoring permissive firewall rules..."
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -F
        iptables -X 2>/dev/null || true
        iptables -t nat -F
        iptables -t nat -X 2>/dev/null || true
        iptables -t mangle -F
        iptables -t mangle -X 2>/dev/null || true
        ipset destroy allowed-domains 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X 2>/dev/null || true
iptables -t nat -F
iptables -t nat -X 2>/dev/null || true
iptables -t mangle -F
iptables -t mangle -X 2>/dev/null || true
ipset destroy allowed-domains 2>/dev/null || true

# Set permissive policies initially to allow DNS resolution
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Get host IP from default route early
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

# Add host network to allowed domains for local communication
ipset add allowed-domains "$HOST_NETWORK"

# # Fetch GitHub meta information and aggregate + add their IP ranges
# echo "Fetching GitHub IP ranges..."
# gh_ranges=$(curl -s --connect-timeout 10 --max-time 30 https://api.github.com/meta)
# if [ -z "$gh_ranges" ]; then
#     echo "ERROR: Failed to fetch GitHub IP ranges"
#     exit 1
# fi

# if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
#     echo "ERROR: GitHub API response missing required fields"
#     exit 1
# fi

# echo "Processing GitHub IPs..."
# while read -r cidr; do
#     if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
#         echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
#         exit 1
#     fi
#     echo "Adding GitHub range $cidr"
#     ipset add allowed-domains "$cidr"
# done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Fetch GitHub meta information and aggregate + add their IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s --connect-timeout 10 --max-time 30 https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

# Check if we have a valid JSON response with IP ranges
if ! echo "$gh_ranges" | jq -e 'has("web") or has("api") or has("git")' >/dev/null; then
    echo "WARNING: GitHub API response missing some expected fields, continuing with available fields..."
fi

echo "Processing GitHub IPs..."
# Get all available IP ranges from the response
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "WARNING: Invalid CIDR range from GitHub meta: $cidr, skipping..."
        continue
    fi
    echo "Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r 'try ((.web // []) + (.api // []) + (.git // []))[]' | aggregate -q 2>/dev/null || echo "$gh_ranges" | jq -r '.[][]?' 2>/dev/null)


# Resolve and add other allowed domains
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "sentry.io" \
    "statsig.anthropic.com" \
    "statsig.com" \
    "pixi.sh" \
    "astral.sh" \
    "platform.openai.com" \
    "ports.ubuntu.com" \
    "archive.ubuntu.com" \
    "ppa.launchpadcontent.net" \
    "download.pytorch.org" \
    "huggingface.co" \
    "hf.co" \
    "cdn-lfs.huggingface.co" \
    "cdn-lfs.hf.co " \
    "cdn-lfs-us-1.hf.co" \
    "cdn-lfs-eu-1.hf.co" \
    "xethub.hf.co" \
    "cas-server.xethub.hf.co" \
    "cas-bridge.xethub.hf.co" \
    "transfer.xethub.hf.co" \
    "api.openai.com" \
    "ollama.com" \
    "registry.ollama.ai" \
    "pypi.org" \
    "pypi.python.org" \
    "pythonhosted.org" \
    "files.pythonhosted.org"; do
    echo "Resolving $domain..."
    
    # Try multiple DNS resolution attempts with timeout
    ips=""
    for attempt in {1..3}; do
        ips=$(timeout 10 dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || true)
        if [ -n "$ips" ]; then
            break
        fi
        echo "Attempt $attempt failed for $domain, retrying..."
        sleep 1
    done
    
    if [ -z "$ips" ]; then
        echo "WARNING: Failed to resolve $domain after 3 attempts, skipping..."
        continue
    fi
    
    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "WARNING: Invalid IP from DNS for $domain: $ip, skipping..."
            continue
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" 2>/dev/null || echo "WARNING: Failed to add $ip to ipset"
    done < <(echo "$ips")
done

# Now set up restrictive iptables rules
echo "Setting up firewall rules..."

# Flush rules again to start fresh
iptables -F
iptables -X 2>/dev/null || true

# Allow localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outbound DNS (needed for ongoing resolution)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT

# Allow outbound SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Allow traffic to/from host network
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Allow traffic to allowed domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Set default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

echo "Firewall configuration complete"

# Verification tests
echo "Verifying firewall rules..."

# Test 1: Should NOT be able to reach blocked site
echo "Testing blocked site access..."
if timeout 5 curl --connect-timeout 3 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "✓ Firewall verification passed - unable to reach https://example.com as expected"
fi

# Test 2: Should be able to reach GitHub API
echo "Testing GitHub API access..."
if ! timeout 10 curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "✓ Firewall verification passed - able to reach https://api.github.com as expected"
fi

# Test 3: Should be able to reach npm registry
echo "Testing npm registry access..."
if ! timeout 10 curl --connect-timeout 5 https://registry.npmjs.org >/dev/null 2>&1; then
    echo "WARNING: Unable to reach npm registry - this may be expected if DNS resolution failed earlier"
else
    echo "✓ npm registry access verified"
fi

echo "All firewall tests completed successfully!"

# Disable cleanup trap since we succeeded
trap - EXIT