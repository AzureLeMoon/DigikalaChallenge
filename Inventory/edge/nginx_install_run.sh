       
      sudo apt-get install -y nginx

      sudo cp /tmp/mysite.conf /etc/nginx/sites-available/mysite.conf

      sudo rm /etc/nginx/sites-enabled/default -f

      sudo ln -s /etc/nginx/sites-available/mysite.conf /etc/nginx/sites-enabled/

      sudo mkdir /var/cache/nginx -p

      sudo systemctl restart nginx