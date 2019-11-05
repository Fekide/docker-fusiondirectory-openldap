#!/usr/bin/env bats

load '../libs/bats-support/load'
load '../libs/bats-assert/load'

function setup() {
    BASE_DN="dc=example,dc=org"
    run docker run --label bats-type="test" -p 389:389 -p 636:636 \
        -e LDAP_ORGANISATION="Example Organization" \
        -e LDAP_DOMAIN="example.org" \
        -e LDAP_READONLY_USER=true \
        --network gitlab_testing \
        -d ${CI_REGISTRY_IMAGE}:bats
    assert_success

    CONTAINER_NAME=$(docker ps --format "{{.Names}}" --filter "label=bats-type")
    i=1
    until [ "$(ldapsearch -x -h ${CONTAINER_NAME} -b ou=snapshots,${BASE_DN} -D cn=admin,${BASE_DN} -w admin | grep 'result:')" = "result: 0 Success" ]
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
    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b cn=admin,${BASE_DN}
    assert_success
}

@test "check readonly user" {
    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b cn=readonly,${BASE_DN}
    assert_success

    run ldapsearch -h ${CONTAINER_NAME} -D cn=readonly,${BASE_DN} -w readonly \
        -b cn=readonly,${BASE_DN}
    assert_success
}

@test "check acl roles" {
    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b ou=aclroles,${BASE_DN}
    assert_success

    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b cn=admin,ou=aclroles,${BASE_DN}
    assert_success

    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b cn=manager,ou=aclroles,${BASE_DN}
    assert_success

    run ldapsearch -LLL -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b cn=editowninfos,ou=aclroles,${BASE_DN}
    assert_success
}

@test "check fusiondirectory" {
    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b ou=fusiondirectory,${BASE_DN}
    assert_success

    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b ou=tokens,ou=fusiondirectory,${BASE_DN}
    assert_success

    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b cn=config,ou=fusiondirectory,${BASE_DN}
    assert_success

    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b ou=locks,ou=fusiondirectory,${BASE_DN}
    assert_success
}

@test "check snapshots" {
    run ldapsearch -h ${CONTAINER_NAME} -D cn=admin,${BASE_DN} -w admin \
        -b ou=snapshots,${BASE_DN}
    assert_success
}

@test "check fd-admin" {
    run ldapwhoami -h ${CONTAINER_NAME} -D uid=fd-admin,${BASE_DN} -w admin
    assert_success
}

function teardown() {
    CIDS=($(docker ps -q --filter "label=bats-type"))
    if [ ${#CIDS[@]} -gt 0 ]; then
        docker stop ${CIDS[@]}
        docker rm ${CIDS[@]}
    fi
}
