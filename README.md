# cilsy-list
BIG PROJECT

BIG PROJECT STEP

1. provision EKS, RDS, etc.
2. install needed add-on
3. use repo rvnaras/cilsy-list
4. configure RDS MySQL
5. install kube metric server (IS A MUST!!!) kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
6. install jenkins, follow ref 8-DO-CICD-P8
7. install argocd, follow ref 8-DO-CICD-P8
8. install argo-rollouts, follow ref 8-DO-CICD-P8
9. install argo-image-updater, follow ref 8-DO-CICD-P8
10. install nginx ingress
11. setup jenkins, credentials (argocd-url, argocd, github, docker), pipeline (staging, production), webhook (staging)
12. setup argocd application (staging, production)
13. wait sync, check all staging and production environment (services, pod, rollouts, hpa, etc.)



TO BE LISTED
- install prometheus grafana
- install EFK stack
- promote preview production to real live production
- use argo image updater
- set domain route53
- use different database staging and production but same RDS
