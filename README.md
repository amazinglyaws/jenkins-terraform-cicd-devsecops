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
    sudo apt install temurin-17-jdk -y
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
- Login using the admin credentials and install the suggested plugins
- Create a user and click 'Save and Continue'
- Congratulations, you have installed Jenkins successfully on the EC2 instance!

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
- Now the SonarQube container should be up and running
- Copy the EC2 public ip, open the browser on your local machine and enter <EC2 public ip:9000>
- In the SonarQube login screen, enter the username and password as 'admin'/'admin' (without '') and update with a new password
- SonqarQube dashboard will be displayed

#### Step 1c: Install Trivy
- Head back to the EC2 terminal and create a trivy.sh file
  
  ```
    vi trivy.sh
  ```
- Copy the following command inside the trivy.sh file and save the file using <esc> wq!

#### Step 1d: Install _JDK_, _SonarQube Scanner_, _Docker_ and _Terraform_ Plugins in Jenkins
- On the Jenkins dashboard, goto Manage Jenkins > Plugins > Available Plugins and setup the following plugins
  - Eclipse Temurin Installer (Install without restart)
  - SonarQube Scanner (Install without restart)
  - Terraform
  - Docker 

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

- Copy the terraform path to clipboard (we need this to setup the Terraform tools)

  ```
    which terraform
  ```

#### Step 2a: Configure Java and Terraform tools in Jenkins Global Tools section 
- Go to Manage Jenkins > Tools > JDK
- Got to Manage Jenkins > Tool > Terraform
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

Now create a _website.sh_ file to add to the UserData section of the EC2 instance (refer tp main.tf)

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





