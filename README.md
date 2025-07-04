This is my learning experience using Terraform.

I am building a Unix VM in Azure.

Here are the steps I followed to get to where I am.

  - Install the Azure CLI so I could use it in a Terminal Window (e.g. "az help").
  ```powershell
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
```

  - Installed Terraform locally ("choco install terraform") https://developer.hashicorp.com/terraform/tutorials/azure-get-started/install-cli

  - Follow the instructions here https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build

Use "az login" to login to Azure.
az account show
Use the ID retrieved from this to set the account
az account set --subscription "5845ceb3-0fe6-4930-815e-e552f66914a2"
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/5845ceb3-0fe6-4930-815e-e552f66914a2"

'Contributer' role assigned under scope '/subscriptions/5845ceb3-0fe6-4930-815e-e552f66914a2'
{
  "appId": "11bf6656-d0f6-49b2-95c4-0deecf1ae1a7",
  "displayName": "azure-cli-2025-06-13-15-32-17",
  "password": "HKI8Q~GW2YmnjIiU8~xlKKcEnDZc8DRRpRuZmblj",
  "tenant": "aff8c00b-2c90-48c8-a620-0fc76d9eb136"
}

Run the following in PowerShell rather than storing these secret values in source control.

$Env:ARM_CLIENT_ID = "11bf6656-d0f6-49b2-95c4-0deecf1ae1a7"
$Env:ARM_CLIENT_SECRET = "HKI8Q~GW2YmnjIiU8~xlKKcEnDZc8DRRpRuZmblj"
$Env:ARM_SUBSCRIPTION_ID = "5845ceb3-0fe6-4930-815e-e552f66914a2"
$Env:ARM_TENANT_ID = "aff8c00b-2c90-48c8-a620-0fc76d9eb136"



$Env:ARM_CLIENT_ID = "<APPID_VALUE>"
$Env:ARM_CLIENT_SECRET = "<PASSWORD_VALUE>"
$Env:ARM_SUBSCRIPTION_ID = "<SUBSCRIPTION_ID>"
$Env:ARM_TENANT_ID = "<TENANT_VALUE>"

For "location" use uksouth rather than westus2.
https://datacenters.microsoft.com/globe/explore


Go here to see your new ResourceGroup.
https://portal.azure.com/#browse/resourcegroups

Run "terraform plan" to see what changes are going to be made before running "terraform apply", which will apply them.
"terraform destroy" deletes your infrastructure.

"terraform fmt" will clean up your .tf file.
"terraform validate" will validate your .tf file.


Go to https://portal.azure.com/ to see your VM.

This link gives an example script for a Unix VM. It didn't work straight out of the box - see the following list of changes I made (and then further changes in Git history)

1. Swapped to uksouth.
1. Set user name to tuglow.
1. Changed VM name to TRISTAN_UGLOW
1. Swapped storage_account_type for os_disk from Premium_LRS to Standard_LRS
1. Specify sku="Standard" in order to get a public IP address
1. Because I'm using Standard, I also have to change from Dynamic to Static
1. Standard_DS1_v2 is not available in uksouth. Tried swapping to Standard_B1_v2, which seems to be the smallest available that supports hypervisor v2.

  - To get a list of vms supported in the location of your choice run this.
```powershell
az vm list-skus --resourceType vms --location uksouth --zone --all --output table
```   