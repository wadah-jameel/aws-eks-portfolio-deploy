#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLUSTER_NAME="dem-eks"
REGION="us-east-1"
NAMESPACE="portfolio"

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Deploy Portfolio to dem-eks Cluster${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Verify connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info
kubectl get nodes

# Build and push Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t portfolio-website:latest .

echo -e "${YELLOW}Tagging image for ECR...${NC}"
docker tag portfolio-website:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/portfolio-website:latest

echo -e "${YELLOW}Authenticating to ECR...${NC}"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo -e "${YELLOW}Pushing image to ECR...${NC}"
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/portfolio-website:latest

# Update deployment.yaml with correct image
echo -e "${YELLOW}Updating deployment configuration...${NC}"
sed "s|<YOUR_AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" deployment.yaml > deployment-configured.yaml

# Deploy to Kubernetes
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f namespace.yaml

echo -e "${YELLOW}Deploying application...${NC}"
kubectl apply -f deployment-configured.yaml

# Wait for deployment
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/portfolio-deployment -n $NAMESPACE --timeout=5m

# Get service details
echo -e "${GREEN}✓ Deployment successful!${NC}"
echo -e "${BLUE}Getting service details...${NC}"

sleep 10

LB_URL=$(kubectl get service portfolio-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")

if [ "$LB_URL" != "Pending..." ] && [ ! -z "$LB_URL" ]; then
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}Your website is available at:${NC}"
    echo -e "${GREEN}http://${LB_URL}${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
else
    echo -e "${YELLOW}LoadBalancer is still being provisioned...${NC}"
    echo -e "${YELLOW}Run this command in a few minutes:${NC}"
    echo -e "kubectl get service portfolio-service -n $NAMESPACE"
fi

# Show pod status
echo -e "${BLUE}Pod Status:${NC}"
kubectl get pods -n $NAMESPACE

# Show all resources
echo -e "${BLUE}All Resources:${NC}"
kubectl get all -n $NAMESPACE
