FROM ubuntu:20.04 AS Base

ENV DEBIAN_FRONTEND=noninteractive

ENV CMAKE_GCC_VERSION_FOR_LTO=9

RUN apt-get update \
	&& apt-get -y upgrade \
	&& apt-get install -y --no-install-recommends \
		cmake build-essential ragel \
		libz-dev libicu-dev libcairo-dev libprotobuf-dev \
		protobuf-compiler libcrypto++-dev libcgal-dev \
		lighttpd cron git-core curl python ca-certificates sudo \
		cgdb \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN ldconfig


#Install Cppms
# Note that our final Image depends on this, hence we only want a single small layer
FROM Base AS Cppcms

RUN cd /usr/src \
	&& git clone https://github.com/artyom-beilis/cppcms.git cppcms \
	&& mkdir /usr/src/cppcms/build \
	&& cd /usr/src/cppcms/build \
	&& cmake -DCMAKE_BUILD_TYPE=Release -DDISABLE_SCGI=ON -DDISABLE_HTTP=ON -DDISABLE_STATIC=ON ../ \
	&& make -j $(nproc) \
	&& make install \
	&& rm -r /usr/src/cppcms


#Install Oscar-create
FROM Base AS OscarCreate

WORKDIR /usr/src
RUN git clone --recursive https://github.com/dbahrdt/oscar.git oscar
RUN git -C /usr/src/oscar fetch \
	&& git -C /usr/src/oscar checkout 18d293369612cdbcffb3fe5895a8fabf8cb54f30 \
	&& git -C /usr/src/oscar submodule update --init --recursive
WORKDIR /usr/src/oscar/build
RUN cmake -DCMAKE_BUILD_TYPE=ultra ../
RUN make -j $(nproc) oscar-create oscar-cmd

##Copy binaries
RUN mkdir -p /image/usr/local/bin
RUN cp /usr/src/oscar/build/oscar-create/oscar-create /image/usr/local/bin/
RUN chmod +x /image/usr/local/bin/oscar-create
RUN cp /usr/src/oscar/build/oscar-cmd/oscar-cmd /image/usr/local/bin/
RUN chmod +x /image/usr/local/bin/oscar-cmd

## Copy configs
RUN mkdir -p /image/etc/oscar-create/lists
RUN cp -a /usr/src/oscar/data/configs/oscar-create/*.json /image/etc/oscar-create/
RUN cp -a -L /usr/src/oscar/data/configs/oscar-create/lists/* /image/etc/oscar-create/lists/
RUN cp -a  /usr/src/oscar/data/configs/srclists/* /image/etc/oscar-create/lists/


#Install oscar-web
FROM Base AS OscarWeb

WORKDIR /usr/src
RUN git clone --recursive https://github.com/dbahrdt/oscar-web.git oscar-web
RUN git -C /usr/src/oscar-web fetch \
	&& git -C /usr/src/oscar-web checkout 65f6e198548b35042d55e212da12b82f00d585f3 \
	&& git -C /usr/src/oscar-web submodule update --init --recursive
WORKDIR /usr/src/oscar-web/build
RUN cmake -DCMAKE_BUILD_TYPE=ultra ../
RUN make -j $(nproc)
RUN mkdir -p /image/usr/local/bin

##Copy Binaries
RUN cp oscar-web /image/usr/local/bin/
RUN chmod +x /image/usr/local/bin/oscar-web
RUN strip /image/usr/local/bin/oscar-web

##Copy data
RUN mkdir -p /image/etc/oscar-web
RUN touch /image/etc/oscar-web/.keep
RUN cp -a /usr/src/oscar-web/website /image/var/www/oscar


#Install OsmGraphCreator
FROM Base AS OsmGraphCreator

WORKDIR /usr/src
RUN git clone --recursive https://github.com/fmi-alg/OsmGraphCreator OsmGraphCreator
RUN git -C /usr/src/OsmGraphCreator fetch \ 
	&& git -C /usr/src/OsmGraphCreator checkout 2610fe34fef46e73036d217529f00596c1de4a18 \
	&& git -C /usr/src/OsmGraphCreator submodule update --init --recursive
WORKDIR /usr/src/OsmGraphCreator/build
RUN cmake -DCMAKE_BUILD_TYPE=Release ../
RUN make -j $(nproc)

##Copy binaries
RUN mkdir -p /image/usr/local/bin
RUN cp creator/creator /image/usr/local/bin/graph-creator 
RUN chmod +x /image/usr/local/bin/graph-creator
RUN strip /image/usr/local/bin/graph-creator

##Copy configs
RUN mkdir /image//etc/graph-creator
RUN cp -r /usr/src/OsmGraphCreator/data/configs /image/etc/graph-creator/


#Install CHConstructor
FROM Base AS CHConstructor

RUN cd /usr/src \
RUN git clone --recursive https://github.com/chaot4/ch_constructor.git CHConstructor
RUN git -C /usr/src/CHConstructor fetch \ 
	&& git -C /usr/src/CHConstructor checkout 05eb8df84b08b2c3f66ec1117d31d44f2e536eca \
	&& git -C /usr/src/CHConstructor submodule update --init --recursive
WORKDIR /usr/src/CHConstructor/build
RUN cmake -DCMAKE_BUILD_TYPE=Release ../
RUN make -j $(nproc)

##Copy binaries
RUN mkdir -p /image/usr/local/bin
RUN cp ch_constructor /image/usr/local/bin/ch-constructor
RUN chmod +x /image/usr/local/bin/ch-constructor
RUN strip /image/usr/local/bin/ch-constructor


#Install path-finder-cli
FROM Base AS PathFinder

WORKDIR cd /usr/src \
RUN git clone --recursive https://github.com/somakolli/path-finder-cli.git PathFinderCli
RUN git -C /usr/src/PathFinderCli fetch \
	&& git -C /usr/src/PathFinderCli checkout 3049eb89404518e872faa51886b13b01a6df657e \
	&& git -C /usr/src/PathFinderCli submodule update --remote --init --recursive
WORKDIR /usr/src/PathFinderCli/build
RUN cmake -DCMAKE_BUILD_TYPE=ultra ../
RUN make -j $(nproc)

##Copy binaries
RUN mkdir -p /image/usr/local/{libexec,lib,bin}
RUN cp vendor/path_finder/vendor/tbb/*.{so,a} /image/usr/local/lib/
RUN cp file_creator /image/usr/local/libexec/path-finder-create
RUN strip /image/usr/local/libexec/path-finder-create
RUN chmod +x /image/usr/local/libexec/path-finder-create
RUN echo -e '#!/bin/bash\nexport LD_LIBRARY_PATH="/usr/local/lib"\nexec /usr/local/libexec/path-finder-create $@' > /image/usr/local/bin/path-finder-create
RUN chmod +x /image/usr/local/bin/path-finder-create


#Final phase
#We simply copy all stuff from /image of the previous images and add our scripts

FROM Cppcms AS Final
COPY --from=OscarCreate /image/* /
COPY --from=OscarWeb /image/* /
COPY --from=OsmGraphCreator /image/* /
COPY --from=CHConstructor /image/* /
COPY --from=PathFinder /image/* /

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
