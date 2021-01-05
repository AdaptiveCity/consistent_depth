#!/bin/bash

docker run --gpus all --net=host -it --rm \
       -e XAUTHORITY=$HOME/.Xauthority \
       -e DISPLAY="$DISPLAY" \
       -v "$HOME":"$HOME":ro \
       -u `id -u`:`id -g` \
       --ipc=host \
       -v $PWD:/pwd \
       consistent_depth $*

