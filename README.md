# Deploy a dockerised application to AWS using Jenking CICD and Terraform using DevSecOps practices
Deploy an application to AWS using Jenkins and Terraform leveraging DevSecOps practices

Tools : AWS EC2, Terraform (S3, DynamoDB), GitHub, Jenkins, Docker, SonarQube, Trivy, Tfsec 

### Architecture

<img width="1021" alt="image" src="https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/2818390a-d227-45a2-8827-3397eb774373">

#### Add toc using doctoc plugin - todo

### Steps

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
  - Docker 
![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/3ac5f382-814b-4c63-beee-99c6c1ffad0f)

![image](https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/d9e8893d-7053-430f-a69f-973c244f2cd0)


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
- Goto Jenkins Dashboard > Manage Jenkins > Credentials > Add Secret Text. It should look like this
- Now, go to Dashboard > Manage Jenkins > System and add as shown. Click 'Apply' and 'Save'
- Goto Jenkins Dashboard > Manage Jenkins > Tools to install a Sonar Scanner
- Go back to SonarQube dashboard, click Administration > Configuration > Webhooks and create a webhook (required to trigger the Sonar scan when the code is commited to GitHub). Add this detail and click 'Create'
```
  <http://jenkins-public-ip:8080>/sonarqube-webhook/
```

#### Step 2c: Create IAM Role, S3 bucket and Dynamo DB table (for Terraform)

##### Create IAM Role and add the following permissions

##### Create an S3 bucket

##### Create DynamoDB table

#### Step 2d: Docker Plugin Setup
- We need to install the Docker tool on the Jenkins server
- Goto Dashboard > Manage Plugins > Available plugins and search for Docker and install these plugins (without restart)

Docker
Docker Commons
Docker Pipeline
Docker API
docker-build-step

- Now, goto Dashboard > Manage Jenkins > Tools and setup the DockerHub Username adnd Password under 'Global credentials'



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

#### Step 4a: Create a Jenkins pipeline
 
- Let's create a pipeline jobs in Jenkisn using declarative way

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

#### Step 4b: Setup permission for jenkins user to run the job

- Log in to your Ubuntu system as a user with sudo privileges, or log in as the root user.
- Open a terminal.
- Run the following command to add a user (replace <username> with the actual username) to the sudo group:
  
  ```
     sudo usermod -aG sudo <username>
  ``` 

- After running the command, the user will have sudo privileges. They can now execute commands with superuser privileges using sudo.

  To test whether the user can use sudo, you can simply open a terminal and have the user run a command with sudo
  
  ```
    sudo apt update
  ```
  
- Now add the below stages to your pipeline
   
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
- add a parameterized step in the pipeline with two options : a) apply b) destroy. Add this insude pipeline job as shown - TODO
- add the following stage in your pipeline. The option selected (apply or destroy) will be executed by terraform based on the $action parameter when this stage executes
  ```
    stage('Terraform apply'){
                steps{
                    sh 'terraform ${action} --auto-approve'
                }
            }
  ```
- if 'apply' was selected thne terraform will 'create' the AWS infrastructure

### Step 5: Running the application
- Go back to your local browser and enter the following to access the Zomato we application
  ```
    <EC2 instance-public-ip:3000> #zomato app container
  ```
<img width="606" alt="image" src="https://github.com/amazinglyaws/jenkins-terraform-cicd-devsecops/assets/133778900/c64e4a16-e1dd-4cf3-85bd-0f715c79a773">

### Step 6: Destroy AWS resources created using Terraform
- To destroy the AWS resources, select the option 'destroy' at the 'Terraform apply' stage in the pipeline


### Step 7: Cleaup AWS Resources
- Stop and Terminate the EC2 instance (Jenkins Server) including EBS volumne to avoid any AWS bill charges


### Complete jenkins pipeline
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





