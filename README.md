# Catkin docker

This is a command line tool and docker context that can generate a catkin 
workspace and link precompiled catkin packages to this workspace. 

## Prerequisites
Docker and make must be installed

## Creating a catkin workspace
Call the provided make target:
```bash
make create_catkin_worspace SOURCE_DIRECTORY=$(realpath <source directory>)
```

The "SOURCE_DIRECTORY" must be an absolute path to a directory containing catkin
packages.
