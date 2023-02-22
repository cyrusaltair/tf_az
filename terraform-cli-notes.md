# Terraform Associate Glossary

## **Basics**

**Physical/Virtual Component**: a physical component that needs to be configured in detail in the TF script. i.e EC2 instance requires a security group, vCPU power, AMI etc. 
**Logical Resource**: a component that requires less direct configuration in TF script because of abstraction. Think RDS; TF doesn't have to manage the underlying infrastructure. Instead, Terraform communicates with the AWS API to create and manage the database instance, and AWS handles the underlying physical components

**Input Variables**: to avoid hard coding, TF allows for use of variables that allow you to write flexible and reusable configurations. 
- When you run `terraform apply`, you can input values with the `-var` flag and assigning a value to the argument chosen. I.e `terraform apply -var instance_name=ANewName`. 

**Outputs**: TF outputs allow you to query terraform data after it has been applied. 
- To enable this, create a file called `outputs.tf` and populate it with the names, values and descriptions of what you want to query. Note this has to be done *before* tf apply. You can then run `terraform output` to query the data from the applied configuration.

**Remote State**: by adding a cloud block to your main.tf file, TF can store the state file remotely on their cloud. This allows for greater collaboration and enhanced security. 

`terraform init`: this initializes the directory you're working in. TF will create the subdirectory `.terraform`, as well as a lock file `terraform.lock.hcl` 

`terraform plan`: this allows you to preview the actions TF would take to modify your infrastructure without actually changing anything.
- You can also save speculative plans. In an automated TF pipeline, applying a saved plan ensures the changes are the ones expected and scoped by the execution plan. TF apply is more common across non-automated workloads. 
- `destroy` is actually an execution plan to delete all managed resources in a project. 

`terraform apply`: terraform will print out an execution plan detailing what changes it intends to make. If approved, TF will execute. It will also write data into a file called `terraform.tfstate`.
- this state file is how TF will track which ressources it manages, their IDs and metadata so it can CRUD them. State files often contain sensitive info so they must be stored securely with restricted access.
- `terraform state` allows for advanced, manual state management. You can use the the `list` subcommand to identify resources for example. 


`terraform destroy`: this terminatess resources managed by your TF project. It will terminate all the resources specified in TF state but will not destroy other resources not managed by TF. 

`terraform show`: will allow you to inspect the **current** state file, allowing you to spot potential misalignments.  

`terraform fmt`: a handy command that will format your configurations in the current directory for readability and consistency.

`terraform validate`: this will check if your configuration is syntactically valid and internally consistent. 

`terraform console`: opens an interactive console that can be used to evaluate expressions in context of your config. This can be very useful for troubleshooting. Leave with "exit" or ctrl+D

`terraform get`: installs modules referenced

## **Initialization** 

- When you run `terraform init`, the output describes the steps Terraform wants to execute if you approve the configuration.
- Terraform will then initialize the backend and store the state data files according to config (i.e cloud or local)
- Terraform will download any modules referenced in the configuration, either from a remote registry or your local machine. 
- Terraform then downloads the providers defined in the configuration, storing providers and modules in the `.terraform` subdirectory.
- It will also create a lock file named `terraform.lock.hcl` which details exact provider versions, allowing you to control when updates are made to providers. 
  - if there is no prexisting lock file, Terraform will download the providers as specified in `versions.tf` or `required_providers` block. After this, it will stick to lock file info.  
  - if the versions.tf and lock file versions conflict, TF will ask you to reinitialize with the the `-upgrade` flag (i.e *"Could not retrieve the list of available versions for provider hashicorp/random: locked provider registry.terraform.io/hashicorp/random 3.1.0 does not match configured version constraint 3.0.1; must use terraform init -upgrade to allow selection of new versions"*)
  - the lock file records the versions and hashes (checksum) of providers used in this run. This ensures consistent runs in different environments, since TF will download the versions recorded in the lock file as default.
  - hashes are a fixed-size string of characters based on the contents of a file. The checksum is used to compare the contents of a file with the previously stored version. If the contents of the file have changed, Terraform will consider the file to be updated and will trigger a resource update. This helps ensure that Terraform is not making unintended changes to resources in an infrastructure, and that the state of the infrastructure is consistent with the Terraform configuration files.
- `terraform init` only needs to be run the first time the configuration is used, or if the provider version, module version or backend are modified.  
- the `.terraform/modules` directory contains a `modules.json` file and local copies of remote modules. The `.terraform` directory files are supposed to be read only. Don't alter these files. 
- the `.terraform/providers` directory stores cached versions of all the configuration's providers. The providers are saved in directories in this format: [hostname]/[namespace]/[name]/[version]/[os_arch]

## **Planning** 

- To generate a saved plan, use the `-out` flag followed by its name. i.e `terraform plan -out tfplan`
- Plans typically contain sensitive data, so plan files should **never** be commited to be version control. 
- The contents of a saved plan are not in a human readable format, so if you want to review before you apply, you can use `terraform show` with the `-json` flag to convert the contents into JSON. Then, use `jq` to format it and save the output to a new file.

*Here's an example*: `terraform show -json tfplan | jq > tfplan.json`
- `terraform show -json tfplan`: This command generates a JSON representation of the Terraform plan file, "tfplan". The -json flag specifies that the output should be in JSON format.
- `jq`: jq is a CLI JSON processor that is used to filter and manipulate JSON data
- `> tfplan.json`: This command writes the output of the previous commands to a file named `tfplan.json`. The `>` symbol is redirecting the standard terminal output to a file. 

Now that we've exported the plan with JSON, we can use `jq` to review a plan and query it.

*Here's an example*: `jq .terraform_version, .format_version' tfplan.json`
- `jq`: again, we use the jq processor to to filter through the contents of the plan
- `.terraform_version, .format_version`: these arguments specify the fields we want to extract from the JSON file. The fields are specified using a dot notation to access the values of specific keys in the JSON object. The dot notation allows you to access key:value pairs from the JSON doc. 
- `tfplan.json`: this refers to the input file we are searching through. Note the lack of `>` because we're not trying to write to a new file, we just want to review the output in the CLI. 
- This command will return the values of `terraform_version` and `format_version`, with an output that looks like this:
    
        ```
        $ jq '.terraform_version, .format_version' tfplan.json
        "1.1.6"
        "1.0"
        ```

You can review a snapshot of your configuration using the `.configuration` object. The snapshot captures the provider versions recorded in your `.terraform.lock.hcl` file. 

*Here's an example*: `jq '.configuration.provider_config' tfplan.json`
- `jq` and `tfplan.json` have the same function as the example above, we've only changed which part of the data we want to output.
- `.configuration` is a snapshot of the entire plan, so `.configuration.provider_config` will return the `provider_config` section only. 

Some more useful sections from the `.configuration` object include `root_module` (where your providers and backend are defined), `module_calls` lists the details of used modules, their input variables, outputs and resources to create. 

*Final example*: `jq '.configuration.root_module.resources[0].expressions.image.references' tfplan.json`
- This should be quite straightforward. `jq`, `tfplan.json` and `.configuration` are all operating the same way.
- The `.root_module` part accesses the `root_module` field inside the "configuration" field.
- The `.resources[0]` part accesses the first resource object in the `resources` field within the root_module.
- The `.expressions.image.references` part accesses the `references` field within the `image` expression object within the expressions object.
- Thus, the entire command retrieves the `references` field within the `image` expression object of the first resource in the root module of the Terraform plan stored in the tfplan.json file.

### Values

You can also review planned changes to resources and values, and compare them with the existing state file. 

*Here's an example*: `jq '.resource_changes[] | select( .address == "docker_image.nginx")' tfplan.json`
- This command filters the `resource_changes` array to only include elemnts that match the condition `.address == "docker_image.nginx"`. `.address` refers to the unique address of a TF resource, in this case the nginx docker image resource.
- The output will look like the following. Note the `action`, `before` and `after` fields that denote what CRUD action is taken, the resource state before plan is applied and state after the plan is applied. `after_unknown` captures the list of values that will be determined through the operation and sets them to `true`, while `before/after_sensitive` captures a list of any values marked sensitive which TF will redact when you apply your config. 

        ```
        {
        "address": "docker_image.nginx",
        "mode": "managed",
        "type": "docker_image",
        "name": "nginx",
        "provider_name": "registry.terraform.io/kreuzwerker/docker",
        "change": {
            "actions": [
            "no-op"
            ],
            "before": {
            "build": [],
            "force_remove": null,
            "id": "sha256:c316d5a335a5cf324b0dc83b3da82d7608724769f6454f6d9a621f3ec2534a5anginx:latest",
            "image_id": "sha256:c316d5a335a5cf324b0dc83b3da82d7608724769f6454f6d9a621f3ec2534a5a",
            "keep_locally": null,
            "latest": "sha256:c316d5a335a5cf324b0dc83b3da82d7608724769f6454f6d9a621f3ec2534a5a",
            "name": "nginx:latest",
            "output": null,
            "pull_trigger": null,
            "pull_triggers": null,
            "repo_digest": "nginx@sha256:2834dc507516af02784808c5f48b7cbe38b8ed5d0f4837f16e78d00deb7e7767",
            "triggers": null
            },
            "after": {
            "build": [],
            "force_remove": null,
            "id": "sha256:c316d5a335a5cf324b0dc83b3da82d7608724769f6454f6d9a621f3ec2534a5anginx:latest",
            "image_id": "sha256:c316d5a335a5cf324b0dc83b3da82d7608724769f6454f6d9a621f3ec2534a5a",
            "keep_locally": null,
            "latest": "sha256:c316d5a335a5cf324b0dc83b3da82d7608724769f6454f6d9a621f3ec2534a5a",
            "name": "nginx:latest",
            "output": null,
            "pull_trigger": null,
            "pull_triggers": null,
            "repo_digest": "nginx@sha256:2834dc507516af02784808c5f48b7cbe38b8ed5d0f4837f16e78d00deb7e7767",
            "triggers": null
            },
            "after_unknown": {},
            "before_sensitive": {
            "build": []
            },
            "after_sensitive": {
            "build": []
            }
        }
        }
        ``` 

The `planned_values` object provides the same before/after snapshot but for the values of your resources, showing you the planned outcome.

*Here's an example*: `jq '.planned_values.root_module.child_modules' tfplan.json` 

        ```
        [
        {
            "resources": [
            {
                "address": "module.hello.random_pet.number_2",
                "mode": "managed",
                "type": "random_pet",
                "name": "number_2",
                "provider_name": "registry.terraform.io/hashicorp/random",
                "schema_version": 0,
                "values": {
                "keepers": {
                    "hello": "World"
                },
                "length": 2,
                "prefix": null,
                "separator": "-"
                },
                "sensitive_values": {
                "keepers": {}
                }
            },
        #...
            }
            ],
            "address": "module.nginx-pet"
        }
        ]
        ```

To apply a saved plan, simply plug in the name of your plan file with the apply command. I.e `terraform apply tfplan`
- Note: due to its use case in automation, when you apply a saved plan, `terraform apply` will **NOT** prompt you for approval. It will execute the changes immediately. 

To modify configuration values, you can use input variables. This is done through `.tfvars` files.
- `.tfvars` is a Terraform file format that is used to specify values for variables in Terraform configuration. This file allows Terraform users to provide input variables for Terraform configuration in a structured, easy-to-read format. The `.tfvars` file is a key-value pairing format, where each line of the file specifies a variable name and its corresponding value. The values specified in the `.tfvars` file are then used by Terraform when it runs to configure infrastructure according to the Terraform configuration.
- You should **never** commit `.tfvars` files to version control. 

You can review a plan's `prior_state` if you already have a state file applied. The `prior_state` object capptures the state file exactly as it was prior to the plan action. 

This prior state comparison allows TF to account for possible resource changes that have taken place outside of the TF workflow. This is known as `drift`.
- To determine if there has been a resource drift, TF will perform a `refresh` operation before it builds the execution plan, pulling the actual state of all the resources currently tracked in the state file. 
- Between the prior state, the actual state and the execution plan, TF can identify and record resource drift.

*Here's an example*: `jq '.resource_drift' tfplan-input-vars.json`
- Similar to our `.resource_changes` example, note the `action`, `before` and `after` fields that denote what CRUD action is taken, the current resource value and the planned resource value
- Remember this is still only a plan, TF will only implement the changes during the apply step. 

        ```
        {
            "address": "docker_container.nginx",
            "mode": "managed",
            "type": "docker_container",
            "name": "nginx",
            "provider_name": "registry.terraform.io/kreuzwerker/docker",
            "change": {
            "actions": [
                "update"
            ],
            "before": {
                "attach": false,
                "bridge": "",
        #...
                "after": {
                "attach": false,
                "bridge": "",
                "capabilities": [],
                "command": [
                    "nginx",
                    "-g",
                    "daemon off;"
                ],
        ```

## **Applying**

- When you apply this configuration, Terraform will: *(see learn-terraform-apply/main.tf)*
- Lock your project's state, so that no other instances of Terraform will attempt to modify your state or apply changes to your resources. If Terraform detects an existing lock file (.terraform.tfstate.lock.info), it will report an error and exit.
- Create a plan, and wait for you to approve it. Alternatively, you can provide a saved speculative plan created with the terraform plan command, in which case Terraform will not prompt for approval.
- Execute the steps defined in the plan using the providers you installed when you initialized your configuration. Terraform executes steps in parallel when possible, and sequentially when one resource depends on another.
- Update your project's state file with a snapshot of the current state of your resources.
- Unlock the state file.
- Print out a report of the changes it made, as well as any output values defined in your configuration.

- When this configuration is applied, TF begins by creating the random pet name and image resources first. It then created the four containers that depend on them in parallel. 
  - When terraform creates a plan, it analyzes the dependencies between your resources so that it makes changes in the correct order. 

We can send a curl request to the one of the provisioned containers:

*Here's an example*: `curl $(terraform output -json nginx_hosts | jq -r '.[0].host')`:
- `terraform output -json nginx_hosts` retrieves the output of the TF config in JSON, filtering just for `nginx_hosts` output
- The output is then piped `|` to the input of `jq -r '.[0].host'`, with `-r` specifying output should be raw and not enclosed in quotes
- The `.[0].host` expression selects the first item in the JSON array and retrieves the host value of that item
- The output of `jq` processor is passed as an arg to `curl`.
- The inclusion of `$(cmd)` is called substitution, and substitutes the output of the command as the arg to `curl` 

If Terraform encounters an **error** during an apply step, it: 
- Logs the error and reports it to the console
- Updates the state file with any changes to your resource
- Unlocks the state file
- Exits
- Terraform won't roll back a partially completed apply, meaning if something went wrong, **your state file may be invalid**. 
  - To fix, reapply your config after resolving the error

Common Errors include:
- A change to a resource outside of TF's control (think of the docker exmaple where we removed the redis image)
- Networking or other transient errors
- An expected error from the upstream API, such as duplicate resource name or reaching a resource limit
- An unexpected error the from upstream API, like internal server error
- A bug in the Terraform provider code or TF itself

Sometimes, you don't need to reapply the entire configuration at once. TF allows two arguments that enable interaction with specific resources:
`-replace` and `-target`:
- `-replace` flag is useful when a resource becomes unhealthy or stops working in ways that are outside of TF control. In these cases, we may only want to reprovision this resource after fixing it. 
- `-replace` requires a resource address, which you can find with `terraform state list`

For example: `terraform apply -replace "docker_container.nginx[1]"` will destroy and create the second docker container resource.

The `-target` flag in Terraform apply is used to target a specific resource or module for the action to be executed on, whereas the `-replace` flag is used to replace a specific resource with a new one. The `-target` flag is useful when you only want to make changes to a specific resource or module instead of the entire infrastructure. For example, if you only want to update the configuration of a single EC2 instance, you can use the `-target` flag to target that instance.

## Variables!

For notes, see learn-terraform-variables. 

Variable declarations can appear anywhere in config files, but best practice is to place them in `variables.tf`.

To parameterize an argument with an input variable, you must:
- Define the variable
- Replace the hardcoded value with a reference to the variable in your config

Variables have three optional arguments:
- Description: a short description for users
- Type: the type of data contained (String, number, bool etc)
- Default: default value if not input. With no default value, TF will not launch unless you assign a custom value
- Values must be literal values and cannot use computed values like resource attributes. You refer to variables with `var.<var_name>`
- When Terraform interprets values, either hard-coded or from variables, it will convert them into the correct type if possible. So the instance_count variable would also work using a string ("2") instead of a number (2).
- Single value variables are called `simple` by TF. It also supporta `collection` variable types that contain more than one value, like:
  - List: a list of values of the same type
  - Map: a lookup table with key/value pairs, all the same type
  - Set: an unordered collection of unique values, all the same type
  - i.e, if you add a list variable to variables.tf, the type would be specified as `type = list(string)`
  - the `slice()` function extracts some consecutive elements from within a list `slice(list, startIndex, endIndex)` [startIndex is inclusive, endIndex is exclusive]
i.e `slice(var.private_subnet_cidr_blocks, 0, 3)`

- Terraform also supports two structural types. Structural types have a fixed number of values that can be of different types.
  - `Tuple`: A fixed-length sequence of values of specified types.
  - `Object`: A lookup table, matching a fixed set of keys to values of specified types.

- the `console` command opens an interactive console that can be used to evaluate expressions in context of your config. This can be very useful for troubleshooting
  - you can refer to the variable name to return the conents, i.e `var.private_subnet_cidr_blocks` returns "toList([the list of cidr values])". 
  - the same command can be indexed through by adding [0] to the end of the var name
  - Note: The terraform console command loads your Terraform configuration only when it starts. Be sure to exit and restart the console to pick up your most recent changes.
  
*Here's an example:* > `var.resource_tags["environment"]`
"dev"
```
variable "resource_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
  default     = {
    project     = "project-alpha",
    environment = "dev"
  }
}
```

You can also assign variables through the command line: 
- using the `-var` flag, assigning a variable value to the variable name outlined in variables.tf
*Here's an example:* `terraform apply -var ec2_instance_type=t2.micro`

Entering variables values manually can be time consuming and error prone, so they can be specified in a document:
- `terraform.tfvars` files are loaded automatically by TF
- These files use syntax like HCL but can also contain JSON
- The contents of this file will then be checked when running `terraform apply` if not all variables have assigned values
- If there are different values assigned for a variable through these methods, Terraform will use the last value it finds, in order of precedence. *[env vars, terraform.tfvars file, terraform.tfvars.json file, *.auto.tfvars or *auto.tfvars.json files, any -var and -var-file cmd flags]*

**Interpolating Variables in Strings**
- TF supports string interpolating (inserting the output of an expression into a string)

**Validate variables**
- validation blocks can be used to enforce character limits and character sets on project and environment values in `variables.tf`. 
  - Using variable validation can be a good way to catch configuration errors early.
```
validation {
    condition = length(var.resource_tags["environment"]) <= 8 & length(regexall("[^a-zA-Z0-9-]", var.resource_tags["environment"])) == 0
    error_message = "The environment tag must be no more than 8 characters, and only contain letters, numbers and hyphens.
}
```
- the `regexall()` function takes a regular expression and a string to test it against, returning a list of matches found in the string. In this case, the regex will match a string that contains anything other than a letter, number or hyphen

## Output Data

- Output values let you export structured data about your resources. You can use this data to configure other parts of your infrastructure with automation tools, or as a data source for another TF workspace. 
- `outputs.tf` is the file where you add output declarations. Outputs have a name, description and value
  - while the 'description' argument is optional, it should be included in all output declarations for documentation and readability
- You can use the result of any TF expression as the value of an output. 

```
output "lb_url" {
  description = "URL of load balancer"
  value       = "http://${module.elb_http.elb_dns_name}/"
}

output "web_server_count" {
  description = "Number of web servers provisioned"
  value       = length(module.ec2_instances.instance_ids)
}
```
- The `lb_url` output uses string interpolation to creaete a URL from the load balancer's domain name. The `web_server_count` output uses the length function to calculate the number of instances attached the ln
- TF stores output values in the config's state file. To see these outputs, you need to update the state by applying this new config, even though the infrastructure wont change.
- After outputs are applied, they can be queried with `terraform output` and `terraform output lb_url` for example 
  - Adding the `-raw` flag will get rid of the quotation marks usually added to the output, meaning you can use it for automation
*Here's an example*: `curl $(terraform output -raw lb_url)`, which returns:
```
<html><body><div>Hello, world!</div></body></html>
```
- For this, we used curl to verify the response of the load balancer.
- You can also redact sensitive outputs, TF will then avoid printing them out to the console
- Use sensitive outputs to share sensitive data from your configuration with other Terraform modules and automation tools
- Terraform will not redact sensitive outputs in cases where specific outputs are queried by name, in JSON format or when child module outputs are used in the root module. 
- TF also stores all output values (regardless of sensitivity) as plain text in your state file
In the case of the following: 
```
output "db_username" {
  description = "Database administrator username"
  value       = aws_db_instance.database.username
  sensitive   = true
}

output "db_password" {
  description = "Database administrator password"
  value       = aws_db_instance.database.password
  sensitive   = true
}
```
- `terraform output db_password` will return "notasecurepassword"

*Here's an example*: `grep --after-context=10 outputs terraform.tfstate`
- `grep` is used to search text or search for a specific pattern of text, and can be used to see the values of the sensitive outputs in your state file. 
- `--after-context=10` option is telling `grep` to display the 10 lines of code that follow the text match.
- `outputs` is the pattern being searched for, and `terraform.tfstate` is the file being search. The output will then be:
```
  "outputs": { #do not include this line in '10 lines' count
      "value": "notasecurepassword",
      "type": "string",
      "sensitive": true
    },
    "db_username": {
      "value": "admin",
      "type": "string",
      "sensitive": true
    },
```

Generating machine-readable output:
- the `-JSON` flag will return json formatted output
- i.e `terraform output -json` will return a key/value pairing for each output block and it's defined arguments
- `-json` output isn't redacted as it's inteded for automated machine use

## Manage Terraform Versions

- The terraform CLI, developed by hashicorp and open source contributors, gives you the opportunity to upgrade to the latest version for new features.
- Use `required_version` setting to control when your TF version will upgrade
- Use `terraform version` to check your version and the version of any providers in your config
- The version format is as follows: `major.minor.patch` The minor and patch versions are backward compatible with configs written for previous versions. 
- Version updates can have consequences for your provider versioning, may refresh your state file version or require configuration file edits to implement new features. 
- We can use grep to inspect the state file version format
*Here's an example*: `grep -e '"version"' -e '"terraform_version"' terraform.tfstate`
- the `-e` flag allows you to specify multiple search patterns in grep
- Note that once you use a newer version of Terraform's state file format on a given project, there is no supported way to revert to using an older state file version.
- The `~>` style version constraint can be used to pin your major and minor Terraform version. Doing so will allow you and your team to use patch version updates without updating your Terraform configuration:
  - For example, if you write Terraform configuration using Terraform 1.0.0, you would add required_version = "~> 1.0.0" to your terraform { } block. This will allow you and your team to use any Terraform 1.0.x, but you will need to update your configuration to use Terraform 1.1.0 or later.

## Lock and Upgrade Provider Versions

- Providers manage resources by communicating between Terraform and target APIs. Whenever target APIs change, provider maintainers may update the version and provider
- When multiple users or tools run configs, they should all use the same versions of their required providers


## Target Resources

- TF lets you target specific resources when you plan/apply/destroy infrastructure. Targeting individual resources could be useful for correcting an out-of-sync state or troubleshooting, but doesn't make up part of a typical workflow. 
- TF#s `-target` option to target specific resources, modules or collectios of resources.
*Here's an example*: `terraform plan -target="random_pet.bucket_name"`


## Manage Resources in Terraform State

- TF stores info in the state file, which keeps track of resources created by your configuration, mapping them to real-world resources
- In the state file, the mode is as follows: `data` refers to a data source, `managed` refers to resources. `Type` is the resource type.
- Under `instances` are the attributes of the resource, i.e sec group
- `terraform state list` will get the list of resource names and local identifiers in the state file
- `terraform apply -replace="aws_instance.example"` to replace specific resources
- `terraform state mv` moves resources from one state file to another, but NOT in your config. Just the state file will change. 
*Here's an example*: `terraform state mv -state-out=../terraform.tfstate aws_instance.example_new aws_instance.example_new`
- note, resource names must be unique to the inteded state file
- `terraform state rm` removes specific resources from your state file. Removing the security group from state did not remove the output value with its ID, so you can use it for the import.
*Here's an example:* `terraform state rm aws_security_group.sg_8080`
- `terraform import` will re-add any missing resources from the state file without a new apply. Note, if you had a resource missing and reapplied instead of importing, TF would make the new resource, and the old one will just sit on your account until you remove it
- `terraform refresh` updates the state file when physical resources change outside the terraform workflow. 
  - It does **NOT** update your configuration, just the state file. 

## Import Configuration

- Terraform allows you to bring your existing infrastructure into TF. Terraform uses the data in your state file to determine the changes it needs to make to your infrastructure.
- Import takes 5 steps@
  - Identify the resources you will import
  - Import infrastructure into your TF state file
  - Write the config that will match your update infrastructure
  - Review plan to ensure config matches expected result
  - Apply config
- If you can apply with the exact attributes needed for your resource, you can run the import and then update the resource to match the state file
- If the requirements aren't exact, TF will need to destroy and recreate your resource.

## Refresh only

- TF can refresh stsate files to update TF's knowledge of your infrastructure, as represented in the state file, with your actual state. 
- TF `plan` and `apply` operations run an implicit in-memory fresh as part of their functionality, reconciling any drift before suggesting infrastructure changes.
- You can also update your state file without making modifications to your infrastructure using the `-refresh-only` flag for `plan` and `apply` operations, which is safer than `terraform refresh` which will overwrite existing state file


## Troubleshooting Terraform

There are four potential types of issues in terraform:
- `Language errors`: the primary interface is HCL. The core application of TF interprets the language. If it picks up a syntax error, it will tell you which line it was found on and the error value
- `State errors`: if the TF state file is out of sync, TF may destroy or change existing resources. If your config looks fine but things aren't working as expected, review your state file. Ensuring it is in sync by `import`, `refresh` or `replace`. 
- Core errors: the TF core application contains all the logic for operations. It's what interprets your config, manages state file, constructs the dependancy graph and communicates with provider plugins. Errors at this level could be a bug.
- Provider errors: The provider plugins handle authentication, API calls and mapping resources to services. 

## TF Console
- The console allows you to evaluate TF expressions and explore project state
- It helps debug and develop your config, especially when complex state data and expressions are involved
- The interpreter does not modify state, config files or resources. It's a safe way to inspect your project's

- We can create  output values to describe resources. In this case a bucket:
    - We'll use a command to create a JSON structure that matches the format required to map info about a bucket
*Here's an example:* `jsonencode({ arn = aws_s3_bucket.data.arn, id = aws_s3_bucket.data.id, region = aws_s3_bucket.data.region })`
- As you can see, the `jsonencode` func in TF is used to encode a map data structure as a JSON string
- As it's returning a string, the JSON func escaped the " characters with the \ prefix

- Bucket policies are defined as JSON, and we can use HCL to dynamically generate JSON string policy, utilising HCL benefits like syntax checking and string interpolation
*Here's an example*: `echo 'jsondecode(file("bucket_policy.json"))' | terraform console`
- The `file()` function loads the file's content into a string, and `jsondecode()` converts the string from JSON to an HCL map.
- `| terraform console` pipes the output from the previous command into the terraform console, which then evaluates the expression parsed in
- The resulting output will be a data structure like a map or list representing the data in he JSON file. 

## Verify Terraform Binary Archives

Hackers can gain access to your critical systems by tricking you into running an executable that includes malicious code. You can avoid this by verifying that HashiCorp created and signed the Terraform executable before you run it.

