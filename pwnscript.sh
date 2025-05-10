#!/bin/bash
# Color Variables
# version = 0745-15FEB-2024
RED='\033[0;31m' # Red
NC='\033[0m' # No Color

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
echo 'Howdy, '"$USER"'. Launching PwnScript.sh!'
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
            nmap -T4 -sV -p 25 "$targetIP" -oN smtp-vulns.out &
            nmap -T4 -v -p 25 --script=smtp*.nse --script-args=unsafe=1 "$targetIP" -oN smtp-nse.out
            cd ..
            ;;
        80|443)
            mkdir -p webstuff/ && cd webstuff/
            # feroxbuster -u "http://$targetIP" -x pdf -x js,html -x php txt json,docx -o ferox.out
            nmap --script http-methods --script-args http-methods.url-path='/test' "$targetIP" -oN http-methods-nmap.out
            curl -A "GoogleBot" "http://$targetIP/robots.txt" >> robots-curl.txt
            wget "$targetIP/robots.txt" > robots.txt
            wget --recursive -np -nc -nH --cut-dirs=4 --random-wait --wait 1 -e robots=off "http://$targetIP"
            whatweb --color=never --no-errors -a 3 -v "http://$targetIP:80" 2>&1 > whatweb.out
            nikto -h "$targetIP" -output nikto.txt
            cewl -d 2 -m 5 -w cewlwords.out "http://$targetIP"
            gobuster dir -e -q -u http://$targetIP -w /usr/share/wordlists/dirb/common.txt -x php,html -o gobuster.out &
            sed '/403/d' gobuster.out > gobuster.txt
            rm gobuster.out
            curl -s -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 Safari/537.36" http://$targetIP | grep API > api-curl.out &
            cd ..
            ;;
        161)
            mkdir -p snmp/ && cd snmp/
            nmap -sV -p 161 --script=snmp-info "$targetIP" > snmp-nmap-nse.out
            nmap -sU --open -p 161 "$targetIP" -oG -oN snmp-nmap-scan.out
            snmpcheck -t "$targetIP" -c public > snmpcheck.out
            snmpwalk -c public -v1 "$targetIP" > snmpwalk.out
            snmpenum -t "$targetIP" > snmpenum.out
            onesixtyone "$targetIP" > snmp-onesixtyone.out
            snmpwalk -c public -v1 -t 10 "$targetIP" > snmpwalk1.out
            snmpwalk -c public -v1 "$targetIP" 1.3.6.1.4.1.77.1.2.25 > snmpwalk2.out
            snmpwalk-windoze-usernames.out > snmp-users.out
            snmpwalk -c public -v1 "$targetIP" 1.3.6.1.2.1.25.4.2.1.2 > snmp4.out
            snmpwalk-windoze-processes.out > snmp-windoze-processes.out
            snmpwalk -c public -v1 "$targetIP" 1.3.6.1.2.1.6.13.1.3 > snmp-something.out
            snmpwalk-windoze-ports.out > snmp-enum-ports.out
            snmpwalk -c public -v1 "$targetIP" 1.3.6.1.2.1.25.6.3.1.2 > snmapwalk-something2.out
            snmpwalk-windoze-software.out > snmp-enum-windows-sftw.out
            cd ..
            ;;
        *)
            # Default case
            ;;
    esac
done < ports.out

# Vuln scans
nmap -T4 -A "$targetIP" -oN nmap-A.out
nmap -T4 --vv --script vuln "$targetIP" -oN vulns-nmap.out

# Cleanup
