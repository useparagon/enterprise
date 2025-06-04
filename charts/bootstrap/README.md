# Bootstrap Helm Chart

## Purpose

This chart bootstraps the Paragon platform with required secrets and configuration. This duplicates functionality that would normally be handled by the `paragon` workspace when deploying to AWS, Azure or GCP with Terraform.

## Usage

1. **Create a `.secure/values.yaml` file:**

   ```yaml
   namespace: paragon

   dockerCfg:
     docker_registry_server: "docker.io"
     docker_username: "your-username"
     docker_password: "your-password"
     docker_email: "your-email@example.com"

   env:
     AWS_REGION: "us-east-1"
     NODE_ENV: "production"
     # ...add more environment variables as needed

   secrets:
     LICENSE: "your-license-key"
     ADMIN_BASIC_AUTH_PASSWORD: "your-admin-password"
     # ...add more secrets as needed
   ```

2. **Prepare the chart:**

   ```sh
   ./prepare.sh k8s
   ```

3. **Deploy the chart:**

   ```sh
   helm install bootstrap ./dist/bootstrap -f .secure/values.yaml --namespace paragon --create-namespace
   ```

   To upgrade:
   ```sh
   helm upgrade bootstrap ./dist/bootstrap -f .secure/values.yaml --namespace paragon
   ```

## Security

- **Never commit `.secure/values.yaml` to version control.**  

## Troubleshooting

- Ensure your YAML is valid.
- Use the correct key paths for `dockerCfg`, `env`, and `secrets` values.
- If you see namespace errors, use `--create-namespace` or create the namespace manually.
