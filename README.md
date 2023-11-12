# Deploy a dockerised application to AWS using Jenking CICD and Terraform using DevSecOps practices
Deploy an application to AWS using Jenkins and Terraform leveraging DevSecOps practices

Tools : AWS EC2, Terraform (S3, DynamoDB), GitHub, Jenkins, Docker, SonarQube, Trivy, Tfsec

### Architecture

<img width="1021" alt="image" src="https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/2818390a-d227-45a2-8827-3397eb774373">

#### Add toc using doctoc plugin - todo

### Steps

# Pre-requisites
- Create AWS Account
  This account with administrative or necessary privileges is required to manage AWS resources
- Create S3 bucket for Terraform state
  An S3 bucket is required to securly store the Terraform state file remotely
- Create Dynamo DB table to Terraform lock
  A Dynamo DB table is required enable locking for Terraform state management
- Setup Jenkins on an EC2 instance
  Setup and configure Jenkins for running the pipeline and confifure necessary plugins for AWS and Terrform integration
- Install Terrform on Jenkins server
  Terraform plugin needs to be installed on this server to execute the Terraform script from the CI/CD pipeline
- Setup Terraform files in GitHub
  Terraform configuration files should be availale in GitHub SCM 
- Setup IAM role for Jenkins EC2 server
  Create a IAM role and add required permissions for Jenkins EC2 server for provisioning AWS resources (using Terraform), Dynamo DB access, S3 bucket operations etc.
  
### Step 1: Launch an EC2 instance (t2.medium)

#### Step 1a: Install Jenkins
#### Step 1b: Install Docker
#### Step 1c: Install Trivy
#### Step 1d: Install plugins - JDK, SonarQube Scanner and Terraform

### Step 2: Setup Terraform

#### Step 2a: Create IAM Role, S3 bucket and Dynamo DB table (for

### Step 3: Setup Terraform
Terraform state, variable and modules are already available in this github repo - TODO

### Step 4: Setup Jenkins pipeline

### Step 5: Running the application

### Step 6: Clean up AWS resources using Terraform





