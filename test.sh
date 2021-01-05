#!/bin/bash
python3 main.py --video_file data/videos/ayush.mp4 --path results/ayush \
  --camera_params "1671.770118, 540, 960" --camera_model "SIMPLE_PINHOLE" \
  --make_video

echo See results/ directory for output.
echo You may want to copy it to /pwd to save it to the working directory outside of the container.
echo See https://github.com/facebookresearch/consistent_depth for more info on results.
