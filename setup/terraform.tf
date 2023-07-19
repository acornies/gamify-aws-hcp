terraform {
  cloud {
    organization = "ender-corp"

    workspaces {
      name = "gamify-aws-hcp"
    }
  }
}