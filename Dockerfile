FROM debian:stable-slim as build-env
ENV DEBIAN_FRONTEND=noninteractive
ARG TESTS
ARG SOURCE_COMMIT

RUN apt-get update
RUN apt-get -y install apt-utils
RUN apt-get -y install build-essential curl git python3 python3-pip golang shellcheck

WORKDIR /build/busybox
RUN curl -L -o /tmp/busybox.tar.bz2 https://busybox.net/downloads/busybox-1.32.1.tar.bz2 \
    && tar xjvf /tmp/busybox.tar.bz2 --strip-components=1 -C /build/busybox \
    && make defconfig \
    && make install

WORKDIR /build/vpenvconf
COPY ./vpenvconf/ /build/vpenvconf/
RUN if [ "${TESTS:-true}" = true ]; then \
        pip3 install tox \
        && tox \
        ; \
    fi
RUN python3 setup.py bdist --format=gztar

WORKDIR /build/valheim-logfilter
COPY ./valheim-logfilter/ /build/valheim-logfilter/
RUN go build -ldflags="-s -w" \
    && mv valheim-logfilter /usr/local/bin/

WORKDIR /build
RUN git clone https://github.com/Yepoleb/python-a2s.git \
    && cd python-a2s \
    && python3 setup.py bdist --format=gztar

WORKDIR /build/supervisor
RUN curl -L -o /tmp/supervisor.tar.gz https://github.com/Supervisor/supervisor/archive/4.2.2.tar.gz \
    && tar xzvf /tmp/supervisor.tar.gz --strip-components=1 -C /build/supervisor \
    && python3 setup.py bdist --format=gztar

COPY bootstrap /usr/local/sbin/
COPY valheim-status /usr/local/bin/
COPY valheim-is-idle /usr/local/bin/
COPY valheim-bootstrap /usr/local/bin/
COPY valheim-backup /usr/local/bin/
COPY valheim-updater /usr/local/bin/
COPY valheim-plus-updater /usr/local/bin/
COPY valheim-server /usr/local/bin/
COPY defaults /usr/local/etc/valheim/
COPY common /usr/local/etc/valheim/
COPY contrib/* /usr/local/share/valheim/contrib/
RUN chmod 755 /usr/local/sbin/bootstrap /usr/local/bin/valheim-*
RUN if [ "${TESTS:-true}" = true ]; then \
        shellcheck -a -x -s bash -e SC2034 \
            /usr/local/sbin/bootstrap \
            /usr/local/bin/valheim-backup \
            /usr/local/bin/valheim-is-idle \
            /usr/local/bin/valheim-bootstrap \
            /usr/local/bin/valheim-server \
            /usr/local/bin/valheim-updater \
            /usr/local/bin/valheim-plus-updater \
            /usr/local/share/valheim/contrib/*.sh \
        ; \
    fi
WORKDIR /
RUN mv /build/busybox/_install/bin/busybox /usr/local/bin/busybox
RUN rm -rf /usr/local/lib/
RUN tar xzvf /build/supervisor/dist/supervisor-*.linux-x86_64.tar.gz
RUN tar xzvf /build/vpenvconf/dist/vpenvconf-*.linux-x86_64.tar.gz
RUN tar xzvf /build/python-a2s/dist/python-a2s-*.linux-x86_64.tar.gz
COPY supervisord.conf /usr/local/etc/supervisord.conf
RUN mkdir -p /usr/local/etc/supervisor/conf.d/ \
    && chmod 600 /usr/local/etc/supervisord.conf

RUN echo "${SOURCE_COMMIT:-unknown}" > /usr/local/etc/git-commit.HEAD


FROM debian:stable-slim
ENV DEBIAN_FRONTEND=noninteractive
COPY --from=build-env /usr/local/ /usr/local/
COPY fake-supervisord /usr/bin/supervisord
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get -y --no-install-recommends install apt-utils \
    && apt-get -y dist-upgrade \
    && apt-get -y --no-install-recommends install \
        libc6-dev \
        lib32gcc1 \
        libsdl2-2.0-0 \
        libsdl2-2.0-0:i386 \
        curl \
        tcpdump \
        libcurl4 \
        libcurl4:i386 \
        ca-certificates \
        procps \
        locales \
        unzip \
        zip \
        rsync \
        openssh-client \
        jq \
        python3-minimal \
        python3-pkg-resources \
    && echo 'LANG="en_US.UTF-8"' > /etc/default/locale \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && rm -f /bin/sh \
    && ln -s /bin/bash /bin/sh \
    && locale-gen \
    && apt-get clean \
    && mkdir -p /var/spool/cron/crontabs /var/log/supervisor /opt/valheim /opt/steamcmd /root/.config/unity3d/IronGate /config \
    && ln -s /config /root/.config/unity3d/IronGate/Valheim \
    && ln -s /usr/local/bin/busybox /usr/local/sbin/syslogd \
    && ln -s /usr/local/bin/busybox /usr/local/sbin/crond \
    && ln -s /usr/local/bin/busybox /usr/local/sbin/mkpasswd \
    && ln -s /usr/local/bin/busybox /usr/local/bin/crontab \
    && ln -s /usr/local/bin/busybox /usr/local/bin/vi \
    && ln -s /usr/local/bin/busybox /usr/local/bin/patch \
    && ln -s /usr/local/bin/busybox /usr/local/bin/unix2dos \
    && ln -s /usr/local/bin/busybox /usr/local/bin/dos2unix \
    && ln -s /usr/local/bin/busybox /usr/local/bin/makemime \
    && ln -s /usr/local/bin/busybox /usr/local/bin/xxd \
    && ln -s /usr/local/bin/busybox /usr/local/bin/wget \
    && ln -s /usr/local/bin/busybox /usr/local/bin/less \
    && ln -s /usr/local/bin/busybox /usr/local/bin/lsof \
    && ln -s /usr/local/bin/busybox /usr/local/bin/httpd \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ssl_client \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ip \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ipcalc \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ping \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ping6 \
    && ln -s /usr/local/bin/busybox /usr/local/bin/iostat \
    && ln -s /usr/local/bin/busybox /usr/local/bin/setuidgid \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ftpget \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ftpput \
    && ln -s /usr/local/bin/busybox /usr/local/bin/bzip2 \
    && ln -s /usr/local/bin/busybox /usr/local/bin/xz \
    && ln -s /usr/local/bin/busybox /usr/local/bin/pstree \
    && ln -s /usr/local/bin/busybox /usr/local/bin/killall \
    && curl -L -o /tmp/steamcmd_linux.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    && tar xzvf /tmp/steamcmd_linux.tar.gz -C /opt/steamcmd/ \
    && chown -R root:root /opt/steamcmd \
    && chmod 755 /opt/steamcmd/steamcmd.sh \
        /opt/steamcmd/linux32/steamcmd \
        /opt/steamcmd/linux32/steamerrorreporter \
        /usr/bin/supervisord \
    && cd "/opt/steamcmd" \
    && ./steamcmd.sh +login anonymous +quit \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 2456-2457/udp
EXPOSE 9001/tcp
EXPOSE 80/tcp
WORKDIR /
CMD ["/usr/local/sbin/bootstrap"]
