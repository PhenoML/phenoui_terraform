# phenoui_terraform

This repository contains Terraform (OpenTofu) code and scripts to easily stand the infrastructure needed to run PhenoUI.

## Quickstart
To get started, clone the repository, checkout the `phenoui-admin` branch and run the `run-tofu.sh` script with the
following arguments:
```
GCP_ORG_ID="<org_id>" GCP_BILLING_ACCOUNT="<billing_account>" GIT_BRANCH="phenoui-admin" ./run_tofu.sh -l -p -a
```
where `<org_id>` is the organization id where the admin project will be created, `<billing_account>` is the billing
account id to link the project to, and `phenoui-admin` is the branch containing the terraform files.
**NOTE:** You need to be logged into the gcloud CLI and have the necessary permissions to create the resources.

After the admin project is created, create a service account key by running the following command:
```
./create_sa_key.sh -a "<service_account_name>@<admin_project_id>.iam.gserviceaccount.com"
```
where `<service_account_name>` is the name of the service account created in the admin project and `<admin_project_id>`
is the id of the admin project. The default values for those are `phenoui-core-sa` and `phenoui-admin` respectively.
This will create a key file in the `gcp_keys` folder of the repository. 

Finally, configure the GitHub repository with the secrets:
- `GCP_ORG_ID`: The organization id where the admin project was created.
- `GCP_BILLING_ACCOUNT`: The billing account id linked to the admin project.
- `GCP_SA_KEY`: The service account key for the service account that was created in the previous step.

**AT THIS POINT, THE REPOSITORY IS READY TO BE USED TO MANAGE PROJECTS VIA GITHUB ACTIONS**

## Structure
Each PhenoUI project is expected to run in its own GCP folder, in each GCP folder that functions as the root of a
PhenoUI project, there must be an `admin` project that will hold all the state files from other projects and a service
account with enough permissions to manage the resources. Note that only the root GCP folder should have the `admin`
project, the other folders should have the `admin` project as a parent.

This should result in a folder structure as follows:
```
root_gcp_folder
├── admin_project
├── project1-product
├── project1-staging
├── project1-develop
└── child_gcp_folder
    ├── project2-product
    ├── project2-staging
    └── project2-develop
    ...
another_root_gcp_folder
├── another_admin_project
└── another_child_gcp_folder   
    ├── project3-product
    ├── project3-staging
    └── project3-develop
...
```

Generally, it is recommended that each root gcp folder is mapped to a fork of this repository, but it is possible to 
modify the scripts and github actions to allow for a single repository to manage multiple root folders.

## Admin Project
To create the admin project, an account with enough permissions to create the necessary resources is needed (the branch
`phenoui-admin`, under the `core` folder contains all the terraform files describing the resources needed). The easiest
way to get started is to run the `run-tofu.sh` script locally with the following arguments:
```
GCP_ORG_ID="<org_id>" GCP_BILLING_ACCOUNT="<billing_account>" GIT_BRANCH="phenoui-admin" ./run_tofu.sh -l -p -a
```
where `<org_id>` is the organization id where the admin project will be created, `<billing_account>` is the billing
account id to link the project to, and `phenoui-admin` is the branch containing the terraform files. The `-l` flag will
create the statefile locally, the `-p` flag will run `tofu plan` and the `-a` flag will run `tofu apply`.

The default configuration for the admin project runs a script after the project is created to transfer the statefile to
the bucket created within the same project.

## Configuration
By default, projects are configured per-branch, meaning that each branch will have its own project and set of resources.
The configuration can be found in the `config.yaml` file at the root of the repository. Each option is documented in the
configuration file itself. Here are some important considerations:
- `project` is a list of projects for which each configuration applies, this is useful to share a single configuration
between environments.
- `region` and `bucket` must match the region and bucket created in the admin project.
- `modules` is a list of modules that will be process individually by terraform, each module must be contained in a
folder at the root of the repository. Each folder has access to the outputs present in the `global` folder.
- `globals` are variables that will be automatically placed in the `auto.outputs.tf` file in the `global` folder of the
repository. This is useful to share variables between modules.

## CI/CD
The repository is configured to run a GitHub action on each push and pull request to the repository. The action will run
the `run-tofu.sh` script for each configured module in the `config.yaml` file. The script will run `tofu plan` for pull 
requests and output the results as a comment to the PR. For pushes, the script will run `tofu apply`.

The CI/CD pipeline needs a few secrets to run, these are:
- `GCP_ORG_ID`: The organization id where the admin project was created.
- `GCP_BILLING_ACCOUNT`: The billing account linked to the admin project.
- `GCP_SA_KEY`: The service account key for the service account that was created by the admin project.

## Service Account Key
The service account key is a JSON file that contains the credentials needed to authenticate with the GCP API. This file
must be crated after the admin project is created and the service account is created. The key can be created by running
the following command:
```
./create_sa_key.sh -a "<service_account_name>@<admin_project_id>.iam.gserviceaccount.com"
```
where:
- `<service_account_name>` is the name of the service account created in the admin project.
- `<admin_project_id>` is the id of the admin project.

the script will create a key for the service account and save it in the `gcp_keys` folder of the repository. The folder
ignored by default in the `.gitignore` file. DO NOT COMMIT THE KEY TO THE REPOSITORY.

The resulting key can be used as a secret in the GitHub repository to enable the CI/CD pipeline.