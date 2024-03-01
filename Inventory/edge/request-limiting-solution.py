import time
from random import random
import requests
from flask import Flask, request, abort, Response

app = Flask(__name__)

# Token bucket settings
capacity = 100  # maximum number of tokens
refill_rate = 5  # tokens per second
tokens = capacity
last_refill_time = time.time()

# Backend webserver settings
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

    # Acquire a token
    if tokens >= 1:
        tokens -= 1
    else:
        # No token available, discard the request with 20% probability
        if random() < 0.2:
            abort(429)  # Too Many Requests

    # Forward the request to the backend webserver
    backend_response = requests.get(backend_url, headers=request.headers)

    # Return the response from the backend webserver
    response_headers = [(name, value) for (name, value) in backend_response.raw.headers.items()]
    response = Response(backend_response.content, backend_response.status_code, response_headers)
    return response

if __name__ == '__main__':
    app.run()
