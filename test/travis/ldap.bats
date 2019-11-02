#!/usr/bin/env bats

load '../libs/bats-support/load'
load '../libs/bats-assert/load'

function setup() {
    BASE_DN="dc=example,dc=org"
    run docker run --label bats-type="test" -p 389:389 -p 636:636 \
        -e LDAP_ORGANISATION="Example Organization" \
        -e LDAP_DOMAIN="example.org" \
        -e LDAP_ADMIN_PASSWORD="adminpwd" \
        -e LDAP_CONFIG_PASSWORD="configpwd" \
        -e LDAP_READONLY_USER=true \
        -e LDAP_READONLY_USER_USERNAME="readonly" \
        -e LDAP_READONLY_USER_PASSWORD="readonlypwd" \
        -e FD_ADMIN_PASSWORD="fdadminpwd" \
        -d fekide/fusiondirectory-openldap:bats
    assert_success

    until [ "$(ldapsearch -x -h localhost -b ou=snapshots,${BASE_DN} -D cn=admin,${BASE_DN} -w adminpwd | grep 'result:')" = "result: 0 Success" ]
    do
        sleep 1
        i=$(( i+1 ))
        if [ $i -gt 100 ]
        then
            fail 'Setup failed, container did not answer!'
        fi
    done
}

@test "check admin" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b cn=admin,${BASE_DN}
    assert_success
}

@test "check readonly user" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b cn=readonly,${BASE_DN}
    assert_success

    run ldapsearch -h localhost -D cn=readonly,${BASE_DN} -w readonlypwd \
        -b cn=readonly,${BASE_DN}
    assert_success
}

@test "check acl roles" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b ou=aclroles,${BASE_DN}
    assert_success

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b cn=admin,ou=aclroles,${BASE_DN}
    assert_success

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b cn=manager,ou=aclroles,${BASE_DN}
    assert_success

    run ldapsearch -LLL -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b cn=editowninfos,ou=aclroles,${BASE_DN}
    assert_success
}

@test "check fusiondirectory" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b ou=fusiondirectory,${BASE_DN}
    assert_success

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b ou=tokens,ou=fusiondirectory,${BASE_DN}
    assert_success

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b cn=config,ou=fusiondirectory,${BASE_DN}
    assert_success

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b ou=locks,ou=fusiondirectory,${BASE_DN}
    assert_success
}

@test "check snapshots" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w adminpwd \
        -b ou=snapshots,${BASE_DN}
    assert_success
}

@test "check fd-admin" {
    run ldapwhoami -h localhost -D uid=fd-admin,${BASE_DN} -w fdadminpwd
    assert_success
}

function teardown() {
    CIDS=$(docker ps -q --filter "label=bats-type")
    if [ ${#CIDS[@]} -gt 0 ]; then
        docker stop ${CIDS[@]}
        docker rm ${CIDS[@]}
    fi
}
