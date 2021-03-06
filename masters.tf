module "master_amitype" {
  source = "github.com/bobtfish/terraform-amitype"
  instance_type = "${var.master-instance_type}"
}

module "master_ami" {
  source = "github.com/bobtfish/terraform-coreos-ami"
  region = "${var.region}"
  channel = "${var.coreos-channel}"
  virttype = "${module.master_amitype.ami_type_prefer_hvm}"
}

resource "aws_launch_configuration" "kubernetes-master" {
    image_id = "${module.master_ami.ami_id}"
    instance_type = "${var.master-instance_type}"
    security_groups = ["${var.sg}"]
    associate_public_ip_address = false
    user_data = "${file(format(\"%s/master.yaml\", path.module))}"
    key_name = "${var.admin_key_name}"
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "kubernetes-master" {
  availability_zones = ["${var.primary-az}", "${var.secondary-az}"]
  name = "kubernetes-master"
  max_size = "${toint(var.master-cluster-size)+1}"
  min_size = "${var.master-cluster-size}"
  desired_capacity = "${var.master-cluster-size}"
  health_check_grace_period = 120
  health_check_type = "EC2"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.kubernetes-master.name}"
  vpc_zone_identifier = [ "${var.primary-az-subnet}", "${var.secondary-az-subnet}" ]
  tag {
    key = "Name"
    value = "kubernetes-master"
    propagate_at_launch = true
  }
}

