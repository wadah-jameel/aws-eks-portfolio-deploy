# aws-eks-portfolio-deploy
Deploy Portfolio Website on EKS Cluster

## step 1: Create an EKS cluster service role

### Before creating an EKS cluster you need to create a Cluster service IAM (Identity and Access Management) role. This grants permissions for the EKS service to access AWS APIs on your behalf.


  ### Select trusted entity: AWS Service
  ### Service or case use: EKS
  ### EKS - Cluster
  ### Role name: eksClusterRole

## Step 2: Create the EKS cluster

  ### Select Custom Configuration
  ### Ensure EKS Auto Mode is switched OFF 
  ### Name: dem-eks
  ### Cluster IAM role: eksClusterRole 
  ### Cluster access: cluster authentication mode > EKS API ConfigMap
  ### Select VPC
  ### Select values for the Subnets fields. There needs to be at least two subnets selected, and we don't need more than 3. Ensure that us-east-1e
  ### Observability: Leave as default-setting 
  ### Select add-ons: Leave as default-setting
  ### Configure selected add-ons settings: Leave as default-setting


## Step 3: Enable kubectl to communicate with your cluster

### Once the cluster is created, enable kubectl to communicate with your cluster by adding a new context to the kubectl config file by executing the following command 

```bash
aws eks update-kubeconfig --region us-east-1 --name demo-eks
```
### Check it is connecting. You should see some resources. All pods are in Pending state because we have yet to create nodes to run them on.

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

  ##### Stack Name: eks-cluster-stack
  ##### ClusterName: demo-eks
  ##### ClusterControlPlaneSecurityGroup: Click in the box and select the one with a name that contains eks-cluster-sg
  ##### NodeGroupName: eks-demo-node
  ##### KeyName: (you will likely need to scroll down to find this) - node-key-pair as created above.
  ##### VpcId: Click in the box and select the only entry that is there
  ##### Subnets: Select the same subnets you selected when configuring cluster networking.
  ##### Nothing to do on the following screen. Scroll to end and press Next
  ##### Now you are on the final screen. Scroll to the end and check the acknowledge box, then press Submit
  
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


 
   

  
