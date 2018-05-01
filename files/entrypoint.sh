#!/bin/bash

###
# vkucukcakar/ip-list-updater
# ip-list-updater as Docker image. (ip-list-updater: Automatic CDN and bogon IP list updater for firewall and server configurations)
# Copyright (c) 2017 Volkan Kucukcakar
#
# This file is part of vkucukcakar/ip-list-updater.
#
# vkucukcakar/ip-list-updater is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# vkucukcakar/ip-list-updater is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This copyright notice and license must be retained in all files and derivative works.
###


# Remove previous ip-list-updater pid file if survived from an unexpected container crash
rm /var/run/ip-list-updater.pid >/dev/null 2>&1

# Set success command to execute after a successful update
# Add automatic reloading support for Nginx and Apache containers
if [ "$SUCCESS" ]; then
	echo "Custom success command is set and will be executed after IP list is updated."
	_SUCCESS="--success=\"$SUCCESS\" "
else
	# Check if the server container to be reloaded is set
	if [ "$RELOAD_SERVER" ]; then
		# Check if docker.sock is mounted
		if [ ! -e /var/run/docker.sock ]; then
			echo "Error: /var/run/docker.sock not mounted which is required to reload server when RELOAD_SERVER specified."
			exit 1
		fi
		if [ "$MODE" == "nginx" ]; then
			echo "RELOAD_SERVER is set. Script will try to reload Nginx when IP list updated."
			# Sending HUP signal to Nginx container makes Nginx to reload configurations without restarting container (when official or any other Nginx image that using Nginx master process as PID 1)
			_SUCCESS="--success=\"echo -e \\\"POST /containers/${RELOAD_SERVER}/kill?signal=HUP HTTP/1.0\r\n\\\" | nc -U /var/run/docker.sock\" "
		elif [ "$MODE" == "apache" ]; then
			echo "RELOAD_SERVER is set. Script will try to reload Apache when IP list updated."
			# Sending USR1 signal to Apache makes Apache to reload configurations without restarting container
			_SUCCESS="--success=\"echo -e \\\"POST /containers/${RELOAD_SERVER}/kill?signal=USR1 HTTP/1.0\r\n\\\" | nc -U /var/run/docker.sock\" "
		else
			echo "Error: RELOAD_SERVER only works if MODE=nginx or MODE=apache. RELOAD_SERVER will be omitted. Try using custom SUCCESS command if you want to restart an arbitrary container."
		fi
	elif [ "$RESTART_CONTAINER" ]; then
		# Check if docker.sock is mounted
		if [ ! -e /var/run/docker.sock ]; then
			echo "Error: /var/run/docker.sock not mounted which is required to restart container when RESTART_CONTAINER specified."
			exit 1
		fi
		echo "RESTART_CONTAINER is set. Script will restart the given container when IP list updated."
		# Restart container after IP list update
		_SUCCESS="--success=\"echo -e \\\"POST /containers/${RESTART_CONTAINER}/restart HTTP/1.0\r\n\\\" | nc -U /var/run/docker.sock\" "
	fi
fi

# Check if sources are specified
if [ ! "$SOURCES" ]; then
	echo "Error: SOURCES environment variable must be specified."
	exit 1
fi

# Check if IP version is defined, set _IPV
if [ "$IPV" ]; then
	_IPV="--ipv=\"${IPV}\" "
fi

echo "Output file will be saved to /configurations/ip-list-updater.lst"
# Set schedule to daily if empty
[ -z "$SCHEDULE" ] && export SCHEDULE="15 3 * * *"
# Restore crontab
cp /ip-list-updater/crontabs/root /etc/crontabs/
# Do not echo all with -e to prevent the need for extra quoting text in parameters
echo -e "\n" >>/etc/crontabs/root
# Add ip-list-updater to crontab
echo "$SCHEDULE /usr/local/bin/ip-list-updater.php --update --mode=\"${MODE}\" ${_IPV}--output=\"/configurations/ip-list-updater.lst\" --sources=\"${SOURCES}\" ${_SUCCESS}${EXTRA_PARAMETERS} >>/var/log/cron.log 2>>/var/log/cron-error.log" >>/etc/crontabs/root
# Initially run ip-list-updater (Note: Without eval, quotes in variable will make command failed. It is related to the behavior of bash and a little complicated...)
eval "/usr/local/bin/ip-list-updater.php --update --mode=\"${MODE}\" ${_IPV}--output=\"/configurations/ip-list-updater.lst\" --sources=\"${SOURCES}\" ${_SUCCESS}${EXTRA_PARAMETERS} >>/var/log/cron.log 2>>/var/log/cron-error.log"

# Execute another entrypoint or CMD if there is one
if [[ "$@" ]]; then
	echo "Executing $@"
	$@
	EXITCODE=$?
	if [[ $EXITCODE > 0 ]]; then
		echo "Error: $@ finished with exit code: $EXITCODE"
		exit $EXITCODE;
	fi
fi
