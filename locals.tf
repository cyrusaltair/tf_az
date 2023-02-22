locals {
  tags = {
    environment  = "test"
    businessUnit = "product-MailServers"
    department   = "techOps"
    source       = "terraform"
  }

  pubkey = file("./postfixTest_key.pub")
}