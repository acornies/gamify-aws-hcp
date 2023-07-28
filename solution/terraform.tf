terraform {
  cloud {
    organization = "ender-corp"

    workspaces {
      name = "super-awesome-team"
    }
  }
}