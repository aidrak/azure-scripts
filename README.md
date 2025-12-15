# Azure Scripts

Personal reference repository for Azure automation scripts.

## Structure

```
├── golden-image/       # Scripts for base image creation/customization
├── vm-provisioning/    # Scripts for VM deployment (host pools, standalone VMs, etc.)
├── platform/           # Deployment scripts (scheduled tasks, configurations)
└── remediation/        # Intune remediation scripts (Detect/Remediate pairs)
    ├── drive-mapping/
    ├── notifications-enable/
    └── office-shortcuts/
```

## Usage

- **Platform scripts**: Run once during deployment to set up scheduled tasks and configurations
- **Remediation scripts**: Intune-based detect/remediate pairs for ongoing compliance
