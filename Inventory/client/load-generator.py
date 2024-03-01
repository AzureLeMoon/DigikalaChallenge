import requests
import time

url = 'http://192.168.20.3'

total_requests = 1000

for i in range(total_requests):
    response = requests.get(url, stream=True)

    print(f'Request {i+1}: {response.status_code}')

    time.sleep(0.0001)