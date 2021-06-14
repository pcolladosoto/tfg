# -*- mode: ruby -*-
# vi: set ft=ruby :

# NOTE: Both network options are EXCLUSIVE or at least I think so XD
# NOTE: Stopping the machine and bringing it up again reconfigures networking!

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/focal64"
  # Uncomment these to enable X11 forwarding. Remember
    # to have XQuartz running on the host if on macOS!
  # config.ssh.forward_agent = true
  # config.ssh.forward_x11 = true
  config.vm.provider "virtualbox" do |v|
  # Let the host be reached from the outside!
  # config.vm.network "public_network"
  # config.vm.network :forwarded_port, guest: 5060, host: 5060
  v.customize ["modifyvm", :id, "--memory", 1024]
  end

  config.vm.define "focalvm" do |focalvm|
    focalvm.vm.hostname = 'focalvm'
    # Activate a private host <-> VM network
    focalvm.vm.network :private_network, ip: "10.0.123.2"
  end
end
