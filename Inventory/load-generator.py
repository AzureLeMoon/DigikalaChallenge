import requests
import time

url = 'http://your-edge-server.com'

total_requests = 1000

for i in range(total_requests):
    response = requests.get(url)

    print(f'Request {i+1}: {response.status_code}')


    time.sleep(0.01)
