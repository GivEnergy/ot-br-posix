#!/bin/bash

#---------------------------------------------------
# Docker image for building the SDK
BUILD_DOCKER_IMAGE_IMX9=905418066572.dkr.ecr.eu-west-2.amazonaws.com/sdk-imx9:0.2.0
#---------------------------------------------------
CONTAINER_NAME=sdk-imx-container
PWD_DIR=$(pwd)

# Default values for variables
RUN_CONTAINER=1
CLEAN_APP=0
CLEAN_LIBRARY=0
BUILD_CUTEST=0
CLEAN_ALL=0
BUILD_APP=1
BUILD_LIBRARY=0
LOG_LEVEL=0

DEV_IMX6=1
VIRTUAL_MACHINE=2
HEMS_IMX93=3

HW_PL=$HEMS_IMX93

SDK_DIR=/SDK            # shall match with docker image
HOST_DIR=$(pwd)         # directory where this script runs
WORK_DIR=/otbr          # directory where the HOST_DIR maps into docker

# Text colors
BLACK='\033[0;30m'
DARK_GRAY='\033[1;30m'
LIGHT_GRAY='\033[0;37m'
WHITE='\033[1;37m'
CYAN='\033[0;36m'
LIGHT_CYAN='\033[1;36m'
PURPLE='\033[0;35m'
LIGHT_PURPLE='\033[1;35m'
BROWN='\033[0;33m'
LIGHT_RED='\033[1;31m'
LIGHT_GREEN='\033[1;32m'
LIGHT_BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
RESET='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}$1${RESET}"
    echo
}

log_yellow() {
    echo -e "${YELLOW}$1${RESET}"
}

log_error() {
    echo
    echo -e "${RED}$1${RESET}"
    echo
}

log_prompt() {
    echo
    echo -e "${LIGHT_CYAN}$1${RESET}"
}

# Function to display help
Help() {
    echo
    echo "Run ./build.sh for default option, or ./build.sh -[h|a|c|p:|n]."
    echo "-h     Print this Help."
    echo "-a     Build all for iMX9 platforms"
    echo "-c     Clean build"
    echo "-n     No container. Use this option when we run this script within container"
    echo
}

# Parse command-line options
while getopts "hacn" arg; do
    case $arg in
        h)
            Help
            exit;;
        a)
            log_info "Building all for iMX6/iMX9 platform"
            CLEAN_ALL=1
            BUILD_LIBRARY=1
            BUILD_APP=1
            ;;
        c)
            BUILD_APP=0
            BUILD_LIBRARY=0
            CLEAN_ALL=1
            CLEAN_APP=1
            ;;
        n)
            RUN_CONTAINER=0
            ;;
        \?)
            echo "Unknown parameter"
            Help
            exit;;
    esac
done

# Function to set environment variables
SetEnv() {
    log_info "Setting environment for platform = $HW_PL .................."
    source $SDK_DIR/environment-setup-armv8a-poky-linux
}

# Function to run the Docker container
RunContainer() {
    log_yellow "Running container on $BUILD_DOCKER_IMAGE image ..."
    docker run --name $CONTAINER_NAME \
        -v $HOST_DIR:$WORK_DIR \
        -e WORK_DIR=$WORK_DIR \
        -e LOG_LEVEL=$LOG_LEVEL \
        -e HW_PL=$HW_PL \
        $BUILD_DOCKER_IMAGE $WORK_DIR/build.sh $@ -n

    log_yellow "Removing container..."
    docker container rm $CONTAINER_NAME
}

##############################################################
Build_Env() {
    SetEnv
    export LIB_DIR=$WORK_DIR/libs
    export USR_LOCAL_INC_DIR=$WORK_DIR/usr/local/include
    export USR_LOCAL_LIB_DIR=$WORK_DIR/usr/local/lib
    export USR_INC_DIR=$WORK_DIR/usr/include
    export USR_LIB_X86_64=$WORK_DIR/usr/lib/x86_64-linux-gnu
}

# Function to clean the cem-app
Clean_All() {
    log_yellow "Cleaning otbr"
    SUB_BUILD_DIR="$WORK_DIR/build"
    cd $SUB_BUILD_DIR || exit 1
    rm -rf *
}


BuildOtbr() {
    log_yellow "Setup Environment for Thread boader router" 
    # may need to run mannually due to sudo
    # refer to: https://openthread.io/codelabs/openthread-border-router#1
    ./script/bootstrap
    INFRA_IF_NAME=wlan0 ./script/setup
    log_yellow "Building Thread boader router"
    ./script/cmake-build -DOTBR_BORDER_ROUTING=ON -DOTBR_REST=ON \
                         -DOTBR_BACKBONE_ROUTER=ON \
                         -DOT_BACKBONE_ROUTER_MULTICAST_ROUTING=ON -DBUILD_TESTING=OFF \
                         -DOTBR_DBUS=ON -DOTBR_DNSSD_DISCOVERY_PROXY=ON \
                         -DOTBR_SRP_ADVERTISING_PROXY=ON -DOT_THREAD_VERSION=1.4 \
                         -DOTBR_INFRA_IF_NAME=wlan0 \
            || exit 1  #-DOTBR_WEB=ON #this will require json lib
    echo
    log_prompt "Build completes"
    
}



##########################  BUILD FUNCTIONS   ####################################

# Main script logic

if [ $RUN_CONTAINER == 1 ]; then
    log_prompt "Running build script for platform = $HW_PL .................."
    BUILD_DOCKER_IMAGE=$BUILD_DOCKER_IMAGE_IMX9
    RunContainer "$@"
else
    log_info "LOG_LEVEL = $LOG_LEVEL"
    log_info "HW_PL = $HW_PL"
    export LOG_LEVEL  # Export LOG_LEVEL to the environment
    export HW_PL  # Export HW_PL to the environment
    cd $WORK_DIR || exit 1
    Build_Env
    if [ $CLEAN_ALL == 1 ]; then
        log_info "Cleaning all the applications and libraries"
        CLEAN_APP=1
        CLEAN_LIBRARY=1
        Clean_All
    fi

    if [ $BUILD_APP == 1 ]; then
        BuildOtbr
    fi

    log_info "Jobs done :)"
fi
