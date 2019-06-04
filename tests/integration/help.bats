#!/usr/bin/env bats

@test "test help contains all driver options" {
  # act
  run docker-machine create --driver cloudscale --help

  # assert
  echo "$output" | grep 'cloudscale-anti-affinity-with'
  echo "$output" | grep 'cloudscale-flavor "flex-4"'
  echo "$output" | grep 'cloudscale-image "ubuntu-18.04"'
  echo "$output" | grep 'cloudscale-region'
  echo "$output" | grep 'cloudscale-server-groups'
  echo "$output" | grep 'cloudscale-ssh-key-path'
  echo "$output" | grep 'cloudscale-ssh-port "22"'
  echo "$output" | grep 'cloudscale-ssh-user "root"'
  echo "$output" | grep 'cloudscale-token'
  echo "$output" | grep 'cloudscale-use-ipv6'
  echo "$output" | grep 'cloudscale-use-private-network'
  echo "$output" | grep 'cloudscale-userdata'
  echo "$output" | grep 'cloudscale-volume-size-gb "10"'
}

