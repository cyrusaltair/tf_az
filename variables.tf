variable "prefix" {
    type = string
    default = "mailer"
}

variable "location" {
  type    = string
  default = "France Central"
}

variable "address_space" {
  type    = list(any)
  default = ["10.0.0.0/16"]
}

variable "subnet_prefix" {
  type    = list(any)
  default = ["10.0.0.0/24"]
}