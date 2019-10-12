#!/bin/bash -e

if [ "$DEBUG_MODE" = "TRUE" ] || [ "$DEBUG_MODE" = "true" ];  then
  set -x
fi

silent() {
  if [ "$DEBUG_MODE" = "TRUE" ] || [ "$DEBUG_MODE" = "true" ];  then
    "$@"
  else
    "$@" > /dev/null 2>&1
  fi
}

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
fi

### Insert Plugin Schemas
if [ ! -e ${FIRST_START_DONE} ] || [ "$REAPPLY_PLUGIN_SCHEMAS" = "TRUE" ] || [ "$REAPPLY_PLUGIN_SCHEMAS" = "true" ];  then
  ### Determine which plugins we want installed 
  PLUGIN_ALIAS=${PLUGIN_ALIAS:-"FALSE"}
  PLUGIN_APPLICATIONS=${PLUGIN_APPLICATIONS:-"FALSE"}
  PLUGIN_ARGONAUT=${PLUGIN_ARGONAUT:-"FALSE"}
  PLUGIN_AUDIT=${PLUGIN_AUDIT:-"TRUE"}
  PLUGIN_AUTOFS=${PLUGIN_AUTOFS:-"FALSE"}
  PLUGIN_CERTIFICATES=${PLUGIN_CERTIFICATES:-"FALSE"}
  PLUGIN_COMMUNITY=${PLUGIN_COMMUNITY:-"FALSE"}
  PLUGIN_CYRUS=${PLUGIN_CYRUS:-"FALSE"}
  PLUGIN_DEBCONF=${PLUGIN_DEBCONF:-"FALSE"}
  PLUGIN_DEVELOPERS=${PLUGIN_DEVELOPERS:-"FALSE"}
  PLUGIN_DHCP=${PLUGIN_DHCP:-"FALSE"}
  PLUGIN_DNS=${PLUGIN_DNS:-"FALSE"}
  PLUGIN_DOVECOT=${PLUGIN_DOVECOT:-"FALSE"}
  PLUGIN_DSA=${PLUGIN_DSA:-"TRUE"}
  PLUGIN_EJBCA=${PLUGIN_EJBCA:-"FALSE"}
  PLUGIN_FAI=${PLUGIN_FAI:-"FALSE"}
  PLUGIN_FREERADIUS=${PLUGIN_FREERADIUS:-"FALSE"}
  PLUGIN_FUSIONINVENTORY=${PLUGIN_FUSIONINVENTORY:-"FALSE"}
  PLUGIN_GPG=${PLUGIN_GPG:-"FALSE"}
  PLUGIN_IPMI=${PLUGIN_IPMI:-"FALSE"}
  PLUGIN_LDAPDUMP=${PLUGIN_LDAPDUMP:-"TRUE"}
  PLUGIN_LDAPMANAGER=${PLUGIN_LDAPMANAGER:-"TRUE"}
  PLUGIN_MAIL=${PLUGIN_MAIL:-"TRUE"}
  PLUGIN_MIXEDGROUPS=${PLUGIN_MIXEDGROUPS:-"TRUE"}
  PLUGIN_NAGIOS=${PLUGIN_NAGIOS:-"FALSE"}
  PLUGIN_NETGROUPS=${PLUGIN_NETGROUPS:-"FALSE"}
  PLUGIN_NEWSLETTER=${PLUGIN_NEWSLETTER:-"FALSE"}
  PLUGIN_OPSI=${PLUGIN_OPSI:-"FALSE"}
  PLUGIN_PERSONAL=${PLUGIN_PERSONAL:-"TRUE"}
  PLUGIN_POSIX=${PLUGIN_POSIX:-"FALSE"}
  PLUGIN_POSTFIX=${PLUGIN_POSTFIX:-"FALSE"}
  PLUGIN_PPOLICY=${PLUGIN_PPOLICY:-"TRUE"}
  PLUGIN_PUPPET=${PLUGIN_PUPPET:-"FALSE"}
  PLUGIN_PUREFTPD=${PLUGIN_PUREFTPD:-"FALSE"}
  PLUGIN_QUOTA=${PLUGIN_QUOTA:-"FALSE"}
  PLUGIN_RENATER_PARTAGE=${PLUGIN_RENATER_PARTAGE:-"FALSE"}
  PLUGIN_REPOSITORY=${PLUGIN_REPOSITORY:-"FALSE"}
  PLUGIN_SAMBA=${PLUGIN_SAMBA:-"FALSE"}
  PLUGIN_SOGO=${PLUGIN_SOGO:-"FALSE"}
  PLUGIN_SPAMASSASSIN=${PLUGIN_SPAMASSASSIN:-"FALSE"}
  PLUGIN_SQUID=${PLUGIN_SQUID:-"FALSE"}
  PLUGIN_SSH=${PLUGIN_SSH:-"TRUE"}
  PLUGIN_SUBCONTRACTING=${PLUGIN_SUBCONTRACTING:-"FALSE"}
  PLUGIN_SUDO=${PLUGIN_SUDO:-"TRUE"}
  PLUGIN_SUPANN=${PLUGIN_SUPANN:-"FALSE"}
  PLUGIN_SYMPA=${PLUGIN_SYMPA:-"FALSE"}
  PLUGIN_SYSTEMS=${PLUGIN_SYSTEMS:-"TRUE"}
  PLUGIN_USER_REMINDER=${PLUGIN_USER_REMINDER:-"FALSE"}
  PLUGIN_WEBLINK=${PLUGIN_WEBLINK:-"FALSE"}
  PLUGIN_WEBSERVICE=${PLUGIN_WEBSERVICE:-"FALSE"}

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
		if [ "$REAPPLY_PLUGIN_SCHEMAS" = "TRUE" ] || [ "$REAPPLY_PLUGIN_SCHEMAS" = "true" ];  then
			RE="Re"
			A="a"
			ARG="-m"
		else 
			A="A"
			ARG="-i"
		fi
		echo "** [openldap-fusiondirectory] ${RE}${A}pplying Fusion Directory "$@" schema"
	}
	
	silent fusiondirectory-insert-schema

	## Handle the core plugins
  if [ "$REAPPLY_PLUGIN_SCHEMAS" = "TRUE" ] || [ "$REAPPLY_PLUGIN_SCHEMAS" = "true" ];  then
  	fd_apply core
  	fusiondirectory-insert-schema -m core*.schema
  	fusiondirectory-insert-schema -m ldapns.schema
  	fusiondirectory-insert-schema -m template-fd.schema
  fi

### Import / Modify Schemas - Put Mail First
  if [[ "$PLUGIN_MAIL" != "FALSE" ]] && [[ "$PLUGIN_MAIL" != "false" ]];  then
    fd_apply mail
    silent fusiondirectory-insert-schema $ARG mail*.schema
  fi
  
  if [[ "$PLUGIN_SYSTEMS" != "FALSE" ]] && [[ "$PLUGIN_SYSTEMS" != "false" ]];  then
    fd_apply systems
    silent fusiondirectory-insert-schema $ARG service*.schema
    silent fusiondirectory-insert-schema $ARG systems*.schema
  fi
  if [[ "$PLUGIN_AUDIT" != "FALSE" ]] && [[ "$PLUGIN_AUDIT" != "false" ]];  then
    fd_apply audit
    silent fusiondirectory-insert-schema $ARG audit*.schema
  fi

  if [[ "$PLUGIN_ALIAS" != "FALSE" ]] && [[ "$PLUGIN_ALIAS" != "false" ]];  then
    fd_apply alias
    silent fusiondirectory-insert-schema $ARG alias*.schema
  fi
  
  if [[ "$PLUGIN_APPLICATIONS" != "FALSE" ]] && [[ "$PLUGIN_APPLICATIONS" != "false" ]];  then
    fd_apply applications
    silent fusiondirectory-insert-schema $ARG applications*.schema
  fi

  if [[ "$PLUGIN_ARGONAUT" != "FALSE" ]] && [[ "$PLUGIN_ARGONAUT" != "false" ]];  then
    fd_apply argonaut
    silent fusiondirectory-insert-schema $ARG argonaut*.schema
  fi
  
  if [[ "$PLUGIN_COMMUNITY" != "FALSE" ]] && [[ "$PLUGIN_COMMUNITY" != "false" ]];  then
  	fd_apply community
    silent fusiondirectory-insert-schema $ARG community*.schema
  fi

  if [[ "$PLUGIN_CYRUS" != "FALSE" ]] && [[ "$PLUGIN_CYRUS" != "false" ]];  then
    fd_apply cyrus
    silent fusiondirectory-insert-schema $ARG cyrus*.schema
  fi

  if [[ "$PLUGIN_DEBCONF" != "FALSE" ]] && [[ "$PLUGIN_DEBCONF" != "false" ]];  then
    fd_apply debconf
    silent fusiondirectory-insert-schema $ARG debconf*.schema
  fi

  if [[ "$PLUGIN_DHCP" != "FALSE" ]] && [[ "$PLUGIN_DHCP" != "false" ]];  then
    fd_apply DHCP
    silent fusiondirectory-insert-schema $ARG dhcp*.schema
  fi

  if [[ "$PLUGIN_DNS" != "FALSE" ]] && [[ "$PLUGIN_DNS" != "false" ]];  then
    fd_apply DNS
    silent fusiondirectory-insert-schema $ARG dns*.schema
  fi

  if [[ "$PLUGIN_DOVECOT" != "FALSE" ]] && [[ "$PLUGIN_DOVECOT" != "false" ]];  then
    fd_apply dovecot
    silent fusiondirectory-insert-schema $ARG dovecot*.schema
  fi

  if [[ "$PLUGIN_DSA" != "FALSE" ]] && [[ "$PLUGIN_DSA" != "false" ]];  then
    fd_apply DSA
    silent fusiondirectory-insert-schema $ARG dsa*.schema
  fi

  if [[ "$PLUGIN_EJBCA" != "FALSE" ]] && [[ "$PLUGIN_EJBCA" != "false" ]];  then
    fd_apply ejbca
    silent fusiondirectory-insert-schema $ARG ejbca*.schema
  fi

  if [[ "$PLUGIN_FAI" != "FALSE" ]] && [[ "$PLUGIN_FAI" != "false" ]];  then
    fd_apply FAI
    silent fusiondirectory-insert-schema $ARG fai*.schema
  fi

  if [[ "$PLUGIN_FREERADIUS" != "FALSE" ]] && [[ "$PLUGIN_FREERADIUS" != "false" ]];  then
    fd_apply FreeRadius
    silent fusiondirectory-insert-schema $ARG freeradius*.schema
  fi

  if [[ "$PLUGIN_FUSIONINVENTORY" != "FALSE" ]] && [[ "$PLUGIN_FUSIONINVENTORY" != "false" ]];  then
    fd_apply Inventory
    silent fusiondirectory-insert-schema $ARG fusioninventory*.schema
    silent fusiondirectory-insert-schema $ARG inventory*.schema
  fi

  if [[ "$PLUGIN_GPG" != "FALSE" ]] && [[ "$PLUGIN_GPG" != "false" ]];  then
    fd_apply GPG
    silent fusiondirectory-insert-schema $ARG gpg*.schema
    silent fusiondirectory-insert-schema $ARG pgp*.schema
  fi

  if [[ "$PLUGIN_IPMI" != "FALSE" ]] && [[ "$PLUGIN_IPMI" != "false" ]];  then
    fd_apply IPMI
    silent fusiondirectory-insert-schema $ARG ipmi*.schema
  fi

  if [[ "$PLUGIN_NAGIOS" != "FALSE" ]] && [[ "$PLUGIN_MIXEDGROUPS" != "false" ]];  then
    fd_apply Nagios
    silent fusiondirectory-insert-schema $ARG nagios*.schema
    silent fusiondirectory-insert-schema $ARG netways*.schema
  fi

  if [[ "$PLUGIN_NETGROUPS" != "FALSE" ]] && [[ "$PLUGIN_NETGROUPS" != "false" ]];  then
    fd_apply Netgroups
    silent fusiondirectory-insert-schema $ARG netgroups*.schema
  fi

  if [[ "$PLUGIN_NEWSLETTER" != "FALSE" ]] && [[ "$PLUGIN_NEWSLETTER" != "false" ]];  then
    fd_apply Newsletter
    silent fusiondirectory-insert-schema $ARG newsletter*.schema
  fi

  if [[ "$PLUGIN_OPSI" != "FALSE" ]] && [[ "$PLUGIN_OPSI" != "false" ]];  then
    fd_apply OPSI
    silent fusiondirectory-insert-schema $ARG opsi*.schema
  fi

  if [[ "$PLUGIN_PPOLICY" != "FALSE" ]] && [[ "$PLUGIN_PPOLICY" != "false" ]];  then
    fd_apply ppolicy
    silent fusiondirectory-insert-schema $ARG ppolicy*.schema
  fi

  if [[ "$PLUGIN_QUOTA" != "FALSE" ]] && [[ "$PLUGIN_QUOTA" != "false" ]];  then
    fd_apply Quota
    silent fusiondirectory-insert-schema $ARG quota*.schema
  fi

  if [[ "$PLUGIN_PUPPET" != "FALSE" ]] && [[ "$PLUGIN_PUPPET" != "false" ]];  then
    fd_apply puppet
    silent fusiondirectory-insert-schema $ARG puppet*.schema
  fi

  if [[ "$PLUGIN_REPOSITORY" != "FALSE" ]] && [[ "$PLUGIN_REPOSITORY" != "false" ]];  then
    fd_apply Repository
    silent fusiondirectory-insert-schema $ARG repository*.schema
  fi

  if [[ "$PLUGIN_SAMBA" != "FALSE" ]] && [[ "$PLUGIN_SAMBA" != "false" ]];  then
    fd_apply Samba
    silent fusiondirectory-insert-schema $ARG samba*.schema
  fi
  
  if [[ "$PLUGIN_PERSONAL" != "FALSE" ]] && [[ "$PLUGIN_PERSONAL" != "false" ]];  then
    fd_apply Personal
    silent fusiondirectory-insert-schema $ARG personal*.schema
  fi

  if [[ "$PLUGIN_POSTFIX" != "FALSE" ]] && [[ "$PLUGIN_POSTFIX" != "false" ]];  then
    fd_apply Postfix
    silent fusiondirectory-insert-schema $ARG postfix*.schema
  fi

  if [[ "$PLUGIN_PUREFTPD" != "FALSE" ]] && [[ "$PLUGIN_PUREFTPD" != "false" ]];  then
    fd_apply PureFTPd
    silent fusiondirectory-insert-schema $ARG pureftpd*.schema
  fi

  if [[ "$PLUGIN_SSH" != "FALSE" ]] && [[ "$PLUGIN_SSH" != "false" ]];  then
    fd_apply SSH
    silent fusiondirectory-insert-schema $ARG openssh*.schema
  fi

  if [[ "$PLUGIN_SOGO" != "FALSE" ]] && [[ "$PLUGIN_SOGO" != "false" ]];  then
    fd_apply SoGo
    silent fusiondirectory-insert-schema $ARG sogo*.schema
    silent fusiondirectory-insert-schema $ARG cal*.schema
  fi

  if [[ "$PLUGIN_SPAMASSASSIN" != "FALSE" ]] && [[ "$PLUGIN_SPAMASSASSIN" != "false" ]];  then
    fd_apply Spamassassin
    silent fusiondirectory-insert-schema $ARG spamassassin*.schema
  fi

  if [[ "$PLUGIN_SQUID" != "FALSE" ]] && [[ "$PLUGIN_SQUID" != "false" ]];  then
    fd_apply Squid
    silent fusiondirectory-insert-schema $ARG proxy*.schema
  fi

  if [[ "$PLUGIN_SUBCONTRACTING" != "FALSE" ]] && [[ "$PLUGIN_SUBCONTRACTING" != "false" ]];  then
    fd_apply Subcontracting
    silent fusiondirectory-insert-schema $ARG subcontracting*.schema
  fi

  if [[ "$PLUGIN_SUDO" != "FALSE" ]] && [[ "$PLUGIN_SUDO" != "false" ]];  then
    fd_apply sudo
    silent fusiondirectory-insert-schema $ARG sudo*.schema
  fi

  if [[ "$PLUGIN_SUPANN" != "FALSE" ]] && [[ "$PLUGIN_SUPANN" != "false" ]];  then
    fd_apply supann
    silent fusiondirectory-insert-schema $ARG internet2*.schema
    silent fusiondirectory-insert-schema $ARG supann*.schema
  fi

  if [[ "$PLUGIN_SYMPA" != "FALSE" ]] && [[ "$PLUGIN_SYMPA" != "false" ]];  then
    fd_apply Sympa
    silent fusiondirectory-insert-schema $ARG sympa*.schema
  fi

  if [[ "$PLUGIN_USER_REMINDER" != "FALSE" ]] && [[ "$PLUGIN_USER_REMINDER" != "false" ]];  then
    fd_apply reminder
    silent fusiondirectory-insert-schema $ARG user-reminder*.schema
  fi

  if [[ "$PLUGIN_WEBLINK" != "FALSE" ]] && [[ "$PLUGIN_WEBLINK" != "false" ]];  then
  	fd_apply weblink
    silent fusiondirectory-insert-schema $ARG weblink*.schema
  fi

  if [[ "$PLUGIN_WEBSERVICE" != "FALSE" ]] && [[ "$PLUGIN_WEBSERVICE" != "false" ]];  then
    fd_apply webservice
    silent fusiondirectory-insert-schema $ARG webservice*.schema
  fi

	if [[ "$LDAP_RFC2307BIS_SCHEMA" != "FALSE" ]] && [[ "$LDAP_RFC2307BIS_SCHEMA" != "false" ]];  then
    fd_apply rfc2307bis
    silent fusiondirectory-insert-schema -m rfc2307bis.schema
  fi

	ldap_add_or_modify "/var/fusiondirectory/bootstrap/ldif/modify.ldif"
	ldap_add_or_modify "/var/fusiondirectory/bootstrap/ldif/add.ldif"

	rm -rf /tmp/*
fi
