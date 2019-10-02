#!/bin/bash -e

if [ ! -e "$FIRST_START_DONE" ]; then

	function file_env() {
		local var="$1"
		local fileVar="${var}_FILE"

		# The variables are already defined from the docker-light-baseimage
		# So if the _FILE variable is available we ovewrite them
		if [ "${!fileVar:-}" ]; then
			log-helper trace "${fileVar} was defined"

			val="$(< "${!fileVar}")"
			log-helper debug "${var} was repalced with the contents of ${fileVar} (the value was: ${val})"

			export "$var"="$val"
		fi
		
		unset "$fileVar"
	}

	function ldap_add_or_modify (){
		local LDIF_FILE=$1

		log-helper debug "Processing file ${LDIF_FILE}"
		sed -i "s|{{ LDAP_BASE_DN }}|${LDAP_BASE_DN}|g" $LDIF_FILE
		sed -i "s|{{ LDAP_BACKEND }}|${LDAP_BACKEND}|g" $LDIF_FILE
		sed -i "s|{{ LDAP_DOMAIN }}|${LDAP_DOMAIN}|g" $LDIF_FILE
		sed -i "s|{{ CN_ADMIN_BS64 }}|${CN_ADMIN_BS64}|g" $LDIF_FILE
		sed -i "s|{{ UID_FD_ADMIN_BS64 }}|${UID_FD_ADMIN_BS64}|g" $LDIF_FILE
		sed -i "s|{{ FD_ADMIN_PASSWORD_HASH }}|${FD_ADMIN_PASSWORD_HASH}|g" $LDIF_FILE
		sed -i "s|{{ LDAP_BASE_DOMAIN }}|${LDAP_BASE_DOMAIN}|g" $LDIF_FILE
		if grep -iq changetype $LDIF_FILE ; then
				( ldapmodify -Y EXTERNAL -Q -H ldapi:/// -f $LDIF_FILE 2>&1 || ldapmodify -h localhost -p 389 -D cn=admin,$LDAP_BASE_DN -w "$LDAP_ADMIN_PASSWORD" -f $LDIF_FILE 2>&1 ) | log-helper debug
		else
				( ldapadd -Y EXTERNAL -Q -H ldapi:/// -f $LDIF_FILE 2>&1 || ldapadd -h localhost -p 389 -D cn=admin,$LDAP_BASE_DN -w "$LDAP_ADMIN_PASSWORD" -f $LDIF_FILE 2>&1 ) | log-helper debug
		fi
	}

	file_env 'FD_ADMIN_USERNAME'

	CN_ADMIN="cn=admin,ou=aclroles,${LDAP_BASE_DN}"
	UID_FD_ADMIN="uid=${FD_ADMIN_USERNAME},${LDAP_BASE_DN}"
	CN_ADMIN_BS64=$(echo -n ${CN_ADMIN} | base64 | tr -d '\n')
	UID_FD_ADMIN_BS64=$(echo -n ${UID_FD_ADMIN} | base64 | tr -d '\n')

	file_env 'FD_ADMIN_PASSWORD'

	LDAP_ADMIN_PASSWORD_HASH=$(slappasswd -s ${LDAP_ADMIN_PASSWORD})
	FD_ADMIN_PASSWORD_HASH=$(slappasswd -s ${FD_ADMIN_PASSWORD})
	
	IFS='.' read -ra LDAP_BASE_DN_TABLE <<< "$LDAP_DOMAIN"
	LDAP_BASE_DOMAIN=${LDAP_BASE_DN_TABLE[0]}
	echo LDAP_BASE_DOMAIN=${LDAP_BASE_DOMAIN}

	fusiondirectory-insert-schema
	mkdir /etc/ldap/schema/fusiondirectory/modify/
	mv /etc/ldap/schema/fusiondirectory/rfc2307bis.schema /etc/ldap/schema/fusiondirectory/modify/rfc2307bis.schema
	fusiondirectory-insert-schema -i /etc/ldap/schema/fusiondirectory/*.schema
	fusiondirectory-insert-schema -m /etc/ldap/schema/fusiondirectory/modify/*.schema

	ldap_add_or_modify "/var/fusiondirectory/bootstrap/ldif/modify.ldif"
	ldap_add_or_modify "/var/fusiondirectory/bootstrap/ldif/add.ldif"

	rm -rf /tmp/*
fi
