# Kubernetes Operator Development Bootstrap Guide

## Overview
Welcome! In this hands-on tutorial, you'll learn the fundamentals of Kubernetes operator development by building a custom operator that manages file reading operations through Persistent Volumes (PV) and Persistent Volume Claims (PVC).

## Learning Objectives
By completing this guide, you will:
- Set up a local Kubernetes cluster using kind
- Understand Kubernetes operators and Custom Resource Definitions (CRDs)
- Work with Persistent Volumes and Persistent Volume Claims
- Build and deploy a custom operator
- Publish container images to Docker Hub
- Implement a simple API for file operations

## Prerequisites
- Basic understanding of Kubernetes concepts
- Familiarity with Go programming language
- Linux development machine (Ubuntu 20.04+ or similar)

## Part 1: Environment Setup

### 1.1 Install Required Tools

Install the following tools on your Linux system:

- **Docker**: https://docs.docker.com/engine/install/ubuntu/
- **kind** (Kubernetes in Docker): https://kind.sigs.k8s.io/docs/user/quick-start/#installation
- **kubectl**: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
- **Go** (1.20+): https://golang.org/doc/install
- **Operator SDK**: https://sdk.operatorframework.io/docs/installation/

**Verification:**
```bash
docker --version
kind --version
kubectl version --client
go version
operator-sdk version
```

### 1.2 Create Docker Hub Account
1. Visit https://hub.docker.com/signup
2. Create a free account
3. Remember your username (you'll need it for image publishing)

**Verification:**
```bash
docker login
# Should successfully authenticate with your credentials
```

## Part 2: Create Kubernetes Cluster with kind

### Task
Create a kind cluster with custom configuration that supports local persistent volumes.

### Requirements
- Create a kind cluster named `operator-dev`
- Configure extra mounts for persistent volume support
- Mount host directory `/tmp/k8s-pv` to container path `/mnt/data`
- Ensure the mount supports bidirectional propagation

### Preparation
```bash
# Create directory for persistent volume on host
sudo mkdir -p /tmp/k8s-pv
sudo chmod 777 /tmp/k8s-pv
```

### Verification
```bash
# Cluster should be running
kubectl cluster-info --context kind-operator-dev

# Should show one node with Ready status
kubectl get nodes

# Should be able to see the mounted directory inside the node
docker exec -it operator-dev-control-plane ls /mnt/data
```

## Part 3: Develop the File Reader Operator

### Task
Create a Kubernetes operator that:
- Manages a custom resource called `FileReader`
- Creates PVCs for storage
- Deploys pods that can read files from the persistent volume
- Updates the status with file content

### Requirements

#### 3.1 Project Initialization
- Initialize an operator project with domain `example.com`
- Repository should be `github.com/example/file-reader-operator`
- Create an API with:
  - Group: `file`
  - Version: `v1alpha1`
  - Kind: `FileReader`
  - Generate both resource and controller

**Verification:**
```bash
# Should have the following directory structure
ls -la api/v1alpha1/
ls -la controllers/
ls -la config/crd/

# Should be able to generate manifests without errors
make manifests
```

#### 3.2 Custom Resource Definition
Define the `FileReader` CRD with:
- **Spec fields:**
  - `fileName`: Name of the file to read (required)
  - `storagePath`: Path where file is located in PV (optional, default: `/mnt/data`)
  - `storageSize`: Size of the PVC (optional, default: `1Gi`)
- **Status fields:**
  - `content`: Content of the file
  - `lastReadTime`: Timestamp of last successful read
  - `error`: Error message if reading failed
  - `phase`: Current phase (Processing, Ready, Failed)

**Verification:**
```bash
# CRD should be valid
make manifests
kubectl apply --dry-run=client -f config/crd/bases/file.example.com_filereaders.yaml
```

#### 3.3 Controller Implementation
Implement a controller that:
- Creates a PVC for each FileReader resource
- Creates a pod that mounts the PVC
- Opens and reads the specified file from the mounted volume
- **Prints the file content to the operator logs** (so engineers can verify file reading works)
- Updates the FileReader status with the file content
- Handles errors gracefully (file not found, permission errors, etc.)

**Verification:**
```bash
# Code should compile without errors
make generate
go build ./...

# Unit tests should pass
go test ./...
```

## Part 4: Build and Push Operator Image

### Task
Build the operator container image and push it to your Docker Hub repository.

### Requirements
- Image name format: `docker.io/<your-username>/file-reader-operator:v1.0.0`
- Image should be publicly accessible on Docker Hub

**Verification:**
```bash
# Set your Docker Hub username
export DOCKER_USERNAME=<your-username>
export IMG=docker.io/$DOCKER_USERNAME/file-reader-operator:v1.0.0

# Image should build successfully
make docker-build IMG=$IMG

# Image should be pushed successfully
make docker-push IMG=$IMG

# Verify image is available on Docker Hub
docker pull $IMG
```

## Part 5: Deploy the Operator

### 5.1 Create Persistent Volume

### Task
Create a persistent volume that uses the host path storage.

### Requirements
- PV name: `local-pv`
- Capacity: `5Gi`
- Access mode: `ReadWriteOnce`
- Storage class: `standard`
- Host path: `/mnt/data`

**Verification:**
```bash
# PV should be created and available
kubectl get pv local-pv
kubectl describe pv local-pv | grep "Status:.*Available"
```

### 5.2 Prepare Test Data
```bash
# Create a test file in the host directory
echo "Hello from Kubernetes Operator!" | sudo tee /tmp/k8s-pv/test-file.txt
sudo chmod 644 /tmp/k8s-pv/test-file.txt

# Verify file is accessible from kind node
docker exec -it operator-dev-control-plane cat /mnt/data/test-file.txt
```

### 5.3 Deploy Operator

### Task
Install CRDs and deploy the operator to the cluster using your Docker Hub image.

**Verification:**
```bash
# CRDs should be installed
kubectl get crd filereaders.file.example.com

# Operator should be deployed and running
kubectl get deployment -n file-reader-operator-system
kubectl get pods -n file-reader-operator-system

# Operator pod should be in Running state
kubectl get pods -n file-reader-operator-system -o jsonpath='{.items[*].status.phase}'
```

## Part 6: Test the Operator

### Task
Create a FileReader custom resource and verify the operator processes it correctly.

### Test Scenario
Create a FileReader resource with:
- Name: `test-filereader`
- Namespace: `default`
- File to read: `test-file.txt`
- Storage path: `/mnt/data`
- Storage size: `1Gi`

**Verification:**
```bash
# FileReader resource should be created
kubectl get filereader test-filereader

# PVC should be automatically created by the operator
kubectl get pvc | grep test-filereader

# Reader pod should be created and running
kubectl get pods | grep test-filereader-reader

# FileReader status should show Ready phase
kubectl get filereader test-filereader -o jsonpath='{.status.phase}'

# Status should contain the file content
kubectl get filereader test-filereader -o jsonpath='{.status.content}'

# IMPORTANT: Check operator logs to see the file content printed
kubectl logs -n file-reader-operator-system deployment/file-reader-operator-controller-manager | grep -A 5 "test-file.txt"

# The operator logs should show:
# - File path being read
# - File content
# - Any read errors

# Verify actual file reading through pod exec
POD_NAME=$(kubectl get pods -l app=file-reader -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- cat /mnt/data/test-file.txt
```

## Part 7: Implement File Reading API (Bonus)

### Task
Add an HTTP API endpoint to the operator that allows querying file content.

### Requirements
- Endpoint: `/api/v1/files`
- Query parameters: `name` (filename) and `namespace` (optional, default: `default`)
- Response: JSON with file content and metadata
- Port: `8080`

**Verification:**
```bash
# Port forward to access the API
kubectl port-forward -n file-reader-operator-system deployment/file-reader-operator-controller-manager 8080:8080 &

# API should respond with file content
curl "http://localhost:8080/api/v1/files?name=test-file.txt&namespace=default"

# Should return JSON with content field
curl -s "http://localhost:8080/api/v1/files?name=test-file.txt" | jq '.content'

# Kill port forward
kill %1
```

## Part 8: Cleanup

```bash
# Delete the test FileReader
kubectl delete filereader test-filereader

# Verify PVC and pod are deleted (due to owner references)
kubectl get pvc | grep test-filereader  # Should return nothing
kubectl get pods | grep test-filereader  # Should return nothing

# Undeploy the operator
make undeploy

# Delete the kind cluster
kind delete cluster --name operator-dev

# Clean up host directory
sudo rm -rf /tmp/k8s-pv
```

## Success Criteria

Your implementation is successful when:

1. ✅ Kind cluster is running with persistent volume support
2. ✅ Operator image is available on Docker Hub
3. ✅ CRDs are installed and valid
4. ✅ Operator pod is running without errors
5. ✅ FileReader resources create PVCs automatically
6. ✅ Reader pods are created and can access files
7. ✅ **File content is visible in operator logs**
8. ✅ FileReader status is updated with file content
9. ✅ API endpoint returns file content in JSON format
10. ✅ Resources are cleaned up when FileReader is deleted

## Troubleshooting Tips

If verification steps fail:

1. **Check operator logs (most important for file reading verification):**
   ```bash
   kubectl logs -n file-reader-operator-system deployment/file-reader-operator-controller-manager -f
   ```
   You should see:
   - Log entries when FileReader resources are processed
   - File paths being accessed
   - **File contents being printed**
   - Any errors reading files

2. **Verify RBAC permissions:**
   ```bash
   kubectl describe clusterrole file-reader-operator-manager-role
   ```

3. **Check events:**
   ```bash
   kubectl get events --all-namespaces --sort-by='.lastTimestamp'
   ```

4. **Validate CRD schema:**
   ```bash
   kubectl explain filereader.spec
   ```

5. **Debug file reading issues:**
   ```bash
   # Check if file exists in the pod
   kubectl exec <reader-pod-name> -- ls -la /mnt/data/
   
   # Check file permissions
   kubectl exec <reader-pod-name> -- stat /mnt/data/test-file.txt
   ```

## Additional Challenges

Once the basic operator is working, try these enhancements:

1. **Multi-file support**: Modify the operator to read multiple files
2. **Watch for changes**: Implement file watching and update status when file changes
3. **Metrics**: Add Prometheus metrics for monitoring
4. **Webhooks**: Add validation webhooks for the FileReader spec
5. **Leader election**: Implement leader election for high availability

## Resources

- [Operator SDK Documentation](https://sdk.operatorframework.io/docs/)
- [Kubebuilder Book](https://book.kubebuilder.io/)
- [Kubernetes Controllers](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

## Submission

When complete, provide:
1. Link to your Docker Hub repository with the operator image
2. GitHub repository with your operator code
3. Screenshot of successful verification commands
4. Any challenges faced and how you resolved them
