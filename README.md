This is my learning experience using Terraform.

I am building a Unix VM in Azure.

Here are the steps I followed to get to where I am.

Go to https://my.visualstudio.com/Benefits?wt.mc_id=o~msft~profile~devprogram_attach&workflowid=devprogram&mkt=en-us and activate the "Azure $50 monthly credit".

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

  - To get a list of vms supported in the location of your choice run this. It takes a long time.
```powershell
az vm list-skus --location uksouth --zone --all --output table
```   

Having built the VM using Terraform it is possible to SSH into it from a GitBash window.
Navigate to this folder in GitBash and run the following command, using the IP address output by Terraform.
```gitbash
ssh -i ./.ssh/id_rsa tuglow@172.167.19.187
```

After connecting to the machine using ssh, run this command to install apache. You'll then be able to use a browser to navigate to http://172.167.19.187/ and see the Apache2 default page.
```
sudo apt install apache2 -y
```
Might also need to run these commands, but I didn't have to first time round.
```
	sudo systemctl start apache2
	sudo systemctl enable apache2
```
The apache html file is found in /var/www/html.

Fun unix commands to try when you're connected via ssh.
 - ls -l    The terraform script will have created a readme file, and set the permissions to read-only.
 - whoami
 - who
 - w
 - pwd
 - uptime
 - hostname
 - uname -a


Ansible debugging guide
https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html


Looks like Ansible has to be run from WSL, if using a Windows machine rather than Unix.
Open up WSL, go to \mnt\d\trisuglow\vm-unix\ansible.

Run this:  ansible-playbook -i 20.68.221.231, -u tuglow apache.yml



Open Ubuntu on the laptop.

################ Maybe this is the wrong route - try using pipx instead #################
You'll need Ansible. Get it by running this. The tuglow password is password.
sudo apt install ansible
#########################################################################################

To make sure you've got the latest Ansible you'll need pip
sudo apt install pipx

Install Ansible using this
pipx install --include-deps ansible

Upgrade Ansible using this
pipx upgrade --include-injected ansible

Make sure the path is set.
pipx ensurepath


Read this

https://docs.ansible.com/ansible-core/2.17/reference_appendices/interpreter_discovery.html



This ran successfully (manually) from the control node.
 ansible-playbook -v -u tuglow -i 172.167.103.97, --private-key ./.ssh/web_id_rsa /home/tuglow/ansible/smoketest.yml