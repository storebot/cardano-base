FROM ubuntu:18.04 as builder

ENV USER cardano
ENV HOME /home/${USER}
ENV LOCAL_BIN ${HOME}/local/bin/
ENV CARDANO_WS ${HOME}/cardano-node
ENV CARDANO_NODE_TAG "1.18.0"

RUN apt-get update -y && apt-get install automake build-essential pkg-config libffi-dev \
    libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ tmux git jq wget \
    libncursesw5 libtool autoconf -y

RUN groupadd -r ${USER} \
    && useradd -r -g ${USER} ${USER} \
    && mkdir ${HOME} \
    && chown -R ${USER}:${USER} ${HOME}

WORKDIR ${HOME}

RUN wget https://downloads.haskell.org/~ghc/8.6.5/ghc-8.6.5-x86_64-deb9-linux.tar.xz \
    && tar -xf ghc-8.6.5-x86_64-deb9-linux.tar.xz \
    && rm ghc-8.6.5-x86_64-deb9-linux.tar.xz \
    && cd ghc-8.6.5 \
    && ./configure \
    && make install

RUN git clone https://github.com/input-output-hk/libsodium \
    && cd libsodium \
    && git checkout 66f017f1 \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install

USER ${USER}

ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

RUN wget https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz \
    && tar -xf cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz \
    && rm cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz cabal.sig \
    && mkdir -p ${LOCAL_BIN} \
    && mv cabal ${LOCAL_BIN}

ENV PATH="${LOCAL_BIN}:$PATH"

RUN cabal update && cabal --version

WORKDIR ${HOME}

RUN git clone https://github.com/input-output-hk/cardano-node.git \
    && cd cardano-node \
    && git fetch --all --tags \
    && git tag \
    && git checkout tags/${CARDANO_NODE_TAG} \
    && cabal build all

RUN cp -p ${CARDANO_WS}/dist-newstyle/build/x86_64-linux/ghc-8.6.5/cardano-node-${CARDANO_NODE_TAG}/x/cardano-node/build/cardano-node/cardano-node ${LOCAL_BIN} \
    && cp -p ${CARDANO_WS}/dist-newstyle/build/x86_64-linux/ghc-8.6.5/cardano-cli-${CARDANO_NODE_TAG}/x/cardano-cli/build/cardano-cli/cardano-cli ${LOCAL_BIN}

FROM ubuntu:18.04

ENV USER cardano
ENV HOME /home/${USER}
ENV LOCAL_BIN ${HOME}/local/bin/

COPY --from=builder /usr/local/lib /usr/local/lib

ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

RUN groupadd -r ${USER} \
    && useradd -r -g ${USER} ${USER} \
    && mkdir ${HOME} \
    && chown -R ${USER}:${USER} ${HOME}

WORKDIR ${HOME}

USER ${USER}

COPY --from=builder ${LOCAL_BIN} ${LOCAL_BIN}

ENV PATH="${LOCAL_BIN}:$PATH"

CMD ["cardano-cli", "--version"]
