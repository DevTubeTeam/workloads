# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# OIDC Identity Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "GitHub Actions OIDC Provider"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${local.env}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:DevTubeTeam/workloads:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "GitHub Actions EKS Role"
  }
}

# IAM Policy for EKS access
resource "aws_iam_policy" "github_actions_eks" {
  name        = "${local.env}-github-actions-eks-policy"
  description = "Policy for GitHub Actions to access EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "github_actions_eks" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_eks.arn
}

# Output the role ARN
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the IAM role for GitHub Actions"
} 