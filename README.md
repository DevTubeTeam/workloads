# workloads
Deploy to eks
1. eksctl create cluster -f cluster-config.yaml
2. kubectl apply -f ingressClass.yaml
3. kubectl create namespace devtube --save-config
4. kubectl apply -f new-dep.yaml
5. kubectl get ingress -n devtube
6. Get the ADDRESS of step 5 go to browser
