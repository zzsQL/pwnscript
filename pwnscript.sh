#!/bin/bash
# Color Variables
# Find this on github at https://github.com/zzsQL/pwnscript.git
# Ver - 17 May, 2023
RED='\033[0;31m' #Red pl0x
NC='\033[0m' #No Color machine.
sed -i.bak '/target/d' /etc/hosts
echo 'Old target removed from /etc/hosts'
cp /home/loki/OSCP/notes.txt . #Maintain your notes file on the target
echo 'Howdy, "$USER$". Launching PwnScript.sh!.'
read -p 'Target IP: ' targetIP
echo $targetIP >> notes.txt
echo -e $targetIP... "${RED} I have you now...${NC}"
echo -e "${RED}Open Ports${NC}"
echo $targetIP  target >>/etc/hosts
echo 'target added to /etc/hosts'
#nmap discovery scan - Fast
echo 'Initial Recon for ports'
#
nmap -sV -T4 -O -F --version-light $targetIP -oN nmap-ver-light.out &
nmap -p 1-65535 -sV -sS -A -T4 target -oN nmap-initial.out
nmap $targetIP --reason -oN nmap-top-1000-reasons.out
#
#FTP 20/21 Vulns
nmap -T4 -v -p 21,20 --script=ftp*.nse --script-args=unsafe=1 $targetIP -oN nmap-ftp.out &
#
#SSH 22 Version
nmap -sV -p 22 $targetIP -oN nmap-ssh.out &
#
#SMTP Enum - Vuln Scans
smtp-user-enum -M VRFY -U /home/loki/passes/users.txt -t $targetIP >smtp-user-enum.out &
nmap -T4 -sV -p25 $targetIP -oN smtp-vulns.out &
nmap -T4 -v -p 25 --script=smtp*.nse --script-args=unsafe=1 $targetIP -oN smtp-nse.out &
#
#Web Stuff
nmap --script http-methods --script-args http-methods.url-path='/test' $targetIP -oN nmap-http-methods.out
#
# curl -s -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 >curl1.out & Safari/537.36" http://$targetIP |grep API >api-curl.out &
curl -A "GoogleBot" http://$targetIP/robots.txt >>robots.txt &
wget $targetIP/robots.txt &
wget $targetIP &  #get the index.html file, if any. Check other open http ports.
whatweb --color=never --no-errors -a 3 -v http://$targetIP:80 2>&1  >whatweb.out
nikto -h $targetIP >nikto.out
#
# nikto -Display 1234EP -o nikto-report.html -Format txt -Tuning 123bde -host http://$targetIP &
cewl -d 2 -m 5 -w cewlwords.out http://$targetIP & #Not really necessry but good form
dirb http://$targetIP /usr/share/wordlists/dirb/big.txt -X .zip,.php,.txt,.json,.html >dirb.out &
gobuster -e -q dir -u http://$targetIP -w /usr/share/wordlists/dirb/common.txt -x php,html  -o gobuster.out &
#
#SMB Enum Usernames / Shares / Groups
enum4linux -a $targetIP >enum4linux.out &
nmap -T4 -v -oA shares --script smb-enum-shares --script-args $targetIP -oN nmap-smb-shares.out&
nmap smbuser=username,smbpass="" -p445 $targetIP -oN nmap-smb-check.out &
#
# smbmap -H $targetIP >smbmap.out &
nmap -T4 -v -p 161 --script=smb*.nse --script-args=unsafe $stargetIP -oN smb-nse.out &
#
#SNMP
nmap -sU --open -p 161 $targetIP -oG -oN snmp-nmap-scan.out & #only show open ports &
snmp-check $targetIP >snmp-check.out &
onesixtyone $targetIP >snmp-onesixtyone.out & #brute force snmp 
snmpwalk -c public -v1 -t 10 $targetIP >snmpwalk1.out &
snmpwalk -c public -v1 $targetIP 1.3.6.1.4.1.77.1.2.25 >snmpwalk2.out &
snmpwalk-windoze-usernames.out >snmp-users.out &
snmpwalk -c public -v1 $targetIP 1.3.6.1.2.1.25.4.2.1.2 >snmp4.out &
snmpwalk-windoze-processes.out >snmp-windoze-processes.out &
snmpalk -c public -v1 $targetIP 1.3.6.1.2.1.6.13.1.3 >snmp-something.out &
snmpwalk-windoze-ports.out >snmp-enum-ports.out &
snmpalk -c publivc -v1 $targetIP 1.3.6.1.2.1.25.6.3.1.2 >snmapwalk-something2.out &
snmpwalk-windoze-software.out >snmp-enum-windows-sftw.out &
#
#Vuln scans
nmap -T4 -A $targetIP -oN nmap-A.out &
nmap -T4 --vv --script vuln $targetIP -oN nmap-vulns.out &
#
#Fix autorecon $targetIP &
#Cleanup
sed -i '/^$/d' * # Delete empty lines from output files for viewability
#
#Fix gobuster.out, removing 403s
sed '/403/d' gobuster.out > gobuster.txt ; rm gobuster.out
