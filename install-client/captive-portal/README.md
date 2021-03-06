# hotspot-login

Hotspot-login is a login utility for CoovaChilli. hotspot-login is a fork of hotspotlogin in daloRADIUS.

## Requirements

In order to integrate the login utility to a captive portal, we will need the following:

* **Raspbian/Ubuntu**  – A Linux distribution. In this article, we will be using Raspbian release 2017-11-29 or Ubuntu 16.04. Later versions should work fine.

* **Raspberry Pi** – a low cost, credit-card sized computer 

* **CoovaChilli** – a feature rich software access controller that provides a captive portal environment.

* **hostapd** – a software access point capable of turning normal network interface cards into access points and authentication servers.

* **FreeRADIUS** – a radius server for provisioning and accounting.

* **MySQL** – a database server backing the radius server.

* **Nginx** – a proxy server.

* **PHP-FPM  (FastCGI Process Manager)** – an alternative PHP FastCGI implementation with some additional features (mostly) useful for heavy-loaded sites.

## Installation

I assume you have been through the installation of captive portal solution.

Download the source and unzip the file

```console
wget -c https://github.com/MME-Connections/hotspot-login/archive/master.zip -O hotspot-login-master.zip

unzip hotspot-login-master.zip
```

Create webroot folder for the hotspot domain name, copy the hotspot-login in the webroot folder

```console
sudo mkdir /var/www/hotspot.example.com
mv hotspot-login-master /var/www/hotspot.example.com/
```

## Create a server block in nginx

Create the server block file that will tell Nginx on how to process the hotspot login utility.

```console
sudo vim /etc/nginx/sites-available/hotspot.example.com
```

Copy the following lines and paste it into the server block file

```bash
server {
	# Redirect all HTTP traffic to HTTPS since daloRADIUS requires an HTTPS connection
	listen 10.10.10.1:80 default_server; # Change this to match your HotSpot IP address
	server_name hotspot.example.com; # Change this to your domain name
	return 301 https://$server_name$request_uri;
}

server {
	listen 10.10.10.1:443 ssl default_server; # Change this to match your HotSpot IP address
        server_name hotspot.example.com;  # Change this to your domain name

        # Self signed certs generated by the ssl-cert package
        # Don't use them in a production server!
        include snippets/snakeoil.conf;

	# Replace your signed ssl certificate 
	# ssl_certificate /etc/ssl/certs/<public_key_of_ssl_certificate_here>.pem;
	# ssl_certificate_key /etc/ssl/private/<private_key_of_ssl_certificate_here>.key;


	root /var/www/hotspot.example.com; # Change this to match the folder of your hotspot app
	index hotspotlogin.php index.php index.phtml index.html index.htm;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files $uri $uri/ /index.php?$args /hotspotlogin.php?$args $uri/ =404;
	}
    
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.1-fpm.sock; # check the php-fpm.conf configuration listen directive
	}
}
```

That is all we need for a basic configuration. Save and close the file to exit.

### Enable the server block and restart nginx

Now that we have our server block file, we need to enable them. We can do this by creating symbolic links from these files to the sites-enabled directory, which Nginx reads from during startup.

We can create these links by typing:

```console
sudo ln -s /etc/nginx/sites-available/hotspot.example.com /etc/nginx/sites-enabled/
```

Next, test to make sure that there are no syntax errors in any of your Nginx files:

```console
sudo nginx -t
```
If no problems were found, restart Nginx to enable your changes:

```console
sudo systemctl restart nginx
```


### Modify configuration in CoovaChilli and in the hotspot-login


Edit /etc/chilli/config.

```console
sudo vi /etc/chilli/config
```

```bash
#   Use HS_UAMFORMAT to define the actual captive portal url.
HS_UAMFORMAT=https://\$HS_UAMLISTEN/hotspotlogin.php
HS_UAMHOMEPAGE=http://\$HS_UAMLISTEN:\$HS_UAMPORT/prelogin
```


Edit /var/www/hotspot.example.com/hotspotlogin.php

```console
sudo vi /var/www/hotspot.example.com/hotspotlogin.php
```

```bash
# Shared secret used to encrypt challenge with. Prevents dictionary attacks.
# You should change this to your own shared secret.
$uamsecret = "uamtesting123"; # Change this to match the coovachilli config directive HS_UAMSECRET
```

### Restart the captive portal

Let’s now start the hostapd, nginx and CoovaChilli. And try accessing captive portal from our web browser.

```console
sudo systemctl stop hostapd
sudo systemctl stop nginx
sudo systemctl stop chilli

sudo systemctl start chilli
sudo systemctl start nginx
sudo systemctl start hostapd
```
