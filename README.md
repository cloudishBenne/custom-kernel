![custom-kernel logo](./media/github-header-image.png)

## Overview

This project provides a comprehensive set of scripts to manage custom kernels on systems using `kernelstub` and `systemd-boot`. The scripts are designed to work seamlessly with Pop!_OS, automating the process of setting and updating custom kernels.
While this tool should work on all systems, that use `kernelstub` and `systemd-boot`, only Pop!_OS is tested and supported at this moment.

![custom-kernel cli](./media/custom-kernel.gif)

## Features

- **Interactive CLI**: Easily select and set your custom kernel through an intuitive command line interface.
- **Configuration Initialization**: Automatically initialize configuration files using `kernelstub` outputs.
- **Automated Kernel Updates**: Automatically update to the next available custom kernel after system upgrades.
- **Dry Run Mode**: Preview actions without making any changes to your system.

## Installation

1. **Clone the repository**:
    ```bash
    git clone https://github.com/cloudishBenne/custom-kernel.git
    cd custom-kernel
    ```

2. **Run the installation script**:
    ```bash
    sudo ./install.sh
    ```

## Usage

### Command Line Options

```bash
Usage: custom-kernel [OPTION]
Manage custom kernels on systems that use kernelstub.

Options:
  -d, --dry-run      Print actions without executing them.
  -u, --update       Update to the next available custom kernel.
  -i, --init-config  Initialize the configuration file. Uses the values from kernelstub.
  -h, --help, help   Display this help message.

Default behavior (no option provided or with --dry-run only):
  Starts an interactive command line dialog to select and set a custom kernel.
```

## Examples

- **Initialize Configuration**:
    ```bash
    sudo custom-kernel --init-config
    ```

- **Set Custom Kernel (Interactive CLI)**:
    ```bash
    sudo custom-kernel
    ```

- **Update to Next Available Custom Kernel**:
    ```bash
    sudo custom-kernel --update
    ```

- **Dry Run Mode**:
    ```bash
    sudo custom-kernel --dry-run
    sudo custom-kernel --dry-run --update
    sudo custom-kernel --dry-run --init-config
    ```

## Contributing

I welcome contributions! Please fork the repository and submit a pull request for any enhancements or bug fixes.

## License

This project is licensed under the GPL-3.0 License. See the [LICENSE](./LICENSE) file for details.

## Support

If you encounter any issues or have questions, please open an issue on the [GitHub repository issues](https://github.com/cloudishBenne/custom-kernel/issues/new).

---

Enjoy managing your custom kernels with ease!