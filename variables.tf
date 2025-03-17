# variables
variable "instance_types" {
  default = {
    "master"  = "t3a.small"
    "worker1" = "t3a.small"
    "worker2" = "t3a.small"
  }
}

variable "key_name"{
    default = "siva"
}

variable "play_book_names"{
    default = {
        "all_node" = "all-nodes-setup.yml"
        "master"   = "master.yml"
        "node"     = "node.yml"
    }
}