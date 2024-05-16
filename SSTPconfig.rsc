####################### hAP ax config ##########################

/import credentials.rsc
:global Version "2.36"
:global USERNAME
:global USERPASSWORD
:global L2tpServer
:global WifiWorkName
:global WifiWorkPassword
:global WifiHomeName
:global WifiHomePassword
:global supportUser
:global supportPassword
################################################################

/interface bridge add name=Bridge-Home protocol-mode=none
/interface bridge add name=Bridge-Work protocol-mode=none
/interface ethernet set [ find default-name=ether1 ] comment="ISP#1" name=Gi1
/interface ethernet set [ find default-name=ether2 ] comment=Work name=Gi2
/interface ethernet set [ find default-name=ether3 ] comment=Home name=Gi3
/interface ethernet set [ find default-name=ether4 ] comment=Home name=Gi4
/interface ethernet set [ find default-name=ether5 ] comment=Home name=Gi5
/interface wifi set [ find default-name=wifi2 ] channel.band=2ghz-ax .width=20/40mhz comment="Master (SSID for Work)" configuration.mode=ap .ssid=($WifiWorkName . "-2GHz") disabled=no name=Wi-Fi-2GHz security.authentication-types=wpa2-psk,wpa3-psk .passphrase=$WifiWorkPassword
/interface wifi set [ find default-name=wifi1 ] channel.band=5ghz-ax .skip-dfs-channels=10min-cac .width=20/40/80mhz comment="Master (SSID for Work)" configuration.mode=ap .ssid=($WifiWorkName . "-5GHz") disabled=no name=Wi-Fi-5GHz security.authentication-types=wpa2-psk,wpa3-psk .passphrase=$WifiWorkPassword
/interface wifi add channel.band=2ghz-ax .width=20/40/80mhz comment="Slave (SSID for Home)" configuration.mode=ap .ssid=($WifiHomeName . "-2GHz") disabled=no mac-address=4A:A9:8A:61:DB:F4 master-interface=Wi-Fi-2GHz name=WiFi-Home-2GHz security.authentication-types=wpa2-psk,wpa3-psk .passphrase=$WifiHomePassword
/interface wifi add channel.band=5ghz-ax .width=20/40/80mhz comment="Slave (SSID for Home)" configuration.mode=ap .ssid=($WifiHomeName . "-5GHz") disabled=no mac-address=4A:A9:8A:61:DB:F3 master-interface=Wi-Fi-5GHz name=WiFi-Home-5GHz security.authentication-types=wpa2-psk,wpa3-psk .passphrase=$WifiHomePassword
/interface list add name=WAN
/interface list add name=Home-LAN
/interface list add name=xDP
/interface list add name=Work-LAN

/ip ipsec profile set [ find default=yes ] dh-group=ecp256,modp2048,modp1024 enc-algorithm=aes-192,aes-128,3des
/ip ipsec proposal set [ find default=yes ] auth-algorithms=sha512,sha256,sha1
/ip pool add name=dhcp_pool_home ranges=192.168.90.2-192.168.90.254
/ip pool add name=dhcp_pool_work ranges=192.168.99.10-192.168.99.200
/ip dhcp-server add address-pool=dhcp_pool_work interface=Bridge-Work lease-time=1d name=DHCP-Work
/ip dhcp-server add address-pool=dhcp_pool_home interface=Bridge-Home lease-time=1d name=DHCP-Home
/ppp profile add name=SSTP-Work use-encryption=no use-ipv6=no use-mpls=no

/interface/sstp-client/add name=SSTP-Work connect-to=$L2tpServer verify-server-certificate=yes verify-server-address-from-certificate=yes profile=SSTP-Work ciphers=aes256-sha,aes256-gcm-sha384 authentication=mschap2 user=$USERNAME password=$USERPASSWORD disabled=no

/queue simple add max-limit=1G/1G name=Global target=""
/queue simple add limit-at=0/0 max-limit=1G/1G name=Work parent=Global priority=1/1 queue=pcq-upload-default/pcq-download-default target=Bridge-Work
/queue simple add max-limit=1G/1G name=Home parent=Global queue=pcq-upload-default/pcq-download-default target=Bridge-Home
/routing table add fib name=work
/interface bridge port add bridge=Bridge-Work interface=Gi2
/interface bridge port add bridge=Bridge-Work interface=Wi-Fi-2GHz
/interface bridge port add bridge=Bridge-Work interface=Wi-Fi-5GHz
/interface bridge port add bridge=Bridge-Home interface=WiFi-Home-2GHz
/interface bridge port add bridge=Bridge-Home interface=WiFi-Home-5GHz
/interface bridge port add bridge=Bridge-Home interface=Gi3
/interface bridge port add bridge=Bridge-Home interface=Gi4
/interface bridge port add bridge=Bridge-Home interface=Gi5
/ip firewall connection tracking set tcp-established-timeout=1h
/ip neighbor discovery-settings set discover-interface-list=xDP
/interface list member add interface=Gi1 list=WAN
/interface list member add interface=Bridge-Work list=Work-LAN
/interface list member add interface=Bridge-Home list=Home-LAN
/interface list member add interface=SSTP-Work list=xDP
/interface list member add interface=Bridge-Work list=xDP
/ip address add address=192.168.99.1/24 comment=Work interface=Bridge-Work network=192.168.99.0
/ip address add address=192.168.90.1/24 comment=Home interface=Bridge-Home network=192.168.90.0
/ip dhcp-client add comment="ISP#1" interface=Gi1 use-peer-dns=no use-peer-ntp=no
/ip dhcp-server network add address=192.168.99.0/24 comment=Work dns-server=10.242.8.168,10.241.8.168 gateway=192.168.99.1
/ip dhcp-server network add address=192.168.90.0/24 comment=Home dns-server=192.168.90.1 gateway=192.168.90.1
/ip dns set servers=1.1.1.1,8.8.8.8 allow-remote-requests=yes
/ip firewall address-list add address=192.168.90.0/24 list=Home-LAN
/ip firewall address-list add address=192.168.99.0/24 list=Work-LAN
/ip firewall address-list add address=$L2tpServer list=Work-VPN-IP-WAN
/ip firewall filter add action=accept chain=input disabled=yes in-interface-list=WAN src-address-list=Work-IP-WAN
/ip firewall filter add action=drop chain=input disabled=yes dst-port=22,8291 in-interface=Bridge-Home protocol=tcp src-address-list=Home-LAN
/ip firewall filter add action=drop chain=forward src-address=192.168.90.0/24 dst-address=192.168.99.0/24
/ip firewall filter add action=accept chain=forward connection-state=established,related disabled=yes
/ip firewall nat add action=masquerade chain=srcnat comment="Masquerade Home Network to Internet" out-interface-list=WAN dst-address=!10.0.0.0/8
/ip firewall nat add action=masquerade chain=srcnat out-interface=SSTP-Work src-address=192.168.99.0/24 dst-address=10.0.0.0/8

/ip firewall raw add action=drop chain=prerouting comment="Drop access to router from WAN" dst-port=22,8291,23 in-interface-list=WAN protocol=tcp
/ip firewall raw add action=add-src-to-address-list address-list=Knock-1 address-list-timeout=30s chain=prerouting comment="ICMP Knock from Home" in-interface=Bridge-Home packet-size=428 protocol=icmp
/ip firewall raw add action=add-src-to-address-list address-list=Knock-2 address-list-timeout=1m chain=prerouting in-interface=Bridge-Home packet-size=528 protocol=icmp src-address-list=Knock-1
/ip firewall raw add action=add-src-to-address-list address-list=Knock-access address-list-timeout=1h chain=prerouting in-interface=Bridge-Home packet-size=628 protocol=icmp src-address-list=Knock-2
/ip firewall raw add action=drop chain=prerouting comment="Drop access to router from Home" dst-port=8291,22,23 in-interface=Bridge-Home protocol=tcp src-address-list=!Knock-access
/ip firewall service-port set ftp disabled=yes
/ip firewall service-port set tftp disabled=yes
/ip firewall service-port set sip disabled=yes
/ip route add dst-address=10.0.0.0/8 gateway=SSTP-Work routing-table=work 
/ip service set telnet disabled=no
/ip service set ssh disabled=no
/ip service set winbox disabled=no
/ip service set ftp disabled=yes
/ip service set www disabled=yes
/ip service set api disabled=yes
/ip service set api-ssl disabled=yes
/mpls settings set allow-fast-path=no propagate-ttl=no
/routing rule add action=lookup-only-in-table disabled=no src-address=192.168.99.0/24 dst-address=10.0.0.0/8 table=work
/system clock set time-zone-name=Europe/Amsterdam
/system identity set name=("RT-RAVPN10-" . $USERNAME . "Ver." . $Version )
/system note set show-at-login=no
/system ntp client set enabled=yes
/system ntp client servers add address=0.ua.pool.ntp.org
/system ntp client servers add address=1.ua.pool.ntp.org
/system ntp client servers add address=3.ua.pool.ntp.org
/tool bandwidth-server set authenticate=no enabled=no
/tool mac-server set allowed-interface-list=xDP
/tool mac-server mac-winbox set allowed-interface-list=xDP
/tool mac-server ping set enabled=no
/tool romon/set enabled=yes
/user add name=$supportUser password=$supportPassword group=full
/user/set admin disabled=yes
/ip firewall filter add chain=input in-interface-list=WAN connection-state=established,related action=accept
/ip firewall filter add chain=input in-interface-list=WAN protocol=icmp action=accept
/ip firewall filter add chain=input in-interface-list=WAN action=drop


######create version file#############
:foreach fileId in=[/file find] do={
    :local fname [/file get $fileId name];
    :if ($fname ~ ".ver") do={
    /file remove $fileId
    			     }
				   }
/file/add name="$Version.ver"


############whatsapp###########
/system script add name="WhatsApp" source={
:if ([:len [/file find name="whatsapp_cidr_ipv4.rsc"]] > 0) do={
    /file remove [find name="whatsapp_cidr_ipv4.rsc"]
}
/tool/fetch url="https://raw.githubusercontent.com/HybridNetworks/whatsapp-cidr/main/WhatsApp/whatsapp_cidr_ipv4.rsc";
:delay 30s;
:if ([:len [/file find name="whatsapp_cidr_ipv4.rsc"]] > 0) do={
    /ip firewall address-list remove [find comment="WHATSAPP-CIDR"]
}
/import whatsapp_cidr_ipv4.rsc verbose=yes
}
/ip firewall nat add action=masquerade chain=srcnat out-interface=SSTP-Work src-address=192.168.99.0/24 dst-address-list=WHATSAPP-CIDR 
/routing table add fib name=whatsapp
/ip route add dst-address=0.0.0.0/0 gateway=SSTP-Work routing-table=whatsapp
/ip firewall/mangle/add chain=prerouting src-address=192.168.99.0/24 dst-address-list=WHATSAPP-CIDR action=mark-routing new-routing-mark=whatsapp passthrough=no
#############end##############

############russia###########
/system script add name="rasha" source={
:if ([:len [/file find name="rasha.rsc"]] > 0) do={
/file remove [find name="rasha.rsc"]
}
/tool/fetch url="https://raw.githubusercontent.com/gusandkon/whatsafuck/main/rasha.rsc";
:delay 30s;
:if ([:len [/file find name="rasha.rsc"]] > 0) do={
/ip firewall address-list remove [find comment="rasha"]
/import rasha.rsc verbose=yes
}
}
/ip firewall nat add action=masquerade chain=srcnat out-interface=SSTP-Work src-address=192.168.99.0/24 dst-address-list=RASHA
/routing table add fib name=rus
/ip route add dst-address=0.0.0.0/0 gateway=SSTP-Work routing-table=rus
/ip firewall/mangle/add chain=prerouting src-address=192.168.99.0/24 dst-address-list=RASHA action=mark-routing new-routing-mark=rus passthrough=no
#############end of russia##############

############letsencrypt#################
/system script add name="ImportCert" source={
:local importSuccess false;
:while ($importSuccess = false) do={
:if ([:len [/file find name="isrgrootx1.der"]] = 0) do={
/tool fetch url="https://letsencrypt.org/certs/isrgrootx1.der" mode=https dst-path="isrgrootx1.der";
:delay 1s;
}
:if ([:len [/file find name="isrgrootx1.der"]] > 0) do={
/certificate import file-name="isrgrootx1.der" name="ISRG Root X1"
:local certExists [:len [/certificate find where name="ISRG Root X1"]];
:if ($certExists > 0) do={
:set importSuccess true
}
}
}
}
#############end of Letsencrypt##############

#########Startup script##############
/system script add name=StartupScripts source={
:while (true) do={
:local pingResult [/ping google.com count=3];
:if ($pingResult > 0) do={     
/import credentials.rsc
/system script run ImportCert;
:delay 5s;
/system script run rasha;
:delay 5s;
/system script run WhatsApp;
break;
} else {
:delay 5s;
}
}
}
/system scheduler add name="StartupScripts" on-event="/system script run StartupScripts" start-time=startup interval=0
/system scheduler add name="UpdateOnboot" on-event="/import Update.rsc" start-time=startup interval=0
/system scheduler add name="WhatsApp" on-event="/system script run WhatsApp" start-time=startup interval=48h
/system scheduler add name="rasha" on-event="/system script run rasha" start-time=startup interval=6h
/system scheduler add name="Update" on-event="/import Update.rsc" start-time=startup interval=1d
/system scheduler add name="CertUpdate" on-event="/system script run ImportCert" start-time=startup interval=30d
/system script run StartupScripts
###########################################################
