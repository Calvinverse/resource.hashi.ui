# resource.hashiui

This repository contains the source code necessary to build Ubuntu Hyper-V hard-drives containing the
[Consul native UI](https://www.consul.io/docs/agent/options.html#_ui).

## Image

The image is created by using the [Linux base image](https://github.com/Calvinverse/base.linux)
and amending it using a [Chef](https://www.chef.io/chef/) cookbook which updates the Consul
configuration to enable the UI.

### Contents

In addition to the default applications installed in the template image the following items are
also installed and configured:

* The Consul native UI is enabled

The image is configured to add the Consul UI as service to Consul under the `dashboard`
service name with the `consul` tag. Additionally the services is added to the reverse
proxy so that the UI is available from outside the environment.

### Configuration

The configuration comes from a set of [Consul-Template](https://github.com/hashicorp/consul-template)
template files which replaces some of the template parameters with values from the Consul Key-Value store.

### Provisioning

No additional configuration is applied other than the default one for the base image.

### Logs

No additional configuration is applied other than the default one for the base image.

### Metrics

No additional configuration is applied other than the default one for the base image.

## Build, test and release

The build process follows the standard procedure for
[building Calvinverse images](https://www.calvinverse.net/documentation/how-to-build).

## Deploy

* Download the new image to one of your Hyper-V hosts.
* Create a directory for the image and copy the image VHDX file there.
* Create a VM that points to the image VHDX file with the following settings
  * Generation: 2
  * RAM: at least 1024 Mb
  * Hard disk: Use existing. Copy the path to the VHDX file
  * Attach the VM to a suitable network
* Update the VM settings:
  * Enable secure boot. Use the Microsoft UEFI Certificate Authority
  * Attach a DVD image that points to an ISO file containing the settings for the environment. These
    are normally found in the output of the [Calvinverse.Infrastructure](https://github.com/Calvinverse/calvinverse.infrastructure)
    repository. Pick the correct ISO for the task, in this case the `Linux Consul Client` image
  * Disable checkpoints
  * Set the VM to always start
  * Set the VM to shut down on stop
* Start the VM, it should automatically connect to the correct environment once it has provisioned
* Remove the old VM
  * SSH into the host
  * Issue the `consul leave` command
  * Shut the machine down with the `sudo shutdown now` command
  * Once the machine has stopped, delete it

## Usage

The Consul UI webpage will be made available from the proxy at the `/dashboards/consul` sub-address.
