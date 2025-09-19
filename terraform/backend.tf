terraform {
  cloud {
    organization = "CJRb8k"

    workspaces {
      name = "observability-stack"
    }
  }
}