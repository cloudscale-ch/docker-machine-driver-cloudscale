#!/usr/bin/env bats

# requries export LC_CTYPE=C on macOS
RAND=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
PREFIX='docker-machine-integration-test-'
MACHINE_NAME=$PREFIX$RAND
CLOUDSCALE_USE_IPV6=true


function setup() {
  if [ -z $CLOUDSCALE_TOKEN ]
  then
    echo "$CLOUDSCALE_TOKEN" does not seem to be set.
    return 1
  fi
}


function teardown() {
  docker-machine rm -f $MACHINE_NAME
  docker-machine env --unset
}


@test "test launch a machine and ping" {
  # pre-condition
  load ./assert_no_server

  # act
  run docker-machine create --driver cloudscale $MACHINE_NAME

  # assert
  [ "$status" -eq 0 ]

  result="$(docker-machine ip $MACHINE_NAME)"
  ping6 -c 3 $result
}


 launch a machine and deploy nginx" {
  # pre-condition
  load ./assert_no_server

  # act
  docker-machine create --driver cloudscale $MACHINE_NAME
  eval "$(docker-machine env $MACHINE_NAME)"
  docker run --detach -p 80:80 nginx


  # assert
  ip="$(docker-machine ip $MACHINE_NAME)"
  curl -g -6 http://[$ip]
}
