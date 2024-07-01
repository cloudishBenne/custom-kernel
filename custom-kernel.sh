#!/usr/bin/env bash


### Global variables

declare CONFIG_FOLDER_PATH="/etc/custom-kernel"
declare CONFIG_PATH="${CONFIG_FOLDER_PATH}/config.ini"


### Helper functions

function show_help() {
    echo "Usage: custom-kernel [OPTION]"
    echo "Manage custom kernels on systems that use kernelstub."
    echo " "
    echo "Options:"
    echo "  -d, --dry-run      Print actions without executing them."
    echo "  -u, --update       Update to the next available custom kernel."
    echo "  -i, --init-config  Initialize the configuration file. Uses the values from kernelstub."
    echo "  -h, --help, help   Display this help message."
    echo " "
    echo "Default behavior (no option provided or with --dry-run only):"
    echo "  Starts an interactive command line dialog to select and set a custom kernel."
}


function require_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
  fi
}

function execute_or_dry_run() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "Dry run: $*"
  else
    "$@"
  fi
}


### Config functions

# uses: CONFIG_FOLDER_PATH, CONFIG_PATH, show_help
function read_config() {
  if [[ ! -d ${CONFIG_FOLDER_PATH} ]]; then
    echo ""
    echo "Config folder not found at '${CONFIG_FOLDER_PATH}'."
    echo "You need to initialize the configuration file first."
    echo ""
    show_help
    exit 1
  elif [[ ! -f ${CONFIG_PATH} ]]; then
    echo ""
    echo "Config file not found at ${CONFIG_PATH}'."
    echo "You need to initialize the configuration file first."
    echo ""
    show_help
    exit 1
  else
    # shellcheck disable=SC1090
    source "${CONFIG_PATH}"
  fi

  if [[ -z ${BOOT_PATH} ]]; then
    echo ""
    echo "Error: BOOT_PATH is not set."
    echo "You need to initialize the configuration file first."
    echo "This will set the BOOT_PATH variable in the config file at '${CONFIG_PATH}'."
    echo ""
    show_help
    exit 1
  elif [[ ! -d ${BOOT_PATH} ]]; then
    echo ""
    echo "Error: The specified BOOT_PATH '${BOOT_PATH}' does not exist on the filesystem."
    echo "Please make sure the output of 'kernelstub --print-config' has the correct BOOT_PATH."
    echo ""
    exit 1
  fi

  if [[ -z ${EFI_PATH} ]]; then
    echo ""
    echo "Error: EFI_PATH is not set."
    echo "You need to initialize the configuration file first."
    echo "This will set the EFI_PATH variable in the config file at '${CONFIG_PATH}'."
    echo ""
    show_help
    exit 1
  elif [[ ! -d ${EFI_PATH} ]]; then
    echo ""
    echo "Error: The specified EFI_PATH '${EFI_PATH}' does not exist on the filesystem."
    echo "Please make sure the output of 'kernelstub --print-config' has the correct ESP_PATH and Root FS UUID."
    exit 1
  fi
}

# uses: CONFIG_FOLDER_PATH, CONFIG_PATH
function init_config() {
  # Fetch the kernelstub configuration
  local kernelstub_output
  kernelstub_output=$(
    kernelstub --print-config 2>&1
  )

  # Parse necessary values
  local boot_path esp_path root_fs_uuid

  boot_path=$(
    echo "${kernelstub_output}" \
      | grep 'Kernel Image Path:' \
      | awk -F':' '{print $2}' \
      | sed 's/^\.*//'
  )
  # Remove the kernel image name and retain the directory path
  boot_path="${boot_path%/*}"
  echo -e "\nBoot Path: ${boot_path}"

  esp_path=$(
    echo "${kernelstub_output}" \
      | grep 'ESP Path:' \
      | awk -F':' '{print $2}' \
      | sed 's/^\.*//'
  )
  echo "ESP Path: ${esp_path}"


  root_fs_uuid=$(
    echo "${kernelstub_output}" \
      | grep 'Root FS UUID:' \
      | awk -F':' '{print $2}' \
      | sed 's/^\.*//'
  )
  echo "Root FS UUID: ${root_fs_uuid}"

  efi_path=$(
    find "${esp_path}/EFI" -type d -name "*${root_fs_uuid}*" -print \
    | head -n 1
  )
  if [[ -n "$efi_path" ]]; then
    echo "EFI folder path found: ${efi_path}"
  else
    echo "EFI folder path not found with the given UUID."
    return 1  # Return failure if not found
  fi

  # Ensure the config folder and file exists or create it
  if [[ ! -d ${CONFIG_FOLDER_PATH} ]]; then
    echo -e "\nCreating config folder at ${CONFIG_FOLDER_PATH}"
    execute_or_dry_run mkdir -p "${CONFIG_FOLDER_PATH}"
  fi
  if [[ ! -f ${CONFIG_PATH} ]]; then
    echo -e "\nCreating config file at${CONFIG_PATH}"
    execute_or_dry_run touch "${CONFIG_PATH}"
  fi

  # Write to config file
  echo -e "\nInitializing config.ini with newest values from kernelstub..."

  config_content="### Configuration settings for custom kernel management

# BOOT_PATH: Specifies the directory where kernel images (vmlinuz) and initial RAM disks (initrd.img) are located.
BOOT_PATH=${boot_path}
  
# EFI_PATH: Specifies the full path to the EFI folder on the EFI System Partition for the local operating system.
EFI_PATH=${efi_path}
"

  execute_or_dry_run bash -c "echo -e \"${config_content}\" > \"${CONFIG_PATH}\""

  echo -e "\nConfiguration file updated successfully."
}


### Kernel management functions

# in: ($1) BOOT_PATH
# out: (echo) available kernels
function get_available_kernels() {
  local boot_path=$1

  # shellcheck disable=SC2231
  for file in ${boot_path}/vmlinuz-*; do
    echo "${file##*/vmlinuz-}"
  done
}

# in: ($1) boot_path
# out: (echo) current custom kernel
function get_current_custom_kernel() {
  local boot_path=$1
  local result
  
  if [[ ! -f "${boot_path}/vmlinuz.custom" ]]; then
    echo "No custom kernel set."
    return 1
  fi

  result=$(
    readlink "${boot_path}/vmlinuz.custom" \
      | cut -d '-' -f 2-
  )

  echo "${result}"
}

# in: ($1) sorted_kernels
# out: (echo) formatting length
function calculate_formatting_length() {
  local sorted_kernels=$1
  local num_kernels num_longest_string additional_chars

  num_kernels=$(
    echo -e "${sorted_kernels}" \
      | wc -l
  )

  num_longest_string=$(
    echo -e "${sorted_kernels}" \
      | awk '{ print length }' \
      | sort -n \
      | tail -1
  )

  additional_chars=$((num_kernels < 10 ? 3 : 4))

  echo $((num_longest_string + additional_chars))
}

# in: ($1) sorted_kernels, ($2) total_length, ($3) current_custom_kernel,
#     ($4) __ret__prompt_for_kernel_selection
# out: (__ret__prompt_for_kernel_selection) selected kernel
function prompt_for_kernel_selection() {
  local sorted_kernels=$1
  local total_length=$2
  local current_custom_kernel=$3
  local -n __ret__prompt_for_kernel_selection=$4
  local current_custom_kernel num_kernels selection

  echo -e "\nYour current custom kernel is: ${current_custom_kernel}"
  echo -e "\nChoose kernel:"
  printf '%*s\n' "${total_length}" '' \
    | tr ' ' '-'
  echo -e "${sorted_kernels}" \
    | awk '{ print NR ": " $0 }'
  printf '%*s\n' "${total_length}" '' \
    | tr ' ' '-'
  
  num_kernels=$(
    echo -e "${sorted_kernels}" \
      | wc -l
  )
  read -r -p "Enter [1-${num_kernels}]: " num

  if [[ -z "$num" ]]; then
    selection=""
  else
    selection=$(
      echo -e "${sorted_kernels}" \
        | sed -n "${num}p;d"
      )
  fi

  __ret__prompt_for_kernel_selection=$selection
}

# in: ($1) available_kernels, ($2) boot_path,
#     ($3) __ret__choose_kernel
# out: (__ret__choose_kernel) selected kernel
# uses: prompt_for_kernel_selection, calculate_formatting_length, get_current_custom_kernel
function choose_kernel() {
  local available_kernels=$1
  local boot_path=$2
  local -n __ret__choose_kernel=$3
  local sorted_kernels total_length

  sorted_kernels=$(
    echo -e "${available_kernels}" \
      | sort -V
  )
  total_length=$(calculate_formatting_length "${sorted_kernels}")
  
  prompt_for_kernel_selection \
      "${sorted_kernels}" "${total_length}" \
      "$(get_current_custom_kernel "${boot_path}")" \
      __ret__choose_kernel
}

# in: ($1) current_custom_kernel
# out: (echo) dynamic regex
function generate_dynamic_regex() {
  local current_custom_kernel=$1
  echo "${current_custom_kernel}" \
    | sed -E 's/[0-9]+/[0-9]+/g'
}

# in: ($1) available_kernels, ($2) regex
# out: (echo) sorted kernels
function filter_and_sort_kernels() {
  local available_kernels=$1
  local regex=$2

  echo -e "${available_kernels}" \
    | grep -E "${regex}" \
    | sort -V
}

# in: ($1) sorted_kernels, ($2) current_custom_kernel
# out: (echo) next kernel
function get_next_kernel() {
  local sorted_kernels=$1
  local current_custom_kernel=$2
  local found_current next_kernel

  found_current=0
  next_kernel=""
  for kernel in ${sorted_kernels}; do
    if [[ "${kernel}" == "${current_custom_kernel}" ]]; then
      found_current=1
      continue
    fi
    if [[ ${found_current} -eq 1 ]]; then
      next_kernel="${kernel}"
      break
    fi
  done

  echo "${next_kernel}"
}

# in: ($1) sorted_kernels, ($2) current_custom_kernel
# out: (__ret__search_next_kernel) next kernel
# uses: generate_dynamic_regex, filter_and_sort_kernels, get_next_kernel
function search_next_kernel() {
  local available_kernels=$1
  local current_custom_kernel=$2
  local -n __ret__search_next_kernel=$3
  local dynamic_regex sorted_kernels next_kern
  
  dynamic_regex=$(generate_dynamic_regex "${current_custom_kernel}")
  sorted_kernels=$(filter_and_sort_kernels "${available_kernels}" "${dynamic_regex}")
  
  next_kern=$(get_next_kernel "${sorted_kernels}" "${current_custom_kernel}")

  __ret__search_next_kernel="$next_kern"
}

# in: ($1) selected_kernel, ($2) boot_path
# uses: execute_or_dry_run
function update_kernel_links() {
  local selected_kernel=$1
  local boot_path=$2

  execute_or_dry_run ln -sf initrd.img-"${selected_kernel}" "${boot_path}/initrd.img.custom"
  execute_or_dry_run ln -sf vmlinuz-"${selected_kernel}" "${boot_path}/vmlinuz.custom"
}


# in: ($1) efi_path, ($2) boot_path
# uses: execute_or_dry_run
function copy_to_efi() {
  local boot_path=$1
  local efi_path=$2

  execute_or_dry_run cp "${boot_path}/initrd.img.custom" "${efi_path}/initrd.img-custom"
  execute_or_dry_run cp "${boot_path}/vmlinuz.custom" "${efi_path}/vmlinuz-custom.efi"
}

# uses: get_available_kernels, choose_kernel, update_kernel_links, copy_to_efi
function set_custom_kernel() {
  local available_kernels selected_kernel retry_choice

  available_kernels=$(get_available_kernels "${BOOT_PATH}")

  while true; do
    choose_kernel "${available_kernels}" "${BOOT_PATH}" selected_kernel
    if [[ -n ${selected_kernel} ]]; then
      break # Valid kernel selected, exit the loop
    else
      echo -e "\nNo kernel selected."
      # TODO: Check if we have to use the "-r" flag for read
      # shellcheck disable=SC2162
      read -p "Do you want to try again? [y|N]: " retry_choice
      if [[ "${retry_choice,,}" != "y" && "${retry_choice,,}" != "yes" ]]; then
        echo -e "\nExiting without selecting a kernel.\n"
        exit 1
      fi
    fi
  done

  update_kernel_links "${selected_kernel}" "${BOOT_PATH}"
  copy_to_efi "${BOOT_PATH}" "${EFI_PATH}"
}

# uses: get_available_kernels, get_current_custom_kernel, search_next_kernel, update_kernel_links, copy_to_efi
function update_to_next_kernel() {
  local available_kernels current_custom_kernel next_kernel

  available_kernels=$(get_available_kernels "${BOOT_PATH}")
  
  if current_custom_kernel=$(get_current_custom_kernel "${BOOT_PATH}"); then
    echo -e "\nCurrent custom kernel: ${current_custom_kernel}"
  else
    echo -e "\nError: No custom kernel set."
    echo -e "Run the script without options to set a custom kernel first.\n"
    show_help
    exit 1
  fi
  
  search_next_kernel "${available_kernels}" "${current_custom_kernel}" next_kernel

  if [[ -n ${next_kernel} ]]; then
    echo -e "\nThe new custom kernel is: ${next_kernel}\n"
  else
    echo -e "\nNo next kernel found for current custom kernel: ${current_custom_kernel}\n"
    exit 0
  fi

  update_kernel_links "${next_kernel}" "${BOOT_PATH}"
  copy_to_efi "${BOOT_PATH}" "${EFI_PATH}"
}


### CLI handling

# Translate long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--dry-run")
      set -- "$@" "-d"
      ;;
    "--update")
      set -- "$@" "-u"
      ;;
    "--init-config")
      set -- "$@" "-i"
      ;;
    "--help")
      set -- "$@" "-h"
      ;;
    "help")
      set -- "$@" "-h"
      ;;
    "--")
      set -- "$@" "--"
      ;;
    *)
      set -- "$@" "$arg"
      ;;
  esac
done

DRY_RUN=0
OPTION_PROVIDED=0

while getopts "udih" opt; do
  case ${opt} in
    d)
      DRY_RUN=1
      ;;
    u)
      OPTION_PROVIDED=1
      require_root
      read_config
      update_to_next_kernel
      ;;
    i)
      OPTION_PROVIDED=1
      require_root
      init_config
      ;;
    h)
      show_help
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))

# Handle default action when no options are provided
if [[ ${OPTION_PROVIDED} -eq 0 ]]; then
  require_root
  read_config
  set_custom_kernel
fi

if [[ ${DRY_RUN} -eq 1 ]]; then
  echo -e "\nThis was a dry run. No changes were made.\n"
else
  echo -e "\nAll operations completed successfully.\n"
fi
