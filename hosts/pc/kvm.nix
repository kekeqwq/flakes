{ config, pkgs, ... }:

{
  boot.kernelParams = [ "amd_iommu=on" ];
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
  # boot.extraModprobeConfig =
  #   "options vfio-pci ids=1022:149c,1002:67df,1002:aaf0";
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore";
    onShutdown = "shutdown";
  };
  security.polkit.enable = true;
  users.groups.libvirtd.members = [ "root" "me" ];
  environment.systemPackages = with pkgs; [ virt-manager ];

  # boot.postBootCommands = ''
  #   DEVS="0000:28:00.3 0000:26:00.0 0000:26.00.1"

  #   for DEV in $DEVS; do
  #     echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
  #   done
  #   modprobe -i vfio-pci
  # '';
}
