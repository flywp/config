#!/bin/bash

# Bad Bot Blocker Update Script
# Fetches latest bad bot and user-agent lists from nginx-ultimate-bad-bot-blocker
# and updates the Nginx configuration file

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NGINX_COMMON_DIR="$PROJECT_ROOT/nginx/common"

# Repository URLs
BAD_USER_AGENTS_URL="https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_generator_lists/bad-user-agents.list"
BAD_REFERRERS_URL="https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_generator_lists/bad-referrers.list"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Download file with retry logic
download_file() {
    local url="$1"
    local output_file="$2"
    local max_retries=3
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        if curl -s --fail "$url" -o "$output_file"; then
            log_info "Successfully downloaded: $url"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warn "Download failed (attempt $retry_count/$max_retries): $url"
            if [[ $retry_count -lt $max_retries ]]; then
                sleep 2
            fi
        fi
    done

    log_error "Failed to download after $max_retries attempts: $url"
    return 1
}

# Generate bad bots http configuration (map directives)
generate_bad_bots_http_config() {
    local temp_user_agents="$1"
    local output_file="$NGINX_COMMON_DIR/block-bad-bots-list.conf"

    log_info "Generating block-bad-bots-list.conf..."

    cat > "$output_file" << 'EOF'
# Bad Bots Blocker - HTTP Block Configuration
# Generated from nginx-ultimate-bad-bot-blocker
# https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker
# Include this file in the http block

# Map bad user agents for efficient lookup
map $http_user_agent $bad_user_agent {
    default         0;
EOF

    # Add user agents from the downloaded list
    while IFS= read -r user_agent || [[ -n "$user_agent" ]]; do
        # Skip empty lines and comments
        [[ -z "$user_agent" ]] && continue
        [[ "$user_agent" =~ ^[[:space:]]*# ]] && continue

        # Add to configuration with proper formatting (using printf for correct tabs)
        printf '\t"~*%s"\t\t%s;\n' "(?:\b)${user_agent}(?:\b)" "3" >> "$output_file"
    done < "$temp_user_agents"

    # Close the map block
    cat >> "$output_file" << 'EOF'
}
EOF

    log_info "Generated: $output_file"
}

# Generate bad bots server configuration (if statements)
generate_bad_bots_server_config() {
    local output_file="$NGINX_COMMON_DIR/block-bad-bots-blocker.conf"

    log_info "Generating block-bad-bots-blocker.conf..."

    cat > "$output_file" << 'EOF'
# Bad Bots Blocker - Server Block Configuration
# Generated from nginx-ultimate-bad-bot-blocker
# https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker
# Include this file in the server block

# Block bad user agents with 403 Forbidden
if ($bad_user_agent) {
    return 403;
}
EOF

    log_info "Generated: $output_file"
}

# Generate bad referrers http configuration (map directives)
generate_bad_referrers_http_config() {
    local temp_referrers="$1"
    local output_file="$NGINX_COMMON_DIR/block-bad-referrers-list.conf"

    log_info "Generating block-bad-referrers-list.conf..."

    cat > "$output_file" << 'EOF'
# Bad Referrers Blocker - HTTP Block Configuration
# Generated from nginx-ultimate-bad-bot-blocker
# https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker
# Include this file in the http block

# Map bad referrers for efficient lookup
map $http_referer $bad_referer {
    default         0;
EOF

    # Add referrers from the downloaded list
    while IFS= read -r referrer || [[ -n "$referrer" ]]; do
        # Skip empty lines and comments
        [[ -z "$referrer" ]] && continue
        [[ "$referrer" =~ ^[[:space:]]*# ]] && continue

        # Add to configuration with proper formatting (using printf for correct tabs)
        printf '\t"~*%s"\t\t%s;\n' "(?:\b)${referrer}(?:\b)" "1" >> "$output_file"
    done < "$temp_referrers"

    # Close the referrer map block
    cat >> "$output_file" << 'EOF'
}
EOF

    log_info "Generated: $output_file"
}

# Generate bad referrers server configuration (if statements)
generate_bad_referrers_server_config() {
    local output_file="$NGINX_COMMON_DIR/block-bad-referrers-blocker.conf"

    log_info "Generating block-bad-referrers-blocker.conf..."

    cat > "$output_file" << 'EOF'
# Bad Referrers Blocker - Server Block Configuration
# Generated from nginx-ultimate-bad-bot-blocker
# https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker
# Include this file in the server block

# Block bad referrers with 403 Forbidden
if ($bad_referer) {
    return 403;
}
EOF

    log_info "Generated: $output_file"
}

# Validate nginx configuration
validate_nginx_config() {
    if command -v nginx >/dev/null 2>&1; then
        log_info "Validating Nginx configuration..."
        if nginx -t 2>/dev/null; then
            log_info "Nginx configuration is valid"
        else
            log_warn "Nginx configuration validation failed. Please check manually."
        fi
    else
        log_warn "Nginx not found in PATH, skipping configuration validation"
    fi
}

# Main function
main() {
    log_info "Starting Bad Bot Blocker update..."
    log_info "Project root: $PROJECT_ROOT"

    # Create temporary files
    temp_user_agents=$(mktemp)
    temp_referrers=$(mktemp)

    # Clean up temp files on exit
    trap "rm -f $temp_user_agents $temp_referrers" EXIT

    # Download the latest lists
    log_info "Downloading latest bad bot lists..."
    if ! download_file "$BAD_USER_AGENTS_URL" "$temp_user_agents"; then
        log_error "Failed to download bad user agents list"
        exit 1
    fi

    if ! download_file "$BAD_REFERRERS_URL" "$temp_referrers"; then
        log_warn "Failed to download bad referrers list (continuing anyway)"
    fi

    # Count entries in downloaded files
    user_agents_count=$(grep -c '^[^#]' "$temp_user_agents" || echo "0")
    referrers_count=$(grep -c '^[^#]' "$temp_referrers" || echo "0")

    log_info "Downloaded $user_agents_count bad user agents"
    log_info "Downloaded $referrers_count bad referrers"

    # Generate configuration files
    generate_bad_bots_http_config "$temp_user_agents"
    generate_bad_bots_server_config
    generate_bad_referrers_http_config "$temp_referrers"
    generate_bad_referrers_server_config

    # Validate configuration
    validate_nginx_config

    log_info "Bad Bot Blocker update completed successfully!"
    log_info "Configuration files updated in: $NGINX_COMMON_DIR"
    log_info "HTTP block files (include in http {}):"
    log_info "  - block-bad-bots-list.conf (user agent maps)"
    log_info "  - block-bad-referrers-list.conf (referrer maps)"
    log_info "Server block files (include in server {}):"
    log_info "  - block-bad-bots-blocker.conf (user agent blocking)"
    log_info "  - block-bad-referrers-blocker.conf (referrer blocking)"
    log_info ""
    log_info "To apply the changes, reload your Nginx configuration:"
    log_info "  sudo nginx -t && sudo nginx -s reload"
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
