package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"time"

	cloudscale "github.com/cloudscale-ch/cloudscale-go-sdk"
	"github.com/docker/machine/libmachine/drivers"
	"github.com/docker/machine/libmachine/log"
	"github.com/docker/machine/libmachine/mcnflag"
	"github.com/docker/machine/libmachine/ssh"
	"github.com/docker/machine/libmachine/state"
	"golang.org/x/oauth2"
)

type Driver struct {
	*drivers.BaseDriver
	APIToken          string
	UUID              string
	Image             string
	Flavor            string
	Region            string
	UsePrivateNetwork bool
	UseIPV6           bool
	UserDataFile      string
	UserData          string
	VolumeSizeGB      int
	AntiAffinityWith  string
	ServerGroups      []string
}

const (
	defaultSSHPort    = 22
	defaultSSHUser    = "root"
	defaultImage      = "ubuntu-18.04"
	defaultFlavor     = "flex-4"
	defaultVolumeSize = 10
)

// GetCreateFlags registers the flags this driver adds to
// "docker hosts create"
func (d *Driver) GetCreateFlags() []mcnflag.Flag {
	return []mcnflag.Flag{
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_TOKEN",
			Name:   "cloudscale-token",
			Usage:  "cloudscale.ch access token",
		},
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_SSH_USER",
			Name:   "cloudscale-ssh-user",
			Usage:  "SSH username",
			Value:  defaultSSHUser,
		},
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_SSH_KEY_PATH",
			Name:   "cloudscale-ssh-key-path",
			Usage:  "SSH private key path",
		},
		mcnflag.IntFlag{
			EnvVar: "CLOUDSCALE_SSH_PORT",
			Name:   "cloudscale-ssh-port",
			Usage:  "SSH port",
			Value:  defaultSSHPort,
		},
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_IMAGE",
			Name:   "cloudscale-image",
			Usage:  "cloudscale.ch Image",
			Value:  defaultImage,
		},
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_REGION",
			Name:   "cloudscale-region",
			Usage:  "cloudscale.ch region",
		},
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_FLAVOR",
			Name:   "cloudscale-flavor",
			Usage:  "cloudscale.ch flavor",
			Value:  defaultFlavor,
		},
		mcnflag.BoolFlag{
			EnvVar: "CLOUDSCALE_PRIVATE_NETWORKING",
			Name:   "cloudscale-use-private-network",
			Usage:  "enable private networking for a server",
		},
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_USERDATA",
			Name:   "cloudscale-userdata",
			Usage:  "cloud-init user-data",
		},
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_USERDATAFILE",
			Name:   "cloudscale-userdatafile",
			Usage:  "path to file with cloud-init user-data",
		},
		mcnflag.IntFlag{
			EnvVar: "CLOUDSCALE_VOLUME_SIZE_GB",
			Name:   "cloudscale-volume-size-gb",
			Usage:  "set the size of the root volume in GB",
			Value:  defaultVolumeSize,
		},
		mcnflag.StringFlag{
			EnvVar: "CLOUDSCALE_ANTI_AFFINITY_WITH",
			Name:   "cloudscale-anti-affinity-with",
			Usage:  "a UUID of another server",
		},
		mcnflag.StringSliceFlag{
			EnvVar: "CLOUDSCALE_SERVER_GROUPS",
			Name:   "cloudscale-server-groups",
			Usage:  "a list of UUIDs of server groups",
		},
		mcnflag.BoolFlag{
			EnvVar: "CLOUDSCALE_USE_IPV6",
			Name:   "cloudscale-use-ipv6",
			Usage:  "enable IPv6 on the public network Interface",
		},
	}
}

func NewDriver(hostName, storePath string) *Driver {
	return &Driver{
		Image:  defaultImage,
		Flavor: defaultFlavor,
		BaseDriver: &drivers.BaseDriver{
			MachineName: hostName,
			StorePath:   storePath,
		},
	}
}

func (d *Driver) GetSSHHostname() (string, error) {
	return d.GetIP()
}

// DriverName returns the name of the driver
func (d *Driver) DriverName() string {
	return "cloudscale"
}

func (d *Driver) SetConfigFromFlags(flags drivers.DriverOptions) error {
	d.APIToken = flags.String("cloudscale-token")
	d.Image = flags.String("cloudscale-image")
	d.Region = flags.String("cloudscale-region")
	d.Flavor = flags.String("cloudscale-flavor")
	d.UsePrivateNetwork = flags.Bool("cloudscale-use-private-network")
	d.UseIPV6 = flags.Bool("cloudscale-use-ipv6")
	d.UserDataFile = flags.String("cloudscale-userdatafile")
	d.UserData = flags.String("cloudscale-userdata")
	d.SSHUser = flags.String("cloudscale-ssh-user")
	d.SSHPort = flags.Int("cloudscale-ssh-port")
	d.VolumeSizeGB = flags.Int("cloudscale-volume-size-gb")
	d.AntiAffinityWith = flags.String("cloudscale-anti-affinity-with")
	d.ServerGroups = flags.StringSlice("cloudscale-server-groups")

	d.SetSwarmConfigFromFlags(flags)

	if d.APIToken == "" {
		return fmt.Errorf("cloudscale.ch driver requires the --cloudscale-token option")
	}

	return nil
}

func (d *Driver) PreCreateCheck() error {
	if d.UserDataFile != "" {
		if _, err := os.Stat(d.UserDataFile); os.IsNotExist(err) {
			return fmt.Errorf("user-data file %s could not be found", d.UserDataFile)
		}
	}
	return nil
}

func (d *Driver) Create() error {
	var userdata string
	if d.UserDataFile != "" {
		buf, err := ioutil.ReadFile(d.UserDataFile)
		if err != nil {
			return err
		}
		userdata = string(buf)
	} else {
		if d.UserData != "" {
			userdata = d.UserData
		}
	}

	log.Infof("Creating SSH key...")

	if err := ssh.GenerateSSHKey(d.GetSSHKeyPath()); err != nil {
		return err
	}
	publicKey, err := ioutil.ReadFile(d.publicSSHKeyPath())
	if err != nil {
		return err
	}

	log.Infof("Starting to create cloudscale.ch server...")

	client := d.getClient()

	createRequest := &cloudscale.ServerRequest{
		Image:             d.Image,
		Flavor:            d.Flavor,
		Name:              d.MachineName,
		UsePrivateNetwork: &d.UsePrivateNetwork,
		UseIPV6:           &d.UseIPV6,
		UserData:          userdata,
		SSHKeys:           []string{string(publicKey)},
		VolumeSizeGB:      d.VolumeSizeGB,
		AntiAffinityWith:  d.AntiAffinityWith,
		ServerGroups:      d.ServerGroups,
	}

	newServer, err := client.Servers.Create(context.TODO(), createRequest)
	if err != nil {
		return err
	}

	d.UUID = newServer.UUID

	log.Info("Waiting for IP address to be assigned to the Server...")
	for {
		newServer, err = client.Servers.Get(context.TODO(), d.UUID)
		if err != nil {
			return err
		}
		for _, interface_ := range newServer.Interfaces {
			if interface_.Type == "public" {
				for _, address := range interface_.Adresses {
					if address.Version == 4 {
						d.IPAddress = address.Address
					}
				}
			}
		}

		if d.IPAddress != "" {
			break
		}

		time.Sleep(1 * time.Second)
	}

	log.Debugf("Created server %d with IP address %s",
		newServer.UUID,
		d.IPAddress)

	return nil
}

func (d *Driver) GetURL() (string, error) {
	if err := drivers.MustBeRunning(d); err != nil {
		return "", err
	}

	ip, err := d.GetIP()
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("tcp://%s", net.JoinHostPort(ip, "2376")), nil
}

func (d *Driver) GetState() (state.State, error) {
	server, err := d.getClient().Servers.Get(context.TODO(), d.UUID)
	if err != nil {
		return state.Error, err
	}
	switch server.Status {
	case "running":
		return state.Running, nil
	case "stopped":
		return state.Stopped, nil
	}
	return state.None, nil
}

func (d *Driver) Start() error {
	err := d.getClient().Servers.Start(context.TODO(), d.UUID)
	return err
}

func (d *Driver) Stop() error {
	err := d.getClient().Servers.Stop(context.TODO(), d.UUID)
	return err
}

func (d *Driver) Restart() error {
	err := d.getClient().Servers.Reboot(context.TODO(), d.UUID)
	return err
}

func (d *Driver) Kill() error {
	err := d.getClient().Servers.Stop(context.TODO(), d.UUID)
	return err
}

func (d *Driver) Remove() error {
	if err := d.getClient().Servers.Delete(context.TODO(), d.UUID); err != nil {
		if err, ok := err.(*cloudscale.ErrorResponse); ok && err.StatusCode == 404 {
			log.Infof("cloudscale.ch server doesn't exist, assuming it is already deleted")
		} else {
			return err
		}
	}
	return nil
}

func (d *Driver) getClient() *cloudscale.Client {
	token := &oauth2.Token{AccessToken: d.APIToken}
	tokenSource := oauth2.StaticTokenSource(token)
	client := oauth2.NewClient(oauth2.NoContext, tokenSource)

	return cloudscale.NewClient(client)
}

func (d *Driver) publicSSHKeyPath() string {
	return d.GetSSHKeyPath() + ".pub"
}
