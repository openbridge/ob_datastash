FROM openjdk:8-jre-alpine
MAINTAINER Thomas Spicer <thomas@openbridge.com>
RUN addgroup -S logstash && adduser -S -G logstash logstash

RUN apk add --no-cache \
		bash \
		curl \
		libc6-compat \
		libzmq

RUN apk add --no-cache 'su-exec>=0.2'
ENV GPG_KEY 46095ACC8548582C1A2699A9D27D666CD88E42B4

ENV LOGSTASH_PATH /usr/share/logstash/bin
ENV PATH $LOGSTASH_PATH:$PATH

ENV LOGSTASH_VERSION 5.5.2
ENV LOGSTASH_TARBALL="https://artifacts.elastic.co/downloads/logstash/logstash-${LOGSTASH_VERSION}.tar.gz" \
	  LOGSTASH_TARBALL_ASC="https://artifacts.elastic.co/downloads/logstash/logstash-${LOGSTASH_VERSION}.tar.gz.asc" \
	  LOGSTASH_TARBALL_SHA1="2961489ccf8bef2bf9ae6c4eaaeeeb65b2ccd109"

RUN set -ex; \
	\
	if [ -z "$LOGSTASH_TARBALL_SHA1" ] && [ -z "$LOGSTASH_TARBALL_ASC" ]; then \
		echo >&2 'error: have neither a SHA1 _or_ a signature file -- cannot verify download!'; \
		exit 1; \
	fi; \
	\
	apk add --no-cache --virtual .fetch-deps \
		ca-certificates \
		gnupg \
		openssl \
		tar \
	; \
	\
	wget -O logstash.tar.gz "$LOGSTASH_TARBALL"; \
	\
	if [ "$LOGSTASH_TARBALL_SHA1" ]; then \
		echo "$LOGSTASH_TARBALL_SHA1 *logstash.tar.gz" | sha1sum -c -; \
	fi; \
	\
	if [ "$LOGSTASH_TARBALL_ASC" ]; then \
		wget -O logstash.tar.gz.asc "$LOGSTASH_TARBALL_ASC"; \
		export GNUPGHOME="$(mktemp -d)"; \
		gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY"; \
		gpg --batch --verify logstash.tar.gz.asc logstash.tar.gz; \
		rm -rf "$GNUPGHOME" logstash.tar.gz.asc; \
	fi; \
	\
	dir="$(dirname "$LOGSTASH_PATH")"; \
	\
	mkdir -p "$dir"; \
	tar -xf logstash.tar.gz --strip-components=1 -C "$dir"; \
	rm logstash.tar.gz; \
	\
	apk del .fetch-deps; \
	\
	export LS_SETTINGS_DIR="$dir/config"; \
	if [ -f "$LS_SETTINGS_DIR/log4j2.properties" ]; then \
		cp "$LS_SETTINGS_DIR/log4j2.properties" "$LS_SETTINGS_DIR/log4j2.properties.dist"; \
		truncate -s 0 "$LS_SETTINGS_DIR/log4j2.properties"; \
	fi; \
	\
	for userDir in \
		"$dir/config" \
		"$dir/data" \
	; do \
		if [ -d "$userDir" ]; then \
			chown -R logstash:logstash "$userDir"; \
		fi; \
	done; \
	\
	/usr/share/logstash/bin/logstash-plugin install logstash-filter-i18n; \
	logstash --version

COPY docker-entrypoint.sh /
COPY logstash.yml /usr/share/logstash/config
COPY config/pipeline /usr/share/logstash/pipeline

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-e", ""]
