# cloudscale.ch Docker machine driver

[![Go Report Card](https://goreportcard.com/badge/github.com/cloudscale-ch/docker-machine-driver-cloudscale)](https://goreportcard.com/report/github.com/cloudscale-ch/docker-machine-driver-cloudscale)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://github.com/cloudscale-ch/docker-machine-driver-cloudscale/actions/workflows/test.yaml/badge.svg)](https://github.com/cloudscale-ch/docker-machine-driver-cloudscale/actions)

> This library adds the support for creating [Docker machines](https://github.com/docker/machine) hosted on [the cloudscale.ch IaaS platform](https://www.cloudscale.ch).

You need to create a read/write API token under `My Account` > [`API Tokens`](https://control.cloudscale.ch/user/api-tokens) in the [cloudscale.ch Control Panel](https://control.cloudscale.ch/server)
and pass it to `docker-machine create` as the `--cloudscale-token` option.

## Installation

You can find sources and pre-compiled binaries [here](https://github.com/cloudscale-ch/docker-machine-driver-cloudscale/releases).

```bash
# Download the binary (this example downloads the binary for Linux amd64)
$ wget https://github.com/cloudscale-ch/docker-machine-driver-cloudscale/releases/download/v1.2.0/docker-machine-driver-cloudscale_v1.2.0_linux_amd64.tar.gz
$ tar xzvf docker-machine-driver-cloudscale_v1.2.0_linux_amd64.tar.gz

# Make it executable and copy the binary to a directory included in your $PATH
$ chmod +x docker-machine-driver-cloudscale
$ cp docker-machine-driver-cloudscale /usr/local/bin/
```

## Usage

```bash
$ docker-machine create \
  --driver cloudscale \
  --cloudscale-token=... \
  --cloudscale-zone lpg1 \
  --cloudscale-image=ubuntu-18.04 \
  --cloudscale-flavor=flex-4 \
  some-machine
```

See `docker-machine create  --driver cloudscale --help` for a complete list of all supported options.

### Using environment variables

```bash
$ CLOUDSCALE_TOKEN=... \
  && CLOUDSCALE_IMAGE=ubuntu-18.04 \
  && CLOUDSCALE_FLAVOR=flex-4
  && CLOUDSCALE_ZONE=lpg1 \
  docker-machine create \
     --driver cloudscale \
     some-machine
```

See `docker-machine create  --driver cloudscale --help` for a complete list of all supported environment variables.

### Using cloud-init

User data (cloud-config for cloud-init) to use for the new server. Needs to be valid YAML. 

#### From File

```bash
$ cat <<EOF > /tmp/my-user-data.yaml
#cloud-config
write_files:
  - path: /test.txt
    content: |
      Here is a line.
      Another line is here.
EOF
```

```bash
$ docker-machine create \
  --driver cloudscale \
  --cloudscale-token=... \
  --cloudscale-userdatafile=/tmp/my-user-data.yaml \
  some-machine
```

#### From Command Line

```bash
$ docker-machine create \
  --driver cloudscale \
  --cloudscale-token=... \
  --cloudscale-userdata "`echo -e "#cloud-config\nwrite_files:\n  - path: /test.txt\n    content: |\n      my cli user-data test\n"`" \
  some-machine
```

## Options

- `--cloudscale-token`: **required**. Your project-specific access token for the cloudscale.ch API.
- `--cloudscale-image`: The slug of the cloudscale.ch image to use, see [Images API](https://www.cloudscale.ch/en/api/v1#images) for how to get a list of available images (defaults to `ubuntu-18.04`). A list of operating systems supported by docker-machine can be obtained [here](https://docs.docker.com/machine/drivers/os-base/).
- `--cloudscale-flavor`: The flavor of the cloudscale.ch server, see [Flavor API](https://www.cloudscale.ch/en/api/v1#flavors) for how to get a list of available flavors (defaults to `flex-4`).
- `--cloudscale-zone`: The zone in which the cloudscale.ch server will be created, see [Regions and Zones](https://www.cloudscale.ch/en/api/v1#regions) for how to get a list of available zones (defaults to [your default zone](https://control.cloudscale.ch/user/project))
- `--cloudscale-volume-size-gb`: The size of the root volume in GB (defaults to `10`).
- `--cloudscale-ssh-user`: The SSH user (defaults to `root`).
- `--cloudscale-ssh-port`: The SSH port (defaults to `22`).
- `--cloudscale-no-public-network`: Disables the public network interface.
- `--cloudscale-use-private-network`: Enables the private network interface.
- `--cloudscale-use-ipv6`: Enables IPv6 on public network interface.
- `--cloudscale-server-groups`: the UUID identifying the [server group](https://www.cloudscale.ch/en/api/v1#server-groups) to which the new server will be added, option can be repeated.
- `--cloudscale-anti-affinity-with`: the UUID of another server to create an anti-affinity group with that server or add it to the same group as that server.
- `--cloudscale-userdata`: string containing cloud-init user data
- `--cloudscale-userdatafile`: path to file with cloud-init user data
- `--cloudscale-volume-ssd`: size of an additional [SSD volume](https://www.cloudscale.ch/en/api/v1#volumes) to be attached to the server, option can be repeated.
- `--cloudscale-volume-bulk`: size of an additional [bulk volume](https://www.cloudscale.ch/en/api/v1#volumes) to be attached to the server, option can be repeated.


## Development

Fork this repository, yielding `github.com/<yourAccount>/docker-machine-driver-cloudscale`.

```shell
# Get the sources of your fork
$ git clone 'https://github.com/<yourAccount>/docker-machine-driver-cloudscale.git'
$ cd docker-machine-driver-cloudscale

# Build it locally
$ make build

# Make the binary accessible to docker-machine
$ export PATH="$PATH:$PWD/bin"

# Print help text including cloudscale.ch-sepcific options
$ docker-machine create --driver cloudscale --help

# To create a test snapshot release
$ make snapshot
```

### Integration Tests

In order to run the integration test suite, please make sure that:

  1. `docker`, `docker-machine` and `docker-machine-driver-cloudscale` are available in your `$PATH`
  1. [bats-core](https://github.com/bats-core/bats-core) is available in your `$PATH`
  1. Your cloudscale.ch API Token is exported as `CLOUDSCALE_TOKEN`
  
If all of the above is fullfilled, invoke the test suite by calling:

`make integration`


## Credits
This driver is based on the great work of:
* [JonasProgrammer](https://github.com/JonasProgrammer/) for [docker-machine-driver-hetzner](https://github.com/JonasProgrammer/docker-machine-driver-hetzner)
* [splattner](https://github.com/splattner) from [Puzzle ITC](https://www.puzzle.ch)
* [DigitalOcean](https://github.com/digitalocean) for their [docker-machine-driver](https://github.com/docker/machine/tree/master/drivers/digitalocean)
