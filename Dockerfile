FROM python:3.10-slim

WORKDIR /app

COPY . .

RUN pip install -r requirements.txt

INVALID_DOCKER_COMMAND this_will_fail

CMD ["python", "app.py"]
