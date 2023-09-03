FROM python:3.10-slim


# Install production dependencies.
COPY ./requirements.txt ./

WORKDIR /app
COPY . /app
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

CMD [ "python", "/app/code/hello.py" ]

