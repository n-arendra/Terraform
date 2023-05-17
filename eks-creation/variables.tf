
variable "vpc_id" {
    default = "create a dedicated VPC, provide the vpc id here like(vpc-0d95a6190a1ad9dcf)"
}   

variable "cluster_name" {
    default = "mycluster"
}

variable "node_group_name" {
    default = "mynode"
}

variable "node_instance_type" {
    default = "t2.micro"
}







