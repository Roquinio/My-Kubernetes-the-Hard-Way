# Kubernetes Partie 2

## Introduction

### Membres

- ROQUES Baptiste 5SRC4
- MOUROT Damien 5SRC4

### Objectif

Ce repository présente l'installation d'un cluster **Kubernetes** via le guide *Kubernetes the Hard Way*.

Notre infrastructure sera composé de :
- 2 serveurs Master :
    - 192.168.1.121
    - 192.168.1.122
- 2 serveurs Worker :
    - 192.168.1.123
    - 192.168.1.124


### Prérequis

Pour commencer le guilde nous devons installer les binaires suivants:
- kubectl 1.26.0
- cfssl
- cfssljson

Nous avons choisi d'installer les dépendances via Ansible pour exécuter les commandes en parallèles sur tout les serveurs en même temps.

### Structure
```
folder
    |
    -> inventory
            |----> inventory.ini
    -> playbook
            |----> requirement.yml
```

### Playbook Ansible
```
- hosts:
    - datacenter
  gather_facts: yes  
  become: yes
  tasks: 
    - name: download requirement
      get_url:
        url: "{{ item }}"
        dest: /usr/local/bin/
        mode: '0755'
      loop:
        - https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl
        - https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson
        - https://storage.googleapis.com/kubernetes-release/release/v1.26.0/bin/linux/amd64/kubectl

```

### Fichier d'inventaire
```
[datacenter]
192.168.1.121
192.168.1.122
192.168.1.123
192.168.1.124


[master]
192.168.1.121
192.168.1.122

[worker]
192.168.1.123
192.168.1.124

[datacenter:vars]
ansible_connection=ssh
ansible_ssh_user=root
ansible_ssh_pass=****
```

### Commande

```
ansible-playbook -i inventory/inventory.ini  playbook/requirement.yml
```

Avec cette dernière commande, nos noeuds possède les paquets nécessaire pour ammorcer le guide *Kubernetes the Hard Way*.

## Création des certificats

Dans cette partie nous aborderons la création d'une autorité de certification et de divers certificats pour nos diverses briques tel que :
- Authorité de certification
- Certificat *admin*
- Certificat *kubelet*
- Certificat *controller manager*
- Certificat *kube proxy*
- Certificat *scheduler*
- Certificat *kube API*
- Certificat *service account key pair*

### Authorité de certification

Dans ce bloc nous aborderons la création d'une authorité de certification qui va nous permettre de générer nos certificats par la suite :

```
#!/bin/bash

{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}
```

### Certificat Admin

Pour créer le certificat du user **Admin** vous pouvez effectuer la commande suivante : 
```
#!/bin/bash

{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}
```

### Certificat kubelet

Pour la création des certificats des kubelet nous allons donc faire un certificat par **worker** :
```
#!/bin/bash
for instance in worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ile-de-France"
    }
  ]
}
EOF


cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance}\
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done
```

> ⚠ Veuillez adapter vos commandes en fonctions de votre nombre de **worker**.

### Certificat controller manager

```
#!/bin/bash

{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager2

}
```

### Certificat kube-proxy

```
#!/bin/bash

{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}
```

### Certificat scheduler

```
#!/bin/bash

{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}
```

### Certificat kube API 

```
#!/bin/bash

{

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=192.168.1.121,192.168.1.122,192.168.1.123,192.168.1.124,127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}
```
> ⚠ Veuillez adapter vos commandes avec les IP de vos noeuds.

### Certificat service account key pair

```
#!/bin/bash

{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Paris",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ile-de-France"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}
```

### Resultat

Après avoir créer les certificats ci-dessus, vous devriez avoir une arborescences tel que :

```
folder -->
          ca
            |---> ca-key.pem
            |---> ca.pem
          admin
            |---> admin-key.pem
            |---> admin.pem
          kubelet
            |---> worker-1-key.pem
            |---> worker-1.pem
            |---> worker-2-key.pem
            |---> worker-2.pem
          controller
            |---> kube-controller-manager-key.pem
            |---> kube-controller-manager.pem
          proxy
            |---> kube-proxy-key.pem
            |---> kube-proxy.pem
          scheduler
            |---> kube-scheduler-key.pem
            |---> kube-scheduler.pem
          api
            |---> kubernetes-key.pem
            |---> kubernetes.pem
          sakp
            |---> service-account-key.pem
            |---> service-account.pem
```

### Transfert

Maintenant que nos certificats ont été crées depuis notre client, nous allons les envoyer sur nos noeuds les certificats necessaire à chacun : 

- **Worker** : 
  - ca.pem 
  - worker-<numéro>-key.pem 
  - worker-<numéro>.pem
- **Controller** :
  - ca.pem 
  - ca-key.pem 
  - kubernetes-key.pem 
  - kubernetes.pem
  - service-account-key.pem 
  - service-account.pem

Pour effectuer l'opération nous avons choisi d'utiliser **Ansible** encore une fois : 

### Inventaire :

```
[datacenter]
192.168.1.121
192.168.1.122
192.168.1.123
192.168.1.124

#################################

[master]
192.168.1.121
192.168.1.122

[master1]
192.168.1.121

[master2]
192.168.1.122

###################################

[worker]
192.168.1.123
192.168.1.124

[worker1]
192.168.1.123

[worker2]
192.168.1.124

#######################################

[datacenter:vars]
ansible_connection=ssh
ansible_ssh_user=root
ansible_ssh_pass=****
```

### Playbook

```
- hosts:
    - datacenter
  gather_facts: yes  
  become: yes
  tasks: 
    - name: Create directory
      file:
        path: /srv/cert
        state: directory
        mode: '0755'

    - name: Upload cert on Worker1
      when: inventory_hostname in groups['worker1']
      copy: 
        src: "../../bin/{{ item }}"
        dest: "/srv/cert/{{ item }}"
        owner: root
        group: root
      loop:
        - ca.pem
        - worker-1-key.pem
        - worker-1.pem

    - name: Upload cert on Worker2
      when: inventory_hostname in groups['worker2']
      copy: 
        src: "../../bin/{{ item }}"
        dest: "/srv/cert/{{ item }}"
        owner: root
        group: root
      loop:
        - ca.pem
        - worker-2-key.pem
        - worker-2.pem

    - name: Upload cert on Master
      when: inventory_hostname in groups['master']
      copy: 
        src: "../../bin/{{ item }}"
        dest: "/srv/cert/{{ item }}"
        owner: root
        group: root
      loop:
        - ca.pem
        - ca-key.pem
        - kubernetes-key.pem 
        - kubernetes.pem
        - service-account-key.pem 
        - service-account.pem
```

### Commande

```
ansible-playbook -i inventory/inventory.ini  playbook/cert.yml
```


tout ce qui contient : https://${KUBERNETES_PUBLIC_ADDRESS} doit être dédoubler en fonction de la brique
127.0.0.1 = pas besoin de doubler



## Création des Kubeconfig

Dans cette partie nous allons généré les kubeconfig pour le controller-mananager, kubelet, kube-proxy, scheduler & admin.


### Kubelet

```
########################## Kubelet for worker1 ##################
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
```

> ⚠ Veuillez adapter vos commandes avec les IP de vos noeuds.

Output : ```worker1.kubeconfig```

### Kube-proxy

```
######################## Kube-Proxy for worker1 ####################################

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
```

Output : ```kube-proxy.kubeconfig```

### Kube-Scheduller

```
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
```

Output : ```kube-scheduler.kubeconfig```

### Admin user

```
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
```

Output : ```admin.kubeconfig```

### Transfert 

Veuillez transférer les fichiers fraichement créé sur vos serveurs.

## Chiffrement

Nous allons créer une configuration et une clé de de chiffrement pour encrypter les secrets stockés dans le cluster.

### Clé

Pour générer votre clé vous pouvez créer la ressource suivante : 
```
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
```

Ce fichier de configuration sera à déposer sur vos serveurs master.

## ETCD

L'installation du cluster etcd doit se faire sur nos deux serveurs master, nous le ferons via ansible : 

### Playbook

```
- hosts:
    - master
  gather_facts: yes  
  become: yes
  tasks: 
    - name: download etcd     
      get_url:
        url: "https://github.com/etcd-io/etcd/releases/download/v3.4.24/etcd-v3.4.24-linux-amd64.tar.gz"
        dest: /tmp
        mode: '0666'
        
    - name: Extract etcd archive
      unarchive:
        src: /tmp/etcd-v3.4.24-linux-amd64.tar.gz
        dest: /tmp
        remote_src: yes

    - name: Move etcd binaries
      copy:
        src: "/tmp/etcd-v3.4.24-linux-amd64/{{ item }}"
        dest: /usr/local/bin/
        owner: root
        group: root
        mode: '0755'
        remote_src: yes
      loop:
        - etcd
        - etcdctl

    - name: Create etcd directory
      file:
        path: "{{ item }}"
        state: directory
        mode: '0700'
      loop:
        - /etc/etcd
        - /var/lib/etcd
      
    - name: Moove certificate
      copy:
        src: "/srv/cert/{{ item }}" 
        dest: /etc/etcd/
        owner: root
        group: root
        mode: '0755'
        remote_src: yes
      loop:
        - ca.pem
        - kubernetes-key.pem
        - kubernetes.pem

    - name: Create etcd service
      template:
        src: ../template/etcd.j2
        dest: /etc/systemd/system/etcd.service
        mode: 0644
    
    - name: Reload Daemon Systemd
      systemd:
        daemon_reload: true
    
    - name: Start etcd service
      systemd:
        name: etcd
        state: started
        enabled: true
```

#### Etcd service

```
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name {{ ansible_hostname }} \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://{{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }}:2380 \
  --listen-peer-urls https://{{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }}:2380 \
  --listen-client-urls https://{{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }}:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://{{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }}:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster tp-srv-master-01=https://192.168.1.121:2380,tp-srv-master-02=https://192.168.1.122:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### Vérification 

Depuis l'un des master faite la commande suivante pour vérifier le fonctionnement de l'etcd 
```
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
  ```

## Control-plane

L'installation du service control-plane doit se faire sur nos deux serveurs master, nous le ferons via ansible : 

```
- hosts:
    - master
  gather_facts: yes  
  become: yes
  tasks: 
    - name: Create the Kubernetes configuration directory
      file:
        path: "{{ item }}"
        state: directory
        mode: '0644'
      loop:
        - /etc/kubernetes/config
        - /var/lib/kubernetes/

    - name: Download the official Kubernetes release binaries
      get_url:
        url: "{{ item }}"
        dest: /usr/local/bin/
        mode: '0755'
      loop:
      - https://storage.googleapis.com/kubernetes-release/release/v1.26.0/bin/linux/amd64/kube-apiserver
      - https://storage.googleapis.com/kubernetes-release/release/v1.26.0/bin/linux/amd64/kube-controller-manager
      - https://storage.googleapis.com/kubernetes-release/release/v1.26.0/bin/linux/amd64/kube-scheduler

    - name: Moove certificate & kubeconfig
      copy:
        src: "/srv/cert/{{ item }}" 
        dest: /var/lib/kubernetes/
        owner: root
        group: root
        mode: '0755'
        remote_src: yes
      loop:
        - ca.pem
        - ca-key.pem
        - kubernetes-key.pem
        - kubernetes.pem
        - service-account-key.pem
        - service-account.pem
        - encryption-config.yaml
        - kube-controller-manager.kubeconfig
        - kube-scheduler.kubeconfig

    - name: Create Kube API service
      template:
        src: ../template/kubeapi.j2
        dest: /etc/systemd/system/kube-apiserver.service
        mode: 0644
    
    - name: Create Kube Controller Manager service
      template:
        src: ../template/kubemngt.j2
        dest: /etc/systemd/system/kube-controller-manager.service
        mode: 0644

    - name: Upload scheduler configuration
      copy: 
        src: "../etc/kube-scheduler.yaml"
        dest: "/etc/kubernetes/config/"
        owner: root
        group: root

    - name: Create Kube scheduler service
      template:
        src: ../template/kubescheduler.j2
        dest: /etc/systemd/system/kube-scheduler.service
        mode: 0644

    - name: Reload Daemon Systemd
      systemd:
        daemon_reload: true
    
    - name: Start Kubernetes service
      systemd:
        name: "{{ item }}"
        state: started
        enabled: true
      loop: 
        - kube-apiserver 
        - kube-controller-manager 
        - kube-scheduler

    - name: Update apt-get repo and cache
      apt: update_cache=yes force_apt_get=yes

    - name: Install nginx
      apt:
        name: nginx
        state: latest

    - name: Upload nginx configuration
      copy: 
        src: "../etc/kubernetes.default.svc.cluster.local"
        dest: "/etc/nginx/sites-available/kubernetes.default.svc.cluster.local"
        owner: root
        group: root

    - name: Create a symbolic link for nginx conf
      file:
        src: /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
        dest: /etc/nginx/sites-enabled/kubernetes.default.svc.cluster.local
        owner: root
        group: root
        state: link

    - name: Reload Daemon Systemd
      systemd:
        daemon_reload: true
    
    - name: Restart etcd service
      systemd:
        name: nginx
        state: restarted
        enabled: true

    - name: Upload RBAC configuration
      copy:
        src: "../etc/rbac.yaml"
        dest: "/etc/kubernentes/config/"
        owner: root
        group: root

    - name: Apply RBAC configuration
      when: inventory_hostname in groups['master1']
      shell: kubectl apply --kubeconfig /srv/cert/admin.kubeconfig -f /etc/kubernentes/config/rbac.yaml
```


## Configuration des noeuds worker

Pour configurer nos noeuds worker, nous allons utiliser ansible :

### Playbook

```- hosts:
    - worker
  gather_facts: yes  
  become: yes
  vars:
    worker1:
      - "worker1.pem"
      - "worker1-key.pem"
      - "worker1.kubeconfig"
    worker2:
      - "worker2.pem"
      - "worker2-key.pem"
      - "worker2.kubeconfig"

  tasks: 
    - name: Update apt-get repo and cache
      apt: update_cache=yes force_apt_get=yes

    - name: Install OS dependencies
      apt:
        name: "{{ item }}"
        state: latest
      loop:
        - socat 
        - conntrack 
        - ipset

    - name: Create the installation directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0644'
      loop:
        - /etc/cni/net.d
        - /opt/cni/bin
        - /var/lib/kubelet
        - /var/lib/kube-proxy
        - /var/lib/kubernetes
        - /var/run/kubernetes
        - /srv/kube-bin
        - /srv/kube-bin/containerd
        - /etc/containerd/
    
    - name: Download the official Kubernetes release binaries
      get_url:
        url: "{{ item }}"
        dest: /srv/kube-bin
        mode: '0755'
      loop:
      - https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.26.0/crictl-v1.26.0-linux-amd64.tar.gz
      - https://github.com/opencontainers/runc/releases/download/v1.0.0-rc93/runc.amd64
      - https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz
      - https://github.com/containerd/containerd/releases/download/v1.7.0/containerd-1.7.0-linux-amd64.tar.gz
      - https://storage.googleapis.com/kubernetes-release/release/v1.26.0/bin/linux/amd64/kubectl
      - https://storage.googleapis.com/kubernetes-release/release/v1.26.0/bin/linux/amd64/kube-proxy
      - https://storage.googleapis.com/kubernetes-release/release/v1.26.0/bin/linux/amd64/kubelet

    - name: Extract binaries archive
      unarchive:
        src: "/srv/kube-bin/{{ item }}"
        dest: /srv/kube-bin
        remote_src: yes
      loop:
        - crictl-v1.26.0-linux-amd64.tar.gz
        - containerd-1.7.0-linux-amd64.tar.gz

    - name: Moove Containerd binaries
      copy:
        mode: '0755'
        src: "/srv/kube-bin/bin/{{ item }}"
        dest: /bin
        remote_src: yes
      loop:
        - containerd  
        - containerd-shim  
        - containerd-shim-runc-v1  
        - containerd-shim-runc-v2  
        - ctr

    - name: Extract CNI archive
      unarchive:
        src: /srv/kube-bin/cni-plugins-linux-amd64-v0.9.1.tgz
        dest: /opt/cni/bin/
        remote_src: yes

    - name: Rename runc
      copy:
        mode: '0755'
        src: /srv/kube-bin/runc.amd64
        dest: /usr/local/bin/runc
        remote_src: yes

    - name: Moove binaries
      copy:
        src: "/srv/kube-bin/{{ item }}" 
        dest: /usr/local/bin/
        owner: root
        group: root
        mode: '0755'
        remote_src: yes
      loop:
        - crictl 
        - kubectl 
        - kube-proxy 
        - kubelet

    - name: Upload CNI configurations
      copy:
        src: "../etc/{{ item }}"
        dest: /etc/cni/net.d/
        owner: root
        group: root
        mode: '0644'
      loop:
        - 10-bridge.conf
        - 99-loopback.conf


    - name: Upload containerd configuration
      copy:
        src: ../etc/containerd.toml
        dest: /etc/containerd/config.toml
        owner: root
        group: root
        mode: '0644'
    
    - name: Upload containerd service
      template:
        src: ../template/containerd.j2
        dest: /etc/systemd/system/containerd.service
        mode: 0644

    - name: Moove certificate  for worker1
      when: inventory_hostname in groups['worker1']
      copy:
        src: "/srv/cert/{{ item }}"
        dest: /var/lib/kubelet/
        mode: '0644'
        remote_src: yes
      loop:
        - worker1.pem
        - worker1-key.pem

    - name: Moove kubeconfig for worker1
      when: inventory_hostname in groups['worker1']
      copy:
        src: /srv/cert/worker1.kubeconfig
        dest: /var/lib/kubelet/kubeconfig
        remote_src: yes
        mode: '0644'

    - name: Moove certificate  for worker2
      when: inventory_hostname in groups['worker2']
      copy:
        src: "/srv/cert/{{ item }}"
        dest: /var/lib/kubelet/
        mode: '0644'
        remote_src: yes
      loop:
        - worker2.pem
        - worker2-key.pem

    - name: Moove kubeconfig for worker2
      when: inventory_hostname in groups['worker2']
      copy:
        src: /srv/cert/worker2.kubeconfig
        dest: /var/lib/kubelet/kubeconfig
        remote_src: yes
        mode: '0644'
    
    - name: Moove CA
      copy:
        src: /srv/cert/ca.pem
        dest: /var/lib/kubernetes/
        remote_src: yes
        mode: '0644'
    
    - name: Upload kubelet configuration
      template:
        src: ../template/kubelet-config.j2
        dest: /var/lib/kubelet/kubelet-config.yaml
        mode: 0644
        
    - name: Upload kubelet service
      template:
        src: ../template/kubelet-service.j2
        dest: /etc/systemd/system/kubelet.service
        mode: 0644

    - name: Copy kube-proxy kubeconfig
      copy:
        src: /srv/cert/kube-proxy.kubeconfig
        dest: /var/lib/kube-proxy/kubeconfig
        remote_src: yes
        mode: '0644'
    
    - name: Upload kube-proxy configuration
      copy:
        src: ../etc/kube-proxy-config.yaml
        dest: /var/lib/kube-proxy/kube-proxy-config.yaml
        owner: root
        group: root
        mode: '0644'

    - name: Upload kube-proxy service
      template:
        src: ../template/kube-proxy.j2
        dest: /etc/systemd/system/kube-proxy.service
        mode: 0644

    - name: Reload Daemon Systemd
      systemd:
        daemon_reload: true
    
    - name: Start Kubernetes service
      systemd:
        name: "{{ item }}"
        state: started
        enabled: true
      loop: 
        - containerd 
        - kubelet
        - kube-proxy
```


### Vérification 

Pour vérifier que vos worker nodes sont bien configurés, faites la commande suivantes depuis l'un de vos master :

```kubectl get nodes --kubeconfig admin.kubeconfig```

## Accès distant au cluster 

Pour que votre client ait accès au cluster, veuillez exécuter la commande suivante : 

```
#!/bin/bash
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../../ca.pem \
    --embed-certs=true \
    --server=https://192.168.1.121:6443

  kubectl config set-credentials admin \
    --client-certificate=../../admin.pem \
    --client-key=../../admin-key.pem

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
```

### Test

Pour tester l'accès distant à votre cluster : 

```kubectl get nodes```

Le retour attendu est l'affichage de vos noeuds.


## CoreDNS

Depuis votre client, déployer le module CoreDNS : 

```kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.8.yaml```

Output : 

```
serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.apps/coredns created
service/kube-dns created
```

### Test

Pour tester le bon fonctionnement du module CoreDNS : 

```
kubectl run busybox --image=busybox:1.28 --command -- sleep 3600
```
Liste des pods busybox

```
kubectl get pods -l run=busybox
```

Récupération du nom complet du pods

```
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
```

Requête DNS dans le pods busybox : 

```
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```

## Test final

### Test d'encryption 

Création d'un secret

```
kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"
```

Vérification 

```
ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem\
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C
  ```

### Test d'un déploiement 

Création d'un déploiement 

```kubectl create deployment nginx --image=nginx```

Liste des pods nginx 
 ```kubectl get pods -l app=nginx```

### Accès distant au pods 

Récupération du nom du pods
```POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")```

Redirection
```kubectl port-forward $POD_NAME 8080:80```

Dans un nouveau terminal, tester l'accès au pod nginx : 

```curl --head http://127.0.0.1:8080```

### Logs

Testez l'accès à vos logs : 
```kubectl logs $POD_NAME```

### Execute 

Test de commande dans un pods :

```kubectl exec -ti $POD_NAME -- nginx -v```

### Service

Exposer le port 80 du déploiement nginx via le node port 
```kubectl expose deployment nginx --port 80 --type NodePort```



## Conclusion

Félicitation vous avez accompli le kubernetes the hard way