FROM osixia/openldap:1.3.0
LABEL maintainer="it@feki.de"\
	version="1.3.0"

ENV FUSIONDIRECTORY_VERSION=1.3\
		SCHEMA2LDIF_VERSION=1.3

RUN apt-get update && \
		apt-get install -y --no-install-recommends curl

## Install Schema2LDIF
RUN curl --insecure https://repos.fusiondirectory.org/sources/schema2ldif/schema2ldif-${SCHEMA2LDIF_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr && \
    rm -rf /usr/CHANGELOG && \
    rm -rf /usr/LICENSE && \
    \
## Install FusionDirectory
    mkdir -p /usr/src/fusiondirectory /usr/src/fusiondirectory-plugins && \
    curl --insecure https://repos.fusiondirectory.org/sources/fusiondirectory/fusiondirectory-${FUSIONDIRECTORY_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr/src/fusiondirectory && \
    curl --insecure https://repos.fusiondirectory.org/sources/fusiondirectory/fusiondirectory-plugins-${FUSIONDIRECTORY_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr/src/fusiondirectory-plugins && \
    \
### Cleanup
    \
    mkdir -p /etc/ldap/schema/fusiondirectory && \
    cp /usr/src/fusiondirectory/contrib/bin/fusiondirectory-insert-schema /usr/sbin && \
    cp -R /usr/src/fusiondirectory/contrib/openldap/*.schema /etc/ldap/schema/fusiondirectory && \
    cp -R /usr/src/fusiondirectory-plugins/*/contrib/openldap/*.schema /etc/ldap/schema/fusiondirectory && \
    \
    chmod +x /usr/sbin/fusiondirectory-insert-schema && \
    \
    rm -rf /usr/src/*

ADD bootstrap /var/fusiondirectory/bootstrap
ADD certs /container/service/slapd/assets/certs
ADD environment /container/environment/01-custom

COPY init.sh /sbin/init.sh
RUN chmod 755 /sbin/init.sh
RUN sed -i "/# stop OpenLDAP/i /sbin/init.sh" /container/service/slapd/startup.sh
