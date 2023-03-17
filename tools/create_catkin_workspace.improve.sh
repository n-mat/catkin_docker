#!/usr/bin/env bash

set -euo pipefail

function echoerr {
  echo "$@" >&2
  exit 1
}
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

DEFAULT_CATKIN_WORKSPACE_DIRECTORY=catkin_workspace
DEFAULT_SOURCE_DIRECTORY="$(realpath .)"
DEFAULT_LOCKFILE=.lock

CATKIN_WORKSPACE_DIRECTORY="${CATKIN_WORKSPACE_DIRECTORY:-${DEFAULT_CATKIN_WORKSPACE_DIRECTORY}}"
CATKIN_SOURCE_DIRECTORY="${CATKIN_WORKSPACE_DIRECTORY}/src"
CATKIN_LIB_DIRECTORY="${CATKIN_WORKSPACE_DIRECTORY}/install/lib"
CATKIN_MSG_DIRECTORY="${CATKIN_WORKSPACE_DIRECTORY}/install/share"
CATKIN_SHARE_DIRECTORY="${CATKIN_WORKSPACE_DIRECTORY}/install/share"

SOURCE_DIRECTORY="${SOURCE_DIRECTORY:-${DEFAULT_SOURCE_DIRECTORY}}"

check_ros_noetic(){
  if [[ ! -f "/opt/ros/noetic/setup.bash" ]]; then
    echoerr "ERROR: ROS Noetic setup script not found: /opt/ros/noetic/setup.bash, is ros-noetic-ros-base package installed?"
  fi

}

function catkin_workspace_init() {

  local source_directory="${1}"
  local catkin_workspace_directory="${2:-${DEFAULT_CATKIN_WORKSPACE_DIRECTORY}}"
  local lockfile="${3:-${DEFAULT_LOCKFILE}}"


  if [[ ! -d "${source_directory}" ]]; then
    echoerr "ERROR: The provided source directory: ${source_directory} does not exist."
  fi

  cd "${source_directory}"
  if [[ ! -d "${catkin_workspace_directory}" ]]; then
    mkdir "${catkin_workspace_directory}"
    touch "${catkin_workspace_directory}/${lockfile}"
    mkdir "${catkin_workspace_directory}"/{build,devel,install,logs,src}
    mkdir -p "${catkin_workspace_directory}"/install/{lib/python3/dist-packages,share,include}
    #ln -sf "${catkin_workspace_directory}/src" src
  else
    echoerr "ERROR: The Catkin workspace directory: ${source_directory}/${catkin_workspace_directory} already exists."
  fi
  printf "catkin_workspace_directory: %s\n" "${source_directory}/${catkin_workspace_directory}"
  cd "${source_directory}/${catkin_workspace_directory}"

  check_ros_noetic
  source /opt/ros/noetic/setup.bash
  catkin config --init --install --extend /opt/ros/noetic/ --workspace "${source_directory}/${catkin_workspace_directory}"
  catkin config --cmake-args -DCMAKE_BUILD_TYPE=Release -DXSD_INCLUDE_DIR=include -DCMAKE_PREFIX_PATH=/opt/ros/noetic
  cd "${source_directory}/${catkin_workspace_directory}/src"
  catkin_create_pkg catkin_workspace_init

  catkin build catkin_workspace_init
  rm -rf src/catkin_workspace_init
  if [ -L "${source_directory}/src" ]; then
    rm "${source_directory}/src"
  fi
  printf "The Catkin workspace directory can be found at: %s \n" "${source_directory}/${catkin_workspace_directory}"
}

find_build_packages() {
  local base_directory="${1}"

  built_packages=$(find "${base_directory}" -wholename "**/build/install" | grep -v "_CPack_Packages" | sed "s|build/install||g")
  printf "%s\n" "${built_packages}"
  #echo "${built_packages}" | while read package; do
  #    find "${package}" -name "package.xml" | grep -v -e "/build/" | grep -v "/external/"
  #done
}

find_package_xmls() {
  local package_base_path="${1}"
  find "${package_absolute_path}" -name "package.xml" | grep -v -e "/build/" | grep -v "/external/"
}

# exclude common-lisp  gennodejs  roseus

get_relative_path() {
  local source="${1}"
  local destination="${2}"

  if [[ -z "${source}" ]]; then
    echoerr "ERROR: source is empty. Must provide a source."
  fi
  if [[ ! -e "${source}" ]]; then
    echoerr "ERROR: source path provided: ${source} does not exist."
  fi

  if [[ -z "${destination}" ]]; then
    echoerr "ERROR: destination is empty. Must provide a destination."
  fi
  if [[ ! -e "${destination}" ]]; then
    echoerr "ERROR: destination path provided: ${destination} does not exist."
  fi
  realpath --relative-to="${source}" "${destination}"
}

print_path_exists() {
  local path="${1}"

  if [ -e "${path}" ]; then
    echo -e "\033[32mTRUE\033[0m"
  else
    echo -e "\033[31mFALSE\033[0m"
  fi
}

echo_bold() {
  local string="${1}"
  echo -e "\033[1m${string}\033[0m"
}

find_package_path(){
    local build_path="${1}"
    local path="${2}"

    if [[ -z "${build_path}" ]]; then
        echoerr "ERROR: build_path is empty. Must provide a build_path."
    fi
    if [[ ! -e "${build_path}" ]]; then
        echoerr "ERROR: build_path provided: ${build_path} does not exist."
    fi

    find "${build_path}" -name "${path}" | grep -e "devel\|install" | head -1
}

find_package_libraries(){
    local build_path="${1}"

    if [[ -z "${build_path}" ]]; then
        echoerr "ERROR: build_path is empty. Must provide a build_path."
    fi
    if [[ ! -e "${build_path}" ]]; then
        echoerr "ERROR: build_path provided: ${build_path} does not exist. Did you build it?"
    fi
    find "${build_path}/install" -name '*.a' -o -name '*.so' | grep -v "_CPack_Packages"
}

find_package_msg_paths() {
    local package_base_path="${1}"

    if [[ -z "${package_base_path}" ]]; then
        echoerr "ERROR: package_base_path is empty. Must provide a package_base_path."
    fi
    if [[ ! -e "${package_base_path}" ]]; then
        echoerr "ERROR: package_base_path provided: ${package_base_path} does not exist."
    fi

    find "${package_base_path}" -name msg -type d | grep -v "/build/"
}

link_package_sources(){
    local package_xml_files="${1}"
    local catkin_source_directory="${2:-${CATKIN_SOURCE_DIRECTORY}}"

    echo "${package_xml_files}" | \
    while read package_xml_file; do
        if [[ ! -z "${package_xml_file}" ]]; then
            link_package_source "${package_xml_file}"
        fi
    done

}

link_package_source(){
    local package_xml_file="${1}"
    local catkin_source_directory="${2:-${CATKIN_SOURCE_DIRECTORY}}"

    if [[ ! -e "${catkin_source_directory}" ]]; then
        echoerr "ERROR: catkin_source_directory provided: ${catkin_source_directory} does not exist."
    fi

    package_xml_file_absolute_path="$(realpath "${package_xml_file}")"
    package_xml_file_relative_path="$(get_relative_path "${catkin_source_directory}" "${package_xml_file}")"
    package_xml_file_parent_directory="$(basename "$(dirname "${package_xml_file_absolute_path}")")"
    package_xml_file_parent_directory_relative_path="$(dirname "${package_xml_file_relative_path}")"
    (
      cd "${catkin_source_directory}" && \
      ln -s -r -f "${package_xml_file_parent_directory_relative_path}" . 
    )
}

link_package_libraries(){
    local package_libraries="${1}"
    local catkin_lib_directory="${2:-${CATKIN_LIB_DIRECTORY}}"

    echo "${package_libraries}" | \
    while read package_library; do
        if [[ ! -z "${package_library}" ]]; then
            link_package_library "${package_library}"
        fi
    done
}

link_package_library(){
    local package_library="${1}"
    local catkin_lib_directory="${2:-${CATKIN_LIB_DIRECTORY}}"
    
    local package_library_absolute_path="$(realpath "${package_library}")"
    local package_library_relative_path="$(get_relative_path "${catkin_lib_directory}" "${package_library}")"

    if [[ ! -e "${catkin_lib_directory}" ]]; then
        echoerr "ERROR: catkin_lib_directory provided: ${catkin_lib_directory} does not exist."
    fi
 
    (
      cd "${catkin_lib_directory}" && \
      ln -s -r -f "${package_library_relative_path}" .
    )

}

link_package_msgs(){
    local package_msg_paths="${1}"
    local catkin_msg_directory="${2:-${CATKIN_MSG_DIRECTORY}}"

    echo "${package_msg_paths}" | \
    while read package_msg_path; do
        if [[ ! -z "${package_msg_path}" ]]; then
            link_package_msg "${package_msg_path}"
        fi
    done
}

link_package_msg(){
    local package_msg_path="${1}"
    local catkin_msg_directory="${2:-${CATKIN_MSG_DIRECTORY}}"
    
    if [[ ! -e "${catkin_msg_directory}" ]]; then
        echoerr "ERROR: catkin_msg_directory provided: ${catkin_msg_directory} does not exist."
    fi

    echo "${package_msg_path}"

    package_msg_absolute_path="$(realpath "${package_msg_path}")"
    package_msg_parent_directory="$(basename "$(dirname "${package_msg_absolute_path}")")"
    mkdir -p "${catkin_msg_directory}/${package_msg_parent_directory}"
    package_msg_relative_path="$(get_relative_path "${catkin_msg_directory}/${package_msg_parent_directory}" "${package_msg_path}")"
    package_msg_parent_directory_relative_path="$(dirname "${package_msg_relative_path}")"
    (
      cd "${catkin_msg_directory}/${package_msg_parent_directory}"
      ln -s -r -f "${package_msg_relative_path}" .
      ln -s -r -f "${package_msg_parent_directory_relative_path}/package.xml" .
    )
}

link_package_cmake_build_context(){
    local package_base_path="${1}"
    local catkin_share_directory="${2:-${CATKIN_SHARE_DIRECTORY}}"
    
    local package=$(basename "${package_base_path}")
    local package_cmake_build_context_directory="${package_base_path}/build/install/share/${package}/cmake"
    local package_share_directory="${catkin_share_directory}/${package}"
    local package_catkin_cmake_directory="${catkin_share_directory}/${package}/cmake"
    local package_cmake_build_context_directory_relative_path="$(get_relative_path "${package_share_directory}" "${package_cmake_build_context_directory}")"

    if [[ ! -d "${package_cmake_build_context_directory}" ]]; then
        echoerr "ERROR: package_cmake_build_context_directory: ${package_cmake_build_context_directory} does not exist. Did you build the package?"
    fi

    (
      cd "${package_share_directory}"
      ln -s -f -r "${package_cmake_build_context_directory_relative_path}" .
    )
}

link_package_build_lib(){
 echo todo
}

link_package_build_include(){
 echo todo
}

print_package_info() {
    local package_base_path="${1}"

    local package=$(basename "${package_base_path}")
    local pwd="$(pwd)"
    local package_absolute_path="$(realpath "${package_base_path}")"
    local package_relative_path="$(get_relative_path "${pwd}" "${package_base_path}")"
    local package_build_path="${package_relative_path}/build"
    local package_library_path="$(find_package_path "${package_build_path}" "lib")"
    local package_include_path="$(find_package_path "${package_build_path}" "include")"
    local package_msg_paths="$(find_package_msg_paths "${package_base_path}")"
    local package_python_msg_path="$(find_package_path "${package_build_path}" "dist-packages")"
    local package_xml_files="$(find_package_xmls "${package_base_path}")"
    local package_libraries="$(find_package_libraries "${package_build_path}")"

    printf "\n  Package Info:\n"
    printf "    %-35s %s \n" "package:" "$(echo_bold ${package})"
    printf "    %-35s %s \n" "current working directory:" "${pwd}"
    printf "    %-35s %s \n" "package absolute path:" "${package_absolute_path}"
    printf "    %-35s %s \n" "package relative path:" "${package_relative_path}"
    printf "    %-35s %s \n" "package build path:" "${package_build_path}"
    printf "    %-35s %s \n" "  package build path exists:" "$(print_path_exists "${package_build_path}")"
    printf "    %-35s %s \n" "package library path:" "${package_library_path}"
    printf "    %-35s %s \n" "  package library path exists:" "$(print_path_exists "${package_library_path}")"
    printf "    %-35s %s \n" "package include path:" "${package_include_path}"
    printf "    %-35s %s \n" "  package include path exists:" "$(print_path_exists "${package_include_path}")"
    printf "    %-35s %s \n" "package python msg path:" "${package_python_msg_path}"
    printf "    %-35s %s \n" "  package python msg path exists:" "$(print_path_exists "${package_python_msg_path}")"
    printf "    %-35s \n" "package msg paths:"
    echo "${package_msg_paths}" | \
    while read package_msg_path; do
        if [[ ! -z "${package_msg_path}" ]]; then
            printf "%-35s     %s\n" "" "$(get_relative_path "${pwd}" "${package_msg_path}")"
        fi
    done
    link_package_msgs "${package_msg_paths}"

    printf "    %-35s \n" "package xml files:"
    echo "${package_xml_files}" | \
    while read package_xml_file; do
        if [[ ! -z "${package_xml_file}" ]]; then
            printf "      %-35s     %s\n" "pack xml file:" "${package_xml_file}"
        fi
    done
    link_package_sources "${package_xml_files}"

    printf "    %-35s \n" "package libraries:"
    echo "${package_libraries}" | \
    while read package_library; do
        if [[ ! -z "${package_library}" ]]; then
            printf "%-35s     %s\n" "" "$(get_relative_path "${pwd}" "${package_library}")"
        fi
    done
    link_package_libraries "${package_libraries}"
 
    link_package_cmake_build_context "${package_base_path}"
}

#find_build_packages "$(pwd)"

#get_package_info "/home/akoerner/repos/csa/github.com-DLR-TS/configurable_submodules/adore/v2x_if_ros_msg/v2x_if_ros_msg/"

{catkin_workspace_init "${SOURCE_DIRECTORY}" "${CATKIN_WORKSPACE_DIRECTORY}" }|| true

print_package_info "/home/akoerner/repos/csa/github.com-DLR-TS/configurable_submodules/adore/adore_if_ros_msg/adore_if_ros_msg/"
#print_package_info "/home/akoerner/repos/csa/github.com-DLR-TS/configurable_submodules/adore/v2x_if_ros_msg/v2x_if_ros_msg/"
#print_package_info "/home/akoerner/repos/csa/github.com-DLR-TS/configurable_submodules/adore/sumo_if_ros/sumo/"
