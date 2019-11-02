#!/usr/bin/env bats

setup() {
    BASE_DN="dc=example,dc=org"
}

@test "initialize" {
    run docker run --label bats-type="test" -p 389:389 -p 636:636 \
        -e LDAP_ORGANISATION="Example Organization" \
        -e LDAP_DOMAIN="example.org" \
        -e LDAP_READONLY_USER=true \
        -d ${CI_REGISTRY_IMAGE}:bats
    echo $status
    [ "${status}" -eq 0 ]

    until [ "$(ldapsearch -x -h localhost -b ou=snapshots,${BASE_DN} -D cn=admin,${BASE_DN} -w adminpwd | grep 'result:')" = "result: 0 Success" ]
    do
        sleep 1
    done
}

@test "check admin" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b cn=admin,${BASE_DN}
    [ "${status}" -eq 0 ]
}

@test "check readonly user" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b cn=readonly,${BASE_DN}
    [ "${status}" -eq 0 ]

    run ldapsearch -h localhost -D cn=readonly,${BASE_DN} -w readonly \
        -b cn=readonly,${BASE_DN}
    [ "${status}" -eq 0 ]
}

@test "check acl roles" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b ou=aclroles,${BASE_DN}
    [ "${status}" -eq 0 ]

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b cn=admin,ou=aclroles,${BASE_DN}
    [ "${status}" -eq 0 ]

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b cn=manager,ou=aclroles,${BASE_DN}
    [ "${status}" -eq 0 ]

    run ldapsearch -LLL -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b cn=editowninfos,ou=aclroles,${BASE_DN}
    [ "${status}" -eq 0 ]
}

@test "check fusiondirectory" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b ou=fusiondirectory,${BASE_DN}
    [ "${status}" -eq 0 ]

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b ou=tokens,ou=fusiondirectory,${BASE_DN}
    [ "${status}" -eq 0 ]

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b cn=config,ou=fusiondirectory,${BASE_DN}
    [ "${status}" -eq 0 ]

    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b ou=locks,ou=fusiondirectory,${BASE_DN}
    [ "${status}" -eq 0 ]
}

@test "check snapshots" {
    run ldapsearch -h localhost -D cn=admin,${BASE_DN} -w admin \
        -b ou=snapshots,${BASE_DN}
    [ "${status}" -eq 0 ]
}

@test "check fd-admin" {
    run ldapwhoami -h localhost -D uid=fd-admin,${BASE_DN} -w admin
    [ "${status}" -eq 0 ]
}

@test "cleanup" {
    CIDS=$(docker ps -q --filter "label=bats-type")
    if [ ${#CIDS[@]} -gt 0 ]; then
        run docker stop ${CIDS[@]}
        run docker rm ${CIDS[@]}
    fi
}
