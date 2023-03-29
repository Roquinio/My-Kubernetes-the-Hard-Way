#!/bin/bash
# for instance in worker-1 worker-2; do
cat > worker2-csr.json <<EOF
{
  "CN": "system:node:tp-srv-worker-02",
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
  -hostname=tp-srv-worker-02,192.168.1.124 \
  -profile=kubernetes \
  worker2-csr.json | cfssljson -bare worker2
# done

