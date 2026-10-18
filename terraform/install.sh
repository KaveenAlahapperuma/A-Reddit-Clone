#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

# Clear the old Jenkins repository before the first apt update.
rm -f /etc/apt/sources.list.d/jenkins.list

apt-get update -y
apt-get install -y ca-certificates curl wget gnupg fontconfig
install -d -m 0755 /etc/apt/keyrings

# Java 21
curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | gpg --batch --yes --dearmor -o /etc/apt/keyrings/adoptium.gpg
chmod 0644 /etc/apt/keyrings/adoptium.gpg

. /etc/os-release
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb ${VERSION_CODENAME} main" \
  > /etc/apt/sources.list.d/adoptium.list

apt-get update -y
apt-get install -y temurin-21-jdk
update-alternatives --set java /usr/lib/jvm/temurin-21-jdk-amd64/bin/java

# Jenkins LTS
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  -o /etc/apt/keyrings/jenkins-keyring.asc
chmod 0644 /etc/apt/keyrings/jenkins-keyring.asc
echo 'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update -y
apt-get install -y jenkins
systemctl enable --now jenkins

# Docker
apt-get install -y docker.io
systemctl enable --now docker
usermod -aG docker ubuntu
usermod -aG docker jenkins
systemctl restart jenkins

# SonarQube host requirements
cat > /etc/sysctl.d/99-sonarqube.conf <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF
sysctl --system > /dev/null

docker volume create sonarqube_data > /dev/null
docker volume create sonarqube_extensions > /dev/null
docker volume create sonarqube_logs > /dev/null

if ! docker container inspect sonar > /dev/null 2>&1; then
  docker run -d \
    --name sonar \
    --restart unless-stopped \
    --ulimit nofile=131072:131072 \
    --ulimit nproc=8192:8192 \
    -p 9000:9000 \
    -v sonarqube_data:/opt/sonarqube/data \
    -v sonarqube_extensions:/opt/sonarqube/extensions \
    -v sonarqube_logs:/opt/sonarqube/logs \
    sonarqube:community
elif [ "$(docker inspect -f '{{.State.Running}}' sonar)" != true ]; then
  docker start sonar
fi

# Trivy
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --batch --yes --dearmor -o /etc/apt/keyrings/trivy.gpg
chmod 0644 /etc/apt/keyrings/trivy.gpg
echo 'deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main' \
  > /etc/apt/sources.list.d/trivy.list

apt-get update -y
apt-get install -y trivy
