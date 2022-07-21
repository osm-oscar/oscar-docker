FROM ubuntu:21.10 AS base

ENV DEBIAN_FRONTEND=noninteractive

ARG SRC_DIR="/usr/src"
ENV SRC_DIR="${SRC_DIR}"

ARG IMAGE_DIR="/image"
ENV IMAGE_DIR="${IMAGE_DIR}"

ARG NUM_THREADS=4
ENV NUM_THREADS="${NUM_THREADS:-4}"

FROM base AS buildenv
RUN apt-get update \
	&& apt-get -y upgrade \
	&& apt-get install -y --no-install-recommends \
		cmake build-essential ragel \
		libz-dev libicu-dev libcairo-dev libprotobuf-dev libtbb-dev \
		protobuf-compiler libcrypto++-dev libcgal-dev \
		git-core curl python ca-certificates \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}

FROM base AS runenv
RUN apt-get update \
	&& apt-get -y upgrade \
	&& apt-get install -y --no-install-recommends \
		libz-dev libicu-dev libcairo-dev libprotobuf-dev libtbb-dev \
		protobuf-compiler libcrypto++-dev libcgal-dev \
		lighttpd cron curl python ca-certificates sudo \
		cgdb \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}

#Install Oscar-create
FROM buildenv AS oscarcreate

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/osm-oscar/oscar.git oscar
RUN git -C ${SRC_DIR}/oscar fetch \
	&& git -C ${SRC_DIR}/oscar checkout 6e6364f15887829ecf42305108b83de36d479630 \
	&& git -C ${SRC_DIR}/oscar submodule sync \
	&& git -C ${SRC_DIR}/oscar submodule update --init --recursive
WORKDIR ${SRC_DIR}/oscar/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DOSCAR_OPTIMIZE_ULTRA=ON -DSSERIALIZE_DISABLE_DTS2=ON ../
RUN make -j ${NUM_THREADS} oscar-create oscar-cmd

##Copy binaries
RUN mkdir -p ${IMAGE_DIR}/usr/local/bin
RUN cp ${SRC_DIR}/oscar/build/oscar-create/oscar-create ${IMAGE_DIR}/usr/local/bin/
RUN chmod +x ${IMAGE_DIR}/usr/local/bin/oscar-create
RUN cp ${SRC_DIR}/oscar/build/oscar-cmd/oscar-cmd ${IMAGE_DIR}/usr/local/bin/
RUN chmod +x ${IMAGE_DIR}/usr/local/bin/oscar-cmd
RUN strip ${IMAGE_DIR}/usr/local/bin/oscar-cmd
RUN strip ${IMAGE_DIR}/usr/local/bin/oscar-create

## Copy configs
RUN mkdir -p ${IMAGE_DIR}/etc/oscar-create/lists
RUN cp -a ${SRC_DIR}/oscar/data/configs/oscar-create/*.json ${IMAGE_DIR}/etc/oscar-create/
RUN cp -a -L ${SRC_DIR}/oscar/data/configs/oscar-create/lists/* ${IMAGE_DIR}/etc/oscar-create/lists/
RUN cp -a  ${SRC_DIR}/oscar/data/configs/srclists/* ${IMAGE_DIR}/etc/oscar-create/lists/

#Install oscar-web
FROM buildenv AS oscarweb

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/osm-oscar/oscar-web.git oscar-web
RUN git -C ${SRC_DIR}/oscar-web fetch \
	&& git -C ${SRC_DIR}/oscar-web checkout ec36f87d273579ab0b2459c05fcc35f21e328c8a \
	&& git -C ${SRC_DIR}/oscar-web submodule sync \
	&& git -C ${SRC_DIR}/oscar-web submodule update --init --recursive
WORKDIR ${SRC_DIR}/oscar-web/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DOSCARWEB_OPTIMIZE_ULTRA=TRUE -DSSERIALIZE_DISABLE_DTS2=ON ../
RUN make -j ${NUM_THREADS}

##Copy Binaries
RUN mkdir -p ${IMAGE_DIR}/usr/local/bin
RUN cp oscar-web ${IMAGE_DIR}/usr/local/bin/
RUN chmod +x ${IMAGE_DIR}/usr/local/bin/oscar-web
RUN strip ${IMAGE_DIR}/usr/local/bin/oscar-web

##Copy data
RUN mkdir -p ${IMAGE_DIR}/etc/oscar-web
RUN touch ${IMAGE_DIR}/etc/oscar-web/.keep
RUN mkdir -p ${IMAGE_DIR}/var/www/
RUN cp -a ${SRC_DIR}/oscar-web/website ${IMAGE_DIR}/var/www/oscar


#Install OsmGraphCreator
FROM buildenv AS osmgraphcreator

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/fmi-alg/OsmGraphCreator OsmGraphCreator
RUN git -C ${SRC_DIR}/OsmGraphCreator fetch \ 
	&& git -C ${SRC_DIR}/OsmGraphCreator checkout 54b8a61035867bc9ef86d8fcfd711ac0b7609a12 \
	&& git -C ${SRC_DIR}/OsmGraphCreator submodule sync \
	&& git -C ${SRC_DIR}/OsmGraphCreator submodule update --init --recursive
WORKDIR ${SRC_DIR}/OsmGraphCreator/build
RUN cmake -DCMAKE_BUILD_TYPE=Release ../
RUN make -j ${NUM_THREADS}

##Copy binaries
RUN mkdir -p ${IMAGE_DIR}/usr/local/bin
RUN cp creator/creator ${IMAGE_DIR}/usr/local/bin/graph-creator 
RUN chmod +x ${IMAGE_DIR}/usr/local/bin/graph-creator
RUN strip ${IMAGE_DIR}/usr/local/bin/graph-creator

##Copy configs
RUN mkdir -p ${IMAGE_DIR}/etc/graph-creator
RUN cp -r ${SRC_DIR}/OsmGraphCreator/data/configs ${IMAGE_DIR}/etc/graph-creator/


#Install CHConstructor
FROM buildenv AS chconstructor

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/osm-oscar/ch_constructor.git CHConstructor
RUN git -C ${SRC_DIR}/CHConstructor fetch \ 
	&& git -C ${SRC_DIR}/CHConstructor checkout 8de181ac2ee3be2450b94650fef3736f435b9f23 \
	&& git -C ${SRC_DIR}/CHConstructor submodule sync \
	&& git -C ${SRC_DIR}/CHConstructor submodule update --init --recursive
WORKDIR ${SRC_DIR}/CHConstructor/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DLARGE_GRAPH=ON ../
RUN make -j ${NUM_THREADS}

##Copy binaries
RUN mkdir -p ${IMAGE_DIR}/usr/local/bin
RUN cp ch_constructor ${IMAGE_DIR}/usr/local/bin/ch-constructor
RUN chmod +x ${IMAGE_DIR}/usr/local/bin/ch-constructor
RUN strip ${IMAGE_DIR}/usr/local/bin/ch-constructor


#Install path-finder-cli
FROM buildenv AS pathfinder

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/osm-oscar/path-finder-cli.git PathFinderCli
WORKDIR ${SRC_DIR}/PathFinderCli
RUN git fetch \
	&& git checkout d2e8068b1fb2b7a716153f2728c7ea0a24c15259 \
	&& git submodule sync \
	&& git submodule update --init --recursive

WORKDIR ${SRC_DIR}/PathFinderCli/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DPATHFINDER_OPTIMIZE_ULTRA=ON -DSSERIALIZE_DISABLE_DTS2=ON ../
RUN make -j ${NUM_THREADS}

##Copy binaries
RUN mkdir -p ${IMAGE_DIR}/usr/local/bin
RUN cp file_creator ${IMAGE_DIR}/usr/local/bin/path-finder-create
RUN strip ${IMAGE_DIR}/usr/local/bin/path-finder-create
RUN chmod +x ${IMAGE_DIR}/usr/local/bin/path-finder-create

#Final phase
#We simply copy all stuff from ${IMAGE_DIR} of the previous images and add our scripts

FROM runenv AS final

COPY --from=oscarcreate ${IMAGE_DIR}/ /
COPY --from=oscarweb ${IMAGE_DIR}/ /
COPY --from=osmgraphcreator ${IMAGE_DIR}/ /
COPY --from=chconstructor ${IMAGE_DIR}/ /
COPY --from=pathfinder ${IMAGE_DIR}/ /


RUN ldconfig

#Setup lighttpd
COPY 20-oscar.conf /etc/lighttpd/conf-available/
RUN ln -s /etc/lighttpd/conf-available/10-fastcgi.conf /etc/lighttpd/conf-enabled/ \
	&& ln -s /etc/lighttpd/conf-available/10-expire.conf /etc/lighttpd/conf-enabled/ \
	&& ln -s /etc/lighttpd/conf-available/20-oscar.conf /etc/lighttpd/conf-enabled/
#This is needed on debian
#	&& ln -s /usr/share/doc/lighttpd/config/conf.d/mime.conf /etc/lighttpd/conf-enabled/

#Setup users
RUN useradd -m -U oscar \
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
