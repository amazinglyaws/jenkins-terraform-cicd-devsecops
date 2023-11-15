
# Deploy a dockerised application to AWS using Jenking CICD and Terraform using DevSecOps practices
Deploy an application to AWS using Jenkins and Terraform leveraging DevSecOps practices

Tools : AWS EC2, Terraform (S3, DynamoDB), GitHub, Jenkins, Docker, SonarQube, Trivy, Tfsec 

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc]*

- [Deploy a dockerised application to AWS using Jenking CICD and Terraform using DevSecOps practices](#deploy-a-dockerised-application-to-aws-using-jenking-cicd-and-terraform-using-devsecops-practices)
    - [Architecture](#architecture)
      - [Add toc using doctoc plugin - todo](#add-toc-using-doctoc-plugin---todo)
    - [Steps](#steps)
- [Pre-requisites](#pre-requisites)
    - [Step 1: Launch an EC2 instance (t2.medium)](#step-1-launch-an-ec2-instance-t2medium)
      - [Step 1a: Install Jenkins](#step-1a-install-jenkins)
      - [Step 1b: Install Docker and run SonarQueb container (using docker)](#step-1b-install-docker-and-run-sonarqueb-container-using-docker)
      - [Step 1c: Install Trivy](#step-1c-install-trivy)
      - [Step 1d: Install _JDK_, _SonarQube Scanner_, _Docker_ and _Terraform_ Plugins in Jenkins](#step-1d-install-_jdk_-_sonarqube-scanner_-_docker_-and-_terraform_-plugins-in-jenkins)
    - [Step 2: Install Terraform (on Jenkins Server)](#step-2-install-terraform-on-jenkins-server)
      - [Step 2a: Configure Java and Terraform tools in Jenkins Global Tools section](#step-2a-configure-java-and-terraform-tools-in-jenkins-global-tools-section)
      - [Step 2b: Integrate SonarQube Server settings with Jenkins](#step-2b-integrate-sonarqube-server-settings-with-jenkins)
      - [Step 2c: Create IAM Role, S3 bucket and Dynamo DB table (for Terraform)](#step-2c-create-iam-role-s3-bucket-and-dynamo-db-table-for-terraform)
        - [Create IAM Role and add the following permissions](#create-iam-role-and-add-the-following-permissions)
        - [Create an S3 bucket](#create-an-s3-bucket)
        - [Create DynamoDB table](#create-dynamodb-table)
    - [Step 3: Setup Terraform](#step-3-setup-terraform)
    - [Step 4: Setup Jenkins pipeline](#step-4-setup-jenkins-pipeline)
      - [Step 4a: Create a Jenkins pipeline](#step-4a-create-a-jenkins-pipeline)
      - [Step 4b: Setup permission for jenkins user to run the User data](#step-4b-setup-permission-for-jenkins-user-to-run-the-user-data)
      - [Step 4c: Setup the Terrform stage (fianl)](#step-4c-setup-the-terrform-stage-fianl)
    - [Step 5: Running the application](#step-5-running-the-application)
    - [Step 6: Destroy AWS resources created using Terraform](#step-6-destroy-aws-resources-created-using-terraform)
    - [Step 7: Cleaup AWS Resources](#step-7-cleaup-aws-resources)
    - [eference: Complete jenkins pipeline](#Reference-complete-jenkins-pipeline)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

### Architecture

<img width="959" alt="image" src="https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/1b7fad01-7d48-40b6-8766-b94bdb91fd89">


# Pre-requisites
- Create AWS Account
  - This account with administrative or necessary privileges is required to manage AWS resources
- Create S3 bucket for Terraform state
  - An S3 bucket is required to securly store the Terraform state file remotely
- Create Dynamo DB table to Terraform lock
  - A Dynamo DB table is required enable locking for Terraform state management
- Setup Jenkins on an EC2 instance
  - Setup and configure Jenkins for running the pipeline and confifure necessary plugins for AWS and Terrform integration
- Install Terrform on Jenkins server
  - Terraform plugin needs to be installed on this server to execute the Terraform script from the CI/CD pipeline
- Setup Terraform files in GitHub
  - Terraform configuration files should be availale in GitHub SCM 
- Setup IAM role for Jenkins EC2 server
  - Create a IAM role and add required permissions for Jenkins EC2 server for provisioning AWS resources (using Terraform), Dynamo DB access, S3 bucket operations etc.
- Application as docker image
  - Please note we are not going to create any application code for this demo. Instead we will be using a pre-built image from the dockerhub repository
  
### Step 1: Launch an EC2 instance (t2.medium)
In this step we will spin up a new AWS EC2 (t2.medium) instance and install Jenkins, SonarQube, Docker, Trivy and Terraform

#### Step 1a: Install Jenkins
- Connect to your EC2 Instance (Jenkins Server) from your local machine
- In the Jenkins server console, create a jenkins.sh file as follows and copy the contents
  ```
    vi jenkins.sh
  ```
  ```
     #!/bin/bash
    sudo apt update -y
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
    sudo apt update -y
    # sudo apt install temurin-17-jdk -y  -- gave error Unable to locate package temurin-17-jdk
    sudo apt install openjdk-17-jdk
    /usr/bin/java --version
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
                      /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
                      https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
                                  /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install jenkins -y
    sudo systemctl start jenkins
    sudo systemctl status jenkins
  ```
- Provide the required permission to jenkins.sh file

  ```
    sudo chmod 777 jenkins.sh
    ./jenkins.sh    # this will install jenkins
  ```
- Go back to AWS console and create a Security Group for thie EC2 instance. Open an Inbound port 8080, as Jenkins listens on 8080 by default
- Now copy the Public IP of the EC2 instance and open a browser on you local machine and type <public ip>:8080
- Copy this command, login to the EC2 terminal and execute this command to get the Jekins administrator password
  ```
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
  ```
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/dc8f35e6-cb0a-4eef-81df-54cd8b26555a)

- Login using the admin credentials and click 'install the suggested plugins'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/a5e55260-a21e-4dcf-bac0-57546db30796)

- Create a user/pwed (admin/admin) and click 'Save and Continue'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/1f755946-89ee-4ebb-92e4-e9b91c2e81c5)

- Congratulations, you have installed Jenkins successfully on the EC2 instance!
![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/5ff17417-2c00-4251-96f5-06adffda4ddd)

![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/bd1bb40a-c703-469f-8e8c-e81ced149a32)

- Jenkins dashboard will be displayed
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/32136804-1e7d-408c-ae8d-4c5e089cb92e)

#### Step 1b: Install Docker and run SonarQueb container (using docker)

- Install docker on the EC2 using the below commands

  ```
    sudo apt-get update
    sudo apt-get install docker.io -y
    sudo usermod -aG docker $USER   #my case is ubuntu
    newgrp docker
    sudo chmod 777 /var/run/docker.sock
  ```

- After installing docker, create a SonarQube container. As SonarQube container listens on port 9000, we need to open a new Inbound Rule in the EC2 Security Group for port 9000

  ```
    docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
  ```
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/c8e27fea-d724-4df0-a164-826adec8084e)

- Now the SonarQube container should be up and running
  
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/ab554118-4850-456b-88e7-4853bd85204c)

- Copy the EC2 public ip, open the browser on your local machine and enter <EC2 public ip:9000>

  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/1681c97f-837b-4433-91e4-19fc147b264a)

- In the SonarQube login screen, enter the username and password as 'admin'/'admin' (without '') and update with a new password (admin123)
  
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/2b84f3b7-6dff-4ea6-97dd-4f16d1200073)

  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/e6bde03e-16f2-4e73-90fb-bab8dc5cd6c6)

- SonqarQube dashboard will be displayed
![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/833de007-a59a-41b2-a304-4a594319865f)

#### Step 1c: Install Trivy
- Head back to the EC2 terminal and create a trivy.sh file
  
  ```
    vi trivy.sh
  ```
- Copy the following command inside the trivy.sh file and save the file using <esc> wq!
  ```
    sudo apt-get install wget apt-transport-https gnupg lsb-release -y
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install trivy -y

  ```

  - Provide required permission and execute trivy.sh
    ```
      sudo chmod 777 trivy.sh
      ./trivy.sh
    ```

    - Verify trivy status
      ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/33d2d39e-4c95-4702-baf9-62221bcfed3b)

#### Step 1d: Install _JDK_, _SonarQube Scanner_, _Docker_ and _Terraform_ Plugins in Jenkins
- On the Jenkins dashboard, goto Manage Jenkins > Plugins > Available Plugins and setup the following plugins
  - Eclipse Temurin Installer (Install without restart)
  - SonarQube Scanner (Install without restart)
  - Terraform

![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/3ac5f382-814b-4c63-beee-99c6c1ffad0f)

![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/d9e8893d-7053-430f-a69f-973c244f2cd0)

  - Docker
    - We need to install the Docker tool on the Jenkins server
    - Goto Dashboard > Manage Plugins > Available plugins and search for Docker and install these plugins (without restart)
      ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/d5be4146-03a1-45f5-bb6f-bb7332f340d6)

- Now, goto Dashboard > Manage Jenkins > Tools. Click 'Apply and 'Save'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/5b926b0d-29a9-4683-a641-bb4009b5f53c)

- DockerHub Username adnd Password under 'Global credentials'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/dd2cc188-5fde-4c1b-b0eb-0f3d6a3612fd)

- The credentials should be displayed
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/f2b74027-9eff-4f13-8bdb-a607d87201b3)

### Step 2: Install Terraform (on Jenkins Server)
- On the EC2 terminal, run the following command to install terraform

  ```
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
  ```

- Check terraform version

  ```
    terraform --version
  ```
![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/e6429f2b-a5ee-4946-9a55-62b67d3a6fe1)

- Copy the terraform path to clipboard (we need this to setup the Terraform tools)

  ```
    which terraform
  ```
![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/c46d41d5-9a91-4696-a939-727534287e9d)

#### Step 2a: Configure Java and Terraform tools in Jenkins Global Tools section 
- Go to Manage Jenkins > Tools > JDK
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/d4e3ce40-707e-4eec-b88b-60d83787523b)

- Got to Manage Jenkins > Tools > Terraform
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/cd669aa3-8659-477d-9229-7aa0aec1637c)

- Click 'Apply' and 'Save' 

#### Step 2b: Integrate SonarQube Server settings with Jenkins
- Grab the Public IP Address of your EC2 Instance, SonarQube works on Port 9000, so <Public IP>:9000.
- Goto your SonarQube Server, then click on Administration > Security > Users >
- Click on Tokens and Update Token → Give it a name → and click on 'Generate Token'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/da7651e3-2f27-42a8-8fcd-bb79d4cd8046)

- Goto Jenkins Dashboard > Manage Jenkins > Credentials > Add Secret Text. This will be the Sonar Token credentials. Click 'Create'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/05367283-822e-4feb-affb-45c25061b030)
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/7948c543-0a62-46b8-9a42-127238197cd3)

- Now, go to Dashboard > Manage Jenkins > System and add the Sonar Server
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/ac37c9c2-c76e-4114-b64c-0c6d942f564f)
  
- Goto Jenkins Dashboard > Manage Jenkins > Tools to install a Sonar Scanner
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/1ffe5ed7-cf02-4130-a21c-ced26cfa1566)

- Now lets add SonarQube quality gate. Head back to SonarQube dashboard, click Administration > Configuration > Webhooks and create a webhook (required to trigger the Sonar scan when the code is commited to GitHub). Add this detail and click 'Create'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/8a05e480-f71c-4ae3-babf-85cafda81014)

  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/3058a685-50a4-4575-ae06-504292ac35d5)

  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/cc7ff6ce-494e-4c25-9929-48165da0488e)

```
  <http://jenkins-public-ip:8080>/sonarqube-webhook/
```

#### Step 2c: Create IAM Role, S3 bucket and Dynamo DB table (for Terraform)

##### Create IAM Role and add the following permissions
- Add a new IAM role named 'jenkins-cicd' using AWS Console > IAM
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/8f264616-31a3-454e-8f7e-9fa9db550baa)

- Attach this IAM role to Jenkins EC2 server
  - go to the Jenkins EC2 instance and add this role
  - select Jenkins instance > Actions > Security > Modify IAM role
     ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/ab5f3807-4def-4ac7-9e72-0686845968ab)
    
  - select the newly created Role 'jenkins-cicd' and click on 'Update IAM role'
    ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/51114935-49f0-4bdc-bb61-b55640b8f5ea)


##### Create an S3 bucket
- Create an S3 bucket and give a name. This bucket name should match with the 'bucket' name given in backend.tf file
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/c9df855a-7ba5-4288-9311-60076b32f22f)

##### Create DynamoDB table
- Create a DynamoDB table. This table name should match with the 'dynamo_table' name given in backend.tf file
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/5f581987-3dfd-4656-be2f-0a54bc626202)
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/9d3971cf-c60c-4e82-a8ea-420fe1e71c62)

### Step 3: Setup Terraform
- In your GitHub repository, cerate the following files for Terraform

backend.td

  ```
    add code
  ```

provider.tf

  ```
    add code
  ```

main.tf

  ```
    add code
  ```

variables.tf

  ```
    add code
  ```

- Now create a _website.sh_ file to add to the UserData section of the EC2 instance (refer tp main.tf)

  ```
    #!/bin/bash
  
    # Update the package manager and install Docker
    sudo apt-get update -y
    sudo apt-get install -y docker.io
    
    # Start the Docker service
    sudo systemctl start docker
    
    # Enable Docker to start on boot
    sudo systemctl enable docker
    
    # Pull and run a simple Nginx web server container
    sudo docker run -d --name zomato -p 3000:3000 sunilsnair1976/zomato:latest
  
  ```  

### Step 4: Setup Jenkins pipeline
- Let's create a Job in Jenkins
- Goto Jenkins dashboard and add a 'New Item' and select 'Pipeline'
- Name it 'Terraform' and add the following pipeline code. Click 'Apply' and 'Save'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/ff631b04-ce12-4d08-97d3-2064de0648de)

- Click 'Build Now' to run the pipleine. If it is successful the following screen will be displayed
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/0679c6b8-ebd2-4237-acb6-8a6bbe2410ba)

- Now got to SonarQube url and click 'Projects' to see the scan results
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/43f45a5f-b378-4b0d-9da5-e6f36e83916e)


#### Step 4a: Create a Jenkins pipeline
 
- Let's create a pipeline jobs in Jenkins using declarative method

  ```
    pipeline{
      agent any
      tools{
          jdk 'jdk17'
          terraform 'terraform'
      }
      environment {
          SCANNER_HOME=tool 'sonar-scanner'
      }
      stages {
          stage('clean workspace'){
              steps{
                  cleanWs()
              }
          }
          stage('Checkout from Git'){
              steps{
                  git branch: 'main', url: 'https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops.git'
              }
          }
          stage('Terraform version'){
               steps{
                   sh 'terraform --version'
                  }
          }
          stage("Sonarqube Analysis "){
              steps{
                  withSonarQubeEnv('sonar-server') {
                      sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Terraform \
                      -Dsonar.projectKey=Terraform '''
                  }
              }
          }
          stage("quality gate"){
             steps {
                  script {
                      waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token' 
                  }
              } 
          }
          stage('TRIVY FS SCAN') {
              steps {
                  sh "trivy fs . > trivyfs.txt"
              }
          }
      }
    }
  
  ```

#### Step 4b: Setup permission for jenkins user to run the User data

- Log in to your Ubuntu system as a user with sudo privileges, or log in as the root user
- Open a terminal
- Run the following command to add a user (replace <username> with the actual username) to the sudo group:
  
  ```
     sudo usermod -aG sudo <username>  # username is ubuntu in my case
  ``` 
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/8de3e84b-6920-49b7-b831-8665f4ed7918)

- After running the command, the user will have sudo privileges. They can now execute commands with superuser privileges using sudo.

  To test whether the user can use sudo, you can simply open a terminal and have the user run a command with sudo
  
  ```
    sudo apt update
  ```
  

- Now add the below stages to your pipeline. 'Apply' and 'Save' changes
   
  ```
     stage('Excutable permission to userdata'){
        steps{
            sh 'chmod 777 website.sh'
        }
    }
    stage('Terraform init'){
        steps{
            sh 'terraform init'
        }
    }
    stage('Terraform plan'){
        steps{
            sh 'terraform plan'
        }
    }
  
  ```
  
- Run the build again and check the results. The new stages should be executed and the entire build should be successful
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/6047f89a-c41f-4195-aeb3-a1c0739e30ee)
  

6. Adding **aqua tfsec** for scsecurity scanning of the Terraform files. NOTE: for this demo this step is optional

- install aqua tfsec using this command
  ```
    curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
  ```
- to perform terraform security scanning, add this stage to your pipeline
  ```
    stage('Trivy terraform scan'){
      steps{
          sh 'tfsec . --no-color'
         }
     }
  ```
- if you run the pipeline now, it will throw many security violations erros for the terraform file. So let's not use this stage for this demo

#### Step 4c: Setup the Terrform stage (fianl)
- This stage is required to create the resources (EC2) in AWS when the 'Terraform apply' is executed
  - for flexibility, we are going to add create this as a parameterized step in the pipeline with two options : a) apply b) destroy
    ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/8722dd3d-af53-4468-a491-1d19931e9117)

  - add the following stage in your pipeline. Click 'Save' and 'Apply'.
  - The option selected (apply or destroy) will be executed by terraform based on the $action parameter when this stage executes
    ```
      stage('Terraform apply'){
                  steps{
                      sh 'terraform ${action} --auto-approve'
                  }
              }
    ```
    ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/ed69fd0a-0039-402f-8403-270ea6bf09dd)


  - Now you should see a 'Build with Parameter' option on the Jenkins page
    ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/dc585dd9-e0e1-45ef-b560-d507cc5c1cc1)

  - Run the pipeline and select 'apply'. The pipeline should be successful
    ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/a7ae59c8-2d8a-4485-91de-26b826c60946)

  - Head back to AWS console the check EC2 console. An EC2 instance with name 'SSN-EC2' should be created. 
    ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/efa568b8-4a9d-44b2-b446-7a7a7a6680ca)

  - NOTE: Selecting 'destroy' from the parameterized option would trigger Terraform to 'destroy' the AWS resources

### Step 5: Running the application
- From the AWS EC2 console, copy the public ip of the 'SSN-EC2' server. Open your local browser and enter the following to access the Zomato application
  ```
    <EC2 instance-public-ip:3000> #zomato app container
  ```
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/7f46addb-2cd1-4c95-94d7-a58c55b0fe19)


### Step 6: Destroy AWS resources created using Terraform
- To destroy the AWS resources, go back to Jenkins pipeline select the option 'destroy' from 'Build with Parameter' option and run the pipeline
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/d6b5544a-73c3-4e53-a2f7-1b7c3d956d4c)

- See the Jenkins build pipeline console ouput. You can see two AWS resouces (EC2 instance and SG) being destroyed

  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/74d71013-825a-4780-9dfb-8863144a801a)

  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/d626e84c-b5e0-495e-ab3f-df78fcca7515)
  
- Now head back to AWS EC2 console and check the status of EC2 instance 'SSN-EC2'. It should show as 'terminated'
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/8fb41f97-7390-49de-a42a-9170c51e9c39)

- Now refresh the browser page where the zomato app was displayed. The page will throw error as shown. This is obvious as the EC2 server 'SSN-EC2' that hosted the Zomato application has been terminated!
  ![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/b07814fc-d7e6-4462-b817-62dbb500fc66)


### Step 7: Cleaup AWS Resources
- Stop and Terminate the EC2 instance (Jenkins Server) including EBS volume and also delete the terraform resources (S3 and DynamoDB table) to avoid any AWS bill charges.


### Reference: Complete jenkins pipeline
  ```
    pipeline{
      agent any
      tools{
          jdk 'jdk17'
          terraform 'terraform'
      }
      environment {
          SCANNER_HOME=tool 'sonar-scanner'
      }
      stages {
          stage('clean workspace'){
              steps{
                  cleanWs()
              }
          }
          stage('Checkout from Git'){
              steps{
                  git branch: 'main', url: 'https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops.git'
              }
          }
          stage('Terraform version'){
               steps{
                   sh 'terraform --version'
                  }
          }
          stage("Sonarqube Analysis "){
              steps{
                  withSonarQubeEnv('sonar-server') {
                      sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Terraform \
                      -Dsonar.projectKey=Terraform '''
                  }
              }
          }
          stage("quality gate"){
             steps {
                  script {
                      waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token' 
                  }
              } 
          }
          stage('TRIVY FS SCAN') {
              steps {
                  sh "trivy fs . > trivyfs.txt"
              }
          }
          stage('Excutable permission to userdata'){
              steps{
                  sh 'chmod 777 website.sh'
              }
          }
          stage('Terraform init'){
              steps{
                  sh 'terraform init'
              }
          }
          stage('Terraform plan'){
              steps{
                  sh 'terraform plan'
              }
          }
          stage('Terraform apply'){
              steps{
                  sh 'terraform ${action} --auto-approve'
              }
          }
      }
  }
  ```





