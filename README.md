# cilsy-list
BIG PROJECT

BIG PROJECT STEP

1. provision EKS, RDS, etc.
2. install needed eks add-on
3. use repo rvnaras/cilsy-list
4. configure RDS MySQL
5. install kube metric server (IS A MUST!!!) kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
6. install jenkins, follow ref 8-DO-CICD-P8
7. install argocd, follow ref 8-DO-CICD-P8
8. install argo-rollouts, follow ref 8-DO-CICD-P8
9. install argo-image-updater, follow ref 8-DO-CICD-P8
10. create secret token github for argo image updater, kubectl --namespace argocd create secret generic git-creds --from-literal=username=<username> --from-literal=password=<token>
10. install nginx ingress, setup to route53
11. setup jenkins, credentials (argocd-url, argocd, github, docker), pipeline (staging, production), webhook (staging)
12. install prometheus grafana, follow ref 9-DO-MON-P9, add alerting to telegram
13. install EFK, follow ref 9-DO-MON-P9, setup dashboard
14. install staging and production argo application yaml
15. test staging pipeline
16. test production pipeline
17. check argocd dashboard, production status will be suspended
18. check argo rollout dashboard, kubectl argo rollouts dashboard
19. promote staging app to production
