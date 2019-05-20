# k8s-deployments


Persistent Volume:
``` 
kubectl apply -f mikro_testdata_pv.yaml
```

Persistent Volume Claim: 
```
kubectl apply -f mikro_testdata_pvc.yaml
```

I also created this dummy-ubuntu-container:
(a simple dummy ubuntu container executing a loop) 
```
kubectl apply -f mikro_testdata_ubuntu_container.yml
```
 
You can execute into it with:
```
# kubectl exec --namespace haste -it test-mikro-datamount-XXXXXXXXXXXXXX bash
```

Start the image processing app:
```
kubectl apply -f image_processing_app.yaml
```

If the image is updated, delete the deployment, and then start again:
```
kubectl --namespace haste delete deployment.apps/image-processing-app ; kubectl apply -f image_processing_app.yaml
```
(there is no nice way to force it to re-fetch this, see: 
https://github.com/kubernetes/kubernetes/issues/33664 )

-------

# Set up mongodb
## Set up PV/PVC for persistence for mongodb
Run the following to set up the PV/PVC for mongodb persistence

`kubectl apply -f mongodb/haste-state-mongodb.yaml`

## Set up mongodb with helm
To set up mongodb with helm chart, run following command from a point with access to Ola's kubernetes cluster and with the `values.yaml` file available:

`helm install --name mongodb-haste --namespace haste -f mongodb/values.yaml stable/mongodb`

Any additional parameters can be configured with additional `--set <param>=<value>` entries, full list of parameters available at https://github.com/helm/charts/tree/master/stable/mongodb

# Set up RabbitMQ
## Set up PV/PVC for persistence for RabbitMQ
Run the following to set up the PV/PVC for RabbitMQ persistence

`kubectl apply -f rabbitmq/haste-rabbitmq.yaml`

## Set up RabbitMQ with helm
To set up RabbitMQ with helm chart, run following command from a point with access to Ola's kubernetes cluster and with the `values.yaml` file available:

`helm install --name haste-rabbitmq --namespace haste -f rabbitmq/values.yaml stable/rabbitmq`

Any additional parameters can be configured with additional `--set <param>=<value>` entries, full list of parameters available at https://github.com/helm/charts/tree/master/stable/rabbitmq


# Redeploying helm applications
To redeploy, the current deployment must be deleted (see name above) before running `helm install` again:
 
 
`helm delete --purge <deployment name>` 

**NOTE**: `<deployment name>` must match the name of the deployed application. To list all helm deployments in haste:
```
$ helm list --namespace haste
NAME          	REVISION	UPDATED                 	STATUS  	CHART         	APP VERSION	NAMESPACE
haste-rabbitmq	1       	Fri May 17 18:07:15 2019	DEPLOYED	rabbitmq-5.5.1	3.7.14     	haste    
mongodb       	1       	Mon May  6 09:42:40 2019	DEPLOYED	mongodb-5.6.1 	4.0.6      	haste  
```

-------
Setup port forwarding for MongoDB:
```
kubectl port-forward <<name of mongo pod>> --namespace haste 27018:27017
```

Copy files out:
```
kubectl cp haste/test-mikro-datamount-6c59856b87-ldqp8:/mnt/mikro-testdata/PolinaG-KO/ .
```
Copy files in:
```
kubectl cp . haste/test-mikro-datamount-6c59856b87-ldqp8:/mnt/mikro-testdata/azn
```
