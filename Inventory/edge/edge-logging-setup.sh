curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.2-amd64.deb

sudo dpkg -i filebeat-8.12.2-amd64.deb

sudo cp /tmp/filebeat.yml /etc/filebeat/filebeat.yml

sudo cp /tmp/nginx.yml /etc/filebeat/modules.d/nginx.yml

sudo cp /tmp/system.yml /etc/filebeat/modules.d/system.yml

sudo filebeat setup --dashboards -e

sudo systemctl restart filebeat

