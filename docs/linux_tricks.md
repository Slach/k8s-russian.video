# Microseconds latency sysctl
```
sysctl -w intel_idle.max_cstate=0
sycctl -w processor.mac_cstate=0
sysctl -w idle=poll
```

# CPU frequency
```bash
#CPU performance governor
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    systemctl disable ondemand
    apt-get install -y cpufrequtils
    echo 'GOVERNOR="performance"' | tee /etc/default/cpufrequtils
    cpufreq-set --governor performance
fi
```

# NUMA - howto disable nodes interleaving
numactl --help

# Memory
```
sysctl -w transparent_hugepages=never
```

# NVMe without IO sheduller
elevator=noop

# ext4 optimization
barrier=0
noatime