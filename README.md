# tfAzureFunctionApp
This repo contains the Terraform main.tf and variable.tf files that creates an Azure Function App with a static public IP. The public IP of an Azure function app can change, to any available public IP within the pool of addresses of that Azure region and Function App service. This can be the result of any number of conditions stipulated by Microsoft. 

To use a static public IP for the function app, you can follow the tutorial guide on Microsoft:

https://docs.microsoft.com/en-us/azure/azure-functions/functions-how-to-use-nat-gateway

The Terraform in this repo creates the similar infrastructure as mentioned in the tutorial.
