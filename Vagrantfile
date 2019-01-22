# -*- mode: ruby -*-
# vi: set ft=ruby

require 'yaml'
require 'securerandom'

servers = YAML.load_file(File.join(File.dirname(__FILE__), 'config/vagrant/servers.yaml'))

Vagrant.configure("2") do |config|
  config.vm.box = "Slach/vagrant-kubernetes"

  servers['vagrant'].each do |name, server|
    config.vm.define name do |host|
      host.vm.hostname = name
      host.vm.network :private_network, ip: server["vm"]["ip"], nic_type: "virtio"
    end

    if server["vm"].has_key?("mem") then
      config.vm.provider :virtualbox do |host|
        host.memory = server["mem"]
      end
    else
      config.vm.provider :virtualbox do |host|
        host.memory = 1024
      end
    end

    if server["vm"].has_key?("cpu") then
      config.vm.provider :virtualbox do |host|
        host.cpus = server["cpu"]
      end
    end

  end

  config.vm.provision :shell, path: "config/vagrant/bootstrap-kubernetes.sh", :privileged => true

end
