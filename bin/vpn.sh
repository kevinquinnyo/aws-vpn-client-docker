#!/usr/bin/env bash

ovpn_file="${OVPN_FILE:-$HOME/client-aws.ovpn}"
local_tmp="${VPN_TMP_DIR:-$HOME/tmp/vpn}"
url_file="$local_tmp/url.txt"
container_name="${VPN_CONTAINER_NAME:-vpn}"

# Parse command-line options
while getopts ":f:t:c:h" opt; do
  case $opt in
    f) ovpn_file="$OPTARG" ;;
    t) local_tmp="$OPTARG" ;;
    c) container_name="$OPTARG" ;;
    h)
      echo "Usage: $0 [options]"
      echo
      echo "Options:"
      echo "  -f  Path to the .ovpn file (default: $HOME/client-aws.ovpn)"
      echo "  -t  Path to the temporary directory (default: $HOME/tmp/vpn)"
      echo "  -c  Name of the Docker container (default: vpn)"
      echo "  stop   Stop and remove the running VPN container"
      echo
      echo "Environment Variables:"
      echo "  OVPN_FILE         Path to the .ovpn file"
      echo "  VPN_TMP_DIR       Path to the temporary directory"
      echo "  VPN_CONTAINER_NAME  Name of the Docker container"
      exit 0
      ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

command="$1"

if [[ "$command" == "stop" ]]; then
    # Stop and remove the container if it exists
    container_id=$(docker ps -aq -f name="$container_name")
    if [[ -z $container_id ]]; then
        echo "Not running"
        exit 0
    fi
    docker stop "$container_name" >/dev/null 2>&1
    docker rm "$container_name" >/dev/null 2>&1
    echo "Container stopped and removed"
    exit 0
fi

container_id=$(docker ps -q -f name="$container_name")
if [[ -n $container_id ]]; then
    echo "Container is already running. Stop it first with '$0 stop'"
    exit 0
fi

# Ensure necessary directories exist
if [[ ! -d $local_tmp ]]; then
    mkdir -p "$local_tmp" || { echo "Error: Failed to create directory $local_tmp"; exit 1; }
fi

> "$url_file"
url=""

# cannot use --net host because it doesnt work on macos
#--net host
docker run \
    --rm \
    --name "$container_name" \
    -d \
    -p 35001:35001 \
    -v $(pwd)/entrypoint.sh:/opt/openvpn/entrypoint.sh \
    -v "$ovpn_file:/opt/openvpn/profile.ovpn:ro" \
    -v "$local_tmp:/output" \
    --device /dev/net/tun:/dev/net/tun \
    --cap-add NET_ADMIN kpalang/aws-vpn:latest

url=$(cat "$url_file")

while [[ -z "$url" ]]; do
    echo "waiting for url"
    echo "url: $url"
    url=$(cat "$url_file")
    sleep 1
done
_open=$(command -v xdg-open)
if [[ -z "$_open" ]]; then
    _open=$(command -v open)
fi
$_open "$url" 2>/dev/null || open "$url" 2>/dev/null || echo "Please open $url in your browser."
