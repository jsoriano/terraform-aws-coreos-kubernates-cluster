module "node_amitype" {
  source = "github.com/bobtfish/terraform-amitype"
  instance_type = "${var.node-instance_type}"
}

module "node_ami" {
  source = "github.com/bobtfish/terraform-coreos-ami"
  region = "${var.region}"
  channel = "${var.coreos-channel}"
  virttype = "${module.node_amitype.ami_type_prefer_hvm}"
}

resource "aws_launch_configuration" "kubernetes-node" {
    image_id = "${module.node_ami.ami_id}"
    instance_type = "${var.node-instance_type}"
    security_groups = ["${var.sg}"]
    associate_public_ip_address = false
    user_data = "${file(format(\"%s/master.yaml\", path.module))}"
    key_name = "${var.admin_key_name}"
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "kubernetes-node" {
  availability_zones = ["${var.primary-az}", "${var.secondary-az}"]
  name = "kubernetes-node"
  max_size = "${toint(var.node-cluster-size)+1}"
  min_size = "${var.node-cluster-size}"
  desired_capacity = "${var.node-cluster-size}"
  health_check_grace_period = 120
  health_check_type = "EC2"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.kubernetes-node.name}"
  vpc_zone_identifier = [ "${var.primary-az-subnet}", "${var.secondary-az-subnet}" ]
  tag {
    key = "Name"
    value = "kubernetes-node"
    propagate_at_launch = true
  }
}

