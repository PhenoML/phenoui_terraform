#!/bin/bash

unset -v service_account
unset -v out

# shellcheck disable=SC2206
while getopts a:o: flag
do
  case "${flag}" in
    a) service_account=${OPTARG};;
    o) out=${OPTARG};;
    *) ;;
  esac
done

if [ -z "$service_account" ]
then
  echo "Service account [-a] is required"
  exit 1
fi

if [ -z "$out" ]
then
  out="./gcp_keys/$service_account.json"
fi

echo "Creating service account key"
echo "Service account: $service_account"
gcloud iam service-accounts keys create "$out" --iam-account "$service_account"