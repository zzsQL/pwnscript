#!/bin/bash
# Color Variables
# Find this on github at https://github.com/zzsQL/pwnscript.git
RED='\033[0;31m' #Red pl0x
NC='\033[0m' #No Color
sed -i.bak '/192/d' /etc/hosts #Remove old /etc/hosts entry for machine. make bakup
sed -i.bak '/10/d' /etc/hosts
echo Old target removed from /etc/hosts
touch notes.txt
echo "Howdy, "$USER". Launching PwnScript.sh!."
read -p 'Target IP: ' targetIP
echo -e $targetIP... "${RED} I have you now...${NC}"
echo -e "${RED}Open Ports${NC}"
echo $targetIP  target >>/etc/hosts
echo target added to /etc/hosts
export target=$targetIP
echo $targetIP >> notes.txt
curl -s -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 Safari/537.36" http://$targetIP |grep API >api-curl.out
curl -A "GoogleBot" http://$targetIP/robots.txt >>robots-googlebot.txt
wget $targetIP/robots.txt &
wget $targetIP &  #get the index.html file, if any. Web server-configured
nmap -F $targetIP > open-ports.out &
whatweb --color=never --no-errors -a 3 -v http://$targetIP:80 2>&1  >whatweb.out
nikto -Display 1234EP -o nikto-report.html -Format txt -Tuning 123bde -host http://$targetIP
cewl -d 2 -m 5 -w cewlwords.out http://$targetIP
wget http://$targetIP/wordpress/robots.txt > wp-robots.txt
wget http://$target/wordpress >wp-curl.out
autorecon $targetIP &
dirb http://$targetIP /usr/share/wordlists/dirb/big.txt -X .php,.txt,.json,.html  >dirb.out &
gobuster -e -q dir -u http://$targetIP -w /usr/share/wordlists/dirb/common.txt -x php,html,sh,txt,cgi,js,css,py  -o gobuster.out &
enum4linux $targetIP >enum4linux.out&
grep tcp ver-ports-os-detect.out >> ports.out &
sed -i '/^$/d' * # Delete empty lines from output files for viewability
sed '/403/d' gobuster.out >>gobuster2.out ; rm gobuster.out | mv gobuster2.out gobuster.out #remove 403s from gobuster
grep open ver-ports-os-detect.out >>notes.txt
nmap -sV -A -O -p- $targetIP >ver-ports-os-detect.out &  #-A svc ver detect, -O OS detect, -p- all ports
nmap -sV -vv -script vuln $targetIP > vulns.out &
echo done!
# Future features: 
# modify to support network scanning of multiple hosts on the subnet
# Targetting of discovered hosts
# subdirectories of potential targets
# Future features: if X found, then do this
# Specifically, scan with nikto urls found with dirb. 
# nmap -n -sV --script memcached-info -p 11211 target #scan for 11211/tcp open memcache
