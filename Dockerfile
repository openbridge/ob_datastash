FROM openjdk:8-jre-alpine

RUN addgroup -S logstash && adduser -S -G logstash logstash

RUN apk add --no-cache \
		bash \
		curl \
		libc6-compat \
		libzmq

RUN apk add --no-cache 'su-exec>=0.2'

ENV LOGSTASH_PATH /usr/share/logstash/bin
ENV PATH $LOGSTASH_PATH:$PATH

ENV LOGSTASH_VERSION 6.2.3
ENV LOGSTASH_TARBALL="https://artifacts.elastic.co/downloads/logstash/logstash-${LOGSTASH_VERSION}.tar.gz" \
	  LOGSTASH_TARBALL_ASC="https://artifacts.elastic.co/downloads/logstash/logstash-${LOGSTASH_VERSION}.tar.gz.asc" \
	  LOGSTASH_TARBALL_SHA1="a553e800665b7ccc1a6f30b49fa0d336526c8f01144751dbe617b33b38595f121f6d8b4c43e8b2f5b648bc283fc839f035c816c696d8ecccc3a93a4bb2a329c7" \
		GPG_KEY="46095ACC8548582C1A2699A9D27D666CD88E42B4"

RUN set -ex; \
	\
	\
	apk add --no-cache --virtual .fetch-deps \
		ca-certificates \
		gnupg \
		openssl \
		libc6-compat \
		tar \
	; \
	\
	wget -O logstash.tar.gz "$LOGSTASH_TARBALL"; \
	\
	if [ "$LOGSTASH_TARBALL_SHA" ]; then \
		echo "$LOGSTASH_TARBALL_SHA *logstash.tar.gz" | sha1sum -c -; \
	fi; \
	\
	if [ "$TARBALL_ASC" ]; then \
  wget --progress=bar:force -O logstash.tar.gz.asc "$TARBALL_ASC"; \
  export GNUPGHOME="$(mktemp -d)"; \
  ( gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
  || gpg --keyserver pgp.mit.edu --recv-keys "$GPG_KEY" \
  || gpg --keyserver keyserver.pgp.com --recv-keys "$GPG_KEY" ); \
  gpg --batch --verify logstash.tar.gz.asc logstash.tar.gz; \
  rm -rf "$GNUPGHOME" logstash.tar.gz.asc || true; \
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
COPY config/drivers /drivers

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-e", ""]