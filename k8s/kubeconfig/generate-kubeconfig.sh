#!/bin/bash
# 每个对应一个namespace，用户名和namespace名称相同
# 注意修改KUBE_APISERVER为你的API Server的地址
KUBE_APISERVER=$1
USER=$2
REGION=$3
USAGE="USAGE: create-user.sh <api_server> <username>  <region>\n
Example: https://172.22.1.1:6443 brand py04"
CSR=`pwd`/user-csr.json
SSL_PATH="/etc/kubernetes/ssl"
SSL_FILES=(ca-key.pem ca.pem ca-config.json)
CERT_FILES=(${USER}.csr $USER-key.pem ${USER}.pem)

if [[ $KUBE_APISERVER == "" ]]; then
   echo -e $USAGE
   exit 1
fi
if [[ $USER == "" ]];then
    echo -e $USAGE
    exit 1
fi
if [[ $REGION == "" ]];then
    echo -e $USAGE
    exit 1
fi

# 创建用户的csr文件
function createCSR(){
cat>$CSR<<EOF
{
  "CN": "USER",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
# 替换csr文件中的用户名
sed -i "s/USER/$USER/g" $CSR
}

function ifExist(){
if [ ! -f "$SSL_PATH/$1" ]; then
    echo "$SSL_PATH/$1 not found."
    exit 1
fi
}

# 判断证书文件是否存在
for f in ${SSL_FILES[@]};
do
    echo "Check if ssl file $f exist..."
    ifExist $f
    echo "OK"
done

echo "Create CSR file..."
createCSR
echo "$CSR created"
echo "Create user's certificates and keys..."
cd $SSL_PATH
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes $CSR| cfssljson -bare $USER
cd -

# 设置集群参数
kubectl config set-cluster ${REGION} \
--certificate-authority=${SSL_PATH}/ca.pem \
--embed-certs=true \
--server=${KUBE_APISERVER} \
--kubeconfig=${USER}.kubeconfig

# 设置客户端认证参数
kubectl config set-credentials $USER \
--client-certificate=$SSL_PATH/${USER}.pem \
--client-key=$SSL_PATH/${USER}-key.pem \
--embed-certs=true \
--kubeconfig=${USER}.kubeconfig

# 设置上下文参数
kubectl config set-context ${REGION} \
--cluster=${REGION} \
--user=$USER \
--namespace=default \
--kubeconfig=${USER}.kubeconfig

# 设置默认上下文
kubectl config use-context ${REGION} --kubeconfig=${USER}.kubeconfig

# 绑定角色
kubectl create rolebinding ${USER}-view-binding --clusterrole=view --user=$USER

kubectl config get-contexts

echo "Congratulations!"
echo "Your kubeconfig file is ${USER}.kubeconfig"