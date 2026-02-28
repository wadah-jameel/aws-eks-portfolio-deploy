# aws-eks-portfolio-deploy

Deploying a Portfolio Website on AWS EKS with Amazon ECR

-----------------------------------------------------------

## Project Overview

This project demonstrates how to containerize and deploy a personal portfolio website to Amazon Elastic Kubernetes Service (EKS) using Amazon Elastic Container Registry (ECR) for secure image storage.

The goal of this project is to showcase real-world DevOps practices including containerization, Kubernetes orchestration, cloud-native deployment, and infrastructure security in AWS.

## step 1: Create an EKS cluster service role

### Before creating an EKS cluster you need to create a Cluster service IAM (Identity and Access Management) role. This grants permissions for the EKS service to access AWS APIs on your behalf.

----------------------------------------------------------

## Architecture

Docker – Containerize the portfolio application

Amazon ECR – Store and manage Docker images securely

Amazon EKS – Managed Kubernetes cluster for container orchestration

kubectl – Deploy and manage Kubernetes resources

AWS IAM – Role-based access control

AWS VPC – Secure networking environment

LoadBalancer Service – Expose the application publicly

------------------------------------------------------------

## High-Level Flow:

Build Docker image locally

Push image to Amazon ECR

Create EKS cluster

Deploy Kubernetes manifests

Expose application via AWS Load Balancer

---------------------------------------------------------------

## Technologies Used

Amazon Web Services

Amazon Elastic Kubernetes Service (EKS)

Amazon Elastic Container Registry (ECR)

Docker

Kubernetes

kubectl

GitHub


-----------------------------------------------------------------

  #### - Select trusted entity: AWS Service
  #### - Service or case use: EKS
  #### - EKS - Cluster
  #### - Role name: eksClusterRole

## Step 2: Create the EKS cluster

### Via AWS console: 

  ### - Select Custom Configuration
  ### - Ensure EKS Auto Mode is switched OFF 
  ### - Name: dem-eks
  ### - Cluster IAM role: eksClusterRole 
  ### - Cluster access: cluster authentication mode > EKS API ConfigMap
  ### - Select VPC
  ### - Select values for the Subnets fields. There needs to be at least two subnets selected, and we don't need more than 3. Ensure that us-east-1e
  ### - Observability: Leave as default-setting 
  ### - Select add-ons: Leave as default-setting
  ### - Configure selected add-ons settings: Leave as default-setting

### Via AWS CLI:

```bash
aws eks create-cluster \
  --name dem-eks \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/eksClusterRole \
  --resources-vpc-config subnetIds=<SUBNET_ID_1>,<SUBNET_ID_2>,securityGroupIds=<SECURITY_GROUP_ID>
```

## Step 3: Enable kubectl to communicate with your cluster

### Once the cluster is created, enable kubectl to communicate with your cluster by adding a new context to the kubectl config file by executing the following command 

```bash
aws eks update-kubeconfig --region us-east-1 --name demo-eks
```
### Check if it is connecting. You should see some resources. All pods are in Pending state because we have yet to create nodes to run them on.

```bash
kubectl get all -A
```

## Step 4: Add Cluster Nodes

### Now we will add some unmanaged nodes to the cluster.

#### 1- Create an SSH keypair for the nodes to use.

#### 2- Navigate to the CloudFormation console.
#### 3- Creat stack, by choosing existing template, template from Amazon S3 URL: 
```bash
https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2022-12-23/amazon-eks-nodegroup.yaml
```
#### 4- Now we fill in the parameters required to deploy the nodes

  ##### - Stack Name: eks-cluster-stack
  ##### - ClusterName: demo-eks
  ##### - ClusterControlPlaneSecurityGroup: Click in the box and select the one with a name that contains eks-cluster-sg
  ##### - NodeGroupName: eks-demo-node
  ##### - KeyName: (you will likely need to scroll down to find this) - node-key-pair as created above.
  ##### - VpcId: Click in the box and select the only entry that is there
  ##### - Subnets: Select the same subnets you selected when configuring cluster networking.
  ##### - Nothing to do on the following screen. Scroll to end and press Next
  ##### - Now you are on the final screen. Scroll to the end and check the acknowledge box, then press Submit
  
#### 5- Wait for stack creation to complete which will take a few minutes. You may need to press the Refresh button a few times until it gets to CREATE COMPLETE
#### 6- Now select the Outputs tab and note down the value of NodeInstanceRole. You need this when you join your Amazon EKS nodes.

## Step 5: Join Worker Nodes
  
  #### 1- Download the node configmap

  ```bash
  curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/aws-auth-cm.yaml
  ```
  #### 2- Edit "aws-auth-cm.yaml" file

  ##### Where it says rolearn: <ARN of instance role (not instance profile)>, you need to delete <ARN of instance role (not instance profile)> and paste in the value for NodeInstanceRole you got from the previous section. When you are done, it should look something like this (though the actual value will be different for you).

```yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::851725221429:role/eks-cluster-stack-NodeInstanceRole-8OYkncRSa4gA
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
```

  #### 2- Apply the confimap
  
  ```bash
  kubectl apply -f aws-auth-cm.yaml
  ```

  #### It will take a minute or so for all nodes to join the cluster
  
  ```bash
  kubectl get nodes
  ```

## Your cluster is now up and you can create resources.


## Step 6: Accessing Node Port services

 #### In order for you to be able to see any NodePort services you create, we must edit the security group applied to the nodes in order to permit your laptop to access them.

 ### 1- Edit the node security group
 
   #### In EC2 console, access Security groups, and look for "eks-cluster-stack-NodeSecurityGroup"
   #### Edit inbound rules, and add Inbound Rules
   
     #### Type: Custom TCP
     #### Port range: 30000 - 32768 which is the default range for node ports
     #### Source: My IP It will automatically determine your broadband public IP. You can find this yourself by browsing http://checkip.amazonaws.com


 ### 2- Create a test service
 
   #### In EC2 instance, note the Public IP address of the nodes, You will need to use any one of these to connect to your nodeport service.

   #### Create pod and service
   
   ```bash
  kubectl run nginx --image nginx --expose --port=80
  ```
   #### Edit the service and change it to nodeport.
   ```bash
    kubectl edit service nginx
   ```

```yaml

ports:
- port: 80
  protocol: TCP
  targetPort: 80
  nodePort: 30080       #<- Add this
selector:
  run: nginx
sessionAffinity: None
type: NodePort          #<- Edit this from ClusterIP to NodePort

```

#### Now you can view your service in your browser by building the URL from the public IP address you got from the EC2 console, and the node port 30080. In this example it is http://44.198.158.250:30080, but for you the IP address will be different. Paste the URL you have formed into your browser. You should see the nginx welcome page.

## Step 7: Prepare Your Docker Image

### First step: Create ECR Repository via AWS Console

 #### 1- Go to Amazon ECR Console:

 ```bash
https://console.aws.amazon.com/ecr/repositories
```

#### 2- Create Repository:

#### - Click "Create repository"
#### - Repository name: portfolio-website
#### - Tag immutability: Disabled
#### - Scan on push: Enabled (optional)
#### - Click "Create repository"

### 3- Note the Repository URI:
#### - You'll see something like: 123456789012.dkr.ecr.us-east-1.amazonaws.com/portfolio-website
#### - Save this URI for later

### Second step: Push Docker Image to ECR
```bash
# Navigate to your project directory
cd ~/eks-portfolio

# Get your AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Your AWS Account ID: $AWS_ACCOUNT_ID"

# Get your region (check where dem-eks is located)
REGION="us-east-1"  # Change if your cluster is in different region

# Authenticate Docker to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Build Docker image
docker build -t portfolio-website:latest .

# Tag image for ECR
docker tag portfolio-website:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/portfolio-website:latest

# Push to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/portfolio-website:latest

# Verify push
aws ecr describe-images --repository-name portfolio-website --region $REGION
```

## Step 8: Create Kubernetes Manifests

#### - Create namespace.yaml
#### - Create deployment.yaml

### Update deployment.yaml with your ECR URI
```bash
# Get your ECR URI
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/portfolio-website:latest"

echo "Your ECR URI: $ECR_URI"

# Replace in deployment.yaml
sed -i.bak "s|<YOUR_AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/portfolio-website:latest|${ECR_URI}|g" deployment.yaml

# Or manually edit the file and replace the image line
```

## Step 9: Deploy Using kubectl

```bash
# Apply namespace
kubectl apply -f namespace.yaml

# Apply deployment and service
kubectl apply -f deployment.yaml

# Verify deployment
kubectl get all -n portfolio

# Watch pods starting
kubectl get pods -n portfolio -w
# Press Ctrl+C to stop watching

# Get service details
kubectl get service portfolio-service -n portfolio

# Wait for LoadBalancer to be provisioned (2-3 minutes)
kubectl get service portfolio-service -n portfolio -w

```

## Step 10: Monitor via AWS Console

### Check Deployment Status in EKS Console

#### 1- Go to EKS Clusters:
```bash
https://console.aws.amazon.com/eks/home?region=us-east-1#/clusters/dem-eks
```

#### 2- View Resources Tab:

#### - Click on "Resources" tab
#### - Click on "Workloads"
#### - You should see portfolio-deployment

### 3- View Service:

#### - Click on "Service and networking"
#### - Click on "Services"
#### - You should see portfolio-service
#### - Note the Load Balancer DNS name

### Check in EC2 Load Balancers

#### 1- Go to EC2 Load Balancers:
```bash
https://console.aws.amazon.com/ec2/home?region=us-east-1#LoadBalancers:
```

#### 2- Find the LoadBalancer:

#### - Look for a load balancer with tags related to your service
#### - Copy the DNS name
#### - Example: a1234567890abcdef-1234567890.us-east-1.elb.amazonaws.com

## Step 10: Access Your Website

### Get LoadBalancer URL
```bash
# Get LoadBalancer DNS
kubectl get service portfolio-service -n portfolio -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Or with more details
kubectl describe service portfolio-service -n portfolio
```

### Access in Browser
```bash
# Get the URL
LB_URL=$(kubectl get service portfolio-service -n portfolio -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Your website is available at: http://$LB_URL"

# Open in browser (macOS)
open http://$LB_URL

# Or copy and paste the URL in your browser
```


## Step 11: Create Quick Deploy Script

#### Create deploy-to-dem-eks.sh:

#### Make it executable and run:
```bash
chmod +x deploy-to-dem-eks.sh
./deploy-to-dem-eks.sh
```

## Step 11: Verify Deployment via AWS Console

### CloudWatch Logs

#### 1- Go to CloudWatch Logs:
```bash
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups
```

#### 2- Find log group:

#### - Look for /aws/eks/dem-eks/cluster
#### - Or /aws/containerinsights/dem-eks

### View Pod Logs in Console

#### 1- Go to EKS Console:
```bash
https://console.aws.amazon.com/eks/home?region=us-east-1#/clusters/dem-eks
```
#### 2- Navigate to Resources:

#### - Click "Resources" tab
#### - Click "Workloads"
#### - Find portfolio-deployment
#### - Click on it
#### - Click "Logs" tab to view pod logs

## Step 12: Management Commands

### View Resources

```bash
# View all resources in portfolio namespace
kubectl get all -n portfolio

# View pods with details
kubectl get pods -n portfolio -o wide

# View service
kubectl get service portfolio-service -n portfolio

# Describe deployment
kubectl describe deployment portfolio-deployment -n portfolio

# View logs
kubectl logs -f deployment/portfolio-deployment -n portfolio

# View events
kubectl get events -n portfolio --sort-by='.lastTimestamp'

```

## Expected Output

### After successful deployment, you should see:
```bash
NAMESPACE   NAME                                      READY   STATUS    RESTARTS   AGE
portfolio   pod/portfolio-deployment-xxxxxxxxx-xxxxx   1/1     Running   0          2m

NAMESPACE   NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)        AGE
portfolio   service/portfolio-service   LoadBalancer   10.100.xxx.xxx   a1234567890abcdef-1234567890.us-east-1.elb.amazonaws.com   80:xxxxx/TCP   2m

NAMESPACE   NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
portfolio   deployment.apps/portfolio-deployment   2/2     2            2           2m
```
#### Your website will be accessible at the EXTERNAL-IP URL! 


### Scale Deployment

```bash
# Scale to 3 replicas
kubectl scale deployment portfolio-deployment --replicas=3 -n portfolio

# Scale to 1 replica (save costs)
kubectl scale deployment portfolio-deployment --replicas=1 -n portfolio
```

### Update Deployment

```bash
# After making changes to your website, rebuild and push
docker build -t portfolio-website:v2 .
docker tag portfolio-website:v2 ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/portfolio-website:v2
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/portfolio-website:v2

# Update deployment with new image
kubectl set image deployment/portfolio-deployment \
  portfolio=${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/portfolio-website:v2 \
  -n portfolio

# Watch rollout
kubectl rollout status deployment/portfolio-deployment -n portfolio

```
### Rollback Deployment

```bash
# Rollback to previous version
kubectl rollout undo deployment/portfolio-deployment -n portfolio

# View rollout history
kubectl rollout history deployment/portfolio-deployment -n portfolio
```
-----------------------------------------------------------------------------------

## Troubleshooting

### If Pods are Not Starting

```bash
# Check pod status
kubectl get pods -n portfolio

# Describe problematic pod
kubectl describe pod <pod-name> -n portfolio

# View logs
kubectl logs <pod-name> -n portfolio

# Common issues:
# ImagePullBackOff - ECR authentication issue
# CrashLoopBackOff - Application error
# Pending - Resource constraints
```

### Fix ImagePullBackOff

```bash
# Verify ECR image exists
aws ecr describe-images --repository-name portfolio-website --region us-east-1

# Re-authenticate Docker
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Verify image URL in deployment
kubectl get deployment portfolio-deployment -n portfolio -o yaml | grep image:
```

### If LoadBalancer is Stuck in Pending

```bash
# Check service events
kubectl describe service portfolio-service -n portfolio

# Check AWS Load Balancer
aws elbv2 describe-load-balancers --region us-east-1

# Verify security groups allow traffic
kubectl get service portfolio-service -n portfolio -o yaml
```
------------------------------------------------------------------------

## Clean Up Resources

### When you want to remove the deployment:
```bash
# Delete all resources in portfolio namespace
kubectl delete namespace portfolio

# Or delete specific resources
kubectl delete -f deployment.yaml
kubectl delete -f namespace.yaml

# Verify deletion
kubectl get all -n portfolio
```
### Delete ECR Repository
```bash
# Via CLI
aws ecr delete-repository \
    --repository-name portfolio-website \
    --region us-east-1 \
    --force

# Or via Console:
# Go to ECR → Select repository → Delete
```
--------------------------------------------------------------------------

## Quick Reference Card

```bash
# Deploy
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml

# Check Status
kubectl get all -n portfolio

# Get URL
kubectl get service portfolio-service -n portfolio

# View Logs
kubectl logs -f deployment/portfolio-deployment -n portfolio

# Scale
kubectl scale deployment portfolio-deployment --replicas=3 -n portfolio

# Delete
kubectl delete namespace portfolio
```














