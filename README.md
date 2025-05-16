# k3s-helloworld

## setup
3 Rockylinux machines. I'm using KVM/QEMU.

This is a simple setup of a fully functional yet lightweight kubernetes cluster of 1 control node and 2 or more worker nodes

## Execution
Simply execute them in respective machine in the following order and ensure they are using static IP address.
- k3s_control.sh (remember take note of the token generated in /etc/)
- k3s_worker.sh

## Test
Verify cluster in the control node.

```bash
k3s kubectl get nodes
```

**Sample Deployment**
Refer to the run.sh script for the test_deploy()

Once deployment complete, open browser and navigate to `http://<k3s_machine_ip>:30081/`

My machine specs is pretty low, only 1.5GB of RAM with 2CPU, so it took sometime to load, but the snake will fully load and playable.

