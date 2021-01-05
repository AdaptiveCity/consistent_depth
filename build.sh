#!/bin/bash

docker build -t consistent_depth \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  .
