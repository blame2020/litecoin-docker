FROM alpine as builder

ENV LITECOIN_VER 0.18.1
ENV DB_VER 4.8.30.NC

# Install dependencies for Berkelay DB
RUN apk --no-cache add autoconf automake build-base

# Install dependencies for litecoin-core
RUN apk --no-cache add\
        build-base\
        autoconf\
        automake\
        libtool\
        chrpath\
        libevent-dev\
        boost-dev


COPY db-$DB_VER.tar.gz db-$DB_VER.tar.gz
RUN tar xzf db-$DB_VER.tar.gz &&\
        cd db-$DB_VER/build_unix &&\
        sed s/__atomic_compare_exchange/__db_atomic_compare_exchange/ -i ../dbinc/atomic.h &&\
        ../dist/configure --prefix=/usr/local\
        --enable-cxx --disable-shared --with-pic &&\
        make && make install

# Install dependencies for litecoin-core
RUN apk --no-cache add\
        build-base\
        autoconf\
        automake\
        libtool\
        chrpath\
        libevent-dev\
        boost-dev\
        openssl-dev

# https://github.com/litecoin-project/litecoin
COPY litecoin-$LITECOIN_VER.tar.gz litecoin-$LITECOIN_VER.tar.gz
RUN tar xzf litecoin-$LITECOIN_VER.tar.gz
WORKDIR litecoin-$LITECOIN_VER
# https://github.com/litecoin-project/litecoin/issues/407
RUN sed -i 's/char scratchpad\[SCRYPT_SCRATCHPAD_SIZE\];/static &/g' src/crypto/scrypt.cpp
RUN ./autogen.sh &&\
        LDFLAGS=-L/usr/local/lib CPPFLAGS=-I/usr/local/include ./configure\
        --prefix=/usr/local\
        --mandir=/usr/share/man\
        --disable-tests\
        --disable-ccache\
        --disable-zmq\
        --with-gui=no\
        --with-utils\
        --with-libs\
        --with-daemon &&\
        make && make install

FROM alpine
COPY --from=builder /usr/local /usr/local

RUN apk --no-cache add libevent boost openssl

RUN mkdir -p /var/litecoin/data &&\
        addgroup -S litecoin &&\
        adduser -SDH -G litecoin litecoin &&\
        chown -R litecoin:litecoin /var/litecoin

USER litecoin
WORKDIR /var/litecoin

EXPOSE 9333 19333 9332 19332
VOLUME /var/litecoin/data
ENTRYPOINT /usr/local/bin/litecoind -datadir=/var/litecoin/data -printtoconsole
