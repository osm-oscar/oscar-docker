FROM ubuntu:19.10

ENV CMAKE_GCC_VERSION_FOR_LTO=9

RUN apt-get update \
	&& apt-get -y upgrade \
	&& apt-get install -y --no-install-recommends \
		cmake build-essential ragel \
		libz-dev libicu-dev libcairo-dev libprotobuf-dev \
		protobuf-compiler libcrypto++-dev libcgal-dev \
		lighttpd cron git-core wget python ca-certificates sudo \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}/

#Install Oscar-create
RUN cd /usr/src/ \
	&& git clone --recursive https://github.com/dbahrdt/oscar.git oscar \
	&& git -C /usr/src/oscar checkout 4fc08c6dbbc1a2ba6db102eb6a76df1314662414 \
	&& git -C /usr/src/oscar submodule update --init --recursive \
	&& mkdir /etc/oscar-create \
	&& cp -a  /usr/src/oscar/data/configs/* /etc/oscar-create/ \
	&& mkdir /usr/src/oscar/build \
	&& cd /usr/src/oscar/build \
	&& cmake -DCMAKE_BUILD_TYPE=ultra ../ \
	&& cd /usr/src/oscar/build \
	&& make -j $(nproc) \
	&& cp oscar-create/oscar-create /usr/local/bin/ \
	&& chmod +x /usr/local/bin/oscar-create \
	&& rm -r /usr/src/oscar

#Install CPPCms
RUN cd /usr/src \
	&& git clone https://github.com/artyom-beilis/cppcms.git cppcms \
	&& mkdir /usr/src/cppcms/build \
	&& cd /usr/src/cppcms/build \
	&& cmake -DCMAKE_BUILD_TYPE=Release -DDISABLE_SCGI=ON -DDISABLE_HTTP=ON -DDISABLE_STATIC=ON ../ \
	&& make -j $(nproc) \
	&& make install

#Install oscar-web
RUN cd /usr/src/ \
	&& git clone --recursive https://github.com/dbahrdt/oscar-web.git oscar-web \
	&& git -C /usr/src/oscar-web checkout bd3e984c2e92e61461e52f68811353ade5b239ff \
	&& git -C /usr/src/oscar-web submodule update --init --recursive \
	&& mkdir /etc/oscar-web \
	&& cp -a /usr/src/oscar-web/website /var/www/oscar \
	&& mkdir /usr/src/oscar-web/build \
	&& cd /usr/src/oscar-web/build \
	&& cmake -DCMAKE_BUILD_TYPE=ultra ../ \
	&& cd /usr/src/oscar-web/build \
	&& make -j $(nproc) \
	&& cp oscar-web /usr/local/bin/ \
	&& rm -r /usr/src/oscar-web

RUN ldconfig

#Setup lighttpd
COPY 20-oscar.conf /etc/lighttpd/conf-available/
RUN ln -s /etc/lighttpd/conf-available/10-fastcgi.conf /etc/lighttpd/conf-enabled/ \
	&& ln -s /etc/lighttpd/conf-available/10-expire.conf /etc/lighttpd/conf-enabled/ \
	&& ln -s /etc/lighttpd/conf-available/20-oscar.conf /etc/lighttpd/conf-enabled/
#This is needed on debian
#	&& ln -s /usr/share/doc/lighttpd/config/conf.d/mime.conf /etc/lighttpd/conf-enabled/

#Setup users
RUN useradd -U oscar \
	&& usermod -a -G oscar www-data

#Setup logging
RUN mkdir /var/log/oscar-web && chmod o+rwx /var/log/oscar-web

#Setup directories
RUN mkdir "/source" \
	&& mkdir "/scratch" \
	&& mkdir "/next" \
	&& mkdir "/active" \
	&& mkdir "/archive"

#Setup oscar-env
COPY oscar-env.sh /etc/oscar-env.sh

#Setup oscar-create config
COPY oscar-machine-config.json /etc/oscar-create/oscar-create/oscar-docker.json
COPY oscar-data-config.json /etc/oscar-create/oscar-create/

#Setup oscar-web config
COPY oscar-web-config.js /etc/oscar-web/

#Setup update skript
COPY oscar-update.sh /usr/local/bin/oscar-update
RUN chmod +x /usr/local/bin/oscar-update \
	&& echo "#!/bin/bash\nsudo -u oscar -g oscar /usr/local/bin/oscar-update" > /etc/cron.daily/oscar-update.sh \
	&& chmod +x /etc/cron.daily/oscar-update.sh

#Setup oscar-web-daemon script
COPY oscar-web-daemon.sh /usr/local/bin/oscar-web-daemon
RUN chmod +x /usr/local/bin/oscar-web-daemon

# Start running
COPY run.sh /
ENTRYPOINT ["/run.sh"]
CMD []

EXPOSE 80
