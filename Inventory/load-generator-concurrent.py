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
