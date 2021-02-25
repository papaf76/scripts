#!/bin/bash
#Prototipo di installatore di Astropi3 "light"

#Link per download software
INDI="https://github.com/indilib/indi/archive/v1.8.8.tar.gz"
INDI3RD="https://github.com/indilib/indi-3rdparty/archive/v1.8.8.tar.gz"
STELLARSOLVER="https://github.com/rlancaste/stellarsolver/archive/1.5.tar.gz"
KSTARS="https://kde.mirror.garr.it/kde/ftp/stable/kstars/kstars-3.5.1.tar.xz"

#Creo la cartella di configurazione se non c'è già
if [ ! -d "$HOME/.config" ]; then
  mkdir "$HOME/.config"
fi

#Aggiustamenti al comportamento del file manager 
if [ -f $HOME/.config/pcmanfm-qt/lxqt/settings.conf ]
then
	sed -i "s/QuickExec=false/QuickExec=true/g" $HOME/.config/pcmanfm-qt/lxqt/settings.conf
fi
if [ -f $HOME/.config/pcmanfm-qt/default/settings.conf ]
then
	sed -i "s/QuickExec=false/QuickExec=true/g" $HOME/.config/pcmanfm-qt/default/settings.conf
fi
if [ -f $HOME/.config/libfm/libfm.conf ]
then
	if [ -z "$(grep 'quick_exec' $HOME/.config/libfm/libfm.conf)" ]
	then
		sed -i "/\[config\]/ a quick_exec=1" $HOME/.config/libfm/libfm.conf
	else
		sed -i "s/quick_exec=0/quick_exec=1/g" $HOME/.config/libfm/libfm.conf
	fi
fi
if [ -f /etc/xdg/libfm/libfm.conf ]
then
	if [ -z "$(grep 'quick_exec' /etc/xdg/libfm/libfm.conf)" ]
	then
		sudo sed -i "/\[config\]/ a quick_exec=1" /etc/xdg/libfm/libfm.conf
	else
		sudo sed -i "s/quick_exec=0/quick_exec=1/g" /etc/xdg/libfm/libfm.conf
	fi
fi

#Autologin
if [ -n "$(grep '#autologin-user' '/etc/lightdm/lightdm.conf')" ]
then
	sudo sed -i "s/#autologin-user=/autologin-user=$SUDO_USER/g" /etc/lightdm/lightdm.conf
	sudo sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/g" /etc/lightdm/lightdm.conf
fi

#Impostazioni HDMI (monitor virtuale sempre connesso e risoluzione 1080p
#Per la lista completa https://www.raspberrypi.org/documentation/configuration/config-txt/video.md
if [ -n "$(grep '#hdmi_force_hotplug=1' '/boot/config.txt')" ]
then
	sudo sed -i "s/#hdmi_force_hotplug=1/hdmi_force_hotplug=1/g" /boot/config.txt
fi
if [ -n "$(grep '#hdmi_mode=1' '/boot/config.txt')" ]
then
	sudo sed -i "s/#hdmi_mode=1/hdmi_mode=16/g" /boot/config.txt
fi

if [ -n "$(grep '^dtoverlay=vc4-kms-v3d' '/boot/config.txt')" ]
then
	sudo sed -i "s/dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/g" /boot/config.txt
fi
if [ -n "$(grep '^dtoverlay=vc4-fkms-v3d' '/boot/config.txt')" ]
then
	sudo sed -i "s/dtoverlay=vc4-fkms-v3d/#dtoverlay=vc4-fkms-v3d/g" /boot/config.txt
fi

#Disattiva lo screensaver
if [ -z "$(grep 'xserver-command=X -s 0 dpms' '/etc/lightdm/lightdm.conf')" ]
then
	sudo sed -i "/\[Seat:\*\]/ a xserver-command=X -s 0 dpms" /etc/lightdm/lightdm.conf
fi

#Abilito SSH
sudo systemctl enable ssh

#Ailito RealVNC
sudo systemctl enable vncserver-x11-serviced.serviced

#Condivisione con windows
sudo apt -y install samba
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.orig
##############
sudo cat > /etc/samba/smb.conf <<- EOF
[global]
   workgroup = ASTROGROUP
   server string = Samba Server
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 50
   dns proxy = no
[homes]
   comment = Home Directories
   browseable = no
   read only = no
   writable = yes
   valid users = $SUDO_USER
EOF
#############
echo "Inserire password per rete windows"
sudo smbpasswd -a "$USER"

#Permessi di aprire le porte seriali per montature etc..
sudo usermod -a -G dialout "$USER"

#Imposto un tema di default per KDE
##################
cat > $HOME/.config/kdeglobals <<- EOF
[Icons]
Theme=breeze
EOF
##################

#Installo i requisiti per compilare indi
sudo apt -y install libnova-dev libcfitsio-dev libusb-1.0-0-dev libusb-dev zlib1g-dev libgsl-dev build-essential cmake git libjpeg-dev libcurl4-gnutls-dev libtiff-dev libftdi-dev libgps-dev libraw-dev libdc1394-22-dev libgphoto2-dev libboost-dev libboost-regex-dev librtlsdr-dev liblimesuite-dev libftdi1-dev ffmpeg libavcodec-dev libavdevice-dev libfftw3-dev

#FIX per problemi con alcune camere DSLR
sudo rm /usr/share/dbus-1/services/org.gtk.vfs.GPhoto2VolumeMonitor.service
sudo rm /usr/share/dbus-1/services/org.gtk.Private.GPhoto2VolumeMonitor.service
sudo rm /usr/share/gvfs/mounts/gphoto2.mount
sudo rm /usr/share/gvfs/remote-volume-monitors/gphoto2.monitor
sudo rm /usr/lib/gvfs/gvfs-gphoto2-volume-monitor

#Creo ambiente di lavoro
mkdir -p $HOME/astropi3_light/build

#Compilo e installo indi base
cd $HOME/astropi3_light
wget "$INDI"
tar xvf v1*tar.gz
rm v1*tar.gz
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo ../indi-1*
make -j4
sudo make install
rm -rf $HOME/astropi3_light/build/*
cd $HOME/astropi3_light

#Compilo e installo la librerie e i drivers di terze parti indi
wget "$INDI3RD"
tar xvf v1*tar.gz
rm v1*tar.gz
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_LIBS=1 ../indi-3rd*
make -j4
sudo make install
rm -rf $HOME/astropi3_light/build/*
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_FXLOAD=1 ../indi-3rd*
make -j4
sudo make install
rm -rf $HOME/astropi3_light/build/*
cd $HOME/astropi3_light

#Installo astrometry.net e xplanet
sudo apt -y install astrometry.net xplanet

#Installo requisiti per compilare kstars
sudo apt -y install build-essential cmake git libeigen3-dev libcfitsio-dev zlib1g-dev libindi-dev extra-cmake-modules libkf5plotting-dev libqt5svg5-dev libkf5iconthemes-dev wcslib-dev libqt5sql5-sqlite libkf5xmlgui-dev kio-dev kinit-dev libkf5newstuff-dev kdoctools-dev libkf5notifications-dev libqt5websockets5-dev qtdeclarative5-dev libkf5crash-dev gettext qml-module-qtquick-controls qml-module-qtquick-layouts libkf5notifyconfig-dev libqt5datavisualization5-dev qt5keychain-dev

#Installo il risolutore stellarsolver
wget "$STELLARSOLVER"
tar xvf 1*tar.gz
rm 1*tar.gz
cd build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr ../stellarsolver*
make -j4
sudo make install
rm -rf $HOME/astropi3_light/build/*
cd $HOME/astropi3_light

#Installo kstars
wget "KSTARS"
tar xvf kstars*xz
rm kstars*xz
cd build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr ../kstars*
make -j4
sudo make install
rm -rf $HOME/astropi3_light/build/*
cd $HOME/astropi3_light

#Installo il catalogo GSC che serve ai simulatori di CCD per generare il campo stellato
mkdir GSC
cd GSC
wget -O bincats_GSC_1.2.tar.gz http://cdsarc.u-strasbg.fr/viz-bin/nph-Cat/tar.gz?bincats/GSC_1.2
tar xvf bincats_GSC_1.2.tar.gz
rm bincats_GSC_1.2.tar.gz
cd src
make -j4
sudo mv gsc.exe /usr/bin/gsc
rm -rf bin-dos src bin/gsc.exe bin/decode.exe
cd ..
sudo mv GSC /usr/share/
if [ -z "$(grep 'export GSCDAT' /etc/profile)" ]; then
	sudo echo "export GSCDAT=/usr/share/GSC" >> /etc/profile
fi
