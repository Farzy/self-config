# Gemini Code Assistant Context

This file provides context to the Gemini Code Assistant to help it understand the project and provide more accurate and relevant assistance.

## Project Overview

This is a personal infrastructure-as-code (IaC) repository for managing personal servers and development environments. It uses a combination of technologies to automate the setup and configuration of various services.

The primary tools used are:

*   **Ansible:** For configuration management and application deployment.
*   **Terraform:** For provisioning and managing cloud infrastructure.
*   **Docker:** For containerization of applications.
*   **Kubernetes (KinD & MicroK8s):** For container orchestration.

The infrastructure is hosted on:

*   **Google Cloud Platform (GCP)**
*   **Scaleway**

The project is structured to manage different environments, including web servers, Kubernetes clusters, and personal laptops.

## Building and Running

### Python Environment

The project uses Python with dependencies managed by `uv`. The required Python version is specified in the `.python-version` file.

To set up the environment:

1.  Install `uv` if you haven't already.
2.  Install the dependencies:

    ```bash
    uv pip install -r requirements.txt
    ```

### Ansible

The Ansible configuration is in the `ansible/` directory.

*   **Configuration:** `ansible/ansible.cfg`
*   **Inventory:** `ansible/hosts`
*   **Roles:** `ansible/roles/`
*   **Playbooks:** `ansible/playbooks/`

To run a playbook, for example `laptop.yml`:

```bash
ansible-playbook ansible/playbooks/laptop.yml
```

### Terraform

The Terraform configuration is in the `terraform/` directory.

*   **Backend:** Google Cloud Storage (GCS)
*   **Providers:** Google Cloud, Scaleway

To apply the Terraform configuration:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Development Conventions

*   **Python:**
    *   Uses `uv` for dependency management.
    *   The main dependencies are listed in `pyproject.toml`.
*   **Ansible:**
    *   Roles are used to structure the configuration.
    *   The inventory is split into groups for different types of hosts.
    *   Vault is used for managing secrets.
*   **Terraform:**
    *   The configuration is modularized.
    *   A GCS backend is used for storing the state.