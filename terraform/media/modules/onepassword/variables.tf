variable "vault" {
  type = string
}

variable "items" {
  type = list(string)
  description = "List of item titles to retrieve from the vault"
}
