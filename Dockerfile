FROM jenkins/jenkins:lts

ENV TF_VERSION=0.11.7

# Install Terraform
USER root
RUN apt-get update && apt-get -y install unzip
RUN wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip \
    && unzip terraform_${TF_VERSION}_linux_amd64.zip \
    && mv terraform /usr/local/bin/terraform
USER jenkins
