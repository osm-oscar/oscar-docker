FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

ENV CMAKE_GCC_VERSION_FOR_LTO=9

RUN apt-get update \
	&& apt-get -y upgrade \
	&& apt-get install -y --no-install-recommends \
		cmake build-essential ragel \
		libz-dev libicu-dev libcairo-dev libprotobuf-dev \
		protobuf-compiler libcrypto++-dev libcgal-dev \
		lighttpd cron git-core curl python ca-certificates sudo \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}/

#Install CPPCms
RUN cd /usr/src \
	&& git clone https://github.com/artyom-beilis/cppcms.git cppcms \
	&& mkdir /usr/src/cppcms/build \
	&& cd /usr/src/cppcms/build \
	&& cmake -DCMAKE_BUILD_TYPE=Release -DDISABLE_SCGI=ON -DDISABLE_HTTP=ON -DDISABLE_STATIC=ON ../ \
	&& make -j $(nproc) \
	&& make install \
	&& rm -r /usr/src/cppcms

#Install Oscar-create
RUN cd /usr/src/ \
	&& git clone --recursive https://github.com/dbahrdt/oscar.git oscar \
	&& git -C /usr/src/oscar checkout 1725958192f4b54888aae9253739fcfc60a28710 \
	&& git -C /usr/src/oscar submodule update --init --recursive \
	&& mkdir /etc/oscar-create \
	&& cp -a /usr/src/oscar/data/configs/oscar-create/*.json /etc/oscar-create/ \
	&& mkdir /etc/oscar-create/lists \
	&& cp -a -L /usr/src/oscar/data/configs/oscar-create/lists/* /etc/oscar-create/lists/ \
	&& cp -a  /usr/src/oscar/data/configs/srclists/* /etc/oscar-create/lists/ \
	&& mkdir /usr/src/oscar/build \
	&& cd /usr/src/oscar/build \
	&& cmake -DCMAKE_BUILD_TYPE=ultra ../ \
	&& cd /usr/src/oscar/build \
	&& make -j $(nproc) oscar-create \
	&& cp /usr/src/oscar/build/oscar-create/oscar-create /usr/local/bin/ \
	&& chmod +x /usr/local/bin/oscar-create \
	&& strip /usr/local/bin/oscar-create \
	&& rm -r /usr/src/oscar

#Install oscar-web
RUN cd /usr/src/ \
	&& git clone --recursive https://github.com/dbahrdt/oscar-web.git oscar-web \
	&& git -C /usr/src/oscar-web checkout 89df75494df4a87f37ac6de3e79e66a288d07816 \
	&& git -C /usr/src/oscar-web submodule update --init --recursive \
	&& mkdir /etc/oscar-web \
	&& cp -a /usr/src/oscar-web/website /var/www/oscar \
	&& mkdir /usr/src/oscar-web/build \
	&& cd /usr/src/oscar-web/build \
	&& cmake -DCMAKE_BUILD_TYPE=ultra ../ \
	&& cd /usr/src/oscar-web/build \
	&& make -j $(nproc) \
	&& cp oscar-web /usr/local/bin/ \
	&& chmod +x /usr/local/bin/oscar-web \
	&& strip /usr/local/bin/oscar-web \
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

#Setup directories
RUN mkdir "/source" \
	&& mkdir "/scratch" \
	&& mkdir "/scratch/fast" \
	&& mkdir "/scratch/slow" \
	&& mkdir "/next" \
	&& mkdir "/active" \
	&& mkdir "/archive"

#Setup oscar-env
COPY oscar-env.sh /etc/oscar-env.sh

#Setup oscar-web-daemon script
COPY oscar-web-daemon.sh /usr/local/bin/oscar-web-daemon
RUN chmod +x /usr/local/bin/oscar-web-daemon

#Setup update skript
COPY oscar-update.sh /usr/local/bin/oscar-update
COPY oscar-cron.sh /usr/local/bin/oscar-cron
RUN chmod +x /usr/local/bin/oscar-update \
	&& chmod +x /usr/local/bin/oscar-cron \
	&& echo "0  1    * * *   oscar    /usr/local/bin/oscar-cron\n" >> /etc/crontab

#Setup default oscar-create config
COPY oscar-create-settings.json /etc/oscar-create/settings.json
COPY oscar-create-user-settings.json /etc/oscar-create/user-settings.json

#Setup default oscar-web config
COPY oscar-web-config.js /etc/oscar-web/config.js

# Start running
COPY run.sh /
ENTRYPOINT ["/run.sh"]
CMD []

EXPOSE 80
