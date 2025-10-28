#!/usr/bin/env bash
set -euo pipefail

# update-8g-firewall.sh
# Template script to download and update one or more files.
# Automated mode: uses built-in variables at the top of the file (no CLI args)

# Needs to be run from site_dir/config directory, not from the scripts/ folder

PROG_NAME="$(basename "$0")"

# Configuration (built-in variables for automated execution)
# Edit the variables below to configure the run. This script does NOT accept CLI args.
# DEST_PREFIX: partial destination path to prepend (e.g. ./custom or /etc/nginx/common)
# BASE_URL: base URL to download from (filename appended)
# BACKUP_DIR: where to store backups
# DRY_RUN: set to true to only simulate actions
# FILES: array of filenames (or relative paths) to download and update

DEST_PREFIX="./nginx/common"
BASE_URL="https://raw.githubusercontent.com/t18d/nG-SetEnvIf/develop"
BACKUP_DIR="./config_backup"
DRY_RUN=false

# Example: FILES=(8g.conf cloudflare.conf)
FILES=(8g.conf 8g-firewall.conf)

# Ensure DEST_PREFIX and BASE_URL have no trailing slash
DEST_PREFIX="${DEST_PREFIX%/}"
BASE_URL="${BASE_URL%/}"

mkdir -p "$BACKUP_DIR"

summary_added=0
summary_updated=0
summary_skipped=0
summary_failed=0

for filename in "${FILES[@]}"; do
	# allow passing path-like filenames too
	dest_path="$DEST_PREFIX/$filename"
	url="$BASE_URL/$filename"
	tmpfile="/tmp/${PROG_NAME}.$(date +%s%3N).$$.$(basename "$filename")"

	echo "----"
	echo "Processing: $filename"
	echo "Destination: $dest_path"
	echo "URL: $url"

	if [ "$DRY_RUN" = true ]; then
		echo "DRY RUN: would download $url to $tmpfile and compare/replace $dest_path"
		summary_skipped=$((summary_skipped+1))
		continue
	fi

	# Download to tmpfile
	if ! curl -fsSL --connect-timeout 10 -o "$tmpfile" "$url"; then
		echo "Failed to download $url" >&2
		summary_failed=$((summary_failed+1))
		rm -f "$tmpfile" || true
		continue
	fi

	if [ -f "$dest_path" ]; then
		# Compare files (binary-safe)
		if cmp -s "$tmpfile" "$dest_path"; then
			echo "No changes for $filename; skipping"
			summary_skipped=$((summary_skipped+1))
			rm -f "$tmpfile"
			continue
		else
			# backup old file
			timestamp=$(date +%Y%m%dT%H%M%S)
			backup_path="$BACKUP_DIR/$(basename "$dest_path").$timestamp"
			mkdir -p "$(dirname "$backup_path")"
			echo "Backing up existing file to $backup_path"
			if ! cp -p "$dest_path" "$backup_path"; then
				echo "Failed to backup $dest_path" >&2
				summary_failed=$((summary_failed+1))
				rm -f "$tmpfile"
				continue
			fi
			# Replace
			mkdir -p "$(dirname "$dest_path")"
			if mv "$tmpfile" "$dest_path"; then
				echo "Updated $dest_path"
				summary_updated=$((summary_updated+1))
			else
				echo "Failed to replace $dest_path" >&2
				summary_failed=$((summary_failed+1))
				rm -f "$tmpfile"
				continue
			fi
		fi
	else
		# New file — ensure directory exists then move
		mkdir -p "$(dirname "$dest_path")"
		if mv "$tmpfile" "$dest_path"; then
			echo "Added new file $dest_path"
			summary_added=$((summary_added+1))
		else
			echo "Failed to move $tmpfile to $dest_path" >&2
			summary_failed=$((summary_failed+1))
			rm -f "$tmpfile"
			continue
		fi
	fi

	# Optional: set safe permissions
	chmod 0644 "$dest_path" 2>/dev/null || true
done

echo "----\nSummary: added=$summary_added updated=$summary_updated skipped=$summary_skipped failed=$summary_failed"

exit 0

