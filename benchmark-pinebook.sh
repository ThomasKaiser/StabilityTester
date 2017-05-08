#!/bin/bash

# This is A64 temperature required for the next test to start
COOLDOWNTEMP=50

RunTests() {
	# 10 openssl runs
	CoolDown
	CPUCores=$(grep -c processor /proc/cpuinfo)
	echo -e "Testing openssl speed rsa2048 -multi ${CPUCores}:"
	for i in $(seq 1 10) ; do openssl speed rsa2048 -multi ${CPUCores} 2>&1 | grep '^rsa' ; done

	# 120 seconds cpuminer
	CoolDown
	echo -e "\nTesting minerd --benchmark:"
	timeout 120 minerd --benchmark 2>&1 | grep 'Total: '

	# 10 times OpenBLAS optimized Linpack
	CoolDown
	echo -e "\nTesting xhpl64:"
	for i in $(seq 1 10) ; do ./xhpl64 | grep WR02R2L2 ; done

	# 4 times 7-zip
	CoolDown
	echo -e "\nTesting 7-zip:"
	for i in $(seq 1 4) ; do 7z b | egrep "Avr:|Tot:" ; done
} # RunTests

InstallCPUMiner() {
	echo -e "\nInstalling cpuminer"
	apt-get -f -qq -y install libcurl4-gnutls-dev || exit 1
	cd /usr/local/src/
	wget http://downloads.sourceforge.net/project/cpuminer/pooler-cpuminer-2.4.5.tar.gz
	tar xf pooler-cpuminer-2.4.5.tar.gz && rm pooler-cpuminer-2.4.5.tar.gz
	cd cpuminer-2.4.5/
	./configure CFLAGS="-O3"
	make
	make install
} # InstallCPUMiner

CoolDown() {
	read SOCTEMP </sys/class/thermal/thermal_zone0/temp
	while [ ${SOCTEMP} -gt ${COOLDOWNTEMP} ]; do
		echo -ne "\rCooling down: ${SOCTEMP}"
		sleep 1
		read SOCTEMP </sys/class/thermal/thermal_zone0/temp
	done
	echo ""
} # CoolDown

which minerd >/dev/null || InstallCPUMiner
which 7z >/dev/null || apt install -y p7zip-full
which openssl >/dev/null || apt install -y openssl

RunTests
