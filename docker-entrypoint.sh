#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- logstash "$@"
fi

mkdir -p /data
# Set a link to datastash as a command.
ln -s /usr/share/logstash/bin/logstash datastash

# Run as user "logstash" if the command is "logstash"
# allow the container to be started with `--user`
if [ "$1" = 'datastash' -a "$(id -u)" = '0' ]; then
	set -- su-exec datastash "$@"
fi

exec "$@"
