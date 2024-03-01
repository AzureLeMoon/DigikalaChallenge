# Table of Contents
- [Table of Contents](#table-of-contents)
- [1. DigikalaChallenge Documentation](#1-digikalachallenge-documentation)
  - [1.1. Base box \& Networking](#11-base-box--networking)
  - [1.2. Setting up the CDN](#12-setting-up-the-cdn)
    - [1.2.1. Step 1 : Webserver](#121-step-1--webserver)
    - [1.2.2. Step 2 : BGP routing](#122-step-2--bgp-routing)
    - [1.2.3. Step 3 : Nginx Reverse Proxy](#123-step-3--nginx-reverse-proxy)
    - [1.2.4. Step 4 : ELK stack](#124-step-4--elk-stack)
    - [1.2.5. Step 5 : Tuning and extra features](#125-step-5--tuning-and-extra-features)
      - [1.2.5.1. Tuning Tcp stack:](#1251-tuning-tcp-stack)
      - [1.2.5.2. Cache purge](#1252-cache-purge)
      - [1.2.5.3. Heavy load](#1253-heavy-load)
      - [1.2.5.4. ELK ILM](#1254-elk-ilm)
# 1. DigikalaChallenge Documentation
## 1.1. Base box & Networking 


First up is choosing a base box to use ,   
for the most part using the base images provided by `ubuntu` or `hashicorp` satisfies our needs how ever for the logger VM we are going to use another box with `elasticsearch` and `kibana` already setup which should be ready to go using some minor configurations.

the VMs are going to be setup as below:

**Client :** 
```ruby
  config.vm.define "client" do |client|
    client.vm.hostname = "client"
    client.vm.network "private_network", ip: "192.168.10.2", virtualbox__intnet: "net1"
  end
```

This spins up the Client machine already on Network-1 which is the network between the Router and the Client.

**Router :**

```ruby
  config.vm.define "router" do |router|
    router.vm.hostname = "router"
    router.vm.network "private_network", ip: "192.168.10.3", virtualbox__intnet: "net1"
    router.vm.network "private_network", ip: "192.168.20.2", virtualbox__intnet: "net2"

  end
  ```
Here the router is assigned to both Network-1 and Network-2.

**Edge :**

```ruby
config.vm.define "edge" do |edge|
    edge.vm.hostname = "edge" 
    edge.vm.network "private_network", ip: "192.168.20.3", virtualbox__intnet: "net2"
    edge.vm.network "private_network", ip: "192.168.30.2", virtualbox__intnet: "net3"
  end

```

Similar to the Router however this time we are using Networks 2 and 3.

**Web :**

```ruby
 config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.30.3", virtualbox__intnet: "net3"
  end
```

**Logger :**


```ruby
  config.vm.define "logger" do |logger|
    logger.vm.box="Dealmi/ubuntu20_elk_agent"
    logger.vm.hostname = "logger"
    logger.vm.network "private_network", ip: "192.168.30.4", virtualbox__intnet: "net3"
    logger.vm.network "forwarded_port", guest: 5601, host: 5601
  end
```

This VM is going to be different in that we are using another image which has `elasticsearch` and `kibana` already installed, we are going to be adding `logstash` to it later on. also we are forwarding port 5601 to be able to access the `kibana` panel from the host.


## 1.2. Setting up the CDN

### 1.2.1. Step 1 : Webserver

This part is simple we are going to be using apache to host a simple website and we are going to configure our VM like below:


```ruby
    web.vm.provision "file", source: "Inventory/web/index.html", destination: "/tmp/index.html"
    web.vm.provision "shell", inline: <<-SHELL
    
    sudo apt-get update

    
    sudo apt-get install -y apache2

    
    sudo cp /tmp/index.html /var/www/html/

    
    sudo systemctl start apache2
    sudo systemctl enable apache2
  SHELL
```

We copy the files to the VM using vagrant provisioning and install and setup the website using the buitlin `SHELL` provisioner

### 1.2.2. Step 2 : BGP routing

In this step we are going to use bird to setup a BGP route between our `router` and the `edge` server, the configuration on the `router` is going to be done using the following shell script:


```bash
#!/bin/bash

sudo apt-get update

sudo apt-get install -y bird

sudo cat << EOF > /etc/bird/bird.conf


log syslog { debug, trace, info, remote, warning, error, auth, fatal, bug };
debug protocols all;

router id 192.168.10.3;

protocol kernel {
  learn;
  persist;
  scan time 20;
  import none;
  export none;
}

protocol device {
  scan time 10;
}

protocol direct {
  interface "enp0s8";
  interface "enp0s9";
}

protocol bgp {
  import all;
  export all;
  local as 65001;
  neighbor 192.168.20.3 as 65002; 
  source address 192.168.10.3; 
}

EOF

sudo sysctl -w net.ipv4.ip_forward=1

sudo systemctl restart bird

sudo systemctl enable bird
```

The bird router is configured by introducing the `edge` server as a neighbor and specifiying the Network interfaces to use and then exporting these routes into system routes. packet forwarding between interfaces also needs to be enabled using `sysctl -w net.ipv4.ip_forward=1`

Wwe run this script in our vagrant file using the shell provisioner
```ruby
    edge.vm.provision "bird install and start", type: "shell", path: "Inventory/edge/bird_install_run_Edge.sh"
```

The edge server setup is similar except for changing the IP addresses around

```sh
protocol bgp {
  import all;
  export all;
  local as 65002;
  neighbor 192.168.20.2 as 65001; 
  source address 192.168.20.3; 
}
```

We also need to setup the default route for our `edge` server to Network-2 since Vagrant sets the NAT network as the default route.

```sh
sudo ip route del default

sudo ip route add default via 192.168.20.2 dev enp0s8
```

The `Client` VM needs some modifications as well

```ruby
    $script = <<-SCRIPT
    sudo ip route add 192.168.20.0/24 via 192.168.10.3 dev enp0s8
    SCRIPT

    client.vm.provision "traceroute", type: "shell", inline: $script
```
This is also due to vagrant using the NAT network by default.

### 1.2.3. Step 3 : Nginx Reverse Proxy

We are going to configure nginx as a reverse proxy to serve our website on the edge

```nginx
proxy_cache_path  /var/cache/nginx  levels=1:2    keys_zone=STATIC:10m inactive=24h  max_size=1g;
limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;

server {
  listen 80;
  server_name mysite.com;

  location / {
    proxy_pass http://localhost:5000;
    include proxy_params;
    limit_req zone=mylimit burst=5;
    add_header X-Server-Name $host;
    add_header X-Cache-Status $upstream_cache_status;
    add_header X-Response-Time $request_time;
  }

  location /static/ {
    proxy_pass http://localhost:5000;
    limit_req zone=mylimit burst=5;
    include proxy_params;
    add_header X-Server-Name $host;
    add_header X-Cache-Status $upstream_cache_status;
    add_header X-Response-Time $request_time;
    proxy_buffering        on;
    proxy_cache            STATIC;
    proxy_cache_valid      200  60m;
    proxy_cache_key $scheme://$host$uri$is_args$query_string;
    proxy_cache_use_stale  error timeout invalid_header updating http_500 http_502 http_503 http_504;
  }
}
```
We are using the builtin caching capabilites of nginx to cache our static content.  
In this config we cache requests with status code 200 for 60 minutes and our cache stays around for either 24 hours to when it reaches 1 gigabyte whichever comes first.

also using the buitlin rate limiter we are limiting requests to `10r/s` and returning status code `429` for those exceeding the limit.

some extra headers including `servername` , `cache status` and `response time` are being passed as well.

afterwards we setup nginx and our configuration using the following shell script:

```sh
       
      sudo apt-get install -y nginx

      sudo cp /tmp/mysite.conf /etc/nginx/sites-available/mysite.conf

      sudo rm /etc/nginx/sites-enabled/default -f

      sudo ln -s /etc/nginx/sites-available/mysite.conf /etc/nginx/sites-enabled/

      sudo mkdir /var/cache/nginx -p

      sudo systemctl restart nginx
```

and add this to our vagrant file :

```ruby 
    edge.vm.provision "file",before: "nginx install and start" , source: "Inventory/edge/nginx.conf", destination: "/tmp/mysite.conf"
    edge.vm.provision "nginx install and start", type: "shell", path: "Inventory/edge/nginx_install_run.sh"
```

### 1.2.4. Step 4 : ELK stack

For our logger VM as said before we are using a box with `elasticsearch` and `kibana` already setup however there are some modifications need to made including installing LogStash to indice our incoming logs.

here is the kibana configuration:

```yml
server.host: '0.0.0.0'
server.port: 5601

server.maxPayloadBytes: 8388608

elasticsearch.hosts: ['http://127.0.0.1:9200']

elasticsearch.username: 'kibana_system'

elasticsearch.requestTimeout: 132000
elasticsearch.shardTimeout: 120000

kibana.index: '.kibana'

vega.enableExternalUrls: true

console.enabled: true

xpack.security.enabled: false
xpack.security.audit.enabled: false

xpack.monitoring.enabled: true
xpack.monitoring.kibana.collection.enabled: true
xpack.monitoring.kibana.collection.interval: 300

xpack.monitoring.ui.enabled: true
xpack.monitoring.min_interval_seconds: 30

xpack.grokdebugger.enabled: true
xpack.searchprofiler.enabled: true

xpack.graph.enabled: false

xpack.infra.enabled: true

xpack.ml.enabled: false

xpack.reporting.enabled: false

xpack.encryptedSavedObjects.encryptionKey: "j2Xv2Q92tPk3euwev4z4FsXQ2PCtZ2eU"
elasticsearch.password: YaAqRsI0kNT7ymFPPop8
```

The password is randomized on VM Creation and is here only for demonstration.

Elasticsearch Configuration:

```yml
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch


network.host: 0.0.0.0
http.port: 9200

discovery.type: 'single-node'

indices.query.bool.max_clause_count: 8192
search.max_buckets: 250000

action.destructive_requires_name: 'true'

reindex.remote.whitelist: '*:*'

xpack.monitoring.enabled: 'true'
xpack.monitoring.collection.enabled: 'true'
xpack.monitoring.collection.interval: 30s

xpack.security.enabled: 'false'
xpack.security.audit.enabled: 'false'

xpack.security.authc.api_key.enabled: 'true'

node.ml: 'false'
xpack.ml.enabled: 'false'

xpack.watcher.enabled: 'false'

xpack.ilm.enabled: 'true'

xpack.sql.enabled: 'true'

action.auto_create_index: '*'
```




after these we need to setup `logstash`:


```c
input {
  beats {
    port => 5044
  }
}

filter {
  if [@metadata][beat] == "filebeat" {
    if [event][dataset] == "system.syslog" {
      mutate { add_field => { "[@metadata][index]" => "syslog-%{[host][name]}" } }
    } else if [event][dataset] == "system.auth" {
      mutate { add_field => { "[@metadata][index]" => "auth-%{[host][name]}" } }
    } else if [event][dataset] == "nginx.error" {
      mutate { add_field => { "[@metadata][index]" => "nginx-error-%{[host][name]}" } }
    } else if [event][dataset] == "nginx.access" {
      mutate { add_field => { "[@metadata][index]" => "nginx-access-%{[host][name]}" } }
    }
  }
}

output {
if [@metadata][beat] in ["heartbeat", "metricbeat", "filebeat"] {
    elasticsearch {
      hosts => "http://127.0.0.1:9200"
      index => "filebeat-%{[@metadata][index]}"
    }
  }

}
```

where we seperate our logs into seperate indices for `access/error` logs of nginx and `auth` and `syslog` for VM logs.


we then script these configuration as below :

```sh
    sudo cp /tmp/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml

    sudo cp /tmp/kibana.yml /etc/kibana/kibana.yml
    
    sudo systemctl restart elasticsearch

    sudo systemctl restart kibana

    curl -L -O https://artifacts.elastic.co/downloads/logstash/logstash-8.12.2-amd64.deb

    sudo dpkg -i logstash-8.12.2-amd64.deb
      
    sudo cp /tmp/beats.conf /etc/logstash/conf.d/beats.conf

    sudo systemctl restart logstash

```

and provision them in vagrant:

```ruby
    logger.vm.provision "file",before: "elk-configure" , source: "Inventory/logger/elasticsearch.yml", destination: "/tmp/elasticsearch.yml"
    logger.vm.provision "file",before: "elk-configure" , source: "Inventory/logger/kibana.yml", destination: "/tmp/kibana.yml"
    logger.vm.provision "file",before: "elk-configure" , source: "Inventory/logger/beats.conf", destination: "/tmp/beats.conf"

    logger.vm.provision "elk-configure", type: "shell", path: "Inventory/logger/elk-configure.sh"
```

now our `logger` VM is ready to receive our logs, which means we need to make some modifications to our `edge` VM.

first up is installing `filebeat` to collect our needed logs:

```sh
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.2-amd64.deb

sudo dpkg -i filebeat-8.12.2-amd64.deb

sudo cp /tmp/filebeat.yml /etc/filebeat/filebeat.yml

sudo cp /tmp/nginx.yml /etc/filebeat/modules.d/nginx.yml

sudo cp /tmp/system.yml /etc/filebeat/modules.d/system.yml

sudo systemctl restart filebeat
```

we are going to be using the builtin `nginx` and `system` modules for `filebeat` to collect the logs:

```yml
# Module: nginx
# Docs: https://www.elastic.co/guide/en/beats/filebeat/8.12/filebeat-module-nginx.html

- module: nginx
  access:
    enabled: true
  error:
    enabled: true
  ingress_controller:
    enabled: false
```


```yml
# Docs: https://www.elastic.co/guide/en/beats/filebeat/main/filebeat-module-system.html

- module: system
  # Syslog
  syslog:
    enabled: true
  auth:
    enabled: true
```

and then configure the logstash output:

```yml
filebeat.config.modules:

  path: ${path.config}/modules.d/*.yml

  reload.enabled: false

output.logstash:
  hosts: ['192.168.30.4:5044']

```
 now our `edge` VM is sending logs to the `logger` , these can be viewed in the `kibana` panel.


 ### 1.2.5. Step 5 : Tuning and extra features

 we already covered some of these in previous segment, however the ones that we didn't cover

 #### 1.2.5.1. Tuning Tcp stack:

 this can be done by changing values for different sysctl parameters like
 `net.core.rmem_max`, `net.core.wmem_max`, `net.ipv4.tcp_rmem`, and `net.ipv4.tcp_wmem`

 which are the buffer sizes for our tcp stack, we can increase these on our edge server for better handling of through put specially in 40G+ networks.

 we could also change the congestion algorithm by changing `net.ipv4.tcp_congestion_control`
using different algorithms like bbr could help with high concurrent connections

`net.ipv4.tcp_fin_timeout` for socket holds and increasing  `net.ipv4.ip_local_port_range` can help with outbound connections not being stuck waiting for an empty port aswell


#### 1.2.5.2. Cache purge

```sh
#!/bin/bash
CACHE_PATH="/var/cache/nginx"

if [ -z "$1" ]; then
    echo "Usage: $0 filename"
    exit 1
fi

find $CACHE_PATH -name "$1" -exec rm -f {} \;

echo "File $1 has been purged from cache."
```


#### 1.2.5.3. Heavy load

here we can use a simple solution which is limited and can be improved significantly however for the scope of this challenge we could use the following solution:


we will use the flask library from python and set it up behind nginx as the webserver to forward requets to( hence `http://localhost:5000`) and use the token bucket algorithm to discard 20% of the requets randomly:

```python
import time
from random import random
import requests
from flask import Flask, request, abort, Response

app = Flask(__name__)

capacity = 100  # maximum number of tokens
refill_rate = 5  # tokens per second
tokens = capacity
last_refill_time = time.time()

backend_url = 'http://192.168.30.3'

def refill_tokens():
    global tokens, last_refill_time
    current_time = time.time()
    elapsed_time = current_time - last_refill_time
    tokens = min(capacity, tokens + refill_rate * elapsed_time)
    last_refill_time = current_time

@app.before_request
def before_request():
    refill_tokens()

@app.route('/', methods=['GET'])
def handle_request():
    global tokens

    if tokens >= 1:
        tokens -= 1
    else:
        if random() < 0.2:
            abort(429) 

    backend_response = requests.get(backend_url, headers=request.headers)

    response_headers = [(name, value) for (name, value) in backend_response.raw.headers.items()]
    response = Response(backend_response.content, backend_response.status_code, response_headers)
    return response

if __name__ == '__main__':
    app.run()

```


which proccesses the requests and return 429 status codes whenever we exceed a certain adjustable limit.

we can use the following scripts for generating the load as well:

```py
#simple load generator
import requests
import time
from concurrent.futures import ThreadPoolExecutor

url = 'http://192.168.20.3'


total_requests = 1000

def send_request(url):
    response = requests.get(url)
    print(f'Request: {response.status_code}')

with ThreadPoolExecutor(max_workers=100) as executor:
    for _ in range(total_requests):
        executor.submit(send_request, url)
```

OR

```py 
#concurrent load generator
import requests
import time
from concurrent.futures import ThreadPoolExecutor

url = 'http://192.168.20.3'


total_requests = 1000

def send_request(url):
    response = requests.get(url)
    print(f'Request: {response.status_code}')

with ThreadPoolExecutor(max_workers=100) as executor:
    for _ in range(total_requests):
        executor.submit(send_request, url)
```


#### 1.2.5.4. ELK ILM

we can define index lifecycle policies on our indices to rotate these our after a certain size or amout of time has passsed, for example setting the included `logs` ILP ensures our indices are rotated after 30 Days or 50 GBs.








