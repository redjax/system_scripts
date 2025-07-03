# Rotate Domain Certificates

This Powershell script rotates a domain certificate secret value in Azure Front Door.

## Setup

- Log into the Azure CLI with `az login`
- Check the resource group of your Front Door instance, and set your Azure CLI's subscription to the same subscription the resource group is in.
  - You can do this by selecting the subscription during the `az login` command.
  - You can also set the subscription using its name (i.e. `--subscription "subscriptionName"`) or ID (i.e. `--subscription "abc12345-6789-0123-4567-89abcdef0123")`).
    - `az account set --subscription "$SubscriptionNameOrID"`
- Find the value for your domain name with `az afd custom-domain list --resource-group $ResourceGroup --profile-name $FrontDoorName --query "[].name" --output table`
  - If your domain is `www.example.com`, the value will likely be `cd-www-example-com`. Likewise for `example.com` -> `cd-example-com`
- List available secrets with `az afd secret list --resource-group $ResourceGroup --profile-name $FrontDoorName$`

## Usage

After following the [setup instructions](#setup), execute the Front Door domain certificate update commands using one of the methods below.

### Powershell Script

Call the [`Start-UpdateCustomDomainCertificate.ps1` script](./Start-UpdateCustomDomainCertificate.ps1) if you're only updating 1 domain. Otherwise, create a `domains.json` file by copying [the example JSON file](./example.domains.json) to `domains.json`, editing the examples to match the domains and secrets you want to update and use the [`Update-MultipleCertificates.ps1` script](./Update-MultipleCertificates.ps1).

You can check script usage by running `Get-Help .\Start-UpdateCustomDomainCertificate.ps1` or `Get-Help .\Update-MultipleCertificates.ps1`.

### AZ CLI

```shell
az afd custom-domain update \
    --resource-group $ResourceGroup \
    --profile-name $FrontDoorName \
    --custom-domain-name $CustomDomainName \
    --certificate-type CustomerCertificate \
    --secret $CertificateName
```

## Notes

### List domains in a Front Door instance

```shell
az afd custom-domain list --resource-group $ResourceGroup --profile-name $FrontDoorName --query "[].name" --output table
```

This will list the custom domains found on a given `$FrontDoorName`. You will notice the syntax is slightly different; `example.com` becomes `cd-example-com`, and `www.example.com` becomes `cd-example-com` for instance.

When you find the domain you want to work on, copy the value as it appears in this list and use it for the `-CustomDomainName` (Powershell) or `--custom-domain-name` for the AZ CLI command.

### List Front Door secret names

```shell
az afd secret list --resource-group $ResourceGroup --profile-name $FrontDoorName
```

This command will list out JSON tables with the names and values of secrets found in the Front Door instance. You can use the output to determine the name of the secret you want to use, or you can view it in the web UI.
