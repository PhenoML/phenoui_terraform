#!/bin/bash

unset -v bucket
unset -v project
unset -v module
unset -v _backend_auto_conf
unset -v _backend_auto_tf

# shellcheck disable=SC2206
while getopts b:p:m: flag
do
  case "${flag}" in
    b) bucket=${OPTARG};;
    p) project=${OPTARG};;
    m) module=${OPTARG};;
    *) ;;
  esac
done

echo "Checking if local state exists..."
if [ -f "./terraform.tfstate" ]
then
  echo "Local state exists migrating to remote state"
  echo "---------------------------------"
else
  echo "Local state does not exist, nothing to do"
  echo "---------------------------------"
  exit 0
fi

if [ -z "$bucket" ]
then
  echo "Bucket [-b] is required"
  exit 1
fi

if [ -z "$project" ]
then
  echo "Project [-p] is required"
  exit 1
fi

if [ -z "$module" ]
then
  echo "Module [-m] is required"
  exit 1
fi

echo "Overwriting backend configuration..."
_backend_auto_tf+=("terraform {")
_backend_auto_tf+=("  backend \"gcs\" {}")
_backend_auto_tf+=("}")

_backend_auto_conf+=("bucket  = \"$bucket\"")
_backend_auto_conf+=("prefix  = \"$project/$module\"")

printf "%s\n" "${_backend_auto_tf[@]}" > backend.auto.tf
printf "%s\n" "${_backend_auto_conf[@]}" > backend.auto.conf

echo "Selecting GCP project with gcloud..."
gcloud auth application-default set-quota-project "$project"

echo "Migrating local state to remote state in bucket"
echo "$bucket"
tofu init -backend-config=backend.auto.conf -force-copy
echo "---------------------------------"
