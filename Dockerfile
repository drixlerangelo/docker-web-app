# use a apache with php docker image
FROM php:7.3-apache

# set the directory to root
WORKDIR /

# update the system
RUN apt-get update && apt-get upgrade

# enable ssl
RUN a2enmod ssl
