FROM ubuntu:14.04
MAINTAINER Nandana Mihindukulasooriya <https://twitter.com/nandanamihindu>

# openjdk 6 hard-coded to resolve 
# ambiguity in build dependency
# https://github.com/openlink/virtuoso-opensource/issues/342
# FIXME: Is openjdk-6-jdk still needed?
ENV BUILD_DEPS openjdk-6-jdk unzip wget net-tools build-essential
ENV URL https://github.com/openlink/virtuoso-opensource/archive/stable/7.zip
#ENV URL https://github.com/openlink/virtuoso-opensource/archive/develop/7.zip

ENV PATCH_00 https://github.com/openlink/virtuoso-opensource/commit/4c438f3f6381db2400a4399f137ae02b998208d6.diff

# Build virtuoso opensource debian package from github
RUN echo "deb http://archive.ubuntu.com/ubuntu/ precise-backports main restricted universe multiverse" >> /etc/apt/sources.list
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y $BUILD_DEPS && \
    cd /tmp && \
    wget --no-check-certificate --quiet $URL \
       -O /tmp/virtuoso-opensource.zip && \
    unzip -q /tmp/virtuoso-opensource.zip && \
    wget --no-check-certificate -O /tmp/00.patch $PATCH_00 && \
    cd /tmp/virtuoso-*/ && \
    patch -p1 < /tmp/00.patch && \
    deps=$(dpkg-checkbuilddeps 2>&1 | sed 's/.*: //' | sed 's/([^)]*)//g') && \
    apt-get install -y $deps && \
    dpkg-buildpackage -us -uc && \
    apt-get remove -y --purge $BUILD_DEPS $deps && \
    apt-get autoremove --purge -y && \
    cd /tmp && \
    dpkg -i virtuoso-opensource*deb virtuoso-server*.deb virtuoso-minimal_*.deb virtuoso-server*.deb  libvirtodbc*.deb virtuoso-vad-conductor*.deb virtuoso-vad-isparql*.deb || apt-get install -f -y && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* && \
    mv /tmp/*deb /var/cache/apt/archives/ && \
    rm -rf /tmp/*

RUN ln -s /usr/bin/isql-vt /usr/local/bin/isql


# Enable mountable /virtuoso for data storage, which
# we'll symlink the standard db folder to point to
RUN mkdir /virtuoso
RUN rm -rf /var/lib/virtuoso-opensource-7/db 
RUN ln -s /virtuoso /var/lib/virtuoso-opensource-7/db
VOLUME /virtuoso

# /staging for loading data
RUN mkdir /staging ; sed -i '/DirsAllowed/ s:$:,/staging:' /etc/virtuoso-opensource-7/virtuoso.ini
VOLUME /staging

COPY staging.sh /usr/local/bin/
COPY docker-entrypoint.sh /
RUN chmod 755 /usr/local/bin/staging.sh /docker-entrypoint.sh


# Virtuoso ports
EXPOSE 8890
EXPOSE 1111
WORKDIR /virtuoso
# Modify config-file on start-up to reflect memory available
ENTRYPOINT ["/docker-entrypoint.sh"]
# Run virtuoso in the foreground
CMD ["/usr/bin/virtuoso-t", "+wait", "+foreground", "+configfile", "/etc/virtuoso-opensource-7/virtuoso.ini"]

