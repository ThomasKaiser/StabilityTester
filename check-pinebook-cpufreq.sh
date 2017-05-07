#!/bin/bash

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Adjust prerequisits -- we need to replace DT to use additional cpufreq steps.
# To revert changes do: 
# mv /boot/pine64/sun50i-a64-pine64-pinebook.dtb.bak /boot/pine64/sun50i-a64-pine64-pinebook.dtb
if [ ! -f /boot/pine64/pinebook_overclock_enabled.dts ]; then
	echo -e "\nInstall overclocked DT and other prerequisits\nAn automated reboot will happen once\n"
	apt install -y libmpich-dev device-tree-compiler
	curl -L "https://raw.githubusercontent.com/ThomasKaiser/StabilityTester/master/pinebook_overclock_enabled.dts" \
		-f --progress-bar --output /boot/pine64/pinebook_overclock_enabled.dts
	cp -p /boot/pine64/sun50i-a64-pine64-pinebook.dtb /boot/pine64/sun50i-a64-pine64-pinebook.dtb.bak
	dtc -I dts -O dtb -o /boot/pine64/sun50i-a64-pine64-pinebook.dtb /boot/pine64/pinebook_overclock_enabled.dts
	sync && reboot
fi

XHPLBINARY="xhpl64"
if [ ! -f "${0%/*}/xhpl64" ]; then
	echo -e "\nDownloading test tool and profile\n"
	curl -L "https://raw.githubusercontent.com/ThomasKaiser/StabilityTester/master/xhpl64" \
	-f --progress-bar --output "${0%/*}/xhpl64"
	curl -L "https://raw.githubusercontent.com/ThomasKaiser/StabilityTester/master/HPL.dat" \
	-f --progress-bar --output "${0%/*}/HPL.dat"
fi
if [ ! -x "${XHPLBINARY}" ]; then
	chmod 755 "${XHPLBINARY}"
fi

MINFREQUENCY=640000 #Only test frequencies from this point.
MAXFREQUENCY=1344000 #Only test frequencies upto this point.
COOLDOWNTEMP=30 #Cool down after a test to mC degrees
COOLDOWNFREQ=480000 # Set to this speed when cooling down

CPUFREQ_HANDLER="/sys/devices/system/cpu/cpu0/cpufreq/"
SCALINGAVAILABLEFREQUENCIES="scaling_available_frequencies"
SCALINGCURFREQUENCY="scaling_cur_freq"
SCALINGMAXFREQUENCY="scaling_max_freq"

SOCTEMPCMD="/sys/class/thermal/thermal_zone0/temp"

REGULATOR_HANDLER="/sys/class/regulator/regulator.2/"
REGULATOR_MICROVOLT="microvolts"

ROOT=$(pwd)

declare -A VOLTAGES=()

trap "{ killall ${ROOT}/${XHPLBINARY}; exit 0; }" SIGINT SIGTERM

if [ ! -d "${ROOT}/results" ];
then
	echo "Create";
	mkdir ${ROOT}/results;
fi

# start to test
AVAILABLEFREQUENCIES="1152000 1200000 1248000 1296000"
echo performance >${CPUFREQ_HANDLER}scaling_governor
echo $COOLDOWNFREQ >${CPUFREQ_HANDLER}scaling_min_freq
for FREQUENCY in $AVAILABLEFREQUENCIES
do
    if [ $FREQUENCY -ge $MINFREQUENCY ] && [ $FREQUENCY -le $MAXFREQUENCY ];
    then
        echo "Testing frequency ${FREQUENCY}";
        
        if [ $FREQUENCY -gt $(cat ${CPUFREQ_HANDLER}${SCALINGMAXFREQUENCY}) ];
        then
            echo $FREQUENCY > ${CPUFREQ_HANDLER}${SCALINGMAXFREQUENCY}
        else
            echo $FREQUENCY > ${CPUFREQ_HANDLER}${SCALINGMAXFREQUENCY}
        fi
        read TOTAL_TRANS <${CPUFREQ_HANDLER}/stats/total_trans

        ${ROOT}/$XHPLBINARY > ${ROOT}/results/xhpl_${FREQUENCY}.log &
        echo -n "Soc temp:"
        while pgrep -x $XHPLBINARY > /dev/null
        do
            SOCTEMP=$(cat ${SOCTEMPCMD})
            CURFREQ=$(cat ${CPUFREQ_HANDLER}${SCALINGCURFREQUENCY})
            CURVOLT=$(cat ${REGULATOR_HANDLER}${REGULATOR_MICROVOLT})
            echo -ne "\rSoc temp: ${SOCTEMP} \tCPU Freq: ${CURFREQ} \tCPU Core: ${CURVOLT} \t"
            if [ $CURFREQ -eq $FREQUENCY ];
            then
                VOLTAGES[$FREQUENCY]=$CURVOLT
            fi
            sleep 1;
        done
        sync &
        read TOTAL_TRANS_NOW <${CPUFREQ_HANDLER}/stats/total_trans
        if [ $TOTAL_TRANS_NOW -gt $TOTAL_TRANS ]; then
        	echo -e "\nThrottling happened, results invalid\n"
        fi
        echo -ne "\r"
        echo -n "Cooling down"
        echo $COOLDOWNFREQ > ${CPUFREQ_HANDLER}${SCALINGMAXFREQUENCY}
        while [ $SOCTEMP -gt $COOLDOWNTEMP ];
        do
            SOCTEMP=$(cat ${SOCTEMPCMD})
            echo -ne "\rCooling down: ${SOCTEMP}"
            
            sleep 1;
        done
	echo -ne "\n"
    fi
done

echo -e "\nDone testing stability:"
for FREQUENCY in $AVAILABLEFREQUENCIES
do
    if [ $FREQUENCY -ge $MINFREQUENCY ] && [ $FREQUENCY -le $MAXFREQUENCY ];
    then
        FINISHEDTEST=$(grep -Ec "PASSED|FAILED" ${ROOT}/results/xhpl_${FREQUENCY}.log )
        SUCCESSTEST=$(grep -Ec "PASSED" ${ROOT}/results/xhpl_${FREQUENCY}.log )
        DIFF=$(grep -E 'PASSED|FAILED' ${ROOT}/results/xhpl_${FREQUENCY}.log)
        #echo $DIFF
        DIFF="${DIFF#*=}"
        DIFF="${DIFF#* }"
        #echo $DIFF
        RESULTTEST="${DIFF% .*}"
        VOLTAGE=${VOLTAGES[$FREQUENCY]}
        if [ $FINISHEDTEST -eq 1 ]; 
        then
            echo -ne "Frequency: ${FREQUENCY}\t"
            echo -ne "Voltage: ${VOLTAGE}\t"
            echo -ne "Success: ${SUCCESSTEST}\t"
            echo -ne "Result: ${RESULTTEST}\n"
        fi
    fi
done
