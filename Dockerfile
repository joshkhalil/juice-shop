# syntax=docker/dockerfile:1
FROM node:12.18.4-buster

# The default repos have been archived by Debian (deb.debian.org returns 404), so
# point apt at the Debian snapshot archive before doing anything else. Use http
# for this bootstrap step so we don't need ca-certificates to be present yet.
RUN echo 'deb     [trusted=yes check-valid-until=no] http://snapshot.debian.org/archive/debian/20211201T215332Z/ buster main \n\
deb-src [trusted=yes check-valid-until=no] http://snapshot.debian.org/archive/debian/20211201T215332Z/ buster main \n\
deb     [trusted=yes check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20211201T215332Z/ buster/updates main \n\
deb-src [trusted=yes check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20211201T215332Z/ buster/updates main' > /etc/apt/sources.list

RUN apt-get -y update && apt-get -y install ca-certificates apt-transport-https

RUN apt-get -y install \
    liblog4j2-java=2.11.1-2

ARG BUILD_DATE
ARG VCS_REF
LABEL maintainer="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
    org.opencontainers.image.title="OWASP Juice Shop" \
    org.opencontainers.image.description="Probably the most modern and sophisticated insecure web application" \
    org.opencontainers.image.authors="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
    org.opencontainers.image.vendor="Open Web Application Security Project" \
    org.opencontainers.image.documentation="https://help.owasp-juice.shop" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.version="12.3.0" \
    org.opencontainers.image.url="https://owasp-juice.shop" \
    org.opencontainers.image.source="https://github.com/clintonherget/juice-shop" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE \
    io.snyk.containers.image.dockerfile="/Dockerfile"

RUN addgroup --system --gid 1001 juicer && \
    adduser juicer --system --uid 1001 --ingroup juicer
COPY --chown=juicer . /juice-shop
WORKDIR /juice-shop
# If building behind a TLS-intercepting proxy (e.g. Zscaler), pass the corporate
# root CA as a build secret so npm can verify the registry without the cert ever
# being committed to the repo or baked into an image layer:
#   docker build --secret id=ca,src=/path/to/corp-ca.crt -t juice-shop .
# The build also works without the secret on networks with no TLS interception.
RUN --mount=type=secret,id=ca \
    if [ -f /run/secrets/ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/ca; fi && \
    npm install --production --unsafe-perm
RUN npm dedupe
RUN rm -rf frontend/node_modules
RUN mkdir logs && \
    chown -R juicer logs && \
    chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/ && \
    chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/
USER 1001
EXPOSE 3000
CMD ["npm", "start"]
