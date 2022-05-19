#!/bin/bash

fnDescription()
{
   cmd_msg="Usage: $0 -u HTTP_PORT -s HTTPS_PORT -e EMAIL [-d DOMAIN] [-p PHP_IMG]"
   cmd_msg="${cmd_msg} [-a SERVER_IP] [-i INDEX_PATH] [-m MODE]"

   echo "${cmd_msg}"
   echo -e "\t-u The unencrypted port"
   echo -e "\t-s The encrypted port"
   echo -e "\t-d The domain name will derive from the parent directory unless specified"
   echo -e "\t-p PHP Docker image (default: apache)"
   echo -e "\t-e Email used for Let's Encrypt registration"
   echo -e "\t-a The public IP of this server"
   echo -e "\t-i The relative path of the index file (like \"public\" for Laravel projects)"
   echo -e "\t-m Toggle between local or prod server setups (default: prod)"
   exit 1
}

while getopts "u:s:d:p:e:a:i:m:" arg
do
   case "$arg" in
      u ) http_port="$OPTARG";;
      s ) https_port="$OPTARG";;
      d ) domain="$OPTARG";;
      p ) php_img="$OPTARG";;
      e ) email="$OPTARG";;
      a ) server_ip="$OPTARG";;
      i ) index_path="$OPTARG";;
      m ) mode="$OPTARG";;
      ? ) fnDescription;;
   esac
done

if [ -z "$http_port" ] || [ -z "$https_port" ] || [ -z "$email" ]
then
   echo "Some or all parameters are missing";
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

if [ -z "$server_ip" -a "$server_ip" != " " ]
then
   server_ip=$(dig +short txt ch whoami.cloudflare @1.0.0.1 | awk -F'"' '{print $2}')
fi

domain_parts=(${domain//./ })
domain_parts_len=${#domain_parts[@]}

if [[ $domain_parts_len < 3 ]]
then
   base_subdomain="www"
else
   base_subdomain=${domain_parts[domain_parts_len-3]}
fi

if [[ "$domain_parts_len" < 3 ]] || [ "$base_subdomain" == "www" ]
then
   order_prefix="0"
else
   order_prefix="1"
fi

if [ "$mode" != "local" -a "$mode" != "prod" ]
then
   mode="prod"
fi

docker-compose down

container=`echo "$domain" | sed 's/\./_/g'`
index_path="/var/www/html/$index_path"

# STEP 1: Replace the keywords

cp apache/container/letsencrypt.example.conf apache/container/letsencrypt.conf
sed -i -e "s/DOMAIN/$domain/g" -e "s/ROOT/$index_path/g" apache/container/letsencrypt.conf

cp apache/host/0-website.example.conf apache/host/0-website.conf
sed -i -e "s/DOMAIN/$domain/g" -e "s/HTTP_PORT/$http_port/g" apache/host/0-website.conf

# STEP 2: Run the website

cont_conf="letsencrypt.conf"

echo -e "CONTAINER=$container\nHTTP_PORT=$http_port\nCONT_CONF=$cont_conf\nPHP_IMG=$php_img\n" > .env

conf_src=`realpath apache/host/0-website.conf`
conf_dst="/etc/apache2/sites-enabled/$order_prefix-$domain.conf"

rm -f $conf_dst

ln -s $conf_src $conf_dst

ln -s ../letsencrypt/data/.well-known ./www/.well-known

systemctl restart apache2

docker-compose up -d --build

if [ "$mode" == "prod" ]
then
   # STEP 4: run letsencrypt

   cert_path=`realpath letsencrypt/certs/`
   data_path=`realpath letsencrypt/data/`

   echo "$server_ip $domain" >> /etc/hosts

   docker run -it --rm -v "$cert_path":/etc/letsencrypt -v "$data_path":/data/letsencrypt \
      certbot/certbot certonly --webroot --webroot-path=/data/letsencrypt \
      -d "$domain" --agree-tos --cert-name "$domain" --email "$email"

   # STEP 5: replace the files with ssl enabled

   cp apache/host/1-website.example.conf apache/host/1-website.conf
   sed -i -e "s/DOMAIN/$domain/g" -e "s/HTTP_PORT/$http_port/g" apache/host/1-website.conf

   conf_src=`realpath apache/host/1-website.conf`

   rm -f $conf_dst

   ln -s $conf_src $conf_dst

   # STEP 6: restart apache

   systemctl restart apache2

   docker-compose down && docker-compose up -d --build

   # STEP 7: auto-renew the certificate

   cron_cmd=`echo -e '0 0 1 */2 * docker run -it --rm'`
   cron_cmd="${cron_cmd} -v $cert_path:/etc/letsencrypt"
   cron_cmd="${cron_cmd} -v $data_path:/data/letsencrypt certbot/certbot certonly --webroot"
   cron_cmd="${cron_cmd} --webroot-path=/data/letsencrypt -d $domain --cert-name $domain"
   cron_cmd="${cron_cmd} --email $email --agree-tos"
   cron_cmd="${cron_cmd} && systemctl restart apache2"

   (crontab -l; echo "$cron_cmd")|awk '!x[$0]++'|crontab -
fi
