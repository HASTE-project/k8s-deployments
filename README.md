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

If the image is updated, delete the deployment, (and then start again.)
```
kubectl --namespace haste delete deployment.apps/image-processing-app
```



# Set up mongodb with helm

To set up mongodb with helm chart, run following command from a point with access to Ola's kubernetes cluster and with the `values.yaml` file available:

`helm install --name mongodb --namespace haste -f mongodb/values.yaml --set persistence.size=30Gi --set usePassword=false stable/mongodb`

Any additional parameters can be configured with additional `--set <param>=<value>` entries, full list of parameters available at https://github.com/helm/charts/tree/master/stable/mongodb

To redeploy, the current helm deployment must be deleted before running `helm install` again:

`helm delete --purge <name of installment, mongodb above>` 


To list everything in haste:
```
$ helm list --namespace haste
NAME    REVISION        UPDATED                         STATUS          CHART           APP VERSION     NAMESPACE
mongodb 1               Thu Feb 28 10:45:11 2019        DEPLOYED        mongodb-5.3.2   4.0.6           haste  
```
