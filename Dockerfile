FROM ubuntu:bionic


LABEL maintainer="Christoph Schreyer <christoph.schreyer@stud.uni-regensburg.de>"


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
 openjdk-11-jdk \
 junit \
 junit4 \
 dejagnu \
 git-core \
 mutt \
 vim \
 wget 
RUN apt-get --trivial-only install sudo
RUN apt-get -y install \
 python2.7-dev \
 python-setuptools \
 python-psycopg2 \
 python-m2crypto \
 python-pip \
 && rm -rf /var/lib/apt/lists/*
RUN pip install --upgrade pip
 

# Download & Install praktomat
WORKDIR /var/www/
RUN git clone --recursive git://github.com/ITSec-UR/Praktomat.git \
 && pip install -r Praktomat/requirements.txt

 
# Create praktomat directories
RUN mkdir -p /var/www/Praktomat/PraktomatSupport /var/www/Praktomat/data /srv/praktomat/mailsign /srv/praktomat/contrib


# Add custom files from praktomat repository
COPY createkey.py /srv/praktomat/mailsign/createkey.py
COPY safe-Dockerfile Praktomat/docker-image/Dockerfile
COPY safe-docker /usr/local/bin/safe-docker
COPY ports.conf /etc/apache2/ports.conf
COPY praktomat.conf /etc/apache2/sites-available/praktomat.conf
COPY mpm_event.conf /etc/apache2/mods-available/mpm_event.conf
RUN chmod 755 /srv/praktomat/mailsign/createkey.py \
 && chmod 755 Praktomat/docker-image/Dockerfile \
 && chmod 755 /usr/local/bin/safe-docker
 

# Add users praktomat and tester
RUN adduser --disabled-password --gecos '' praktomat \
 && adduser --disabled-password --gecos '' tester
RUN echo 'Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"\n\nroot    ALL=(ALL:ALL) ALL\n\n%sudo   ALL=(ALL:ALL) ALL\n\n%praktomat ALL=NOPASSWD:ALL\npraktomat ALL=NOPASSWD:ALL\nwww-data ALL=NOPASSWD:ALL\ndeveloper ALL=NOPASSWD:ALL\npraktomat ALL=NOPASSWD: /usr/local/bin/safe-docker\nwww-data ALL=(tester)NOPASSWD:ALL\npraktomat ALL=(tester)NOPASSWD:ALL, NOPASSWD:/usr/local/bin/safe-docker' >> /etc/sudoers


# Add mailsign key
RUN python /srv/praktomat/mailsign/createkey.py
RUN mv signer_key.pem /srv/praktomat/mailsign/signer_key.pem \
 && mv signer_key_pub.pem /srv/praktomat/mailsign/signer_key_pub.pem


# Get JPlag 2.11.8 and checkstyle 8.20
RUN wget -O /srv/praktomat/contrib/jplag.jar https://github.com/jplag/jplag/releases/download/v2.11.8-SNAPSHOT/jplag-2.11.8-SNAPSHOT-jar-with-dependencies.jar \
 && wget -O /srv/praktomat/contrib/checkstyle.jar https://github.com/checkstyle/checkstyle/releases/download/checkstyle-8.20/checkstyle-8.20-all.jar

# Set permissions for Praktomat directory
RUN chmod -R 0775 Praktomat \
 && chown -R praktomat:praktomat Praktomat \
 && adduser www-data praktomat \
 && adduser tester praktomat
 

# Adjust settings for new Praktomat instance
# RUN sed -i "s/praktomat.itsec.ur.de/${HOST_NAME}/g" /var/www/Praktomat/src/settings/local.py \
# && sed -i "s/praktomat.itsec.ur.de/${HOST_NAME}/g" /etc/apache2/sites-available/praktomat.conf

 
# Migrate database changes
RUN /var/www/Praktomat/src/manage-devel.py migrate --noinput
RUN /var/www/Praktomat/src/manage-local.py collectstatic --noinput -link
RUN chown -R praktomat:praktomat Praktomat/static


# Configure apache webserver
RUN service apache2 start \ 
 && a2enmod wsgi \
 && a2enmod rewrite \
 && a2ensite praktomat.conf \
 && service apache2 restart


# Fix locale
RUN echo "export LANG='de_DE.UTF-8'\nexport LC_ALL='de_DE.UTF-8'" >> /etc/apache2/envvars \
 && echo "LC_ALL=de_DE.UTF-8" >> /etc/environment \
 && echo "de_DE.UTF-8" >> /etc/locale.gen \
 && echo "LANG=de_DE.UTF-8" >> /etc/locale.conf \
 && locale-gen de_DE.UTF-8


# Performance tweaks
RUN echo DefaultTasksMax=1000 >> /etc/systemd/system.conf
 

EXPOSE 25 9001
