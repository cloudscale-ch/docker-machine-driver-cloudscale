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


@test "test launch a machine with cloud-init from file" {
  # pre-condition
  load ./assert_no_server

  # arrange
  echo "#cloud-config
write_files:
  - path: /test.txt
    content: |
      my userdatafile" >> test_user_data.yaml

  # act
  docker-machine create --driver cloudscale --cloudscale-userdatafile test_user_data.yaml $MACHINE_NAME
  actual="$(docker-machine ssh $MACHINE_NAME 'cat /test.txt')"

  # assert
  [ "$actual" = "my userdatafile" ]
}


@test "test launch a machine with cloud-init from command line" {
  # pre-condition
  load ./assert_no_server

  # arrange
  TEST_USER_DATA="#cloud-config\nwrite_files:\n  - path: /test.txt\n    content: |\n      my cli user-data test\n"

  # act
  docker-machine create --driver cloudscale --cloudscale-userdata "`echo -e "$TEST_USER_DATA"`" $MACHINE_NAME
  actual="$(docker-machine ssh $MACHINE_NAME 'cat /test.txt')"

  # assert
  [ "$actual" = "my cli user-data test" ]
}


@test "test cannot launch a machine when both --cloudscale-userdata and --cloudscale-userdatafile are given" {
  # pre-condition
  load ./assert_no_server

  # act
  run docker-machine create --driver cloudscale --cloudscale-userdata astring --cloudscale-userdatafile afile wontwork

  # assert
  [ "$status" -eq 3 ]
  [ "${lines[1]}" = "Error with pre-create check: \"--cloudscale-userdata and --cloudscale-userdatafile cannot be used together\"" ]
}


@test "test launch a machine with private interface" {
  # pre-condition
  load ./assert_no_server

  # act
  run docker-machine create --driver cloudscale --cloudscale-use-private-network $MACHINE_NAME
  interfaces="$(docker-machine ssh $MACHINE_NAME 'ls -m /sys/class/net')"


  # assert
  [ "$interfaces" = "docker0, ens3, ens4, lo" ]
}
