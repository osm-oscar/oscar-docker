FROM ubuntu:20.04 AS Base

ENV DEBIAN_FRONTEND=noninteractive

ENV CMAKE_GCC_VERSION_FOR_LTO=9

ARG SRC_DIR="/usr/src"
ENV SRC_DIR="${SRC_DIR}"

ARG IMAGE_DIR="/image"
ENV IMAGE_DIR="${IMAGE_DIR}"

ARG NUM_THREADS=4
ENV NUM_THREADS="${NUM_THREADS:-4}"

FROM Base AS RunEnv
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


FROM Base AS BuildEnv
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

#Install Cppms
FROM BuildEnv AS CppcmsBuild

WORKDIR ${SRC_DIR}
RUN git clone https://github.com/artyom-beilis/cppcms.git cppcms
WORKDIR ${SRC_DIR}/cppcms/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DDISABLE_SCGI=ON -DDISABLE_HTTP=ON -DDISABLE_STATIC=ON ../
RUN make -j ${NUM_THREADS}
RUN make install
RUN make DESTDIR=${IMAGE_DIR} install


#Install Oscar-create
FROM BuildEnv AS OscarCreate

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/dbahrdt/oscar.git oscar
RUN git -C ${SRC_DIR}/oscar fetch \
	&& git -C ${SRC_DIR}/oscar checkout ed82e3d2dea9dc6d5869c40799b328127fcd0e83 \
	&& git -C ${SRC_DIR}/oscar submodule update --init --recursive
WORKDIR ${SRC_DIR}/oscar/build
RUN cmake -DCMAKE_BUILD_TYPE=ultra ../
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
FROM CppcmsBuild AS OscarWeb

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/dbahrdt/oscar-web.git oscar-web
RUN git -C ${SRC_DIR}/oscar-web fetch \
	&& git -C ${SRC_DIR}/oscar-web checkout 886acf68234078537fc6e99ba095b010813265a5 \
	&& git -C ${SRC_DIR}/oscar-web submodule update --init --recursive
WORKDIR ${SRC_DIR}/oscar-web/build
RUN cmake -DCMAKE_BUILD_TYPE=ultra ../
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
FROM BuildEnv AS OsmGraphCreator

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/fmi-alg/OsmGraphCreator OsmGraphCreator
RUN git -C ${SRC_DIR}/OsmGraphCreator fetch \ 
	&& git -C ${SRC_DIR}/OsmGraphCreator checkout 904e27b3992bf2bda87254c5af1ec88aa03de616 \
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
FROM BuildEnv AS CHConstructor

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/chaot4/ch_constructor.git CHConstructor
RUN git -C ${SRC_DIR}/CHConstructor fetch \ 
	&& git -C ${SRC_DIR}/CHConstructor checkout 05eb8df84b08b2c3f66ec1117d31d44f2e536eca \
	&& git -C ${SRC_DIR}/CHConstructor submodule update --init --recursive
WORKDIR ${SRC_DIR}/CHConstructor/build
RUN cmake -DCMAKE_BUILD_TYPE=Release ../
RUN make -j ${NUM_THREADS}

##Copy binaries
RUN mkdir -p ${IMAGE_DIR}/usr/local/bin
RUN cp ch_constructor ${IMAGE_DIR}/usr/local/bin/ch-constructor
RUN chmod +x ${IMAGE_DIR}/usr/local/bin/ch-constructor
RUN strip ${IMAGE_DIR}/usr/local/bin/ch-constructor


#Install path-finder-cli
FROM BuildEnv AS PathFinder

WORKDIR ${SRC_DIR}
RUN git clone --recursive https://github.com/dbahrdt/path-finder-cli.git PathFinderCli
WORKDIR ${SRC_DIR}/PathFinderCli
RUN git fetch \
	&& git checkout 1c484bebdab4197c43977fb784c55867fbe77dc9 \
	&& git submodule sync \
	&& git submodule update --init --recursive

WORKDIR ${SRC_DIR}/PathFinderCli/build
RUN cmake -DCMAKE_BUILD_TYPE=ultra ../
RUN make -j ${NUM_THREADS}

##Copy binaries
RUN mkdir -p ${IMAGE_DIR}/usr/local/bin
RUN cp file_creator ${IMAGE_DIR}/usr/local/bin/path-finder-create
RUN strip ${IMAGE_DIR}/usr/local/bin/path-finder-create
RUN chmod +x ${IMAGE_DIR}/usr/local/bin/path-finder-create


#Final phase
#We simply copy all stuff from ${IMAGE_DIR} of the previous images and add our scripts

FROM RunEnv AS Final

COPY --from=CppcmsBuild ${IMAGE_DIR}/ /
COPY --from=OscarCreate ${IMAGE_DIR}/ /
COPY --from=OscarWeb ${IMAGE_DIR}/ /
COPY --from=OsmGraphCreator ${IMAGE_DIR}/ /
COPY --from=CHConstructor ${IMAGE_DIR}/ /
COPY --from=PathFinder ${IMAGE_DIR}/ /

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
