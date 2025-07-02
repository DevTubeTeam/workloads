# DevTube - AWS EKS Deployment

## Tổng quan
DevTube là một ứng dụng microservices được triển khai trên Amazon EKS (Elastic Kubernetes Service) với kiến trúc API Gateway và các dịch vụ backend.

## Kiến trúc hệ thống

```
Internet → ALB Ingress → API Gateway Service → API Gateway Pod
                     ↘ Auth Service (staging)
                     ↘ Upload Service (staging)
```

## Cấu trúc thư mục
```
workloads/
├── cluster-config.yaml    # Cấu hình EKS cluster
├── ingressClass.yaml      # Cấu hình ALB Ingress Controller
├── new-dep.yaml          # Deployment chính cho production
└── stg/                  # Staging environment
    ├── api-gateway/      # API Gateway staging configs
    ├── auth-service/     # Authentication service configs
    └── upload-service/   # Upload service configs
```

## Cấu hình chi tiết

### 1. EKS Cluster (cluster-config.yaml)
- **Tên cluster**: devtube
- **Region**: ap-southeast-1 (Singapore)
- **Mode**: Auto Mode (quản lý tự động)

### 2. Production Deployment (new-dep.yaml)
#### API Gateway
- **Image**: `public.ecr.aws/s0p6q3j7/api-gateway:v0.0.2-beta-2-e61f743`
- **Port**: 8080 (container) → 80 (service)
- **Replicas**: 1
- **Namespace**: devtube

#### SSL/TLS
- **Certificate ARN**: `arn:aws:acm:ap-southeast-1:564439693649:certificate/3a6cdb8f-c952-42c3-84f5-235d9747fc55`
- **Redirect**: HTTP → HTTPS
- **Ports**: 80 (HTTP), 443 (HTTPS)

## Hướng dẫn triển khai

### Yêu cầu tiên quyết
- AWS CLI đã được cấu hình
- kubectl
- eksctl
- Quyền truy cập AWS với các permissions cần thiết

### Bước 1: Tạo EKS Cluster
```bash
eksctl create cluster -f cluster-config.yaml
```
**Thời gian**: ~15-20 phút

### Bước 2: Cài đặt ALB Ingress Controller
```bash
kubectl apply -f ingressClass.yaml
```

### Bước 3: Tạo Namespace
```bash
kubectl create namespace devtube --save-config
```

### Bước 4: Deploy ứng dụng
```bash
kubectl apply -f new-dep.yaml
```

### Bước 5: Kiểm tra Ingress
```bash
kubectl get ingress -n devtube
```

### Bước 6: Cấu hình DNS
1. Lấy địa chỉ ALB từ output của bước 5
2. Truy cập địa chỉ này qua trình duyệt để kiểm tra
3. Cập nhật DNS record tại Namecheap với địa chỉ ALB

## Kiểm tra trạng thái

### Pods
```bash
kubectl get pods -n devtube
kubectl logs -f deployment/api-gateway-deployment -n devtube
```

### Services
```bash
kubectl get services -n devtube
```

### Ingress
```bash
kubectl describe ingress ingress-api-gateway -n devtube
```

## Quản lý

### Scale ứng dụng
```bash
kubectl scale deployment api-gateway-deployment --replicas=3 -n devtube
```

### Update image
```bash
kubectl set image deployment/api-gateway-deployment api-gateway=public.ecr.aws/s0p6q3j7/api-gateway:NEW_TAG -n devtube
```

### Xem logs
```bash
kubectl logs -f deployment/api-gateway-deployment -n devtube
```

## Staging Environment
Thư mục `stg/` chứa các cấu hình cho môi trường staging với:
- API Gateway configurations
- Authentication service
- Upload service

## Xử lý sự cố

### Pod không start
```bash
kubectl describe pod <pod-name> -n devtube
kubectl logs <pod-name> -n devtube
```

### Ingress không hoạt động
```bash
kubectl describe ingress ingress-api-gateway -n devtube
# Kiểm tra ALB Controller logs
kubectl logs -n kube-system deployment.apps/aws-load-balancer-controller
```

### SSL Certificate issues
- Đảm bảo certificate ARN đúng
- Kiểm tra certificate status trong AWS ACM
- Verify domain ownership

## Cleanup
```bash
kubectl delete -f new-dep.yaml
kubectl delete namespace devtube
eksctl delete cluster devtube
```

## Liên hệ & Hỗ trợ
- Repository: [GitHub Repository URL]
- Issues: [GitHub Issues URL]
- Documentation: [Documentation URL]
