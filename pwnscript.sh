#!/bin/bash
# version = 16 Mai 2025

# Color Variables
RED='\033[0;31m' # Red
NC='\033[0m'     # No Color

# Remove old target from /etc/hosts
sed -i.bak '/target/d' /etc/hosts
echo 'Old target removed from /etc/hosts'

# Copy notes.txt file to the current directory
cp /home/loki/OSCP/notes.txt .

# Function to validate IP address
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Prompt user for target IP and validate
echo "Howdy, $USER. Launching PwnScript.sh!"
while true; do
    read -p 'Target IP: ' targetIP
    if validate_ip "$targetIP"; then
        break
    else
        echo "Invalid IP address. Please enter a valid IPv4 address."
    fi
done

echo "$targetIP" >> notes.txt
echo -e "$targetIP... ${RED}I have you now...${NC}"
echo -e "${RED}Open Ports${NC}"

echo "$targetIP target" >> /etc/hosts
echo 'Target added to /etc/hosts'

# Initial Recon for ports
echo 'Initial Recon for ports'
nmap -sV -T4 -O -F --version-light "$targetIP" -oN ver-nmap-light.out
grep tcp ver-nmap-light.out | grep '/' | grep open > ports.txt
cut -d '/' -f 1 ports.txt > ports.out
rm ports.txt

# Loop over each port and perform commands
while IFS= read -r port; do
    echo "Performing commands for port $port"
    case $port in
        20|21)
            mkdir -p ftp/ && cd ftp/
            nmap -T4 -v -p 21,20 --script=ftp*.nse --script-args=unsafe=1 "$targetIP" -oN ftp-nmap.out
            cd ..
            ;;
        22)
            nmap -sV -p 22 "$targetIP" -oN ssh-mmap.out
            ;;
        25)
            mkdir -p smtp/ && cd smtp/
            smtp-user-enum -M VRFY -U /home/loki/passes/users.txt -t "$targetIP" > smtp-user-enum.out
            nmap -T4 -sV -p25 "$targetIP" -oN smtp-vulns.out &
            nmap -T4 -v -p 25 --script=smtp*.nse --script-args=unsafe=1 "$targetIP" -oN smtp-nse.out
            cd ..
            ;;
        80|443)
            mkdir -p webstuff/ && cd webstuff/
            nmap --script http-methods --script-args http-methods.url-path='/test' "$targetIP" -oN http-methods-nmap.out
            wget "$targetIP/robots.txt" -O robots.txt
            wget --recursive -np -nc -nH --cut-dirs=4 --random-wait --wait 1 -e robots=off "http://$targetIP"
            nikto -h "$targetIP" -output nikto.txt
            feroxbuster -u "http://$targetIP" -x pdf,js,html,php,txt,json,docx -o ferox.out
            curl -A "GoogleBot" "http://$targetIP/robots.txt" >> robots-curl.txt
            whatweb --color=always --no-errors -a 3 -v "http://$targetIP:80" > whatweb.out 2>&1
            cewl -d 2 -m 5 -w cewlwords.out "http://$targetIP"
            gobuster -e -q dir -u "http://$targetIP" -w /usr/share/wordlists/dirb/common.txt -x php,html -o gobuster.out
	    ffuf -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -u "http://$targetIP/FUZZ"
            sed '/403/d' gobuster.out > gobuster.txt
            rm gobuster.out
            if grep -qi "WordPress" whatweb.out; then
                echo -e "${RED}[+] WordPress detected. Launching WPScan...${NC}"
                wpscan --url "http://$targetIP" --enumerate u,vp,vt,cb,dbe --random-user-agent --ignore-main-redirect --disable-tls-checks -o wpscan.txt
            else
                echo "[i] No WordPress detected by WhatWeb."
            fi
            cd ../..
            ;;
        *)
            echo "[*] No specific actions for port $port"
            ;;
    esac
done < ports.out

# Vuln scans
nmap -T4 -A "$targetIP" -oN nmap-A.out
nmap -T4 --vv --script vuln "$targetIP" -oN vulns-nmap.out
hydra -l root -P /home/loki/passwords/rockyou.txt "$targetIP" mysql -s 3306 -f -o mysql-hydra.out

# Cleanup
sed -i '/^$/d' *                 # Remove empty lines from all files
find . -empty -type f -delete   # Delete empty files

