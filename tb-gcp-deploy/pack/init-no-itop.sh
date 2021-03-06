#!/bin/bash
# Copyright 2019 The Tranquility Base Authors
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -o pipefail

echo "User: $(whoami)"
echo "Pwd: $(pwd)"
ls -al

# install and configure stackdriver logging agent
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash ./install-logging-agent.sh
cat <<EOF > /etc/google-fluentd/config.d/bootstrap-log.conf
<source>
    @type tail
    # Format 'none' indicates the log is unstructured (text).
    format none
    # The path of the log file.
    path /var/log/bootstrap.log
    # The path of the position file that records where in the log file
    # we have processed already. This is useful when the agent
    # restarts.
    pos_file /var/lib/google-fluentd/pos/bootstrap-log.pos
    read_from_head true
    # The log tag for this log input.
    tag bootstrap-log
</source>
EOF
systemctl restart google-fluentd
rm install-logging-agent.sh

apt-get -y update
apt-get -y install unzip
apt-get -y install zip
apt-get -y install nodejs
apt-get -y install git
apt-get -y install kubectl
apt-get -y install jq
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
apt-get -y install build-essential nodejs
npm install -g @angular/cli

node -v
npm -v

# install Terraform 0.13
wget https://releases.hashicorp.com/terraform/0.13.3/terraform_0.13.3_linux_amd64.zip
unzip -d /usr/local/bin/ terraform_0.13.3_linux_amd64.zip
rm terraform_0.13.3_linux_amd64.zip

# Clone Tranquility Base repository
git clone -b "${TB_GIT_BRANCH}" --single-branch "${TB_GIT_URL}" repo
cd repo

# remove autogenerated folders
find . -type d -name .idea -exec rm -rf {} +
find . -type d -name .terraform -exec rm -rf {} +
find . -type d -name .gcloud -exec rm -rf {} +
# find -type d -name nnpm install -g @angular/cliode_modules -exec rm -rf {} +
# remove autogenerated files
find . -type f -name clash.log -delete
find . -type f -name '*.tfstate' -delete
find . -type f -name '*.tfstate.*' -delete
find . -type f -name '*.out' -delete
find . -type f -name '*.bak' -delete
find . -type f -name '*.old' -delete
cd ..

# move TB Repo files from packer's home directory to target /opt/tb/repo directory
mkdir -p /opt/tb
mv repo /opt/tb/

# create certificate directory
mkdir -p /opt/certs

# Navigate to Landing Zone working dir
cd /opt/tb/repo/tb-gcp-tr/landingZone/no-itop/
# Download required terraform providers
terraform init -backend=false
# Check terraform syntax
terraform validate
echo "Pwd: $(pwd)"
