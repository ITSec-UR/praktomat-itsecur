FROM ubuntu:xenial


LABEL maintainer="Christoph Schreyer <christoph.schreyer@stud.uni-regensburg.de>"

# Build arguments
ARG DB_NAME=praktomat_2
ARG HOST_NAME=praktomat.itsec.ur.de
ARG PRAKTOMAT_NAME=ADP


# Install required packages
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install \
 apache2 \
 libpq-dev \ 
 zlib1g-dev \
 libmysqlclient-dev \
 libsasl2-dev \
 libssl-dev \
 swig \
 libapache2-mod-xsendfile \
 libapache2-mod-wsgi \
 openjdk-8-jdk \
 junit \
 junit4 \
 dejagnu \
 gcj-jdk \
 git-core \
 mutt \
 vim
RUN apt-get -y install \
 python2.7-dev \
 python-setuptools \
 python-psycopg2 \
 python-m2crypto \
 python-pip \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip
 
 
# Download & Install Praktomat
WORKDIR /var/www/
RUN git clone --recursive git://github.com/ITSec-UR/Praktomat.git \
 && pip install -r Praktomat/requirements.txt

 
# Create directories
RUN mkdir -p /var/www/Praktomat/PraktomatSupport /var/www/Praktomat/data /srv/praktomat/mailsign


# Add custom files from praktomat repository
COPY createkey.py /srv/praktomat/mailsign/createkey.py
COPY safe-Dockerfile Praktomat/docker-image/Dockerfile
COPY safe-docker /usr/local/bin/safe-docker
COPY ports.conf /etc/apache2/ports.conf
COPY praktomat.conf /etc/apache2/sites-available/praktomat.conf
 
RUN chmod 755 /srv/praktomat/mailsign/createkey.py \
 && chmod 755 Praktomat/docker-image/Dockerfile \
 && chmod 755 /usr/local/bin/safe-docker
 

# Add praktomat user
RUN adduser --disabled-password --gecos '' praktomat


# Add mailsign
WORKDIR /srv/praktomat/mailsign/
RUN python createkey.py
RUN apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D


# Adjust settings for new Praktomat instance
RUN sed -i "s/praktomat_default/${DB_NAME}/g" /var/www/Praktomat/src/settings/local.py \
 && sed -i "s/praktomat.itsec.ur.de/${HOST_NAME}/g" /var/www/Praktomat/src/settings/local.py \
 && sed -i "s/Praktomat Lehrstuhl Kesdogan/Praktomat Lehrstuhl Kesdogan ${PRAKTOMAT_NAME}/g" /var/www/Praktomat/src/settings/local.py \
 && sed -i "s/praktomat.itsec.ur.de/${HOST_NAME}/g" /etc/apache2/sites-available/praktomat.conf
 
# RUN sed -i 's/{% load motd %}//g' /var/www/Praktomat/src/templates/registration/login.html \
# && sed -i 's/{% motd %}//g' /var/www/Praktomat/src/templates/registration/login.html

 
# Migrate changes
RUN ./Praktomat/src/manage-devel.py migrate --noinput
RUN ./Praktomat/src/manage-local.py collectstatic --noinput -link
 

# Set permissions for Praktomat directory
RUN chmod -R 0775 Praktomat/ \
 && chown -R praktomat Praktomat/ \
 && chgrp -R praktomat Praktomat/ \
 && adduser www-data praktomat
 
 
# Configure apache
RUN service apache2 start \ 
 && a2enmod wsgi \
 && a2enmod rewrite \
 && a2ensite praktomat.conf \
 && service apache2 restart 
 

# Docker setup (inactive)
WORKDIR /var/www/Praktomat/
RUN echo 'deb http://apt.dockerproject.org/repo ubuntu-xenial main' >> /etc/apt/sources.list.d/docker.list
RUN apt-get update \
 && apt-get -y install linux-image-extra-4.4.0-128-generic
RUN apt-get -y install docker-engine
RUN service docker start
RUN apt-get --trivial-only install sudo
RUN echo 'Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"\n\nroot    ALL=(ALL:ALL) ALL\n\n%sudo   ALL=(ALL:ALL) ALL\n\n%praktomat ALL=NOPASSWD:ALL\npraktomat ALL=NOPASSWD:ALL\nwww-data ALL=NOPASSWD:ALL\ndeveloper ALL=NOPASSWD:ALL\npraktomat ALL= NOPASSWD: /usr/local/bin/safe-docker' >> /etc/sudoers \
 && echo 'www-data ALL=(TESTER)NOPASSWD:ALL\npraktomat ALL=(TESTER)NOPASSWD:ALL, NOPASSWD:/usr/local/bin/safe-docker' >> /etc/sudoers.d/praktomat_tester

EXPOSE 25 9002