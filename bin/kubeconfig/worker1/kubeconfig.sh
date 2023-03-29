#!/bin/bash

########################## Kubelet ##################################
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../ca.pem \
  --embed-certs=true \
  --server=https://192.168.1.121:6443 \
  --kubeconfig=worker1.kubeconfig

kubectl config set-credentials system:node:tp-srv-worker-01 \
  --client-certificate=../../worker1.pem \
  --client-key=../../worker1-key.pem \
  --certificate-authority=../../ca.pem \
  --embed-certs=true \
  --kubeconfig=worker1.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:node:tp-srv-worker-01 \
  --kubeconfig=worker1.kubeconfig

kubectl config use-context default --kubeconfig=worker1.kubeconfig

######################## Proxy ####################################

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../ca.pem \
  --embed-certs=true \
  --server=https://192.168.1.121:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=../../kube-proxy.pem \
  --client-key=../../kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

######################################################################