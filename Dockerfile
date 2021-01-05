# Build a docker image to run the consistent_depth samples
# https://github.com/facebookresearch/consistent_depth
# Build with build.sh
# Run with run.sh
# 
# See results/ directory for output.
# You may want to copy it to /pwd to save it to the working directory outside of the container.
# See https://github.com/facebookresearch/consistent_depth for more info on results.

FROM nvidia/cuda:10.1-cudnn7-devel-ubuntu18.04 
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

RUN apt-get -y update && apt-get install -y \
    curl \
    git \
    cmake \
    build-essential \
    ffmpeg \
    libboost-program-options-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-regex-dev \
    libboost-system-dev \
    libboost-test-dev \
    libeigen3-dev \
    libsuitesparse-dev \
    libfreeimage-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libglew-dev \
    qtbase5-dev \
    libqt5opengl5-dev \
    libcgal-dev \
    libcgal-qt5-dev \
    python3-opencv


# Get the consistent_depth repo and set it up
WORKDIR /work
RUN git clone https://github.com/facebookresearch/consistent_depth.git
WORKDIR /work/consistent_depth
RUN git submodule update --init --recursive

# Set up Conda
RUN cd /tmp && curl -O https://repo.anaconda.com/archive/Anaconda3-2019.07-Linux-x86_64.sh
RUN chmod +x /tmp/Anaconda3-2019.07-Linux-x86_64.sh
RUN mkdir /root/.conda
RUN bash -c "/tmp/Anaconda3-2019.07-Linux-x86_64.sh -b -p /opt/anaconda3"

# Initializes Conda for bash shell interaction.
RUN /opt/anaconda3/bin/conda init bash

# Upgrade Conda to the latest version
RUN /opt/anaconda3/bin/conda update -n base -c defaults conda -y

# Create the work environment and setup its activation on start.
RUN /opt/anaconda3/bin/conda create --name main -y python=3.6
RUN echo conda activate main >> /root/.bashrc

# Run commands inside the Conda environment
SHELL ["/opt/anaconda3/bin/conda", "run", "-n", "main", "/bin/bash", "-c"]

RUN conda install pytorch torchvision scikit-image opencv tensorboard h5py wget cudatoolkit=10.1 -c pytorch
RUN pip3 install wget pypng networks gdown


RUN mkdir -p colmap-packages
WORKDIR colmap-packages

# Install ceres-solver [10-20 min]
RUN apt-get install -y libatlas-base-dev libsuitesparse-dev
RUN git clone https://ceres-solver.googlesource.com/ceres-solver
WORKDIR ceres-solver
RUN git checkout $(git describe --tags) # Checkout the latest release
RUN mkdir build
WORKDIR build
RUN cmake .. -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF
RUN make
RUN make install
WORKDIR ../..

# Install COLMAP
RUN git clone https://github.com/colmap/colmap
WORKDIR colmap
RUN git checkout dev
RUN git checkout tags/3.6-dev.3 -b dev-3.6
RUN mkdir build
WORKDIR build
# Workaround compile issue / conflict with libtiff:
RUN conda uninstall libtiff
RUN cmake ..
RUN make
RUN make install
RUN CC=/usr/bin/gcc-6 CXX=/usr/bin/g++-6 cmake ..
WORKDIR ../../..

RUN mkdir -p checkpoints
RUN gdown https://drive.google.com/uc?id=1hF8vS6YeHkx3j2pfCeQqqZGwA_PJq_Da -O checkpoints/flownet2.pth
# or, if you have a local copy:
#COPY flownet2.pth checkpoints/
ARG results_dir="results/ayush"
RUN mkdir -p data/videos/
RUN wget https://www.dropbox.com/s/9a2kb7flg3o1eb5/ayush_color.mp4?dl=1 -O data/videos/ayush.mp4
# or, if you have a local copy:
#COPY ayush.mp4 data/videos/
RUN mkdir -p "${results_dir}"
RUN wget https://www.dropbox.com/s/7mbvu60qbs7hzod/ayush_colmap.zip?dl=1 -O "${results_dir}/ayush_colmap.zip"
# or, if you have a local copy:
#COPY ayush_colmap.zip "${results_dir}/"
RUN apt-get install -y unzip
RUN unzip "${results_dir}/ayush_colmap.zip" -d "${results_dir}"
RUN rm "${results_dir}/ayush_colmap.zip"

# Do general 'user' set-up, creating a non-root user to run the experiment
ARG USER_ID
ARG GROUP_ID

RUN addgroup --gid $GROUP_ID user
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user

RUN mkdir -p /work
RUN chown -R user:user /work

# Allow password-less 'root' login with 'su'
RUN passwd -d root
RUN sed -i 's/nullok_secure/nullok/' /etc/pam.d/common-auth

# Copy testing scripts into container
COPY test.sh /work/consistent_depth
COPY test-gpu.py /home/user
RUN chmod +x /work/consistent_depth/test.sh /home/user/test-gpu.py
RUN chown -R user:user /opt/anaconda3/envs/main/ /work /home/user/test-gpu.py

# Switch to non-root user from this step forward
USER user

WORKDIR /work

# Install flownet2
RUN git clone https://github.com/NVIDIA/flownet2-pytorch.git
WORKDIR flownet2-pytorch
# fix problem: PyTorch needs C++14 now
RUN find . -name setup.py -exec sed -i 's/c++11/c++14/' \{\} \;
RUN bash install.sh

RUN conda install torchvision scikit-image opencv -c pytorch

WORKDIR /work/consistent_depth
# Use mpeg4 to encode sample videos instead of problematic libx264 codec
RUN sed -i 's/libx264/mpeg4/' tools/make_video.py utils/visualization.py

SHELL ["/bin/bash","-c"]

# Initializes Conda for bash shell interaction.
RUN /opt/anaconda3/bin/conda init bash
RUN echo conda activate main >> /home/user/.bashrc

CMD ["/opt/anaconda3/bin/conda", "run", "-n", "main", "/bin/bash", "-c", "time sh test.sh"]
