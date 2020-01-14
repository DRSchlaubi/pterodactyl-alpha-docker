FROM alpine:edge

MAINTAINER Michael Rittmeister <michael@rittmeister.in>

ARG VERSION

ENV DAEMON_VERSION=${VERSION} \
    UID=500

WORKDIR /srv/daemon

RUN \
 apk --update --no-cache add coreutils curl \
 && curl -Lo wings https://github.com/pterodactyl/wings/releases/download/${DAEMON_VERSION}/wings \
 && addgroup -S -g ${UID} pterodactyl && adduser -S -D -H -G pterodactyl -u ${UID} -s /bin/false pterodactyl \
 && apk del curl \
 && rm -rf /var/cache/apk/* /tmp/* \
 && chmod u+x ./wings

EXPOSE 8080

CMD [ "./wings" ]
