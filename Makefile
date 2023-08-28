SHELL:=/bin/bash

.DEFAULT_GOAL := all

ROOT_DIR:=$(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

MAKEFLAGS += --no-print-directory

SUBMODULES_PATH?=${ROOT_DIR}

include ${SUBMODULES_PATH}/ci_teststand/ci_teststand.mk

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT?=1
DOCKER_CONFIG?=

SOURCE_DIRECTORY?=$(shell realpath ${ROOT_DIR})
CATKIN_WORKSPACE_DIRECTORY:=${SOURCE_DIRECTORY}/catkin_workspace


include catkin_base.mk

.PHONY: set_env 
set_env:
	$(eval PROJECT := ${CATKIN_BASE_PROJECT}) 
	$(eval TAG := ${CATKIN_BASE_TAG})

.PHONY: build
build: set_env
	make build_catkin_base
	mkdir -p ${PROJECT}/build

.PHONY: clean
clean: set_env
	make clean_catkin_base 
	rm -rf ${PROJECT}/build

.PHONY: test
test: ci_test
