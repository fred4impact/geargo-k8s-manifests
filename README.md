# GearGo Kubernetes Deployment

This directory contains all the Kubernetes manifests needed to deploy the GearGo Django application to a Kubernetes cluster using ArgoCD.

## Quick Start

### Prerequisites

1. **Kubernetes Cluster**: A running Kubernetes cluster (minikube, kind, or cloud provider)
2. **kubectl**: Kubernetes command-line tool
3. **ArgoCD**: ArgoCD installed in your cluster
4. **Docker Registry**: Access to push/pull Docker images

### Quick Deployment

1. **Update configuration**:
   ```bash
   # Edit the deployment script
   vim k8s/deploy.sh
   
   # Update these variables:
   REGISTRY="your-registry"  # Your Docker registry
   DOMAIN="your-domain.com"  # Your domain
   ```

2. **Run the deployment script**:
   ```bash
   cd k8s
   ./deploy.sh
   ```

### Manual Deployment

If you prefer to deploy manually, follow these steps:

1. **Build and push the Docker image**:
   ```bash
   docker build -t your-registry/geargo:latest .
   docker push your-registry/geargo:latest
   ```

2. **Update image references** in the manifests:
   ```bash
   sed -i 's|your-registry/geargo:latest|your-registry/geargo:latest|g' deployment.yaml
   sed -i 's|your-registry/geargo:latest|your-registry/geargo:latest|g' celery-deployment.yaml
   ```

3. **Create secrets**:
   ```bash
   kubectl create secret generic geargo-db-secret \
     --from-literal=POSTGRES_DB=geargo_db \
     --from-literal=POSTGRES_USER=geargo_user \
     --from-literal=POSTGRES_PASSWORD=your-secure-password
   
   kubectl create secret generic geargo-django-secret \
     --from-literal=SECRET_KEY=your-django-secret-key \
     --from-literal=DEBUG=False \
     --from-literal=ALLOWED_HOSTS=your-domain.com
   ```

4. **Deploy the application**:
   ```bash
   kubectl apply -k .
   ```

5. **Initialize the application**:
   ```bash
   kubectl exec -it deployment/geargo-web -- python manage.py migrate
   kubectl exec -it deployment/geargo-web -- python manage.py collectstatic --noinput
   kubectl exec -it deployment/geargo-web -- python manage.py setup_initial_data
   ```

## File Structure

```
k8s/
├── README.md                    # This file
├── deploy.sh                    # Automated deployment script
├── kustomization.yaml           # Kustomize configuration
├── deployment.yaml              # Django web application deployment
├── celery-deployment.yaml       # Celery worker deployment
├── service.yaml                 # Web service
├── ingress.yaml                 # Ingress configuration
├── hpa.yaml                     # Horizontal Pod Autoscaler
├── network-policy.yaml          # Network policy for security
├── media-pvc.yaml               # Media files persistent volume claim
├── argocd-application.yaml      # ArgoCD application definition
├── postgresql/
│   ├── deployment.yaml          # PostgreSQL deployment
│   ├── service.yaml             # PostgreSQL service
│   └── pvc.yaml                 # PostgreSQL persistent volume claim
└── redis/
    ├── deployment.yaml          # Redis deployment
    ├── service.yaml             # Redis service
    └── pvc.yaml                 # Redis persistent volume claim
```

## Components

### Application Components

- **geargo-web**: Django web application (2 replicas)
- **geargo-celery**: Celery worker for background tasks (1 replica)
- **postgresql**: PostgreSQL database (1 replica)
- **redis**: Redis cache and message broker (1 replica)

### Infrastructure

- **Ingress**: Nginx ingress controller for external access
- **Services**: ClusterIP services for internal communication
- **PVCs**: Persistent volume claims for data storage
- **HPA**: Horizontal pod autoscaler for automatic scaling
- **Network Policy**: Security policy for traffic control

## Configuration

### Environment Variables

The application uses the following environment variables:

- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `SECRET_KEY`: Django secret key
- `DEBUG`: Debug mode (False for production)
- `ALLOWED_HOSTS`: Comma-separated list of allowed hosts

### Secrets

Two Kubernetes secrets are required:

1. **geargo-db-secret**: Database credentials
2. **geargo-django-secret**: Django configuration

### Storage

The application uses persistent volumes for:

- **PostgreSQL data**: 10Gi
- **Redis data**: 5Gi
- **Media files**: 20Gi (ReadWriteMany)

## Monitoring

### Health Checks

The application includes health check endpoints:

- **Liveness probe**: `/health/` (checks database connectivity)
- **Readiness probe**: `/health/` (checks application readiness)

### Logging

View application logs:

```bash
# Web application logs
kubectl logs -f deployment/geargo-web

# Celery worker logs
kubectl logs -f deployment/geargo-celery

# Database logs
kubectl logs -f deployment/postgresql

# Redis logs
kubectl logs -f deployment/redis
```

### Scaling

Scale the application:

```bash
# Scale web application
kubectl scale deployment geargo-web --replicas=3

# Scale Celery workers
kubectl scale deployment geargo-celery --replicas=2
```

## ArgoCD Integration

### Setup ArgoCD Application

1. **Update the ArgoCD application manifest**:
   ```bash
   # Edit argocd-application.yaml
   # Update the repoURL to your repository
   ```

2. **Apply the ArgoCD application**:
   ```bash
   kubectl apply -f argocd-application.yaml
   ```

3. **Sync the application**:
   ```bash
   argocd app sync geargo-app
   ```

### ArgoCD Features

- **Automated sync**: Automatic deployment on Git changes
- **Self-healing**: Automatic recovery from drift
- **Pruning**: Automatic cleanup of removed resources
- **Revision history**: Track deployment history

## Troubleshooting

### Common Issues

1. **Database connection issues**:
   ```bash
   kubectl describe pod -l app=geargo,component=web
   kubectl logs deployment/geargo-web
   ```

2. **Static files not loading**:
   ```bash
   kubectl exec -it deployment/geargo-web -- python manage.py collectstatic --noinput
   ```

3. **Celery tasks not processing**:
   ```bash
   kubectl logs deployment/geargo-celery
   kubectl exec -it deployment/geargo-celery -- celery -A geargo_project inspect active
   ```

### Useful Commands

```bash
# Check all resources
kubectl get all -l app=geargo

# Describe specific resource
kubectl describe pod <pod-name>

# Execute commands in pods
kubectl exec -it <pod-name> -- /bin/bash

# Port forward for local access
kubectl port-forward svc/geargo-web 8000:8000

# View ArgoCD application status
argocd app get geargo-app
```

## Security

### Network Policies

The deployment includes network policies that:

- Restrict ingress traffic to the web application
- Allow communication between application components
- Restrict egress traffic to necessary services

### Secrets Management

- Database credentials are stored in Kubernetes secrets
- Django secret key is generated automatically
- No hardcoded secrets in manifests

### RBAC

Consider implementing RBAC for production:

```bash
# Create service accounts
kubectl create serviceaccount geargo-web
kubectl create serviceaccount geargo-celery

# Create roles and role bindings as needed
```

## Production Considerations

### High Availability

- Use multiple replicas for web and Celery components
- Consider using managed database services
- Implement proper backup strategies

### Performance

- Configure resource limits and requests
- Use horizontal pod autoscaling
- Monitor application metrics

### Security

- Enable TLS/SSL for HTTPS
- Use network policies
- Implement proper RBAC
- Regular security updates

### Monitoring

- Set up logging aggregation
- Configure alerting
- Monitor application metrics
- Set up tracing for distributed requests
