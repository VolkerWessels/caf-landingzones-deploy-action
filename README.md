# caf-landingzones-deploy-action
Github action for CAF Landingzone deployment
<p align="left">
  <a href="https://github.com/VolkerWessels/caf-landingzones-deploy-action/actions">
    <img alt="Continuous Integration" src="https://github.com/VolkerWessels/caf-landingzones-deploy-action/workflows/Landingzones/badge.svg" /></a>
</p>

The ` VolkerWessels/caf-landingzones-deploy-action` action is a 'composite' action that sets up deployments for CAF landing zones by:

- Downloading a specific version of [Cloud Adoption Framework for Azure landing zones on Terraform](https://github.com/Azure/caf-terraform-landingzones).
- Run it on the [Cloud Adoption Framework for Azure - Landing zones on Terraform - Rover](https://github.com/aztfmod/rover) container.
- Making it a VolkerWessels biased version following our conventions and scheme's
- Logging into azure using ARM_CLIENT_SECRET ARM_CLIENT_ID ARM_TENANT_ID and ARM_SUBSCRIPTION_ID

## Landing zone deployment
A landing zone is a segment of a cloud environment, that has been preprovisioned through code, and is dedicated to the 
support of one or more workloads. Landing zones provide access to foundational tools and controls to establish a 
compliant place to innovate and build new workloads in the cloud, or to migrate existing workloads to the cloud. 
Landing zones use defined sets of cloud services and best practices to set you up for success.

## Usage

This action can be run on `ubuntu-latest` GitHub Actions runners.

Currently this action runs on the rover container so it is critial add the `container` block to the workflow file like so:

```yaml
container:
  image: aztfmod/rover:<< VERSION MATCHING the .devcontainer/docker-compose.yml image >>
  options: --user 0
```
Check for the version to use in the output of the job:
```shell 
#### ROVER IMAGE VERSION REQUIRED FOR LANDINGZONES: aztfmod/rover:1.0.x-xxxx.xxxx ####
```

Use below example to run a single action: 
```yaml
steps:
- uses: actions/checkout@v2
- uses:  VolkerWessels/caf-landingzones-deploy-action@v1
  with:
    action: validate
    config_dir: ${{ github.workspace }}/configuration
    environment: ${{ github.ref == 'refs/heads/main' && 'prd' || 'non-prd' }}
    landingzone: launchpad
    level: 0
    prefix: 'foo-bar'
```



When in need of a more complex setup use a matrix like so:

```yaml
strategy:
  fail-fast: true
  max-parallel: 1
  matrix:
    landingzones:
      - { level: "0", landingzone: "launchpad" }
      - { level: "1", landingzone: "gitops" }
    action: ["validate", "plan", "apply"]
    
steps:
- uses: actions/checkout@v2  
- uses:  VolkerWessels/caf-landingzones-deploy-action@v1
  name: deploy
  with:
    action: ${{ matrix.action }}
    config_dir: ${{ github.workspace }}/.github/workflows/tests/config
    environment: ${{ github.ref == 'refs/heads/main' && 'prd' || 'non-prd' }} ## For azure tags
    level: ${{ matrix.landingzones.level }}
    landingzone: ${{ matrix.landingzones.landingzone }}
    prefix: 'foo-bar'
```

### Full workflow example
```yaml
name: Landingzones

on:
  workflow_dispatch:

env:
  ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
  ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}

jobs:
  launchpad:
    name: Deploy landingzones'
    runs-on: ubuntu-latest
    environment: ${{ github.ref == 'refs/heads/main' && 'prd' || 'non-prd' }} ## For secrets

    container:
      image: aztfmod/rover:1.0.4-2108.1802
      options: --user 0

    strategy:
      fail-fast: true
      max-parallel: 1
      matrix:
        landingzones:
          - { level: "0", landingzone: "launchpad" }
          - { level: "1", landingzone: "gitops" }
        action: ["validate", "plan", "apply"]

    steps:
      - uses: actions/checkout@v2
      - uses: VolkerWessels/caf-landingzones-deploy-action@v1
        name: deploy
        with:
          action: ${{ matrix.action }}
          config_dir: ${{ github.workspace }}/configuration
          environment: ${{ github.ref == 'refs/heads/main' && 'prd' || 'non-prd' }} ## For azure tags
          prefix: opco
          level: ${{ matrix.landingzones.level }}
          landingzone: ${{ matrix.landingzones.landingzone }}
```

## Inputs

The action supports the following inputs:

- `action` - (required) one of the following Terraform actions to execute.
  - `validate`
  - `init`
  - `plan`
  - `apply`
  - `destroy`
  
- `config_dir` - (required) the directory containing the `*.tfvar(.json)` files.
- `environment` - (required) the environment you are deploying to, should preferably matcht the environments for secrets. Use ${{ github.run_id }} for CI purposes.
- `landingzone` - (required) the segment (launchpad, solution or add-on) of a cloud environment to deploy.
- `level` - (required) the landingzone [isolation level](https://github.com/Azure/caf-terraform-landingzones/blob/master/documentation/code_architecture/hierarchy.md)
- `prefix` - (prefix) prefix to prepend as the first characters of the generated name. Use g${{ github.run_id }} for CI purposes.


## Experimental Status

By using the software in this repository (the "Software"), you acknowledge that: (1) the Software is still in development, may change, and has not been released as a commercial product by HashiCorp and is not currently supported in any way by HashiCorp; (2) the Software is provided on an "as-is" basis, and may include bugs, errors, or other issues;  (3) the Software is NOT INTENDED FOR PRODUCTION USE, use of the Software may result in unexpected results, loss of data, or other unexpected results, and HashiCorp disclaims any and all liability resulting from use of the Software; and (4) HashiCorp reserves all rights to make all decisions about the features, functionality and commercial release (or non-release) of the Software, at any time and without any obligation or liability whatsoever.
