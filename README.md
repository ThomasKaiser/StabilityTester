# StabilityTester for Pinebook

The `check-pinebook-cpufreq.sh` script bases on community's work to test through various dvfs operation points on H5 devices. The purpose is to test through 1200, 1248 and 1296 MHz maximum cpufreq on Pinebook since if at least 20 different PB users report that their Pinebooks survive running this test at 1248 MHz we could enable 1.2GHz max cpufreq on Pinebook.

The scripts needs to install a modified `sun50i-a64-pine64-pinebook.dtb` which requires an (automated) reboot. To revert changes simply do later a `mv /boot/pine64/sun50i-a64-pine64-pinebook.dtb.bak /boot/pine64/sun50i-a64-pine64-pinebook.dtb` and reboot again. After first reboot execution looks like:

    root@pinebook:~# /home/ubuntu/check-pinebook-cpufreq.sh 
    Testing frequency 1152000
    Cooling down: 30CPU Freq: 1152000 	CPU Core: 1300000 	
    Testing frequency 1200000
    Cooling down: 30CPU Freq: 1200000 	CPU Core: 1300000 	
    Testing frequency 1248000
    Cooling down: 30CPU Freq: 1248000 	CPU Core: 1300000 	
    Testing frequency 1296000
    Cooling down: 30CPU Freq: 1296000 	CPU Core: 1300000 	
    
    Done testing stability:
    Frequency: 1152000	Voltage: 1300000	Success: 1	Result:        0.0048034
    Frequency: 1200000	Voltage: 1300000	Success: 1	Result:        0.0048034
    Frequency: 1248000	Voltage: 1300000	Success: 1	Result:        0.0048034
    Frequency: 1296000	Voltage: 1300000	Success: 0	Result: 11793685593.4324627

That means no throttling occured (otherwise results are marked invalid) and tests with both 1200 and 1248 MHz succeeded while with 1296 MHz already data corruption due to A64 SoC being undervolted occured (you can check logs in `results` subdirectory).

Please note that the script requires an idle CPU temperature of below 30°C. My Pinebook was sitting in my fridge (surprisingly good Wi-Fi receiption!) with an ice pack below the CPU board. With an ambient temperature of above 20°C SoC temperature will be around 40°C and then test execution is tampered by throttling. It's also highly recommended to run this test on battery since when the PB is charged temperatures increase a lot which also affects throttling jumping in more early.
