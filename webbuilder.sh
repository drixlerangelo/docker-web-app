#!/bin/sh

fnDescription()
{
   echo ""
   echo "Usage: $0 -u HTTP_PORT -s HTTPS_PORT [-d DOMAIN] [-p PHP_IMG]"
   echo "\t-u The unencrypted port"
   echo "\t-s The encrypted port"
   echo "\t-d The domain name will derive from the parent directory unless specified"
   echo "\t-p PHP Docker image (default: apache)"
   exit 1 # Exit script after printing help
}

while getopts "u:s:d:p:" arg
do
   case "$arg" in
      u ) http_port="$OPTARG";;
      s ) https_port="$OPTARG";;
      d ) domain="$OPTARG";;
      p ) php_img="$OPTARG";;
      ? ) fnDescription;; # Print fnDescription in case parameter is non-existent
   esac
done

if [ -z "$http_port" ] || [ -z "$https_port" ]
then
   echo "Some or all of the parameters are empty";
   fnDescription
fi

if [ -z "$domain" -a "$domain" != " " ]
then
   domain=$(basename ${PWD%})
fi

if [ -z "$php_img" -a "$php_img" != " " ]
then
   php_img="apache"
fi

docker-compose down

container=`echo "$domain" | sed 's/\./_/g'`

# STEP 1: Replace the keywords

sed -i "s/DOMAIN/$domain/g" apache/container/letsencrypt.conf

sed -i -e "s/DOMAIN/$domain/g" -e "s/HTTP_PORT/$http_port/g" apache/host/0-website.conf

# STEP 2: Run the website

cont_conf="letsencrypt.conf"

echo "CONTAINER=$container\nHTTP_PORT=$http_port\nCONT_CONF=$cont_conf\nPHP_IMG=$php_img" > .env

conf_src=`realpath apache/host/0-website.conf`
conf_dst="/etc/apache2/sites-enabled/$domain.conf"

rm -f $conf_dst

ln -s $conf_src $conf_dst

ln -s ../letsencrypt/data/.well-known ./www/.well-known

systemctl restart apache2

docker-compose up -d --build

# STEP 4: run letsencrypt

cert_path=`realpath letsencrypt/certs/`
data_path=`realpath letsencrypt/data/`

docker run -it --rm -v "$cert_path":/etc/letsencrypt -v "$data_path":/data/letsencrypt \
    certbot/certbot certonly --webroot --webroot-path=/data/letsencrypt \
    -d "$domain" --agree-tos --cert-name "$domain"

# STEP 5: replace the files with ssl enabled

sed -i -e "s/DOMAIN/$domain/g" -e "s/HTTP_PORT/$http_port/g" apache/host/1-website.conf

conf_src=`realpath apache/host/1-website.conf`

rm -f $conf_dst

ln -s $conf_src $conf_dst

# STEP 6: restart apache

systemctl restart apache2

docker-compose down && docker-compose up -d --build
