# DevTube - AWS EKS Deployment

## Tổng quan
DevTube là một ứng dụng microservices được triển khai trên Amazon EKS (Elastic Kubernetes Service) với kiến trúc API Gateway và các dịch vụ backend. Hệ thống sử dụng Terraform để tự động hóa việc triển khai infrastructure.

## Kiến trúc hệ thống

```
Internet → ALB Ingress → API Gateway Service → API Gateway Pod
                     ↘ Auth Service (staging)
                     ↘ Upload Service (staging)
```

## Cấu trúc thư mục
```
workloads/
├── tf/                   # Terraform infrastructure code
│   ├── 0-locals.tf      # Local variables
│   ├── 1-providers.tf   # Provider configurations
│   ├── 2-vpc.tf         # VPC and networking
│   ├── 7-eks.tf         # EKS cluster
│   ├── 8-nodes.tf       # Node groups
│   ├── 15-aws-lbc.tf    # AWS Load Balancer Controller
│   └── 12-metrics-server.tf # Metrics server
├── cluster-config.yaml   # EKS cluster config (legacy)
├── ingressClass.yaml    # ALB Ingress Controller config
├── new-dep.yaml         # Production deployment
└── stg/                 # Staging environment
    ├── api-gateway/     # API Gateway staging configs
    ├── auth-service/    # Authentication service configs
    └── upload-service/  # Upload service configs
```

## Infrastructure Configuration

### Terraform Variables (locals)
- **Environment**: prod
- **Region**: ap-southeast-1 (Singapore)
- **EKS Cluster**: devtube
- **EKS Version**: 1.32
- **Node Instance Type**: t3.large
- **Scaling Config**: Min: 0, Max: 10, Desired: 1

### Production Deployment
#### API Gateway
- **Image**: `public.ecr.aws/s0p6q3j7/api-gateway:v0.0.2-beta-2-e61f743`
- **Port**: 8080 (container) → 80 (service)
- **Replicas**: 1
- **Namespace**: devtube

#### SSL/TLS
- **Certificate ARN**: `arn:aws:acm:ap-southeast-1:564439693649:certificate/3a6cdb8f-c952-42c3-84f5-235d9747fc55`
- **Redirect**: HTTP → HTTPS
- **Ports**: 80 (HTTP), 443 (HTTPS)

## Triển khai Infrastructure

### Yêu cầu tiên quyết
- AWS CLI đã được cấu hình với appropriate permissions
- Terraform >= 1.0
- kubectl
- Helm (được cài đặt tự động thông qua Terraform)

### Bước 1: Deploy Infrastructure với Terraform
```bash
cd tf/
terraform init
terraform plan
terraform apply
```

**Thời gian**: ~20-25 phút

**Terraform sẽ tạo:**
- VPC và networking components
- EKS cluster với node groups
- AWS Load Balancer Controller
- Metrics Server
- Cluster Autoscaler
- Tất cả IAM roles và policies cần thiết

### Bước 2: Cấu hình kubectl
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name prod-devtube
```

### Bước 3: Verify Deployment
```bash
# Kiểm tra pods
kubectl get pods

# Kiểm tra services
kubectl get services 

# Kiểm tra ingress
kubectl get ingress
```

## Quản lý Ứng dụng

### Kiểm tra trạng thái
```bash
# Pods
kubectl get pods
kubectl logs -f deployment/api-gateway-deployment

# Services
kubectl get services 

# Ingress
kubectl describe ingress ingress-api-gateway
```

### Scale ứng dụng
```bash
kubectl scale deployment api-gateway-deployment --replicas=3 
```

### Update image
```bash
kubectl set image deployment/api-gateway-deployment api-gateway=public.ecr.aws/s0p6q3j7/api-gateway:NEW_TAG 
```

### Xem logs
```bash
kubectl logs -f deployment/api-gateway-deployment 
```

## Staging Environment
Thư mục `stg/` chứa các cấu hình cho môi trường staging:
- API Gateway configurations
- Authentication service
- Upload service

Deploy staging services:
```bash
kubectl apply -f stg/api-gateway/k8s.yaml
kubectl apply -f stg/auth-service/k8s.yaml
kubectl apply -f stg/video-service/k8s.yaml
```

## Monitoring và Troubleshooting

### Kiểm tra cluster health
```bash
kubectl cluster-info
kubectl get nodes
kubectl top nodes
kubectl top pods 
```

### Pod không start
```bash
kubectl describe pod <pod-name> 
kubectl logs <pod-name> 
```

### Ingress không hoạt động
```bash
kubectl describe ingress ingress-api-gateway 
kubectl logs -n kube-system deployment.apps/aws-load-balancer-controller
```

### SSL Certificate issues
- Kiểm tra certificate ARN trong configuration
- Verify certificate status trong AWS ACM console
- Confirm domain ownership

## Cleanup

### Xóa Applications
```bash
kubectl delete -f <all `k8s.yaml`>
kubectl delete -f ingressClass.yaml
```

### Xóa Infrastructure
```bash
cd tf/
terraform destroy
```

**Lưu ý**: Terraform destroy sẽ xóa toàn bộ infrastructure, bao gồm VPC, EKS cluster, và tất cả tài nguyên liên quan.

## Tài liệu tham khảo
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Kiến trúc hệ thống chi tiết
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Hướng dẫn triển khai chi tiết
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
