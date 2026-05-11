# Azure Survey

Uses the `az` CLI to read information about the connected Azure environment/tenant. Useful for getting a "lay of the land."

## Purpose

These scripts provide a quick Azure environment survey from the terminal so you can find core resources without digging through the portal.

Use them when you want a fast overview of:

- Account and subscription context
- Resource groups and resources
- Common service areas (AKS, VMs, storage, SQL, Key Vault, and more)

## Usage

### Run a broad survey

Use the orchestrator script:

```bash
./survey-azure-environment.sh
```

Common variants:

```bash
./survey-azure-environment.sh -q
./survey-azure-environment.sh -c groups,resources
./survey-azure-environment.sh -s my-subscription-id
```

### Run one survey area by name

Use the single-section runner:

```bash
./run-section.sh groups
./run-section.sh account
./run-section.sh vms
```

### Run a one-off section shortcut

Use direct section scripts when you already know what you want:

```bash
./sections/groups.sh
./sections/storage.sh
./sections/roles.sh
```

## Get Full Option Details

Each launcher supports built-in help:

```bash
./survey-azure-environment.sh -h
./run-section.sh -h
./sections/groups.sh -h
```

Use these help menus for full argument details and additional flags.
