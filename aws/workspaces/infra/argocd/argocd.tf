locals {
  argocd_manifest_url = "https://raw.githubusercontent.com/argoproj/argo-cd/${var.argocd_version}/manifests/install.yaml"
  eso_sa_name         = "external-secrets"
  eso_namespace       = "external-secrets"
}

resource "aws_ssm_document" "argocd_bootstrap" {
  name            = "${var.workspace}-argocd-bootstrap"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Bootstrap ArgoCD and External Secrets Operator on EKS"
    parameters = {
      clusterName = {
        type        = "String"
        description = "EKS cluster name"
      }
      awsRegion = {
        type        = "String"
        description = "AWS region"
      }
      argocdNamespace = {
        type        = "String"
        description = "ArgoCD namespace"
      }
      argocdManifestUrl = {
        type        = "String"
        description = "URL to the ArgoCD install manifest"
      }
      esoChartVersion = {
        type        = "String"
        description = "ESO Helm chart version"
      }
      esoRoleArn = {
        type        = "String"
        description = "IAM role ARN for ESO"
      }
      esoNamespace = {
        type        = "String"
        description = "ESO namespace"
      }
      esoServiceAccountName = {
        type        = "String"
        description = "ESO service account name"
      }
      clusterSecretStoreManifest = {
        type        = "String"
        description = "Base64-encoded ClusterSecretStore YAML"
      }
      applicationManifests = {
        type        = "String"
        description = "Base64-encoded concatenated Application + ExternalSecret YAMLs"
      }
    }
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "bootstrapArgoCD"
        inputs = {
          timeoutSeconds = "600"
          runCommand = [
            "#!/bin/bash",
            "set -euo pipefail",
            "",
            "export HOME=/root",
            "aws eks update-kubeconfig --name '{{ clusterName }}' --region '{{ awsRegion }}'",
            "",
            "echo '=== Creating namespaces ==='",
            "kubectl create namespace '{{ argocdNamespace }}' --dry-run=client -o yaml | kubectl apply -f -",
            "kubectl create namespace '{{ esoNamespace }}' --dry-run=client -o yaml | kubectl apply -f -",
            "kubectl create namespace paragon --dry-run=client -o yaml | kubectl apply -f -",
            "kubectl label namespace paragon elbv2.k8s.aws/pod-readiness-gate-inject=enabled --overwrite",
            "",
            "echo '=== Creating gp3 StorageClass ==='",
            "cat <<'SCEOF' | kubectl apply -f -",
            "apiVersion: storage.k8s.io/v1",
            "kind: StorageClass",
            "metadata:",
            "  name: gp3",
            "  annotations:",
            "    storageclass.kubernetes.io/is-default-class: \"true\"",
            "allowVolumeExpansion: true",
            "reclaimPolicy: Delete",
            "provisioner: ebs.csi.aws.com",
            "volumeBindingMode: WaitForFirstConsumer",
            "parameters:",
            "  encrypted: \"true\"",
            "  fsType: ext4",
            "  type: gp3",
            "SCEOF",
            "",
            "echo '=== Installing ArgoCD ==='",
            "kubectl apply -n '{{ argocdNamespace }}' -f '{{ argocdManifestUrl }}'",
            "echo 'Waiting for ArgoCD server deployment...'",
            "kubectl -n '{{ argocdNamespace }}' rollout status deployment/argocd-server --timeout=300s",
            "",
            "echo '=== Installing External Secrets Operator ==='",
            "helm repo add external-secrets https://charts.external-secrets.io || true",
            "helm repo update external-secrets",
            "helm upgrade --install external-secrets external-secrets/external-secrets \\",
            "  --namespace '{{ esoNamespace }}' \\",
            "  --version '{{ esoChartVersion }}' \\",
            "  --set serviceAccount.name='{{ esoServiceAccountName }}' \\",
            "  --set 'serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn={{ esoRoleArn }}' \\",
            "  --wait --timeout 300s",
            "",
            "echo '=== Applying ClusterSecretStore ==='",
            "echo '{{ clusterSecretStoreManifest }}' | base64 -d | kubectl apply -f -",
            "",
            "echo '=== Applying ArgoCD Applications and ExternalSecrets ==='",
            "echo '{{ applicationManifests }}' | base64 -d | kubectl apply -f -",
            "",
            "echo '=== Bootstrap complete ==='",
          ]
        }
      }
    ]
  })

  tags = {
    Name = "${var.workspace}-argocd-bootstrap"
  }
}

resource "aws_ssm_association" "argocd_bootstrap" {
  name             = aws_ssm_document.argocd_bootstrap.name
  association_name = "${var.workspace}-argocd-bootstrap"

  targets {
    key    = "tag:Name"
    values = [var.bastion_asg_name]
  }

  parameters = {
    clusterName                = var.cluster_name
    awsRegion                  = var.aws_region
    argocdNamespace            = var.argocd_namespace
    argocdManifestUrl          = local.argocd_manifest_url
    esoChartVersion            = var.eso_chart_version
    esoRoleArn                 = aws_iam_role.eso.arn
    esoNamespace               = local.eso_namespace
    esoServiceAccountName      = local.eso_sa_name
    clusterSecretStoreManifest = local.cluster_secret_store_b64
    applicationManifests       = local.application_manifests_b64
  }

  depends_on = [aws_iam_role_policy.eso_secrets]
}

locals {
  cluster_secret_store_yaml = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = local.eso_sa_name
                namespace = local.eso_namespace
              }
            }
          }
        }
      }
    }
  })

  cluster_secret_store_b64 = base64encode(local.cluster_secret_store_yaml)

  application_manifests_b64 = base64encode(
    join("\n---\n", var.argocd_application_manifests)
  )
}
