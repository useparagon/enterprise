locals {
  sync_policy = {
    automated = var.auto_sync ? {
      selfHeal = var.self_heal
      prune    = true
    } : null
    syncOptions = ["CreateNamespace=true"]
    retry = var.auto_sync ? {
      limit = 3
      backoff = {
        duration    = "30s"
        factor      = 2
        maxDuration = "5m"
      }
    } : null
  }

  # --- Ingress Controller (sync-wave 0) ---
  app_ingress = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-ingress"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "0"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://aws.github.io/eks-charts"
        chart          = "aws-load-balancer-controller"
        targetRevision = var.ingress_chart_version
        helm = {
          valuesObject = {
            clusterName  = var.cluster_name
            replicaCount = 3
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_namespace
      }
      syncPolicy = local.sync_policy
    }
  })

  # --- Metrics Server (sync-wave 0) ---
  app_metrics_server = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-metrics-server"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "0"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://kubernetes-sigs.github.io/metrics-server/"
        chart          = "metrics-server"
        targetRevision = var.metrics_server_chart_version != "" ? var.metrics_server_chart_version : "*"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_namespace
      }
      syncPolicy = local.sync_policy
    }
  })

  # --- AWS Node Termination Handler (sync-wave 0) ---
  app_nth = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-node-termination-handler"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "0"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://aws.github.io/eks-charts"
        chart          = "aws-node-termination-handler"
        targetRevision = "*"
        helm = {
          valuesObject = {
            jsonLogging = true
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "kube-system"
      }
      syncPolicy = local.sync_policy
    }
  })

  # --- Cluster Autoscaler (sync-wave 0) ---
  # Replaces the lablabs/eks-cluster-autoscaler Terraform module in cluster/autoscaling.tf
  app_cluster_autoscaler = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-cluster-autoscaler"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "0"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://kubernetes.github.io/autoscaler"
        chart          = "cluster-autoscaler"
        targetRevision = "*"
        helm = {
          valuesObject = {
            autoDiscovery = {
              clusterName = var.cluster_name
            }
            awsRegion = var.aws_region
            rbac = {
              serviceAccount = {
                name = "${var.workspace}-cluster-autoscaler"
                annotations = {
                  "eks.amazonaws.com/role-arn" = var.cluster_autoscaler_role_arn
                }
              }
            }
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "kube-system"
      }
      syncPolicy = local.sync_policy
    }
  })

  # --- Paragon On-Prem (sync-wave 2) ---
  app_paragon_onprem = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-paragon-onprem"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "2"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.chart_repository
        chart          = "paragon-onprem"
        targetRevision = var.chart_version
        helm = {
          valuesObject = {
            global = {
              env = {
                secretName = "paragon-secrets"
              }
            }
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_namespace
      }
      syncPolicy = local.sync_policy
    }
  })

  # --- Paragon Logging (sync-wave 1) ---
  app_paragon_logging = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-paragon-logging"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "1"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.chart_repository
        chart          = "paragon-logging"
        targetRevision = var.chart_version
        helm = {
          valuesObject = {
            global = {
              env = {
                ZO_S3_PROVIDER    = "s3"
                ZO_S3_BUCKET_NAME = var.logs_bucket
                ZO_S3_REGION_NAME = var.aws_region
              }
            }
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_namespace
      }
      syncPolicy = local.sync_policy
    }
  })

  # --- Paragon Monitoring (sync-wave 3, conditional) ---
  app_paragon_monitoring = var.monitors_enabled ? yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-paragon-monitoring"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "3"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.chart_repository
        chart          = "paragon-monitoring"
        targetRevision = var.monitor_version
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_namespace
      }
      syncPolicy = local.sync_policy
    }
  }) : null

  # --- Managed Sync (sync-wave 3, conditional) ---
  app_managed_sync = var.managed_sync_enabled ? yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.workspace}-managed-sync"
      namespace = var.argocd_namespace
      annotations = {
        "argocd.argoproj.io/sync-wave" = "3"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.managed_sync_repository
        chart          = "managed-sync"
        targetRevision = var.managed_sync_version
        helm = {
          valuesObject = {
            ingress = {
              certificate      = var.certificate_arn
              loadBalancerName = var.workspace
              logsBucket       = var.logs_bucket
              scheme           = var.ingress_scheme
            }
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_namespace
      }
      syncPolicy = local.sync_policy
    }
  }) : null
}
