FROM python:2.7

ADD requirements.txt /tmp/
RUN pip install -Ur /tmp/requirements.txt

RUN curl -sf -o /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq

WORKDIR /opt/app

ENV LISTEN_HOST 0.0.0.0
ENV LISTEN_PORT 9001
ENV XM_USERNAME none
ENV XM_PASSWORD none

ADD *.py /opt/app/

ENTRYPOINT python /opt/app/server.py
