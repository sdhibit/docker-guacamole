FROM debian:jessie
MAINTAINER Steve Hibit <sdhibit@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get upgrade -y

# Install Oracle Java
RUN \
	echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list && \
	echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list && \
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886 && \
	apt-get update && \
	echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
	apt-get install -y oracle-java8-installer && \
	apt-get install -y oracle-java8-set-default

# Set Java environment variables
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle
ENV JRE_HOME /usr/lib/jvm/java-8-oracle/jre
ENV PATH $PATH:$JAVA_HOME/bin:$JRE_HOME

RUN apt-get install -y \
 supervisor wget make \
 tomcat7 tomcat7-admin tomcat7-docs \
 libcairo2-dev libpng12-dev uuid libossp-uuid-dev \
 libfreerdp-dev freerdp-x11 libpango-1.0-0 libpango1.0-dev \
 libssh2-1 libssh2-1-dev libssh-dev libtelnet-dev libvncserver-dev \
 libpulse-dev libssl1.0.0 gcc libvorbis-dev 

# Set Tomcat environment variables
ENV CATALINA_BASE /var/lib/tomcat7
ENV CATALINA_HOME /usr/share/tomcat7 

RUN mkdir -p $CATALINA_BASE/temp
ADD ./tomcat/server.xml $CATALINA_BASE/conf/server.xml

RUN mkdir /etc/guacamole

ENV GUACAMOLE_HOME /etc/guacamole

#Install Guacamole Server
RUN wget 'http://downloads.sourceforge.net/project/guacamole/current/source/guacamole-server-0.9.2.tar.gz' -O /etc/guacamole/guacamole-server-0.9.2.tar.gz && \
 cd /etc/guacamole && \
 tar xvzf ./guacamole-server-0.9.2.tar.gz && \
 mv ./guacamole-server-0.9.2 ./guacamole-server && \
 cd guacamole-server && \
 ./configure --with-init-dir=/etc/init.d && \
 make && \
 make install && \
 update-rc.d guacd defaults && \
 ldconfig

#Install Guacamole Client
RUN mkdir -p /var/lib/guacamole && \
 mkdir -p $CATALINA_BASE/temp && \
 mkdir $CATALINA_HOME/.guacamole && \
 wget 'http://downloads.sourceforge.net/project/guacamole/current/binary/guacamole-0.9.2.war' -O /var/lib/guacamole/guacamole.war

ADD ./config/guacamole.properties /etc/guacamole/
ADD ./config/user-mapping.xml /etc/guacamole/

ADD ./ssl/guacd.pem /etc/ssl/certs/guacd.pem
ADD ./ssl/guacd.key /etc/ssl/private/guacd.key

RUN chmod 600 /etc/ssl/private/guacd.key && \
 chmod 640 /etc/ssl/certs/guacd.pem

RUN ln -s /etc/guacamole/guacamole.properties $CATALINA_HOME/.guacamole/guacamole.properties && \
 ln -s /var/lib/guacamole/guacamole.war $CATALINA_BASE/webapps/guacamole.war

RUN chmod 755 /etc/guacamole && \
 chmod 644 /etc/guacamole/guacamole.properties && \
 chmod 650 /etc/guacamole/user-mapping.xml && \
 chown root:tomcat7 -R /etc/guacamole/* && \
 chown root:tomcat7 -R $CATALINA_BASE/webapps/*

ADD ./supervisor/supervisor.conf /etc/supervisor/supervisor.conf
ADD ./supervisor/tomcat7.sv.conf /etc/supervisor/conf.d/
ADD ./supervisor/guacd.sv.conf /etc/supervisor/conf.d/

EXPOSE 8080
EXPOSE 8009

ADD ./tomcat/server.xml /etc/tomcat7/server.xml

CMD ["supervisord", "-c", "/etc/supervisor/supervisor.conf"]