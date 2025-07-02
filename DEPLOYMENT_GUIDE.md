# DevTube - Hướng dẫn Triển khai Chi tiết

## Mục lục
1. [Chuẩn bị môi trường](#chuẩn-bị-môi-trường)
2. [Triển khai từng bước](#triển-khai-từng-bước)
3. [Xác minh deployment](#xác-minh-deployment)
4. [Cấu hình post-deployment](#cấu-hình-post-deployment)
5. [Monitoring và Logging](#monitoring-và-logging)
6. [Backup và Recovery](#backup-và-recovery)
7. [Troubleshooting](#troubleshooting)

## Chuẩn bị môi trường

### 1. Cài đặt công cụ cần thiết

#### AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### eksctl
```bash
# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

#### kubectl
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### 2. Cấu hình AWS
```bash
aws configure
# Nhập:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: ap-southeast-1
# - Default output format: json
```

### 3. Xác minh permissions
```bash
# Kiểm tra identity
aws sts get-caller-identity

# Kiểm tra permissions EKS
aws eks list-clusters --region ap-southeast-1
```

## Triển khai từng bước

### Bước 1: Tạo EKS Cluster
```bash
# Tạo cluster
eksctl create cluster -f cluster-config.yaml

# Theo dõi quá trình tạo cluster
eksctl utils describe-stacks --region ap-southeast-1 --cluster devtube
```

**Thời gian dự kiến**: 15-20 phút

**Kết quả mong đợi**:
- EKS cluster được tạo thành công
- Node groups được tạo và sẵn sàng
- kubectl context được cập nhật

### Bước 2: Cài đặt AWS Load Balancer Controller

#### 2.1 Tạo IAM policy
```bash
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
```

#### 2.2 Tạo service account
```bash
eksctl create iamserviceaccount \
  --cluster=devtube \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn=arn:aws:iam::YOUR_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

#### 2.3 Cài đặt controller
```bash
# Thêm EKS repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Cài đặt AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=devtube \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

#### 2.4 Tạo IngressClass
```bash
kubectl apply -f ingressClass.yaml
```

### Bước 3: Deploy ứng dụng

#### 3.1 Tạo namespace
```bash
kubectl create namespace devtube --save-config
```

#### 3.2 Deploy resources
```bash
kubectl apply -f new-dep.yaml
```

#### 3.3 Kiểm tra deployment
```bash
# Kiểm tra pods
kubectl get pods -n devtube

# Kiểm tra services
kubectl get services -n devtube

# Kiểm tra ingress
kubectl get ingress -n devtube
```

## Xác minh deployment

### 1. Kiểm tra cluster health
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

### 2. Kiểm tra application health
```bash
# Check deployment status
kubectl rollout status deployment/api-gateway-deployment -n devtube

# Check pod logs
kubectl logs -f deployment/api-gateway-deployment -n devtube

# Check service endpoints
kubectl get endpoints -n devtube
```

### 3. Kiểm tra ingress
```bash
# Get ingress details
kubectl describe ingress ingress-api-gateway -n devtube

# Check ALB status
aws elbv2 describe-load-balancers --region ap-southeast-1
```

### 4. Test connectivity
```bash
# Get ALB DNS name
ALB_DNS=$(kubectl get ingress ingress-api-gateway -n devtube -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test HTTP access
curl -I http://$ALB_DNS

# Test HTTPS access
curl -I https://$ALB_DNS
```

## Cấu hình post-deployment

### 1. Cấu hình DNS
1. Lấy DNS name của ALB:
```bash
kubectl get ingress ingress-api-gateway -n devtube
```

2. Truy cập Namecheap dashboard
3. Cập nhật A record hoặc CNAME record
4. Đợi DNS propagation (5-10 phút)

### 2. Cấu hình SSL certificate
```bash
# Verify certificate
aws acm describe-certificate --certificate-arn arn:aws:acm:ap-southeast-1:564439693649:certificate/3a6cdb8f-c952-42c3-84f5-235d9747fc55 --region ap-southeast-1
```

### 3. Cấu hình security groups
```bash
# Lấy security group của ALB
ALB_ARN=$(aws elbv2 describe-load-balancers --region ap-southeast-1 --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-devtube`)].LoadBalancerArn' --output text)
SG_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region ap-southeast-1 --query 'LoadBalancers[0].SecurityGroups[0]' --output text)

# Cập nhật security group rules nếu cần
aws ec2 describe-security-groups --group-ids $SG_ID --region ap-southeast-1
```

## Monitoring và Logging

### 1. Cài đặt monitoring
```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Check metrics
kubectl top nodes
kubectl top pods -n devtube
```

### 2. Cấu hình logging
```bash
# View cluster logs
kubectl logs -f deployment/api-gateway-deployment -n devtube

# View AWS Load Balancer Controller logs
kubectl logs -f deployment/aws-load-balancer-controller -n kube-system
```

### 3. Cấu hình alerts (optional)
```bash
# Install Prometheus and Grafana (if needed)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

## Backup và Recovery

### 1. Backup cấu hình
```bash
# Backup all resources
kubectl get all -n devtube -o yaml > devtube-backup.yaml

# Backup specific resources
kubectl get deployment api-gateway-deployment -n devtube -o yaml > api-gateway-deployment-backup.yaml
kubectl get service api-gateway-service -n devtube -o yaml > api-gateway-service-backup.yaml
kubectl get ingress ingress-api-gateway -n devtube -o yaml > ingress-backup.yaml
```

### 2. Restore procedures
```bash
# Restore from backup
kubectl apply -f devtube-backup.yaml

# Or restore individual components
kubectl apply -f api-gateway-deployment-backup.yaml
kubectl apply -f api-gateway-service-backup.yaml
kubectl apply -f ingress-backup.yaml
```

## Troubleshooting

### 1. Cluster issues

#### Cluster creation failed
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name eksctl-devtube-cluster --region ap-southeast-1

# Check eksctl logs
eksctl utils describe-stacks --region ap-southeast-1 --cluster devtube
```

#### Node group issues
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check node group status
eksctl get nodegroup --cluster=devtube --region=ap-southeast-1
```

### 2. Application issues

#### Pods not starting
```bash
# Check pod status
kubectl get pods -n devtube
kubectl describe pod <pod-name> -n devtube

# Check events
kubectl get events -n devtube --sort-by=.metadata.creationTimestamp

# Check resource limits
kubectl describe nodes
```

#### Service issues
```bash
# Check service endpoints
kubectl get endpoints -n devtube
kubectl describe service api-gateway-service -n devtube

# Test service connectivity
kubectl run debug --image=nicolaka/netshoot -it --rm -- /bin/bash
# Inside the pod:
nslookup api-gateway-service.devtube.svc.cluster.local
wget -qO- http://api-gateway-service.devtube.svc.cluster.local
```

### 3. Ingress issues

#### ALB not created
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller
kubectl logs -f deployment/aws-load-balancer-controller -n kube-system

# Check service account
kubectl get serviceaccount aws-load-balancer-controller -n kube-system
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system
```

#### SSL certificate issues
```bash
# Check certificate status
aws acm describe-certificate --certificate-arn arn:aws:acm:ap-southeast-1:564439693649:certificate/3a6cdb8f-c952-42c3-84f5-235d9747fc55 --region ap-southeast-1

# Check certificate validation
aws acm list-certificates --region ap-southeast-1
```

#### DNS resolution issues
```bash
# Check DNS propagation
nslookup your-domain.com
dig your-domain.com

# Check from different locations
curl -H "Host: your-domain.com" http://ALB_DNS_NAME
```

### 4. Performance issues

#### High CPU/Memory usage
```bash
# Check resource usage
kubectl top pods -n devtube
kubectl top nodes

# Check resource limits
kubectl describe pod <pod-name> -n devtube
```

#### Slow response times
```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region ap-southeast-1

# Check application logs
kubectl logs -f deployment/api-gateway-deployment -n devtube
```

## Cleanup

### Complete cleanup
```bash
# Delete application resources
kubectl delete -f new-dep.yaml

# Delete namespace
kubectl delete namespace devtube

# Delete cluster
eksctl delete cluster devtube --region ap-southeast-1

# Delete IAM policy (if created)
aws iam delete-policy --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy
```

### Partial cleanup (keep cluster)
```bash
# Delete only application
kubectl delete deployment api-gateway-deployment -n devtube
kubectl delete service api-gateway-service -n devtube
kubectl delete ingress ingress-api-gateway -n devtube
```

## Checklist

### Pre-deployment
- [ ] AWS CLI configured
- [ ] kubectl installed
- [ ] eksctl installed
- [ ] Permissions verified
- [ ] SSL certificate ready

### Deployment
- [ ] Cluster created successfully
- [ ] ALB Controller installed
- [ ] IngressClass created
- [ ] Application deployed
- [ ] Ingress configured

### Post-deployment
- [ ] DNS configured
- [ ] SSL working
- [ ] Application accessible
- [ ] Monitoring set up
- [ ] Backup created

### Troubleshooting completed
- [ ] All pods running
- [ ] Services accessible
- [ ] Ingress working
- [ ] SSL certificate valid
- [ ] DNS resolving correctly 