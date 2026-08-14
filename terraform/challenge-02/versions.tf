terraform {
  required_version = ">= 1.10"

  required_providers {
    launchdarkly = {
      source  = "launchdarkly/launchdarkly"
      version = "~> 2.29"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "launchdarkly" {
  access_token = "" # supplied via LAUNCHDARKLY_ACCESS_TOKEN env var at runtime
}
