################################################################################
# This Dockerfile was generated from the template at distribution/src/docker/Dockerfile
#
# Beginning of multi stage Dockerfile
################################################################################

################################################################################
# Build stage 0 `builder`:
# Extract elasticsearch artifact
# Install required plugins
# Set gid=0 and make group perms==owner perms
################################################################################

FROM centos:7 AS builder

ENV VERSION 7.4.1
ENV PATH /usr/share/elasticsearch/bin:$PATH

RUN groupadd -g 1000 elasticsearch &&     adduser -u 1000 -g 1000 -d /usr/share/elasticsearch elasticsearch

WORKDIR /usr/share/elasticsearch

RUN cd /opt && curl --retry 8 -s -L -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${VERSION}-no-jdk-linux-x86_64.tar.gz -# && cd -
RUN cd /opt && curl --retry 8 -s -L -O https://github.com/AdoptOpenJDK/openjdk13-binaries/releases/download/jdk-13.0.1+9/OpenJDK13U-jdk_aarch64_linux_hotspot_13.0.1_9.tar.gz && cd -

RUN tar zxf /opt/elasticsearch-${VERSION}-no-jdk-linux-x86_64.tar.gz --strip-components=1
# RUN rm -rf /usr/share/elasticsearch/jdk/*
RUN tar zxf /opt/OpenJDK13U-jdk_aarch64_linux_hotspot_13.0.1_9.tar.gz -C jdk --strip-components=1

RUN rm -rf /usr/share/elasticsearch/jdk/lib/src.zip && rm -rf /usr/share/elasticsearch/jdk/demo

RUN grep ES_DISTRIBUTION_TYPE=tar /usr/share/elasticsearch/bin/elasticsearch-env     && sed -ie 's/ES_DISTRIBUTION_TYPE=tar/ES_DISTRIBUTION_TYPE=docker/' /usr/share/elasticsearch/bin/elasticsearch-env
RUN mkdir -p config data logs
RUN chmod 0775 config data logs
COPY config/elasticsearch.yml config/log4j2.properties config/
RUN echo "xpack.ml.enabled: false" >> config/elasticsearch.yml 

################################################################################
# Build stage 1 (the actual elasticsearch image):
# Copy elasticsearch from stage 0
# Add entrypoint
################################################################################

FROM debian

ENV ELASTIC_CONTAINER true

RUN for iter in {1..10}; \
    do \
		  apt update  -y && apt install -y  netcat \
		  && apt autoremove -y && apt clean && exit_code=0 \
		  && break || exit_code=$? \
		  && echo "apt error: retry $iter in 10s" \
		  && sleep 10; \
		done;\
		(exit $exit_code) \
		&& groupadd -g 1000 elasticsearch && useradd -u 1000 -g 1000 -G 0 -m -d /usr/share/elasticsearch elasticsearch \
		&& chmod 0775 /usr/share/elasticsearch && chgrp 0 /usr/share/elasticsearch

WORKDIR /usr/share/elasticsearch
COPY --from=builder --chown=1000:0 /usr/share/elasticsearch /usr/share/elasticsearch

ENV PATH /usr/share/elasticsearch/bin:$PATH

COPY --chown=1000:0 bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
# Allow ENTRYPOINT (and ES) to run even with a different user

# Replace OpenJDK's built-in CA certificate keystore with the one from the OS
# vendor. The latter is superior in several ways.
# REF: https://github.com/elastic/elasticsearch-docker/issues/171

RUN chgrp 0 /usr/local/bin/docker-entrypoint.sh && chmod g=u /etc/passwd && chmod 0775 /usr/local/bin/docker-entrypoint.sh \
    && ln -sf /etc/pki/ca-trust/extracted/java/cacerts /usr/share/elasticsearch/jdk/lib/security/cacerts

EXPOSE 9200 9300

LABEL org.label-schema.build-date="2019-12-16T22:57:37.839371Z"   org.label-schema.license="Elastic-License"   org.label-schema.name="Elasticsearch"   org.label-schema.schema-version="1.0"   org.label-schema.url="https://www.elastic.co/products/elasticsearch"   org.label-schema.usage="https://www.elastic.co/guide/en/elasticsearch/reference/index.html"   org.label-schema.vcs-ref="3ae9ac9a93c95bd0cdc054951cf95d88e1e18d96"   org.label-schema.vcs-url="https://github.com/elastic/elasticsearch"   org.label-schema.vendor="Elastic"   org.label-schema.version="7.5.1"   org.opencontainers.image.created="2019-12-16T22:57:37.839371Z"   org.opencontainers.image.documentation="https://www.elastic.co/guide/en/elasticsearch/reference/index.html"   org.opencontainers.image.licenses="Elastic-License"   org.opencontainers.image.revision="3ae9ac9a93c95bd0cdc054951cf95d88e1e18d96"   org.opencontainers.image.source="https://github.com/elastic/elasticsearch"   org.opencontainers.image.title="Elasticsearch"   org.opencontainers.image.url="https://www.elastic.co/products/elasticsearch"   org.opencontainers.image.vendor="Elastic"   org.opencontainers.image.version="7.5.1"

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# Dummy overridable parameter parsed by entrypoint
CMD ["eswrapper"]

################################################################################
# End of multi-stage Dockerfile
################################################################################