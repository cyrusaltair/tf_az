variable "prefix" {
    type = string
    default = "mailer"
}

variable "location" {
  type    = string
  default = "Francecentral"
}

variable "address_space" {
  type    = list(any)
  default = ["10.0.0.0/16"]
}

variable "subnet_prefix" {
  type    = list(any)
  default = ["10.0.0.0/24"]
}

variable "vm_size" {
  type = string
  default = "Standard_B1s"
}

variable "adminuser" {
  type = string
  default = "ubuntu"
}

/* variable "public_key" {
  type = map
  default = public_key
} */