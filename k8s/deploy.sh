#!/bin/bash

# GearGo Kubernetes Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="default"
REGISTRY="your-registry"
IMAGE_TAG="latest"
DOMAIN="geargo.local"

echo -e "${GREEN}🚀 Starting GearGo Kubernetes Deployment${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ docker is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Build and push Docker image
echo -e "${YELLOW}🐳 Building and pushing Docker image...${NC}"
docker build -t ${REGISTRY}/geargo:${IMAGE_TAG} .
docker push ${REGISTRY}/geargo:${IMAGE_TAG}
echo -e "${GREEN}✅ Docker image pushed successfully${NC}"

# Update image references in manifests
echo -e "${YELLOW}📝 Updating image references...${NC}"
sed -i.bak "s|your-registry/geargo:latest|${REGISTRY}/geargo:${IMAGE_TAG}|g" deployment.yaml
sed -i.bak "s|your-registry/geargo:latest|${REGISTRY}/geargo:${IMAGE_TAG}|g" celery-deployment.yaml
echo -e "${GREEN}✅ Image references updated${NC}"

# Create namespace if it doesn't exist
echo -e "${YELLOW}📦 Creating namespace...${NC}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Create secrets
echo -e "${YELLOW}🔐 Creating secrets...${NC}"

# Check if secrets already exist
if ! kubectl get secret geargo-db-secret -n ${NAMESPACE} >/dev/null 2>&1; then
    kubectl create secret generic geargo-db-secret \
        --from-literal=POSTGRES_DB=geargo_db \
        --from-literal=POSTGRES_USER=geargo_user \
        --from-literal=POSTGRES_PASSWORD=geargo_password \
        -n ${NAMESPACE}
    echo -e "${GREEN}✅ Database secret created${NC}"
else
    echo -e "${YELLOW}⚠️  Database secret already exists${NC}"
fi

if ! kubectl get secret geargo-django-secret -n ${NAMESPACE} >/dev/null 2>&1; then
    kubectl create secret generic geargo-django-secret \
        --from-literal=SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())') \
        --from-literal=DEBUG=False \
        --from-literal=ALLOWED_HOSTS=${DOMAIN} \
        -n ${NAMESPACE}
    echo -e "${GREEN}✅ Django secret created${NC}"
else
    echo -e "${YELLOW}⚠️  Django secret already exists${NC}"
fi

# Deploy using kustomize
echo -e "${YELLOW}🚀 Deploying application...${NC}"
kubectl apply -k . -n ${NAMESPACE}

# Wait for deployments to be ready
echo -e "${YELLOW}⏳ Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/geargo-web -n ${NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/geargo-celery -n ${NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/postgresql -n ${NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/redis -n ${NAMESPACE}

echo -e "${GREEN}✅ All deployments are ready${NC}"

# Initialize application
echo -e "${YELLOW}🔧 Initializing application...${NC}"

# Run migrations
echo -e "${YELLOW}📊 Running database migrations...${NC}"
kubectl exec -it deployment/geargo-web -n ${NAMESPACE} -- python manage.py migrate

# Collect static files
echo -e "${YELLOW}📁 Collecting static files...${NC}"
kubectl exec -it deployment/geargo-web -n ${NAMESPACE} -- python manage.py collectstatic --noinput

# Setup initial data
echo -e "${YELLOW}📝 Setting up initial data...${NC}"
kubectl exec -it deployment/geargo-web -n ${NAMESPACE} -- python manage.py setup_initial_data

# Setup email templates
echo -e "${YELLOW}📧 Setting up email templates...${NC}"
kubectl exec -it deployment/geargo-web -n ${NAMESPACE} -- python manage.py setup_email_templates

echo -e "${GREEN}✅ Application initialization completed${NC}"

# Show deployment status
echo -e "${YELLOW}📊 Deployment Status:${NC}"
kubectl get pods -n ${NAMESPACE} -l app=geargo
kubectl get services -n ${NAMESPACE} -l app=geargo
kubectl get ingress -n ${NAMESPACE}

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${YELLOW}🌐 Access your application at: http://${DOMAIN}${NC}"
echo -e "${YELLOW}📊 Monitor with: kubectl get pods -n ${NAMESPACE} -l app=geargo${NC}"
echo -e "${YELLOW}📋 View logs with: kubectl logs -f deployment/geargo-web -n ${NAMESPACE}${NC}"
