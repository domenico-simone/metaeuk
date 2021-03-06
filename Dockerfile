ARG NAMESPACE=
FROM ${NAMESPACE}debian:stable-slim as metaeuk-builder
ARG NAMESPACE

RUN apt-get update && apt-get install -y \
    build-essential cmake xxd git zlib1g-dev libbz2-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/metaeuk
ADD . .

RUN git submodule update --init

RUN mkdir -p build_sse/bin && mkdir -p build_avx/bin && mkdir -p build_neon/bin

WORKDIR /opt/metaeuk/build_sse
RUN if [ X"$NAMESPACE" = X"" ]; then \
      cmake -DHAVE_SSE4_1=1 -DHAVE_MPI=0 -DHAVE_TESTS=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=. ..; \
      make -j $(nproc --all) && make install; \
    fi

WORKDIR /opt/metaeuk/build_avx
RUN if [ X"$NAMESPACE" = X"" ]; then \
      cmake -DHAVE_AVX2=1 -DHAVE_MPI=0 -DHAVE_TESTS=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=. ..; \
      make -j $(nproc --all) && make install; \
    fi

FROM ${NAMESPACE}debian:stable-slim
ARG NAMESPACE
MAINTAINER Eli Levy Karin <eli.levy.karin@gmail.com>

RUN apt-get update && apt-get install -y \
      gawk bash grep libstdc++6 libgomp1 zlib1g libbz2-1.0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=metaeuk-builder /opt/metaeuk/build_sse/bin/metaeuk /usr/local/bin/metaeuk_sse42
COPY --from=metaeuk-builder /opt/metaeuk/build_avx/bin/metaeuk /usr/local/bin/metaeuk_avx2
RUN echo -e '#!/bin/bash\n\
if $(grep -q -E "^flags.+avx2" /proc/cpuinfo); then\n\
    exec /usr/local/bin/metaeuk_avx2 "$@"\n\
else\n\
    exec /usr/local/bin/metaeuk_sse42 "$@"\n\
fi' > /usr/local/bin/metaeuk

ENTRYPOINT ["/usr/local/bin/metaeuk"]
