# vkucukcakar/ip-list-updater

This Docker image simply, updates Cloudflare (or other CDN) IP list and reloads Nginx (or Apache)!

ip-list-updater as Docker image. (ip-list-updater: Automatic CDN and bogon IP list updater for firewall and server configurations)

* Downloads CDN IP ranges to whitelist in firewalls, update server configurations
* Supports Nginx ngx_http_realip_module, Apache mod_remoteip module, raw mode (for any firewall, server or daemon)
* Pre-defined CDN IP range sources with keywords: cloudflare, cloudfront, fastly, maxcdn

The main purpose of this image is to download and update CDN IP ranges periodically. 
However, other functionalities of ip-list-updater like ipset mode and firewall configuration updates are still available if you wish to use them inside a container.
Other usage cases of ip-list-updater is possible but not documented here, please see ip-list-updater documentation for them.

## Supported tags

* alpine, latest

## Environment variables supported

* SCHEDULE=["15 3 * * *"]
	Cron schedule. Do not set to assign default value, daily/03:15.
* MODE=[nginx|apache|raw]
	ip-list-updater operation mode parameter. This variable is required.
* IPV=[4|6|all]
	ip-list-updater validate IP version parameter. This variable is required.
* SOURCES=[keyword-or-url]
	Set download sources ("spamhaus", "cymru", "cloudflare", "maxcdn", "cloudfront", "fastly" keywords or space separated custom URLs). This variable is required.
* RELOAD_SERVER=[server-proxy]
	Container name of Nginx or Apache server to be reloaded. If set, /var/run/docker.sock must be mounted.
	For supported containers, server is automatically reloaded without any downtime after a successful IP list update if RELOAD_SERVER is defined.
	The official Nginx Docker image is supported and the server could be reloaded without any downtime after a successful IP list update. 
* RESTART_CONTAINER=[server-proxy]
	Container name to restart. If set, /var/run/docker.sock must be mounted.
	If RELOAD_SERVER is not supported for your image, you can use RESTART_CONTAINER to restart server container after a successful IP list update, 
	which usually means a few or less seconds of downtime and disconnected clients sometimes.
	Ideally, you should use RELOAD_SERVER or SUCCESS command to send signals to make your server reloaded for zero downtime.
* SUCCESS=['echo -e \"POST /containers/server-proxy/kill?signal=HUP HTTP/1.0\r\n\" | nc -U /var/run/docker.sock']
	Custom success command is set and will be executed after IP list is updated. 
	SUCCESS command is handled automatically if "nginx" or "apache" mode is selected and RELOAD_SERVER or RESTART_CONTAINER is defined.
	The default success command sends Nginx container a HUP signal which makes Nginx reload configuration files without restarting container.
	There is no need to override default success command if you use official Nginx images or any other Nginx image that use Nginx master process as PID 1. 
	(That is USR1 signal for Apache server.) The above example is already the default success command for "nginx" mode and just given to demonstrate quoting.
	In other words, SUCCESS command should not be set while using official Nginx image or any compatible image.
* EXTRA_PARAMETERS=['--timeout==60']
	Extra parameters for ip-list-updater, except "-u, --update, -o, --output, -c, --success" since they are hardcoded and handled by image.

## Example

	$ docker run --name ip-list-updater -v /my/location/configurations:/configurations -v /var/run/docker.sock:/var/run/docker.sock -e SCHEDULE="15 3 * * *" -e MODE=nginx -e IPV=all -e SOURCES=cloudflare -e RELOAD_SERVER=server-proxy -d vkucukcakar/ip-list-updater

	
### Docker Compose example

version: '2'

services:

    ip-list-updater:

        image: vkucukcakar/ip-list-updater

        container_name: ip-list-updater

        environment:

            SCHEDULE: "15 3 * * *"

            MODE: nginx

            IPV: 4

            SOURCES: cloudflare

            RELOAD_SERVER: server-proxy

            # SUCCESS command is handled automatically if "nginx" or "apache" mode is selected and RELOAD_SERVER or RESTART_CONTAINER is defined. 
			
            #SUCCESS='echo -e \"POST /containers/server-proxy/kill?signal=HUP HTTP/1.0\r\n\" | nc -U /var/run/docker.sock'
            #SUCCESS='echo -e \"POST /containers/server-proxy/restart HTTP/1.0\r\n\" | nc -U /var/run/docker.sock'

            EXTRA_PARAMETERS: '--timeout==60'

        volumes:

            - /var/run/docker.sock:/var/run/docker.sock

            - ./configurations:/configurations


### Nginx example configuration

	#real_ip_header X-Real-IP;
	#real_ip_header X-Forwarded-For;
	real_ip_header CF-Connecting-IP;
	real_ip_recursive off;
	include path/configurations/ip-list-updater.lst;
	
	
## Caveats

* Docker socket must me mounted to /var/run/docker.sock for RELOAD_SERVER to work.
* Output directory /configurations can be mounted and the created output file /configurations/ip-list-updater.lst can be included by your server configuration.
