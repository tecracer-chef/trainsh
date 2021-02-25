# TrainSH

## Summary

Interactive Shell for Remote Systems

Based on the Train ecosystem, provide a shell to manage systems via a multitude of transports.

Train default supports:

- Docker
- Local
- SSH (Unix, Windows, Cisco)
- WinRM (Windows)

3rd party plugins support:

- AWS Systems Manager
- LXD
- Telnet
- Serial/USB interfaces
- VMware Guest Operations (VMware Tools)
- ...

## Example uses

When specifying a password within an URL take care of special characters or the connection will fail.

```shell
trainsh connect local://
```

```shell
trainsh connect winrm://Administrator:Passw0rd@10.20.30.40
```

```shell
trainsh connect awsssm://i-123456789abc0
```

```shell
trainsh connect vsphere-gom://example-vm
```
