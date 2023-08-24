SHELL:=/bin/bash

.DEFAULT_GOAL := all

ROOT_DIR:=$(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

MAKEFLAGS += --no-print-directory

SUBMODULES_PATH?=${ROOT_DIR}

include ${SUBMODULES_PATH}/ci_teststand/ci_teststand.mk

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT?=1
DOCKER_CONFIG?=

SOURCE_DIRECTORY:=$(shell realpath ../)
CATKIN_WORKSPACE_DIRECTORY:=${SOURCE_DIRECTORY}/catkin_workspace


include catkin_base.mk



.PHONY: build
build:
	make build_catkin_base

.PHONY: clean
clean:
	make clean_catkin_base 

.PHONY: test
test: ci_test
