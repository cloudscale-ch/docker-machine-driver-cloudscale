#!/usr/bin/env bats

# requries export LC_CTYPE=C on macOS
RAND=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
PREFIX='docker-machine-integration-test-'
MACHINE_NAME=$PREFIX$RAND


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
  ping -c 3 $result
}


@test "test launch a machine and remove gracefully" {
  # pre-condition
  load ./assert_no_server

  # act
  docker-machine create --driver cloudscale $MACHINE_NAME
  run docker-machine rm -y $MACHINE_NAME

  # assert
  [ "$status" -eq 0 ]
}


@test "test launch a machine, then stop and start" {
  # pre-condition
  load ./assert_no_server

  # act & assert
  docker-machine create --driver cloudscale $MACHINE_NAME

  docker-machine stop $MACHINE_NAME
  count="$(docker-machine ls -q --filter state=stopped --filter name=$MACHINE_NAME | wc -l)"
  [ "$count" -eq 1 ]

  docker-machine start $MACHINE_NAME
  count="$(docker-machine ls -q --filter state=running --filter name=$MACHINE_NAME | wc -l)"
  [ "$count" -eq 1 ]
}


@test "test launch a machine and deploy nginx" {
  # pre-condition
  load ./assert_no_server

  # act
  docker-machine create --driver cloudscale $MACHINE_NAME
  eval "$(docker-machine env $MACHINE_NAME)"
  docker run --detach -p 80:80 nginx


  # assert
  ip="$(docker-machine ip $MACHINE_NAME)"
  curl http://$ip
}


@test "test launch a machine with non-default size" {
  # pre-condition
  load ./assert_no_server

  # act
  docker-machine create --driver cloudscale --cloudscale-flavor flex-2 --cloudscale-volume-size-gb 13 $MACHINE_NAME
  disk="$(docker-machine ssh $MACHINE_NAME 'lsblk -ndr -o size')"
  mem="$(docker-machine ssh $MACHINE_NAME 'grep MemTotal /proc/meminfo | tr -s " "')"

  # assert
  [ "$disk" = "13G" ]
  [ "$mem" = "MemTotal: 2041232 kB" ]
}
