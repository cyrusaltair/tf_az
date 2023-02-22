# HCL Breakdowns
### Refer to appropriate sub-directory on AWS instance for complete code examples

## Resources

- Terraform uses `resource` blocks to manage infrastructure.
- `resource` blocks represent one more more infrastructure objects in your TF config, like virtual networks, compute instances or higher level components like DNS. 
- TF resources map to API providers that allow TF to manage that infrastructure type

- The learn-terraform-resources directory has five files:
`init-script.sh` contains the provisioning script to install dependencies and start a sample PHP application
```
  #!/bin/bash
yum update -y
yum -y remove httpd
yum -y remove httpd-tools
yum install -y httpd24 php72 mysql57-server php72-mysqlnd
service httpd start
chkconfig httpd on

usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
cd /var/www/html
curl http://169.254.169.254/latest/meta-data/instance-id -o index.html
curl https://raw.githubusercontent.com/hashicorp/learn-terramino/master/index.php -O
```

`terraform.tf` contains the terraform block that defines the providers required by your config
```
    terraform {

  /* Uncomment this block to use Terraform Cloud for this tutorial
  cloud {
      organization = "organization-name"
      workspaces {
        name = "learn-terraform-*"
      }
  }
  */

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.15.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  required_version = "~> 1.2.0"
}
```

`main.tf` contains the configuration for an EC2 instance
```
    provider "aws" {
  region = "us-west-2"
}

provider "random" {}

resource "random_pet" "name" {}

resource "aws_instance" "web" {
  ami           = "ami-a0cfeed8"
  instance_type = "t2.micro"
  user_data     = file("init-script.sh")

  tags = {
    Name = random_pet.name.id
  }
}
```

`outputs.tf` contains the definitions for output values
```
    output "domain-name" {
  value = aws_instance.web.public_dns
}

output "application-url" {
  value = "${aws_instance.web.public_dns}/index.php"
}
```
`README.md` describes the repo and its contents

Let's break down a resource: `random_pet` in `main.tf`
```
resource "random_pet" "name" {}
```

Resource blocks declare a `resource type` and `name`. Together, the type and name form a `resource identifier (ID)` in the format of `resource_type.resource_name`.

So in this case, the RID of random_pet is `random_pet.name`. RIDs must always be unique within workspaces; if TF displays info related to this RID, it will use the RID in its output.

`Resource types` always start with the provider name and an underscore, followed by the type.
So `random_pet` means `random` is the provider, `pet` is the type.

`Resources` have `arguments`, `attributes` and `meta-arguments`:

`Arguments` configure a particular resource. As a result, many args are resource-specific. Some are **required** while others are *optional*, as specified by the provider. If a required arg isn't supplied, TF will return an error and not apply a config.

`Attributes` are values exposed by an existing resource. While `arguments` specify a resource's configuration, `attributes` are often assigned to resources by the underlying cloud provider or API.

`Meta-arguments` change a resource's behaviour and are a function of TF itself. `Count` is an example meta-argument that can be used to create multiple resources. 

Let's use the `aws_instance` resource from `main.tf` for an example:
```
resource "aws_instance" "web" {
  ami           = "ami-a0cfeed8"
  instance_type = "t2.micro"
  user_data     = file("init-script.sh")

  tags = {
    Name = random_pet.name.id
  }
}
```

`Resource`: "aws"
`resource_type`: "instance"
`resource_name`: "web" 
`arguments:` "ami", "instance_type", "user_data", "tags" [only a subset of total aws_instance args. see docs for full list]

Note how the tags argument assigns `random_pet.name`'s ID attribute to name the EC2 instance, this makes the `random_pet.name` resource an `implicit dependency` for the `aws_instance.web` resource. 

## Provider Plugins
### CRUD and APIs

`Terraform core` reads the configuration and builds the resource dependency graphs
`Terraform Plugins` bridge Terraform Core and their respective target APIs. Plugins implement resources via `CRUD` APIs.

When `plan` or `apply` are run, the TF Core will send an action request via RPC (*remote procedural call*) interface. The RPC request will prompt the `Provider` to run a CRUD operation on the target's API library. While TF is focused on cloud infrastructure, this model means Providers can serve as an interface to any API, meaning TF Core might be able to manage any resource. 
*Here's an example*: 
```
TFCore:"Create NGINX Container" >>> DockerPlugin:"Create container [options, image, commands]" >>> Docker API >>> "docker create -dp nginx 80:80 --name nginx"
```

#### HashiCups

Hashicups is a demo app that can show how the API system works with terraform. 

- docker-compose up will launch the application and feed back the log messages from the application
- create a login with an auth token
- run init && apply from a different terminal, watch the API feedback:
  - The provider invoked 4 total operations:
    - First, the signin operation when terraform apply was run to retrieve current state of resources. As main.tf was empty, it just ran authentication for user
    - The provider invoked a second signin after confirming the apply run. Provider authenticated using provided credentials and JWT token for auth
    - The provider invoked CreateOrder to create the order added to main.tf. This is a protected CRUD endpoint, so provider authenticated with JWT
    - The provider invoked getUserOrder to retrieve order detail. This is also protected so provider auth with JWT. 
After updating:
  - The provider runs 5 total operations:
    - First signin operation with terraform apply to determine current state
    - Provider invoked getUserOrder to reconcile any potential differences in state stored by TF
    - Provider invoked second SignIn operation after apply is run and state updated
    - Provider invoked updateOrder operation to update the order to the newly defined config. Again uses JWT auth from signin
    - Provider invoked getUserOrder to retrieve order detail. This is also protected so provider auth with JWT. 


## Variables

- TF variables dont change during a plan, apply or destroy run.
- They're made for users to safely customise their infrastructure by assigning different values to the variables before execution begins

- To parameterize an argument with an input var, first define the var and replace the hardcoded value with a reference to that variable
- Vars have three option arguments: Description for users, type of data contained, default value 
*Here's an example*:
```
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}
```
- If you do not set a default, you must assign a value before apply. TF does not support unassigned vars
- Variable values must be literal values. Computed values like resource attributes, expressions or other variables cannot be used.
- For ref, it's `var.<variable-name>`
- When TF interprets values, it will convert them into the correct data type if possible. I.e "2" can be interpreted as 2.

**Variable Types**:
- Bool: for true/false values

### Simple vs Collection vs Structural
**SIMPLE:**
- Single value variables are called `simple` in terraform

**COLLECTION**
- TF supports `collection` variables that contain more than one of the same value, including:
  - `List`: a sequence of values of the same type
  - `Map`: a Lookup table, matching keys to values, all same type
  - `Set`: unordered collection of unique values, all same type
*Here's an example*: - We can use lists for subnet IPs
```
variable "public_subnet_cidr_blocks" {
  description = "Available cidr blocks for public subnets."
  type        = list(string)
  default     = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24",
    "10.0.5.0/24",
    "10.0.6.0/24",
    "10.0.7.0/24",
    "10.0.8.0/24",
  ]
}
```

*Here's an example:* of sorting maps through terraform console: To sort through maps, run `terraform console`, `var.resource_tags["environment"]`

**STRUCTURAL**
- TF supports `structural` variables that have a fixed number of values that can be of different types:
  - `tuple`: a fixed-length sequence of values of specified types
  - `object`: a lookup table, matching a fixed set of keys to values of specific types


### Assign values to variables
- TF requires a value for every variable, there are several ways to assign them:
  - **CLI flag:** using `-var <variable_name>=<value>`
  - **Assign values with file** from `terraform.tfvars`: TF automatically loads all files in current dir with the name `terraform.tfvars` or matching `*.auto.tfvars`. The `-var-file` flag is used to specify other files by name
  - **Interpolate Vars in Strings**: you can insert the output of an expression into a string. This means you can use vars, local values and function outputs to create strings in your config.
  - i.e `"web-sg-${var.resource_tags["project"]}-${var.resource_tags["environment"]}"`
      - `web-sg-` is a static string value that is included in the final output
      - `${var.resource_tags["project"]}` is the dynamic value that will be inserted through string interpolation. It references the `key` of '`project`' from the `resource_tags` var from `variables.tf`, interpolating the value of the specified key.
      - `-` is another static string included in the final output
      - the dynamic value is repeated, but this time looking for the value of the `environment` key.


### Validate Variables

Some configurations have restrictions you need to adhere to, like load balancers. LB names cannot be longer than 32chars, and a limited set of them. We'll use `variable validation` to *restrict the possible values for our tags*. 

We'll update the existing resource tags variable with the following `validation blocks` to enforce char limits and sets:
```
  validation {
    condition     = length(var.resource_tags["project"]) <= 16 && length(regexall("[^a-zA-Z0-9-]", var.resource_tags["project"])) == 0
    error_message = "The project tag must be no more than 16 characters, and only contain letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.resource_tags["environment"]) <= 8 && length(regexall("[^a-zA-Z0-9-]", var.resource_tags["environment"])) == 0
    error_message = "The environment tag must be no more than 8 characters, and only contain letters, numbers, and hyphens."
  }
```
- the `regexall()` function takes a regular expression and a string to test it against, returning a list of matches found in the string. In this case, the regex will match a string that contains anything *other* than a letter, number or hyphen. 
- Test the validation with `terraform apply -var='resource_tags={project="my-project",environment="development"}'`, this is the error thrown:
```
│ Error: Invalid value for variable
│
│   on variables.tf line 68:
│   68: variable "resource_tags" {
│     ├────────────────
│     │ var.resource_tags["environment"] is "development"
│
│ The environment tag must be no more than 8 characters, and only contain letters, numbers, and hyphens.
│
│ This was checked by the validation rule at variables.tf:81,3-13.
```

## Protect Sensitive Variables

When you need to use sensitive or secret information to configure your infrastructure, you need to ensure that none of it is accidentally exposed in CLI, log or source control output. We'll replace hard-coded credentials in the DB with vars configured with the `sensitive` flag. TF wil then redact these values in outputs. 
Then we'll set values for these variables using environment variables and with a .tfvars file and how to protect state file. 

#### Refactoring DB Credentials
```
resource "aws_db_instance" "database" {
  allocated_storage = 5
  engine            = "mysql"
  instance_class    = "db.t2.micro"
  username          = "admin"
  password          = "notasecurepassword"

  db_subnet_group_name = aws_db_subnet_group.private.name

  skip_final_snapshot = true
}
```
- To hide the sensitive data, we can make `db_username` and `db_password` vars, setting the `sensitive = true`:
```
variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}
* note that there is no default value,  so TF will prompt asking for the input. To save time doing this manually, we can:
```

**Set values with the `.tfvars`** file:
``` 
**secret.tfvars**
db_username = "admin"
db_password = "insecurepassword"
```
To apply these in CLI, run: `terraform apply -var-file="secret.tfvars"`
- Terraform will now redact the info marked with `(sensitive)` instead of the value
- Notice that the password is marked `sensitive value` though. This is because AWS provider considers the password argument for any database instance as sensitive, whether or not you declare the variable as sensitive, and will redact it as a sensitive value. 
- You should still declare this variable as sensitive to make sure it's redacted if you reference it in other locations than the specific password argument.
- Using a `.tfvars` file ensures separation of secret information, but it also requires more careful file management. Ensure only those authorised can access the file, and **make sure it is not submitted to version control**.
  
#### Setting Values with Variables

When Terraform runs, it looks in your environment for variables that match the pattern `TF_VAR_<VARIABLE_NAME>`, and assigns those values to the corresponding Terraform variables in your configuration.
*Here's an example*: `export TF_VAR_db_username=admin TF_VAR_db_password=adifferentpassword`
- keep in mind env vars will be stored in the environment and cli history

#### Referencing Sensitive Variables

- When referencing sensitive variables in `outputs.tf`, the outputs have to be marked `sensitive=true` or an error will be thrown 

#### Sensitive Values in State
- Local state files store the state as plain text, including sensitive data
- TF needs these values in the state to ensure sync with your infrastructure


## Simplify TF Config with Locals

Local values assign a name to an expression or value. Using locals simplifies configuration since one local can be referenced multiple times. This reduces duplication, and also helps write more readable configuration using meaningful names rather than hard-coding values.
- `locals` do not change values during or between TF runs. Unlike input vars, locals are not set directly by users of the config.
*Here's an example:* Let's take `"web-sg-${var.resource_tags["project"]}-${var.resource_tags["environment"]}"` and assign it to a local:
```
locals {
  name_suffix = "${var.resource_tags["project"]}-${var.resource_tags["environment"]}"
}
```
- We can now replace the `"${var.resource_tags["project"]}-${var.resource_tags["environment"]}"` with `${local.name_suffix}`
  
#### Combine variables with local values
- Local values can use dynamic expressions and resource args, unlike variable values.
- Using variables and locals in tandem allows you to manage resource tags to easily track them.
- For example, include at least the project name and environment for each resource

## Output Data TF

TF output calues let you export structured data about your resources. This can then be used to configure other TF parts or as a data source for another TF workspace.
- Outputs are also how you expose child module data to a root module. 
- Keep outputs in `outputs.tf`. While they can be written anywhere, it's easier to review in a separate file. 
- You can use the result of any Terraform expression as the value of an output.
*Here's an example:* Value for output "lb_url" `value = "http://${module.elb_http.elb_dns_name}/"`
- the `lb_url` output uses string interpolation to create a URL from the load balancer's domain name.

*Here's an example:* Value for output "web-server-count" `value = length(module.ec2_instances.instance_ids)`
- the `web-server-count` output uses the `length()` function to calculate the number of instances attached to the elb. 
  
- TF stores output values in the config's state file. 

#### Query outputs
- `terraform output` will return all outputs registered
- `terraform output <output_name>` will query an individual output
- adding `-raw` flag before the output name will return the output without wrapping it in "" (TF wraps output in quotations by default)

#### Redacting Outputs
- Designating outputs as sensitive will cause TF to redact the values, avoiding accidentally printing them to console
- It will only redact outputs from plan, apply and destroy actions. 
- It will **NOT** redact sensitive outputs from specific name queries or queries that convert to JSON
- All outputs, regardless of sensitivity, are stored as plain text in the state file
- The `sensitive` arg will help avoid inadvertent exposure, but security is still important

#### Machine Readable Output
- The TF CLI is designed to be parsed by humans
- use the `-json` flag for formatted output that can be used in automation
- i.e `terraform output -json`

## Query Data Sources

- TF data sources allow you to dynamically fetch data from APIs and TF state backends. 
- Examples of data sources include AMIs and TF outputs from other configs.
- Data sources make your config more flexible, widens scope and reference values from other configs or workspaces.
- You can reference data source attributes with the pattern `data.<NAME>.<ATTRIBUTE>`. I.e `data.aws_availability_zones.available.names`

## Create Resource Dependencies

TF infers dependencies between resources and modules, but there's also a `depends_on` argument that can create an explicit dependency.
- The most common source of dependencies is implicit between two resources or modules
- In logs after applying, you can follow how the resources are being created to see the dependency order. I.e if defining an Elastic IP block for an instance, the instance will be created first. 
- TF will create a dependency graph to figure out which order to create resources
- the `depends_on` argument is accepted by any source or module block, and accepts a `list` of resources to create explicit dependencies
- The order in which resources in main.tf are declared has no effect on the order of creation/destroy. 


## Count

`count` is an optional argument that can be used in a Terraform resource block to create multiple instances of a resource. It takes an integer value as an argument and creates that many instances of the resource, each with a unique index number.
- The `count` argument replicates the given resource or module a specified number of times. It works best with identitical or very similar resources. 

In learn-tf-data-sources, the configuration has limitations. Each private subnet has 1 hard-coded EC2 instances, meaning even if the `private_subnets_per_vpc` var is increased, TF won't add any instances
With count, this config will become more robust:
- i.e `count = var.instances_per_subnet * length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)`
- more info: https://developer.hashicorp.com/terraform/tutorials/configuration-language/data-sources
-  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]

## For Each

`for_each` is a meta argument that allows you to configure similar resources by iterating over a data structure, configuring resources for each item in the structure
   - use `for_each` to customsise similar resources that share the same lifecycle
   - `for_each` supports `maps`, `lists` and `sets` collections
   - It takes a map or a set of strings as an argument, and creates an instance of the resource for each key or value in the map or set. Each instance is assigned a unique name based on the corresponding key or value.
   - You cannot use `count` and `for_each` in the same block
   - When you use for_each with a list or set, `each.key` is the index of the item in the collection, and `each.value` is the value of the item.
   - You can differentiate between instances of resources and modules configured with for_each by using the keys of the map you use. In this example, using module.vpc[each.key].vpc_id to define the VPC means that the security group for a given project will be assigned to the corresponding VPC.
   -  it is not possible to reference individual instances of a resource created with count. This can make it difficult to manage resources that need to be created with unique settings, such as when you need to create multiple subnets with different CIDR blocks.
```
variable "servers" {
  type = map
  default = {
    "web-server" = "ami-0c55b159cbfafe1f0"
    "db-server"  = "ami-0c55b159cbfafe1f0"
  }
}

resource "aws_instance" "example" {
  for_each      = var.servers
  ami           = each.value
  instance_type = "t2.micro"
}
```
- In this example, two instances of an AWS EC2 instance are created, each with a unique name based on the corresponding key in the servers map variable. 
- The for_each argument is set to var.servers, which is a map with two key-value pairs. Terraform will create one instance with an AMI of ami-0c55b159cbfafe1f0 and an instance type of t2.micro for each key in the servers map.
- Additionally, when you use for_each, the name of the resource is determined by the key or value in the map or set. If you need to reference an instance of the resource by a specific name, you will need to use a separate data source to look up the name of the instance based on the key or value in the map or set.

## Functions and Dynamics Ops

Terraform allows you to write declarative expressions to create infrastructure.
- `templatefile()`
- `lookup()`
- `file()`

## Dynamic Expressions
- Conditional expressions select values based on true/false expressions
- You can use `locals` to create a resource name based on conditional values
*Here's an example*: `(var.name != "" ? var.name : random_id.id.hex)`
This is how the syntax works:
- `condition` = `!=` (if the variable is not empty)
- `then` = `?` 
- `true` = assign `var.name` value
- `else` = `:`
- `false` = assign `random_id.id.hex` value

### Conditional count criteria
*Here's an example:* `(var.high_availability == true ? 3 : 1)`
This is how the syntax works:
- `condition` = `==` (high availability equals)
- `then` = `?` 
- `true` = assign `3` value
- `else` = `:`
- `false` = assign `1` value

*Here's an example:* `(count.index == 0 ? true : false)`
This is how the syntax works:
- `condition` = `==` (count.index equals 0)
- `then` = `?` 
- `true` = assign `true` value
- `else` = `:`
- `false` = assign `false` value

### Splat Expression
A splat expression `*` captures all objects in a list that shares an attribute. 
- the `*` iterates over all of the elements of a given list and returns information based on the shared attribute



## Manage TF Versions
*Here's an example*
```
terraform {
  required_providers {
    aws = {
      version = "~> 2.13.0"
    }
    random = {
      version = ">= 2.1.2"
    }
  }

  required_version = "~> 0.12.29"
}
```
- `~>` symbol allows the patch version to be greater than 29 but requires the major and minor versions to match the versions config specifies.
- `terraform version` to check your terraform version and any versions of providers
- HashiCorp uses the format `major.minor.patch` for Terraform versions
- more info on `constraints`: https://developer.hashicorp.com/terraform/language/expressions/version-constraints