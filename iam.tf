# Get the access to the effective Account ID in which Terraform is working.
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Allows AWS Config IAM role to access the S3 bucket where AWS Config records
# are stored.
data "template_file" "aws_config_policy" {
  template = "${file("${path.module}/iam-policies/aws-config-policy.tpl")}"

  vars = {
    config_logs_bucket = "${var.config_logs_bucket}"
    config_logs_prefix = "${var.config_logs_prefix}"
    account_id         = "${data.aws_caller_identity.current.account_id}"
  }
}

# Allow IAM policy to assume the role for AWS Config
data "aws_iam_policy_document" "aws-config-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    effect = "Allow"
  }
}

#
# IAM
#

resource "aws_iam_role" "main" {
  name = "aws-config-${data.aws_region.current.name}-role"

  assume_role_policy = "${data.aws_iam_policy_document.aws-config-role-policy.json}"
}

resource "aws_iam_policy_attachment" "managed-policy" {
  name       = "aws-config-${data.aws_region.current.name}-managed-policy"
  roles      = ["${aws_iam_role.main.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_iam_policy" "aws-config-policy" {
  name   = "aws-config-${data.aws_region.current.name}-policy"
  policy = "${data.template_file.aws_config_policy.rendered}"
}

resource "aws_iam_policy_attachment" "aws-config-policy" {
  name       = "aws-config-${data.aws_region.current.name}-policy"
  roles      = ["${aws_iam_role.main.name}"]
  policy_arn = "${aws_iam_policy.aws-config-policy.arn}"
}

data "aws_iam_policy_document" "allow_sns_publish" {
  count = "${var.sns_topic_arn == "" ? 0 : 1}"

  statement {
    actions   = ["sns:Publish"]
    resources = ["${var.sns_topic_arn}"]
  }
}

resource "aws_iam_policy" "allow_sns_publish" {
  count  = "${var.sns_topic_arn == "" ? 0 : 1}"
  name   = "aws-config-${data.aws_region.current.name}-sns"
  policy = "${data.aws_iam_policy_document.allow_sns_publish.json}"
}

resource "aws_iam_role_policy_attachment" "allows_sns_publish" {
  count      = "${var.sns_topic_arn == "" ? 0 : 1}"
  policy_arn = "${aws_iam_policy.allow_sns_publish.arn}"
  role       = "${aws_iam_role.main.name}"
}
