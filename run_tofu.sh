#!/bin/bash

unset -v project
unset -v config_path
unset -v plan
unset -v apply
unset -v module_keys
unset -v key
unset -v local
unset -v get_config

# shellcheck disable=SC2206
while getopts c:m:k:g:pal flag
do
  case "${flag}" in
    c) config_path="${OPTARG}";;
    m) module_keys=($OPTARG);;
    k) key="${OPTARG}";;
    p) plan=true;;
    a) apply=true;;
    l) local=true;;
    g) get_config="${OPTARG}";;
    *) ;;
  esac
done

_run_path=$(pwd)
if [ ! -d "$_run_path/global" ]
then
  echo "This script must be run from the root of the repository"
  exit 1
fi

if [ -z "$config_path" ]
then
  config_path="./config.yaml"
fi

if [ -n "$get_config" ]
then
  yq "... comments=\"\" | .$get_config" < $config_path
  exit 0
fi

function cleanup {
  echo "Cleaning up..."

  if [ -d "$tmp_folder" ]
  then
    echo "Removing temporary folder: $tmp_folder"
    rm -rf "$tmp_folder"
  fi
  echo "---------------------------------"
}

function sigint_handler {
  echo "Caught SIGINT, exiting..."
  exit 1
}

trap cleanup EXIT
trap sigint_handler SIGINT

function load_configuration {
  config=$(yq '... comments=""' < $config_path)

  # load project list
  while read -r object
    do
      # substitute environment variables
      local _project
      _project=$(eval echo "$object")
      projects+=("$_project")
    done < <(echo "$config" | yq '.project | .[]')

  # select one project based on GIT_BRANCH environment variable
  for _project in "${projects[@]}"
  do
    if [ "$_project" == "$GIT_BRANCH" ]
    then
      project="$_project"
      break
    fi
  done

  # load the rest of the configuration
  region=$(echo "$config" | yq '.region')
  bucket=$(echo "$config" | yq '.bucket')
  description=$(echo "$config" | yq '.description')

  # substitute environment variables
  region=$(eval echo "$region")
  bucket=$(eval echo "$bucket")
  description=$(eval echo "$description")

  run_before=$(echo "$config" | yq '.run_before')
  run_after=$(echo "$config" | yq '.run_after')

  # shellcheck disable=SC2128
  if [ -n "$module_keys" ]
  then
    for module_key in "${module_keys[@]}"
    do
      modules+=("$(echo "$config" | yq -o json -I0 ".modules | .[] | select(.path == \"$module_key\")")")
    done
  else
    while read -r object
      do
        modules+=("$object")
      done < <(echo "$config" | yq -o json -I0 '.modules | .[]')
  fi

  while read -r object
    do
      globals+=("$object")
    done < <(echo "$config" | yq '.globals | .[]')

  echo "Configuration loaded:"
  echo "  project: $project"
  echo "  description: $description"
  echo "  region: $region"
  echo "  bucket: $bucket"
  echo "  run_before: $run_before"
  echo "  run_after: $run_after"

  for global in "${globals[@]}"
  do
    echo "  global: $(echo "$global" | yq '"\(.key) => \(.value // .env)"')"
  done

  for module in "${modules[@]}"
  do
    echo "  module:"
    echo "    path: $(echo "$module" | yq '.path')"
    echo "    run_before: $(echo "$module" | yq '.run_before')"
    echo "    run_after: $(echo "$module" | yq '.run_after')"
  done

  echo "---------------------------------"

  if [ "$project" != "$GIT_BRANCH" ]
  then
    echo "Project is not enabled, exiting..."
    echo "---------------------------------"
    exit 0
  fi
}

function do_run {
  local script=${1}
  if [[ "$script" == "null" ]]
  then
    return
  fi

  echo "Running script [$script]..."
  eval "$script" | sed -e 's/^/==> /;'
}

function setup_module_env {
  local module=${1}
  local bucket=${2}

  tmp_folder=$(mktemp -d -p "$(pwd)")
  echo "Created temporary folder for module: $tmp_folder"
  cp -a "$module/." "$tmp_folder/$module"
  cp -a "global/." "$tmp_folder/global"
  cd "$tmp_folder/$module" || exit 1

  local _global_key
  local _global_value
  local _auto_outputs
  local _backend_auto_conf
  local _backend_auto_tf

  # create auto.outputs.tf file
  for global in "${globals[@]}"
  do
    _global_key=$(echo "$global" | yq '.key')
    _global_value=$(echo "$global" | yq '.value')
    # account for environment variables
    _global_value=$(eval echo "$_global_value")
    _auto_outputs+=("output \"$_global_key\" { value = \"$_global_value\" }")
  done
  printf "%s\n" "${_auto_outputs[@]}" > ../global/auto.outputs.tf

  # create backend.auto.conf and backend.auto.tf files
  _backend_auto_tf+=("terraform {")
  if [ -z "$local" ]
  then
    _backend_auto_tf+=("  backend \"gcs\" {}")
    _backend_auto_conf+=("bucket  = \"$bucket\"")
    _backend_auto_conf+=("prefix  = \"$project/$module\"")
  else
    _backend_auto_tf+=("  backend \"local\" {}")
  fi
  _backend_auto_tf+=("}")

  printf "%s\n" "${_backend_auto_tf[@]}" > backend.auto.tf
  printf "%s\n" "${_backend_auto_conf[@]}" > backend.auto.conf
}

function cleanup_module_env {
  echo "Cleaning up module environment..."
  cd "$_run_path" || exit 1
  if [ -d "$tmp_folder" ]
  then
    rm -rf "$tmp_folder"
  fi
}

function run_module {
  local module=${1}

  local _path
  local _run_before
  local _run_after

  _path=$(echo "$module" | yq '.path')
  _run_before=$(echo "$module" | yq '.run_before')
  _run_after=$(echo "$module" | yq '.run_after')

  echo "Running module: $_path"
  setup_module_env "$_path" "$bucket"

  do_run "$_run_before"

  if [ -n "$plan" ] || [ -n "$apply" ]
  then
    if [ -n "$key" ]
    then
      echo "Using provided key..."
      GOOGLE_CREDENTIALS="$key" tofu init -no-color -backend-config=backend.auto.conf
      [ -n "$plan" ] && [ -n "$apply" ] && GOOGLE_CREDENTIALS="$key" tofu plan -no-color -input=false -out=__tfplan__
      [ -n "$plan" ] && [ -z "$apply" ] && GOOGLE_CREDENTIALS="$key" tofu plan -no-color -input=false
      [ -n "$apply" ] && [ -n "$plan" ] && GOOGLE_CREDENTIALS="$key" tofu apply -no-color -auto-approve -input=false __tfplan__
      [ -n "$apply" ] && [ -z "$plan" ] && GOOGLE_CREDENTIALS="$key" tofu apply -no-color -auto-approve -input=false
      unset -v GOOGLE_CREDENTIALS
    else
      echo "Using default credentials..."
      tofu init -no-color -backend-config=backend.auto.conf
      [ -n "$plan" ] && [ -n "$apply" ] && tofu plan -no-color -input=false -out=__tfplan__
      [ -n "$plan" ] && [ -z "$apply" ] && tofu plan -no-color -input=false
      [ -n "$apply" ] && [ -n "$plan" ] && tofu apply -no-color -auto-approve -input=false __tfplan__
      [ -n "$apply" ] && [ -z "$plan" ] && tofu apply -no-color -auto-approve -input=false
    fi
  else
      echo "Nothing to do for module: $_path"
  fi

  # uncomment to keep the temporary folder, good for debugging
  #unset -v tmp_folder

  module="$_path"
  do_run "$_run_after"
  unset -v module

  cleanup_module_env
}

function run_modules {
  for module in "${modules[@]}"
  do
    run_module "$module"
    echo "---------------------------------"
  done
}

echo "---------------------------------"
load_configuration
do_run "$run_before"
run_modules
do_run "$run_after"
