#!/bin/bash
echo "######################################################"
echo "# Bitsquare auto install on Raspberry PI.            #"
echo "# phosphor forked from metabit and SjonHortensius    #"
echo "# https://github.com/phosphorit                      #"
echo "######################################################"
echo

# Prerequisites - Raspbian installation:
#   1. Get Raspbian Jessie image from https://www.raspberrypi.org/downloads/raspbian/
#   2. Follow https://www.raspberrypi.org/documentation/installation/installing-images/README.md

set -e

# Sanity check - raspbery pi hardware?
uname -m | grep -v arm > /dev/null && echo "This is not a Raspberry PI. Aborting ..." && exit 1

# Let's work at home
cd

echo "Installing bitsquare ..."
echo "Update (and upgrade) repository"
sudo apt-get -y update
#sudo apt-get -y upgrade

echo "Removing openjdk-7"
sudo apt-get -y remove openjdk-7.*

echo "Get oracle JDK"
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u92-b14/jdk-8u92-linux-arm32-vfp-hflt.tar.gz

echo "Install oracle JDK"
sudo tar zxvf jdk-8u92-linux-arm32-vfp-hflt.tar.gz -C /opt
sudo update-alternatives --install /usr/bin/javac javac /opt/jdk1.8.0_92/bin/javac 1111
sudo update-alternatives --install /usr/bin/java java /opt/jdk1.8.0_92/bin/java 1111

echo "Getting openjfx overlay"
wget http://chriswhocodes.com/downloads/openjfx-8u60-sdk-overlay-linux-armv6hf.zip
sudo unzip -o openjfx-8u60-sdk-overlay-linux-armv6hf.zip -d /opt/jdk1.8.0_92

echo "Enable unlimited Strength for cryptographic keys"
wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip
unzip -o jce_policy-8.zip
sudo cp UnlimitedJCEPolicyJDK8/US_export_policy.jar /opt/jdk1.8.0_92/jre/lib/security/US_export_policy.jar
sudo cp UnlimitedJCEPolicyJDK8/local_policy.jar /opt/jdk1.8.0_92/jre/lib/security/local_policy.jar

echo "Install mvn and tor"
sudo apt-get -y install maven tor

echo "Install bitcoinj"
[[ -d bitcoinj ]] || git clone -b FixBloomFilters https://github.com/bitsquare/bitcoinj.git
cd bitcoinj
git pull
mvn clean install -DskipTests -Dmaven.javadoc.skip=true
cd -

echo "Getting bitsquare code"
[[ -d bitsquare ]] || git clone https://github.com/bitsquare/bitsquare.git
cd bitsquare
git pull
echo "Apply tor executable patch for RPi"
wget https://github.com/metabit/bitsquare/commit/330e661709ec1478dac81b967fade81d953ced0a.patch
patch -f -p1 <330e661709ec1478dac81b967fade81d953ced0a.patch || :
echo "Build bitsquare"
mvn clean package -DskipTests
cd -

echo "Copy the BouncyCastle provider jar file"
sudo cp /home/pi/.m2/repository/org/bouncycastle/bcprov-jdk15on/1.53/bcprov-jdk15on-1.53.jar /opt/jdk1.8.0_92/jre/lib/ext/bcprov-jdk15on-1.53.jar

echo "Update java.security file to add BouncyCastleProvider"
sudo chmod 666 /opt/jdk1.8.0_92/jre/lib/security/java.security
sudo echo "security.provider.11=org.bouncycastle.jce.provider.BouncyCastleProvider" >> /opt/jdk1.8.0_92/jre/lib/security/java.security
sudo chmod 644 /opt/jdk1.8.0_92/jre/lib/security/java.security

echo "write start script"
echo "sudo su; /usr/bin/java -Dsun.java2d.opengl=True -Xmx256m -jar /home/pi/bitsquare/gui/target/shaded.jar --maxConnections 6 --logLevel OFF \"\$@\"" > start.sh
sudo chmod 777 start.sh

# Done
echo
echo "to start enter: ./start.sh"
echo "to quit use ctrl-q"
