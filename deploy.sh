#!/usr/bin/bash
echo "INFO: wordpress-stack init script is running..."
which kubectl &> /dev/null

if [ $? -ne 0 ]; then
    echo "ERROR: kubectl is not installed."
    exit 1
fi

kubectl get ns wordpress-stack &> /dev/null

if [ $? -eq 0 ]; then
    echo "INFO: wordpress-stack is already deployed."
    exit 0
fi

echo "INFO: Creating PVs"
kubectl apply -f pv.yaml


echo "Create  wordpress-stack namespace"
kubectl create ns wordpress-stack


echo "INFO: Creating  services..."
kubectl apply -f FileBrowser/svc.yaml
kubectl apply -f MySQL/svc.yaml
kubectl apply -f Poste.io/svc.yaml
kubectl apply -f phpMyAdmin/svc.yaml
kubectl apply -f WordPress/svc.yaml



echo "INFO: Creating  PVCs..."
kubectl apply -f MySQL/pvc.yaml
kubectl apply -f Poste.io/pvc.yaml
kubectl apply -f WordPress/pvc.yaml


echo "INFO: Creating self-sgined SSL for mail.dwsclass.io"
mkdir -p Cert
openssl req -newkey rsa:4096 \
            -x509 \
            -sha256 \
            -days 3650 \
            -nodes \
            -out Cert/mail.dwsclass.io.crt \
            -keyout Cert/mail.dwsclass.io.key \
            -subj "/CN=mail.dwsclass.io"

echo "INFO: Creating Configs and Secrets..."
kubectl -n wordpress-stack create secret tls mail.dwsclass --cert=Cert/mail.dwsclass.io.crt --key=Cert/mail.dwsclass.io.key
kubectl -n wordpress-stack create configmap mail-server-ini-file  --from-file=Poste.io/data/server.ini
kubectl -n wordpress-stack create configmap mail-userdb-file  --from-file=Poste.io/data/users.db
kubectl -n wordpress-stack create configmap mail-davdb-file  --from-file=Poste.io/data/dav.db
kubectl apply -f MySQL/secret.yaml
kubectl apply -f Poste.io/cm.yaml
kubectl apply -f phpMyAdmin/cm.yaml
kubectl apply -f WordPress/secret.yaml


echo "INFO:  Going to deploy Backing Service..."
kubectl apply -f MySQL/deploy.yaml

echo "INFO:  Going to deploy File Browser..."
kubectl apply -f FileBrowser/deploy.yaml

echo "INFO: Going to deploy WordPress"
kubectl apply -f WordPress/deploy.yaml

echo "INFO:  Going to deploy Poste.io Mail Server..."
kubectl apply -f Poste.io/deploy.yaml

echo "INFO: Going to deploy phpMyAdmin..."
kubectl apply -f phpMyAdmin/deploy.yaml


echo "INFO:  Creating Ingress..."
kubectl apply -f FileBrowser/ingress.yaml
kubectl apply -f Poste.io/ingress.yaml
kubectl apply -f phpMyAdmin/ingress.yaml
kubectl apply -f WordPress/ingress.yaml

# Get address of services
WORDPRESS_ADDR=$(kubectl -n wordpress-stack get ingress  wordpress -o json |jq .spec.rules[0].host|tr -d '"')
FILE_BROWSER_ADDR=$(kubectl -n wordpress-stack get ingress  filebrowser -o json |jq .spec.rules[0].host|tr -d '"')
MAIL_ADDR=$(kubectl -n wordpress-stack get ingress  mail -o json |jq .spec.rules[0].host|tr -d '"')
PHPMYADMIN_ADDR=$(kubectl -n wordpress-stack get ingress  phpmyadmin -o json |jq .spec.rules[0].host|tr -d '"')

echo "INFO: wordpress-stack deployed successfully."

echo "INFO: Deployment preparation may take a while."

sleep 10

cat <<EOL

WordPress URL: http://$WORDPRESS_ADDR
File Browser URL: http://$FILE_BROWSER_ADDR
phpMyAdmin URL: http://$PHPMYADMIN_ADDR
Mail Server URL: https://$MAIL_ADDR
----------- Poste.io Credential -----------
Admin User: admin@dwsclass.io
Admin Pass: admin
----------- File Browser Credential ---------
Admin User: admin
Admin Pass: admin
EOL