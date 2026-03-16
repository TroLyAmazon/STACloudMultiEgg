#!/bin/bash
cd /home/container

# Make internal Docker IP address available to processes.
INTERNAL_IP=127.0.0.1
export INTERNAL_IP

# Print Node.js Version
node -v

# Replace Startup Variables
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}
