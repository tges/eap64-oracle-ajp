docker save -o eap64-ajp.tar jboss-eap-6/eap64-openshift-ajp:latest
scp eap64-ajp.tar root@10.1.0.42:/root
ssh root@10.1.0.42 "docker load -i /root/eap64-ajp.tar"
ssh root@10.1.0.42 "docker push jboss-eap-6/eap64-openshift-ajp:latest"

