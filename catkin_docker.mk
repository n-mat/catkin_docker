
ifeq ($(filter catkin_base.mk, $(notdir $(MAKEFILE_LIST))), catkin_base.mk)

SOURCE_DIRECTORY?=$(shell realpath "$(shell dirname "$(lastword $(MAKEFILE_LIST))")")
CATKIN_DOCKER_MAKEFILE_PATH?=$(shell realpath "$(shell dirname "$(lastword $(MAKEFILE_LIST))")")

include ${CATKIN_DOCKER_MAKEFILE_PATH}/catkin_base.mk

endif
