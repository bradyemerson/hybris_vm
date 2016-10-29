#!/bin/bash

# Install additional packages
add-apt-repository ppa:webupd8team/java;
apt-get update;
apt-get install oracle-java8-installer glade zenity bleachbit build-essential module-assistant;


# Guest Additions
m-a prepare;
# Activate CD via device menu
/media/cdrom/VBoxLinuxAdditions.run;
usermod -aG vboxsf hybris;

/usr/share/applications/hybris.desktop

tar --lzma -cpf hybris.tar.lzma --directory="/home/hybris/app" .



# HOSTS file
127.0.0.1   telco.local
127.0.0.1	electronics.local
127.0.0.1	apparel-de.local
127.0.0.1	apparel-uk.local
127.0.0.1	powertools.local
127.0.0.1	b2ctelco.local
127.0.0.1	insurance.local
127.0.0.1	financialservices.local
127.0.0.1	api.hybrisdev.com