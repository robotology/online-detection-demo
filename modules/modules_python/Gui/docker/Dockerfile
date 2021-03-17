
# Copyright 2019 - 2020 The MathWorks, Inc.

#FROM python:3.6.9

FROM ubuntu:18.04 as prebuilder

MAINTAINER Elisa Maiettini

RUN apt-get update && apt-get install -y \
        software-properties-common
RUN apt-get install -y \
    libsdl2-dev \
    libsdl2-image-dev \
    libsdl2-mixer-dev \
    libsdl2-ttf-dev \
    libportmidi-dev \
    libswscale-dev \
    libavformat-dev \
    libavcodec-dev \
    zlib1g-dev

RUN apt-get install -y libmtdev-dev
RUN apt-get install -y python-enchant  python-dev
RUN apt-get install -y build-essential libgl1-mesa-dev libgles2-mesa-dev zlib1g-dev

RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update && apt-get install -y \
        python3.6 \
        python3-pip

RUN apt-get update && apt-get install -y \
        python3-distutils \
        python3-setuptools

RUN python3.6 -m pip install pip
RUN apt-get update

RUN python3.6 -m pip install --upgrade setuptools
RUN python3.6 -m pip install --user cython
RUN add-apt-repository ppa:kivy-team/kivy
RUN python3.6 -m pip install --no-binary kivy kivy

RUN apt install -y git

ARG username
ARG password

RUN git clone https://{username}:{password}@github.com/Arya07/online-detection-demo.git
RUN apt install -y gedit
RUN apt-get install mesa-utils
