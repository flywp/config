#!/bin/bash

# script to set Cloudflare IPs (ipv4 and ipv6)

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PARENT_DIR=$(dirname $SCRIPT_DIR)
FILE_PATH="$PARENT_DIR/nginx/common/cloudflare-ip-list.conf"

# empty the list
echo -n >$FILE_PATH

# fetch and update ipv4
for i in $(curl -s https://www.cloudflare.com/ips-v4); do
    echo "set_real_ip_from $i;" >>$FILE_PATH
done

# fetch and update ipv6
for i in $(curl -s https://www.cloudflare.com/ips-v6); do
    echo "set_real_ip_from $i;" >>$FILE_PATH
done
