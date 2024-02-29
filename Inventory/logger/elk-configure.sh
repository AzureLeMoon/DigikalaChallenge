
    sudo cp /tmp/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml

    sudo cp /tmp/kibana.yml /etc/kibana/kibana.yml
    
    sudo systemctl restart elasticsearch

    sudo systemctl restart kibana

    curl -L -O https://artifacts.elastic.co/downloads/logstash/logstash-8.12.2-amd64.deb

    sudo dpkg -i logstash-8.12.2-amd64.deb
      
    sudo cp /tmp/beats.conf /etc/logstash/conf.d/beats.conf

    sudo systemctl restart logstash
