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
