#!/bin/bash -e

if [ ! -e "$FIRST_START_DONE" ]; then

	function file_env () {
		local var="$1"
		local fileVar="${var}_FILE"
		local def="${2:-}"
		# if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		# 	echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		# 	exit 1
		# fi
		local val="$def"
		if [ "${!fileVar:-}" ]; then
			val="$(<"${!fileVar}")"
		elif [ "${!var:-}" ]; then
			val="${!var}"
		fi
		if [ -z ${val} ]; then
			echo >&2 "error: neither $var nor $fileVar are set but are required"
			exit 1
		fi
		export "$var"="$val"
		unset "$fileVar"
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

	ldap_add_or_modify (){
		local LDIF_FILE=$1

		log-helper info "Processing file ${LDIF_FILE}"
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

	fd_apply() {
		if [[ "$REAPPLY_PLUGIN_SCHEMAS" =~ [tT][rR][uU][eE] ]];  then
			RE="Re"
			A="a"
			ARG="-m"
		else 
			A="A"
			ARG="-i"
		fi
		log-helper info "[openldap-fusiondirectory] ${RE}${A}pplying Fusion Directory "$@" schema"
	}
	fusiondirectory-insert-schema | log-helper debug

	## Handle the core plugins
  if [ "$REAPPLY_PLUGIN_SCHEMAS" =~ [tT][rR][uU][eE] ];  then
  	fd_apply core
  	fusiondirectory-insert-schema -m core*.schema | log-helper debug
  	fusiondirectory-insert-schema -m ldapns.schema | log-helper debug
  	fusiondirectory-insert-schema -m template-fd.schema | log-helper debug
  fi

### Import / Modify Schemas - Put Mail First
  if [[ "$PLUGIN_MAIL" =~ [tT][rR][uU][eE] ]];  then
    fd_apply mail
    fusiondirectory-insert-schema $ARG mail*.schema | log-helper debug
  fi
  
  if [[ "$PLUGIN_SYSTEMS" =~ [tT][rR][uU][eE] ]];  then
    fd_apply systems
    fusiondirectory-insert-schema $ARG service*.schema | log-helper debug
    fusiondirectory-insert-schema $ARG systems*.schema | log-helper debug
  fi
  if [[ "$PLUGIN_AUDIT" =~ [tT][rR][uU][eE] ]];  then
    fd_apply audit
    fusiondirectory-insert-schema $ARG audit*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_ALIAS" =~ [tT][rR][uU][eE] ]];  then
    fd_apply alias
    fusiondirectory-insert-schema $ARG alias*.schema | log-helper debug
  fi
  
  if [[ "$PLUGIN_APPLICATIONS" =~ [tT][rR][uU][eE] ]];  then
    fd_apply applications
    fusiondirectory-insert-schema $ARG applications*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_ARGONAUT" =~ [tT][rR][uU][eE] ]];  then
    fd_apply argonaut
    fusiondirectory-insert-schema $ARG argonaut*.schema | log-helper debug
  fi
  
  if [[ "$PLUGIN_COMMUNITY" =~ [tT][rR][uU][eE] ]];  then
  	fd_apply community
    fusiondirectory-insert-schema $ARG community*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_CYRUS" =~ [tT][rR][uU][eE] ]];  then
    fd_apply cyrus
    fusiondirectory-insert-schema $ARG cyrus*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_DEBCONF" =~ [tT][rR][uU][eE] ]];  then
    fd_apply debconf
    fusiondirectory-insert-schema $ARG debconf*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_DHCP" =~ [tT][rR][uU][eE] ]];  then
    fd_apply DHCP
    fusiondirectory-insert-schema $ARG dhcp*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_DNS" =~ [tT][rR][uU][eE] ]];  then
    fd_apply DNS
    fusiondirectory-insert-schema $ARG dns*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_DOVECOT" =~ [tT][rR][uU][eE] ]];  then
    fd_apply dovecot
    fusiondirectory-insert-schema $ARG dovecot*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_DSA" =~ [tT][rR][uU][eE] ]];  then
    fd_apply DSA
    fusiondirectory-insert-schema $ARG dsa*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_EJBCA" =~ [tT][rR][uU][eE] ]];  then
    fd_apply ejbca
    fusiondirectory-insert-schema $ARG ejbca*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_FAI" =~ [tT][rR][uU][eE] ]];  then
    fd_apply FAI
    fusiondirectory-insert-schema $ARG fai*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_FREERADIUS" =~ [tT][rR][uU][eE] ]];  then
    fd_apply FreeRadius
    fusiondirectory-insert-schema $ARG freeradius*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_FUSIONINVENTORY" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Inventory
    fusiondirectory-insert-schema $ARG fusioninventory*.schema | log-helper debug
    fusiondirectory-insert-schema $ARG inventory*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_GPG" =~ [tT][rR][uU][eE] ]];  then
    fd_apply GPG
    fusiondirectory-insert-schema $ARG gpg*.schema | log-helper debug
    fusiondirectory-insert-schema $ARG pgp*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_IPMI" =~ [tT][rR][uU][eE] ]];  then
    fd_apply IPMI
    fusiondirectory-insert-schema $ARG ipmi*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_NAGIOS" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Nagios
    fusiondirectory-insert-schema $ARG nagios*.schema | log-helper debug
    fusiondirectory-insert-schema $ARG netways*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_NETGROUPS" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Netgroups
    fusiondirectory-insert-schema $ARG netgroups*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_NEWSLETTER" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Newsletter
    fusiondirectory-insert-schema $ARG newsletter*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_OPSI" =~ [tT][rR][uU][eE] ]];  then
    fd_apply OPSI
    fusiondirectory-insert-schema $ARG opsi*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_PPOLICY" =~ [tT][rR][uU][eE] ]];  then
    fd_apply ppolicy
    fusiondirectory-insert-schema $ARG ppolicy*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_QUOTA" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Quota
    fusiondirectory-insert-schema $ARG quota*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_PUPPET" =~ [tT][rR][uU][eE] ]];  then
    fd_apply puppet
    fusiondirectory-insert-schema $ARG puppet*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_REPOSITORY" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Repository
    fusiondirectory-insert-schema $ARG repository*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SAMBA" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Samba
    fusiondirectory-insert-schema $ARG samba*.schema | log-helper debug
  fi
  
  if [[ "$PLUGIN_PERSONAL" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Personal
    fusiondirectory-insert-schema $ARG personal*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_POSTFIX" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Postfix
    fusiondirectory-insert-schema $ARG postfix*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_PUREFTPD" =~ [tT][rR][uU][eE] ]];  then
    fd_apply PureFTPd
    fusiondirectory-insert-schema $ARG pureftpd*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SSH" =~ [tT][rR][uU][eE] ]];  then
    fd_apply SSH
    fusiondirectory-insert-schema $ARG openssh*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SOGO" =~ [tT][rR][uU][eE] ]];  then
    fd_apply SoGo
    fusiondirectory-insert-schema $ARG sogo*.schema | log-helper debug
    fusiondirectory-insert-schema $ARG cal*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SPAMASSASSIN" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Spamassassin
    fusiondirectory-insert-schema $ARG spamassassin*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SQUID" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Squid
    fusiondirectory-insert-schema $ARG proxy*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SUBCONTRACTING" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Subcontracting
    fusiondirectory-insert-schema $ARG subcontracting*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SUDO" =~ [tT][rR][uU][eE] ]];  then
    fd_apply sudo
    fusiondirectory-insert-schema $ARG sudo*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SUPANN" =~ [tT][rR][uU][eE] ]];  then
    fd_apply supann
    fusiondirectory-insert-schema $ARG internet2*.schema | log-helper debug
    fusiondirectory-insert-schema $ARG supann*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_SYMPA" =~ [tT][rR][uU][eE] ]];  then
    fd_apply Sympa
    fusiondirectory-insert-schema $ARG sympa*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_USER_REMINDER" =~ [tT][rR][uU][eE] ]];  then
    fd_apply reminder
    fusiondirectory-insert-schema $ARG user-reminder*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_WEBLINK" =~ [tT][rR][uU][eE] ]];  then
  	fd_apply weblink
    fusiondirectory-insert-schema $ARG weblink*.schema | log-helper debug
  fi

  if [[ "$PLUGIN_WEBSERVICE" =~ [tT][rR][uU][eE] ]];  then
    fd_apply webservice
    fusiondirectory-insert-schema $ARG webservice*.schema | log-helper debug
  fi

	if [[ "$LDAP_RFC2307BIS_SCHEMA" =~ [tT][rR][uU][eE] ]];  then
    fd_apply rfc2307bis
    fusiondirectory-insert-schema -m rfc2307bis.schema | log-helper debug
  fi

	ldap_add_or_modify "/var/fusiondirectory/bootstrap/ldif/modify.ldif" 
	ldap_add_or_modify "/var/fusiondirectory/bootstrap/ldif/add.ldif" 

	rm -rf /tmp/*
fi
