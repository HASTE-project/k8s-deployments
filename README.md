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

`helm install --name mongodb --namespace haste -f mongodb/values.yaml stable/mongodb`

Any additional parameters can be configured with additional `--set <param>=<value>` entries, full list of parameters available at https://github.com/helm/charts/tree/master/stable/mongodb

To redeploy, the current helm deployment must be deleted (see name above) before running `helm install` again:
 
 
TODO: this isn't great -- its not possible to specify the namespace here (we could delete the wrong mongodb)
`helm delete --purge mongodb` 


To list everything in haste:
```
$ helm list --namespace haste
NAME    REVISION        UPDATED                         STATUS          CHART           APP VERSION     NAMESPACE
mongodb 1               Thu Feb 28 10:45:11 2019        DEPLOYED        mongodb-5.3.2   4.0.6           haste  
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
