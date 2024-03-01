Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/bionic64"

  config.vm.define "client" do |client|
    #client.vm.box="generic/ubuntu1804"
    client.vm.hostname = "client"
    client.vm.network "private_network", ip: "192.168.10.2", virtualbox__intnet: "net1"

    client.vm.provision "file", source: "Inventory/client/load-generator-concurrent.py", destination: "/tmp/load-generator-concurrent.py"
    client.vm.provision "file", source: "Inventory/client/load-generator.py", destination: "/tmp/load-generator.py"


    $script = <<-SCRIPT
    sudo apt-get update
      
    sudo apt-get install -y traceroute

    sudo ip route add 192.168.20.0/24 via 192.168.10.3 dev enp0s8

    python3 /tmp/load-generator.py
    SCRIPT

    client.vm.provision "traceroute", type: "shell", inline: $script


  end
  
  
  config.vm.define "logger" do |logger|
    logger.vm.box="Dealmi/ubuntu20_elk_agent"
    logger.vm.hostname = "logger"
    logger.vm.network "private_network", ip: "192.168.30.4", virtualbox__intnet: "net3"
    logger.vm.network "forwarded_port", guest: 5601, host: 5601

    

    logger.vm.provision "file",before: "elk-configure" , source: "Inventory/logger/elasticsearch.yml", destination: "/tmp/elasticsearch.yml"
    logger.vm.provision "file",before: "elk-configure" , source: "Inventory/logger/kibana.yml", destination: "/tmp/kibana.yml"
    logger.vm.provision "file",before: "elk-configure" , source: "Inventory/logger/beats.conf", destination: "/tmp/beats.conf"



    logger.vm.provision "elk-configure", type: "shell", path: "Inventory/logger/elk-configure.sh"
  end

  config.vm.define "router" do |router|
    router.vm.hostname = "router"
    router.vm.network "private_network", ip: "192.168.10.3", virtualbox__intnet: "net1"
    router.vm.network "private_network", ip: "192.168.20.2", virtualbox__intnet: "net2"

    
    #router.vm.provision "file" ,before: "bird install and start" , source: "Inventory/Router-bird.conf", destination: "/tmp/bird.conf"
    
    router.vm.provision "bird install and start", type: "shell", path: "Inventory/router/bird_install_run_Router.sh"

    #router.vm.network "public_network", bridge: false

  end

  config.vm.define "edge" do |edge|
    edge.vm.hostname = "edge" 
    edge.vm.network "private_network", ip: "192.168.20.3", virtualbox__intnet: "net2"
    edge.vm.network "private_network", ip: "192.168.30.2", virtualbox__intnet: "net3"

    #edge.vm.network "public_network", bridge: false

    # bird provisioning
    #edge.vm.provision "file" ,before: "bird install and start" , source: "Inventory/edge-bird.conf", destination: "/tmp/bird.conf"
    
    edge.vm.provision "bird install and start", type: "shell", path: "Inventory/edge/bird_install_run_Edge.sh"


    #nginx provisioning
    edge.vm.provision "file",before: "nginx install and start" , source: "Inventory/edge/nginx.conf", destination: "/tmp/mysite.conf"
    edge.vm.provision "nginx install and start", type: "shell", path: "Inventory/edge/nginx_install_run.sh"
    
    #filebeat provisioning
    edge.vm.provision "file",before: "filebeat-configure" , source: "Inventory/edge/filebeat.yml", destination: "/tmp/filebeat.yml"
    edge.vm.provision "file",before: "filebeat-configure" , source: "Inventory/edge/nginx.yml", destination: "/tmp/nginx.yml"
    edge.vm.provision "file",before: "filebeat-configure" , source: "Inventory/edge/system.yml", destination: "/tmp/system.yml"
    edge.vm.provision "filebeat-configure", type: "shell", path: "Inventory/edge/edge-logging-setup.sh"

    edge.vm.provision "file",before: "edgescript" , source: "Inventory/edge/request-limiting-solution.py", destination: "/tmp/request-limiting-solution.py"
    edge.vm.provision "edgescript", type: "shell", path: "Inventory/edge/edge-configure.sh"

  end





  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.30.3", virtualbox__intnet: "net3"
    #web.vm.network "public_network", bridge: false


    web.vm.provision "file", source: "Inventory/web/index.html", destination: "/tmp/index.html"
    web.vm.provision "shell", inline: <<-SHELL
    
    sudo apt-get update

    
    sudo apt-get install -y apache2

    
    sudo cp /tmp/index.html /var/www/html/

    
    sudo systemctl start apache2
    sudo systemctl enable apache2
  SHELL

  end


end