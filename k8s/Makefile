# GearGo Kubernetes Makefile

.PHONY: help deploy undeploy build-push secrets logs status port-forward clean

# Default target
help:
	@echo "GearGo Kubernetes Management Commands:"
	@echo ""
	@echo "  build-push    - Build and push Docker image"
	@echo "  secrets       - Create Kubernetes secrets"
	@echo "  deploy        - Deploy application to Kubernetes"
	@echo "  undeploy      - Remove application from Kubernetes"
	@echo "  status        - Show deployment status"
	@echo "  logs          - Show application logs"
	@echo "  port-forward  - Port forward to access application"
	@echo "  migrate       - Run database migrations"
	@echo "  collectstatic - Collect static files"
	@echo "  setup-data    - Setup initial data"
	@echo "  clean         - Clean up all resources"

# Configuration
NAMESPACE ?= default
REGISTRY ?= your-registry
IMAGE_TAG ?= latest
DOMAIN ?= geargo.local

# Build and push Docker image
build-push:
	@echo "Building and pushing Docker image..."
	docker build -t $(REGISTRY)/geargo:$(IMAGE_TAG) ..
	docker push $(REGISTRY)/geargo:$(IMAGE_TAG)
	@echo "✅ Docker image pushed successfully"

# Create Kubernetes secrets
secrets:
	@echo "Creating Kubernetes secrets..."
	kubectl create secret generic geargo-db-secret \
		--from-literal=POSTGRES_DB=geargo_db \
		--from-literal=POSTGRES_USER=geargo_user \
		--from-literal=POSTGRES_PASSWORD=geargo_password \
		-n $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl create secret generic geargo-django-secret \
		--from-literal=SECRET_KEY=$$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())') \
		--from-literal=DEBUG=False \
		--from-literal=ALLOWED_HOSTS=$(DOMAIN) \
		-n $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ Secrets created successfully"

# Deploy application
deploy: build-push secrets
	@echo "Deploying application to Kubernetes..."
	kubectl apply -k . -n $(NAMESPACE)
	@echo "⏳ Waiting for deployments to be ready..."
	kubectl wait --for=condition=available --timeout=300s deployment/geargo-web -n $(NAMESPACE)
	kubectl wait --for=condition=available --timeout=300s deployment/geargo-celery -n $(NAMESPACE)
	kubectl wait --for=condition=available --timeout=300s deployment/postgresql -n $(NAMESPACE)
	kubectl wait --for=condition=available --timeout=300s deployment/redis -n $(NAMESPACE)
	@echo "✅ Application deployed successfully"

# Undeploy application
undeploy:
	@echo "Removing application from Kubernetes..."
	kubectl delete -k . -n $(NAMESPACE) || true
	@echo "✅ Application removed successfully"

# Show deployment status
status:
	@echo "📊 Deployment Status:"
	@echo ""
	@echo "Pods:"
	kubectl get pods -n $(NAMESPACE) -l app=geargo
	@echo ""
	@echo "Services:"
	kubectl get services -n $(NAMESPACE) -l app=geargo
	@echo ""
	@echo "Ingress:"
	kubectl get ingress -n $(NAMESPACE)
	@echo ""
	@echo "Persistent Volume Claims:"
	kubectl get pvc -n $(NAMESPACE) -l app=geargo

# Show application logs
logs:
	@echo "📋 Application Logs:"
	@echo ""
	@echo "Web Application:"
	kubectl logs -f deployment/geargo-web -n $(NAMESPACE)

# Show specific component logs
logs-web:
	kubectl logs -f deployment/geargo-web -n $(NAMESPACE)

logs-celery:
	kubectl logs -f deployment/geargo-celery -n $(NAMESPACE)

logs-db:
	kubectl logs -f deployment/postgresql -n $(NAMESPACE)

logs-redis:
	kubectl logs -f deployment/redis -n $(NAMESPACE)

# Port forward to access application
port-forward:
	@echo "🔗 Port forwarding to application..."
	kubectl port-forward svc/geargo-web 8000:8000 -n $(NAMESPACE)

# Run database migrations
migrate:
	@echo "📊 Running database migrations..."
	kubectl exec -it deployment/geargo-web -n $(NAMESPACE) -- python manage.py migrate

# Collect static files
collectstatic:
	@echo "📁 Collecting static files..."
	kubectl exec -it deployment/geargo-web -n $(NAMESPACE) -- python manage.py collectstatic --noinput

# Setup initial data
setup-data:
	@echo "📝 Setting up initial data..."
	kubectl exec -it deployment/geargo-web -n $(NAMESPACE) -- python manage.py setup_initial_data

# Setup email templates
setup-email:
	@echo "📧 Setting up email templates..."
	kubectl exec -it deployment/geargo-web -n $(NAMESPACE) -- python manage.py setup_email_templates

# Initialize application (migrate + collectstatic + setup data)
init: migrate collectstatic setup-data setup-email
	@echo "✅ Application initialization completed!"

# Scale deployments
scale-web:
	@echo "Scaling web deployment to $(REPLICAS) replicas..."
	kubectl scale deployment geargo-web --replicas=$(REPLICAS) -n $(NAMESPACE)

scale-celery:
	@echo "Scaling Celery deployment to $(REPLICAS) replicas..."
	kubectl scale deployment geargo-celery --replicas=$(REPLICAS) -n $(NAMESPACE)

# Execute commands in pods
shell-web:
	kubectl exec -it deployment/geargo-web -n $(NAMESPACE) -- /bin/bash

shell-celery:
	kubectl exec -it deployment/geargo-celery -n $(NAMESPACE) -- /bin/bash

shell-db:
	kubectl exec -it deployment/postgresql -n $(NAMESPACE) -- psql -U geargo_user -d geargo_db

# Database operations
db-backup:
	@echo "💾 Creating database backup..."
	kubectl exec -it deployment/postgresql -n $(NAMESPACE) -- pg_dump -U geargo_user geargo_db > backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "✅ Database backup created"

db-restore:
	@echo "📥 Restoring database from $(FILE)..."
	kubectl exec -i deployment/postgresql -n $(NAMESPACE) -- psql -U geargo_user geargo_db < $(FILE)
	@echo "✅ Database restored successfully"

# Health check
health:
	@echo "🏥 Checking application health..."
	@echo ""
	@echo "Pod status:"
	kubectl get pods -n $(NAMESPACE) -l app=geargo -o wide
	@echo ""
	@echo "Health check endpoint:"
	kubectl exec -it deployment/geargo-web -n $(NAMESPACE) -- curl -s http://localhost:8000/health/ || echo "Health check failed"

# Clean up all resources
clean: undeploy
	@echo "🧹 Cleaning up all resources..."
	kubectl delete secret geargo-db-secret geargo-django-secret -n $(NAMESPACE) || true
	kubectl delete pvc -l app=geargo -n $(NAMESPACE) || true
	@echo "✅ Cleanup completed"

# ArgoCD operations
argocd-sync:
	@echo "🔄 Syncing ArgoCD application..."
	argocd app sync geargo-app

argocd-status:
	@echo "📊 ArgoCD Application Status:"
	argocd app get geargo-app

# Development helpers
dev-up:
	@echo "🚀 Starting development environment..."
	kubectl apply -f postgresql/ -n $(NAMESPACE)
	kubectl apply -f redis/ -n $(NAMESPACE)
	@echo "✅ Database and Redis started"

dev-down:
	@echo "🛑 Stopping development environment..."
	kubectl delete -f postgresql/ -n $(NAMESPACE) || true
	kubectl delete -f redis/ -n $(NAMESPACE) || true
	@echo "✅ Development environment stopped"
