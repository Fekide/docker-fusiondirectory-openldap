FROM osixia/openldap:1.2.4
LABEL maintainer="it@feki.de"\
	version="1.2.5"

ARG FUSIONDIRECTORY_VERSION=1.3-1

# Get Keys
RUN set -e; \
	export GNUPGHOME="/tmp/gnupg_home" && \
	mkdir -p "$GNUPGHOME" && \
	chmod 700 "$GNUPGHOME" && \
	echo "disable-ipv6" >> "$GNUPGHOME/dirmngr.conf" && \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
		keys.gnupg.net \
	; do \
		echo "  trying $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --receive-keys D744D55EACDA69FF && found=yes && break; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --receive-keys D744D55EACDA69FF && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
	exit 0

	RUN (echo "deb https://repos.fusiondirectory.org/fusiondirectory-current/debian-stretch stretch main"; \
	echo "deb https://repos.fusiondirectory.org/fusiondirectory-extra/debian-stretch stretch main") \
	> /etc/apt/sources.list.d/fusiondirectory-stretch.list \
	&& apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
	fusiondirectory-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-argonaut-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-autofs-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-gpg-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-mail-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-postfix-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-ssh-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-sudo-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-systems-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-weblink-schema=${FUSIONDIRECTORY_VERSION} \
	fusiondirectory-plugin-webservice-schema=${FUSIONDIRECTORY_VERSION} \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD bootstrap /var/fusiondirectory/bootstrap
ADD certs /container/service/slapd/assets/certs
ADD environment /container/environment/01-custom

COPY init.sh /sbin/init.sh
RUN chmod 755 /sbin/init.sh
RUN sed -i "/# stop OpenLDAP/i /sbin/init.sh" /container/service/slapd/startup.sh
