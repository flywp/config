#!/usr/bin/env bash
set -euo pipefail

# Download and update configuration files
# Run from: {SITE_DIR}/config directory

# Configuration
BASE_URL="https://raw.githubusercontent.com/t18d/nG-SetEnvIf/develop"
FILES=(8g.conf 8g-firewall.conf)

for filename in "${FILES[@]}"; do
	dest_path="./nginx/common/$filename"
	url="$BASE_URL/$filename"
	tmpfile="/tmp/8g-firewall-config-$(date +%s)-$(basename "$filename")"

	echo "Processing: $filename"

	# Download file
	if ! curl -fsSL -o "$tmpfile" "$url"; then
		echo "❌ Failed to download"
		rm -f "$tmpfile"
		continue
	fi

	# Skip if unchanged
	if [ -f "$dest_path" ] && cmp -s "$tmpfile" "$dest_path"; then
		echo "✅ No changes"
		rm -f "$tmpfile"
		continue
	fi

	# Install new file
	mkdir -p "$(dirname "$dest_path")"
	mv "$tmpfile" "$dest_path"
	chmod 0644 "$dest_path"
	echo "✅ Updated: $dest_path"
done

echo "Add Done!"
