#!/bin/bash
# BlackArch Launcher v11

ROFI_THEME="$HOME/.config/rofi/blackarch-theme.rasi"
ICON="/usr/share/icons/Papirus/64x64/apps/distributor-logo-blackarch.svg"
PIDFILE="/tmp/blackarch-launcher.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
  kill "$(cat $PIDFILE)"
  rm -f "$PIDFILE"
  exit 0
fi
echo $$ > "$PIDFILE"
trap "rm -f $PIDFILE" EXIT

launch_tool() {
  local tool="$1"

  # GUI apps
  local gui_apps="burpsuite maltego wireshark autopsy ghidra zenmap armitage beef caido-desktop ettercap-graphical networkminer fern-wifi-cracker vega webscarab owasp-zap"
  for g in $gui_apps; do
    if [[ "$tool" == "$g" ]]; then
      nohup "$tool" > /dev/null 2>&1 & disown; return
    fi
  done

  # Check .desktop GUI
  if find /usr/share/applications /usr/local/share/applications ~/.local/share/applications \
       -name "${tool}.desktop" 2>/dev/null | grep -q .; then
    nohup gtk-launch "$tool" > /dev/null 2>&1 & disown; return
  fi

  local tmpscript
  tmpscript=$(mktemp /tmp/ba_XXXXXX.sh)

  {
    echo '#!/bin/bash'
    echo 'R="\033[1;31m"'
    echo 'Y="\033[1;33m"'
    echo 'D="\033[0;37m"'
    echo 'N="\033[0m"'
    echo ''
    echo '# Collect help silently first — no output yet'
    echo "BINARY=\"${tool}\""
    echo 'HELP=""'
    echo 'command -v "$BINARY" &>/dev/null && HELP=$("$BINARY" --help 2>&1)'
    echo '[ -z "$HELP" ] && command -v "$BINARY" &>/dev/null && HELP=$("$BINARY" -h 2>&1)'
    echo 'B2="${BINARY//-/_}"'
    echo '[ -z "$HELP" ] && command -v "$B2" &>/dev/null && HELP=$("$B2" --help 2>&1)'
    echo '[ -z "$HELP" ] && command -v "$B2" &>/dev/null && HELP=$("$B2" -h 2>&1)'
    echo '[ -z "$HELP" ] && HELP=$(man "$BINARY" 2>/dev/null | col -bx | head -60)'
    echo '[ -z "$HELP" ] && HELP=$(man "$B2" 2>/dev/null | col -bx | head -60)'
    echo ''
    echo '# Hard reset terminal — clears everything including scrollback'
    echo 'printf "\033c"'
    echo ''
    echo '# Figlet ASCII art tool name in red'
    echo 'echo -e "${R}"'
    echo "figlet -f slant '${tool}' 2>/dev/null || figlet '${tool}' 2>/dev/null || echo '  ${tool}'"
    echo 'echo -e "${N}"'
    echo 'echo ""'
    echo ''
    echo '# Show usage or info'
    echo 'if [ -n "$HELP" ]; then'
    echo '  echo -e "${R}-- Usage & Flags ---------------------------------------------------${N}"'
    echo '  echo ""'
    echo '  echo -e "${D}${HELP}${N}" | head -50'
    echo '  echo ""'
    echo '  echo -e "${R}--------------------------------------------------------------------${N}"'
    echo 'else'
    echo '  echo -e "${R}-- Info ------------------------------------------------------------${N}"'
    echo '  echo ""'
    echo '  echo -e "${Y}  No CLI flags found.${N}"'
    echo "  echo -e \"\${D}  Try: pacman -Ql ${tool} | grep bin\${N}\""
    echo '  echo ""'
    echo '  echo -e "${R}--------------------------------------------------------------------${N}"'
    echo 'fi'
    echo 'echo ""'
    echo ''
    echo '# Write a bashrc for the interactive shell with correct PS1'
    echo 'TMPRC=$(mktemp /tmp/ba_rc_XXXXXX)'
    echo "echo \"PS1=\\\"\\[\\033[31m\\][${tool}]\\[\\033[0m\\]> \\\"\" > \"\$TMPRC\""
    echo 'echo "export HISTFILE=~/.bash_history" >> "$TMPRC"'
    echo 'exec bash --rcfile "$TMPRC"'
  } > "$tmpscript"

  chmod +x "$tmpscript"

  nohup kitty \
    --config ~/.config/kitty/blackarch-tool.conf \
    --title "BlackArch :: ${tool}" \
    --start-as maximized \
    -e bash "$tmpscript" > /dev/null 2>&1 &
  disown
  sleep 0.3 && hyprctl dispatch fullscreenstate 1 &
  disown
  (sleep 30 && rm -f "$tmpscript") &
  disown
}

declare -A categories=(
  ["⚙️  Automation & Misc"]="blackarch-mirrorlist bopscrk cewl comission crunch cupp docem eazy eindeutig eos lyricpass mentalist ms-sys mxtract naft netspionage pipal pipeline python-witnessme regipy regripper regrippy regview smplshllctrlr spaf tell-me-your-secrets uff usbrip wcvs weirdaal wmat wyd xxeinjector yaaf"
  ["🌀  Fuzzer"]="cmsfuzz crlfuzz dalfox easyfuzzer ffuf fhttp interactsh-client lorsrf monsoon ppfuzz ppmap radamsa restler-fuzzer shortfuzzy spike-proxy stunner wfuzz ws-attacker wsfuzzer xspear"
  ["🌐  Webapp"]="adminpagefinder albatar anti-xss arachni arjun asp-audit assassingo aws-extender-cli backcookie badministration badsecrets bfac blindelephant blisqy brakeman brutexss burpsuite c5scan caido-cli caido-desktop cangibrina cansina captipper cloudget cms-explorer cms-few cmseek cmsmap cmsscan cmsscanner commentor compp conpass conscan corscanner corstest cpfinder crabstick crawlic crlf-injector crlfuzz csrftester cutycapt dalfox davscan davtest dawnscanner dcrawl depant device-pharmer dff-scanner dirb dirble dirbuster dirbuster-ng directorytraversalscan dirscanner dirscraper dirsearch dirstalk disitool dontgo403 droopescan drupal-module-enum drupalscan drupwn dsstore-crawler dsxs dumpzilla easyfuzzer evine extended-ssrf-search f-scrack feroxbuster filebuster fireprox flashscanner flunym0us fockcache ftp-scanner ghost-py gobuster graphinder graphql-cop graphql-path-enum graphqlmap graphw00f gwtenum h2buster h2csmuggler h2t habu hakku halberd hexhttp hookshot htcap htpwdscan http2smugl httpforge httpgrep httppwnly httpx identywaf iisbruteforcer imagejs inurlbr isr-form jira-scan jomplug jooforce joomlascan joomlavs joomscan jsonbee jsparser juumla kadimus keye konan laf lightbulb linkfinder loki-scanner lulzbuster magescan mantra mwebfp mybff nikto nuclei nuclei-templates obevilion okadminfinder otori owasp-bywaf owtf parameth parampampam paramspider paranoic paros php-malware-finder php-mt-seed phpggc pixload plecost poracle ppmap pyfiscan rapidscan ratproxy rawr recsech red-hawk replayproxy restler-fuzzer rpdscan rustbuster sawef sb0x scrying secretfinder secscan see-surf semgrep sergio-proxy sitadel sitediff skipfish smuggler smuggler-py snallygaster snuck sparta sparty spike-proxy spipscan sslstrip sslyze ssrf-sheriff ssrfmap sstimap stews striker subjs taipan tinja tomcatwardeployer trevorproxy typo3scan uatester uniscan v3n0m vane vega vulnerabilities-spider vulnx w13scan w3af wafninja wafp wafpass wafw00f wapiti wascan wayparam wcvs web-soul webborer webenum webkiller webrute webscarab webshag webslayer webspa webtech webxploiter whatwaf whichcdn whitewidow wig witchxtool wmat wordbrutepress wordpress-exploit-framework wordpresscan wpbf wpbrute-rpc wpbullet wpforce wpintel wpseku wssip wuzz x8 xsrfprobe xss-freak xsscon xsscrapy xsser xssless xsspy xsss xssscan xsssniper xsstracer xsstrike xssya xwaf yawast ycrawler"
  ["🍯  Honeypot"]="epicwebhoneypot sentrypeer snare"
  ["🎭  Spoofing & MitM"]="bettercap ettercap evilmaid hamster hyperfox intercepter-ng ipsourcebypass responder sslnuke sslstrip trevorproxy"
  ["🏁  CTF Tools"]="binwalk bkcrack bulk-extractor exrex foremost jdeserialize pcapxray pev pngcheck python2-exrex recoverjpeg rsactftool scalpel seccomp-tools stegdetect steghide stegsolve swftools unblob zipdump"
  ["💥  Exploitation"]="0d1n abuse-ssl-bypass-waf astra atlas bbqsql beef bing-lfi-rfi brainstorm bsqlbf bsqlinjector byepass chankro cjexploiter clairvoyance cmsfuzz commix corsy darkmysqli doozer dsfs dsjs dsss dsxs enabler evilize fdsploit fimap fuxploider ghauri gopherus grabber inguma injectus iptv jaidam jast jboss-autopwn jdeserialize jeangrey jexboss jinjector jshell jsql-injection kadimus laudanum leviathan lfi-exploiter lfi-fuzzploit lfi-image-helper lfi-scanner lfi-sploiter lfifreak lfimap lfisuite lfle liffy log4j-bypass log4j-scan morxbtcrack morxcoinpwn morxtraversal mosquito msfconsole multiinjector nosqli nosqli-user-pass-enum nosqlmap nox-framework obevilion opendoor owtf payloadmask pblind pdblaster php-findsock-shell php-rfi-payload-decoder php-vulnerability-hunter phpggc phpsploit pixload plown poly poracle pureblood pythem rabid remot3d richsploit rookie rww-attack scanqli serializationdumper sjet skul sqlbrute sqldict sqlivulscan sqlninja sqlpat sqlping sqlpowerinjector sqlsus ssrfmap sstimap stunner themole tomcatwardeployer tplmap ufonet uncaptcha2 uppwn vbscan visql w3af webacoo webexploitationtool webhandler webpwn3r webshells webxploiter weevely weirdaal ws-attacker wsfuzzer xmlrpc-bruteforcer xxeinjector xxexploiter xxxpwn xxxpwn-smart yinjector ysoserial zackattack"
  ["📡  Sniffer"]="bettercap chaosreader dshell dsniff ettercap fs-nyarl hamster hdmi-sniff intercepter-ng morxbook mosquito netspionage networkminer pcapfex pcapxray responder sergio-proxy stenographer tcpdump wireshark xplico"
  ["📦  Post Exploit"]="ares cachedump creddump credmaster evilmaid fridump impacket-ba kekeo laudanum lazagne limeaide mimikatz mimipenguin netexec phpsploit pwncat-caleb pwndrop rekall remot3d webacoo webhandler webshells weevely"
  ["📱  Social & OSINT"]="belati canari casefile exiflooter facebash facebot facebrute fbht gspy haystack instashell maltego mando.me maryam morxbook onionsearch pinkerton seeker seekr sherlock tekdefense-automater tinfoleak tinfoleak2 tweetshell"
  ["📲  Mobile"]="androick android-sdk androidpincrack apktool fridump iosforensic ipba2 iphoneanalyzer"
  ["📶  Wireless"]="aircrack-ng asleap auto-eap chapcrack eapmd5pass fern-wifi-cracker hashcatch ike-scan ikecrack ikeforce ikeprobe linset mdk3 pixiewps reaver rfcat rfcrack riwifshell samydeluxe ufo-wardriving wifibroot wifite wirouter-keyrec wpa2-halfhandshake-crack"
  ["📻  Radio / SDR"]="rfcat rfcrack sdrsharp sdrtrunk"
  ["🔁  Reversing"]="analyzepesig androick android-sdk apktool balbuzard captipper chipsec dpeparser emldump erl-matter gdb ghidra iheartxor jadx jdeserialize jefferson jstillery lief ltrace make-pdf malheur malicious-pdf malwaredetect origami pdf-parser pdfid peepdf pev php-malware-finder python-lief python-oletools python2-capstone python2-frida python2-jsbeautifier python2-oletools python2-pcodedmp python2-peepdf radare2 seccomp-tools serializationdumper strace stringsifter swftools unblob vipermonkey vsvbp"
  ["🔊  VoIP"]="iaxscan sipbrute sipcrack sj sjet stunner"
  ["🔍  Recon"]="allthevhosts amap amass archivebox assetfinder bbscan belati canari cariddi casefile cent chaosmap chaosreader cloudget cybercrowl d-tect darkbing darkd0rk3r darkdump darkjumper darkscrape dcrawl detectem dirhunt dmitry dnsenum dnsmap dnsrecon dnswalk domi-owned doork dorknet dpscan dumb0 eindeutig eos evine exiflooter eyewitness fang fbht fierce fingerprinter ftp-spider gau git-dumper gitdump gittools golismero gomapenum goohak goop-dump gospider gowitness graphinder grpc-pentest-suite gspy gwtenum h2t habu hakrawler halberd haystack hetty host-extract htcap httpx inguma interrogate inurlbr jaeles jok3r jsearch jsparser katana-framework katana-pd keye kiterunner kolkata konan lbd lbmap linkfinder list-urls lorsrf maltego mando.me mantra maryam massdns meg metoscan monsoon morxtraversal mwebfp mxtract naft netspionage networkminer novahot o365enum okadminfinder onesixtyone onionsearch otori pack pappy-proxy parameth parampampam paramspider peepingtom periscope phantomcollect phoss photon pinkerton plecost pown proxenet python2-api-dnsdumpster python2-shodan rapidscan ratproxy rawr recsech red-hawk replayproxy rpdscan rustbuster rustpad sawef sb0x scrying sea search1337 seat second-order secretfinder secscan see-surf seeker seekr sees semgrep shortfuzzy shuffledns sidguesser sitadel sitediff sj sn1per snallygaster snitch sourcemapper sparta spiga spipscan sqid striker subfinder subjs swarm taipan tekdefense-automater tell-me-your-secrets theharvester tidos-framework tinfoleak tinfoleak2 torcrawl trid truehunter uatester uniscan urlcrazy urldigger urlextractor urx v3n0m vanguard vulnerabilities-spider vulnx w13scan w3af wascan waybackpack wayparam webanalyze webhunter webshag webslayer webspa webtech whatweb whichcdn whitewidow wig witchxtool yaaf yasuo yawast ycrawler zgrab"
  ["🔑  Passwords & Crypto"]="aesfix aeskeyfind bkcrack blackhash btcrack crackle duplicut flask-session-cookie-manager2 flask-session-cookie-manager3 flask-unsign hashdb hasher hashpump hate-crack ikecrack jwt-tool jwtcat mdcrack morxbtcrack morxcoinpwn morxkeyfmt myjwt orakelcrackert passe-partout passgan pemcrack pemcracker pkcrack pyrit rcracki-mt rsactftool rsakeyfind thc-keyfinder ttpassgen wordlistctl zykeys"
  ["🔓  Cracker"]="acccheck against androidpincrack asleap auto-eap beleth bgp-md5crack bkhive blackhash bob-the-butcher bopscrk brute-force brute12 bruteforce-luks bruteforce-salted-openssl bruteforce-wallet brutemap brutespray brutessh brutex brutus btcrack cachedump cewl chapcrack cintruder cisco5crack cisco7crack cmospwd crackhor crackle crackmapexec crackpkcs12 crackq crackql crackserver creddump credmaster crowbar crunch cupp dbpwaudit duplicut eapmd5pass f-scrack facebash facebrute firefox-decrypt flask-session-cookie-manager2 flask-session-cookie-manager3 flask-unsign gpocrack gpp-decrypt hashcat hashcatch hashdb hasher hashpump hashtag hate-crack hdcp-genkey hydra ibrute icloudbrutter iisbruteforcer ikecrack instashell jbrute john johnny jooforce jwt-cracker jwt-hack jwt-tool jwtcat keimpx kerbcrack kerberoast kerbrute khc ldap-brute ldsview letmefuckit-scanner levye lodowep lyricpass mdcrack mdk3 mentalist mkbrutus morxbrute morxbtcrack morxcoinpwn morxcrack morxkeyfmt munin-hashchecker mybff myjwt ntlmv1-multi o365spray oclhashcat omen ophcrack orakelcrackert outlook-webapp-brute owabf pack passe-partout passgan patator pemcrack pemcracker phrasendrescher pipal pkcrack pmdump pwcrack pwdump pybozocrack pyrit rainbowcrack rcracki-mt rdesktop-brute rdpassspray rhodiola rlogin-scanner rootbrute rsactftool rsakeyfind ruler samdump2 sipbrute sipcrack smbbf smplshllctrlr smtp-user-enum snmp-brute speedpwn spray365 spraycharles sprayingtoolkit ssh-privkey-crack sshatter sshprank sshscan sshtrix sucrack talon tftp-bruteforce thc-keyfinder thc-pptp-bruter thc-smartbrute trevorspray ttpassgen tweetshell uppwn vnc-bypauth vncrack wordlistctl wpa2-halfhandshake-crack wyd xorbruteforcer zykeys"
  ["🔬  Scanner"]="amap apachetomcatscanner atscan atstaketools blackbox-scanner cisco-auditing-tool cisco-ocs cisco-scanner cisco-snmp-enumeration cisco-torch conscan dbpwaudit delldrac dpscan hostbox-ssh iaxscan ipmipwn jok3r katana-pd konan kubolt lbd lbmap masscan mooscan naft nmap ocs onesixtyone openvas rapidscan rlogin-scanner rpdscan smtp-user-enum smtptester sn1per snmp-brute sparta sshscan sshtrix sslyze uniscan unsecure wascan xprobe2 zgrab zulu"
  ["🔵  Bluetooth / NFC"]="btcrack crackle"
  ["🕳️  Backdoor"]="evilmaid laudanum phpsploit pwncat-caleb pwndrop sbd shellinabox webacoo webshells weevely"
  ["🕵️  Forensic"]="afflib aimage air analyzemft autopsy balbuzard binwalk bios_memimage bitdump bkcrack bmap-tools bmc-tools bulk-extractor captipper chainsaw chrome-decode chromefreak chromensics dc3dd dcfldd dfir-ntfs dftimewolf disitool dmde dmg2img dpeparser dshell dumpzilla emldump evtkit exiflooter ext4magic extractusnjrnl filegps foremost fridump galleta grokevt gtalk-decode guymager haystack iheartxor imagemounter indx2csv indxcarver indxparse iosforensic ipba2 iphoneanalyzer jefferson jpegdump libfvde lief log-file-parser mac-robber magicrescue make-pdf malheur malicious-pdf malwaredetect mboxgrep mdbtools memdump memfetch memimager mft2csv mftcarver mftrcrd mftref2name mobiusft mp3nema ms-sys myrescue networkminer nfex ntds-decode ntdsxtract ntfs-file-extractor ntfs-log-tracker origami parse-evtx pasco pcapfex pdf-parser pdfbook-analyzer pdfid pdfresurrect pdgmail peepdf pev pextractor php-malware-finder pmdump pngcheck powermft procscope python-flow.record python-lief python-oletools python-pcodedmp python2-capstone python2-darts.util.lru python2-exrex python2-frida python2-jsbeautifier python2-oletools python2-pcodedmp python2-peepdf rcrdcarver recentfilecache-parser recoverdm recoverjpeg recuperabit regipy reglookup regreport regripper regrippy regview rekall rifiuti2 safecopy scalpel scrounge-ntfs secure2csv shadowexplorer shreder skype-dump skypefreak stenographer stringsifter swap-digger tchunt-ng thumbcacheviewer timeverter unblob undbx usbrip usnjrnl2csv usnparser vinetto vipermonkey volafox volatility-extra volatility3 vsvbp windows-prefetch-parser wmi-forensics xplico zipdump"
  ["🛡️  Defensive"]="chipsec chkrootkit lynis openvas rkhunter sentrypeer shellinabox snort ufw"
  ["🪟  Windows / AD"]="adfind adfspray cachedump crackmapexec creddump domi-owned dumpacl enum4linux gpocrack gpp-decrypt impacket-ba keimpx kekeo kerbcrack kerberoast kerbrute ldap-brute ldsview mimikatz mimipenguin mkbrutus netexec ntds-decode ntdsxtract ntlmv1-multi o365enum o365spray outlook-webapp-brute owabf rdesktop-brute rdpassspray responder ridenum ruler samdump2 sensepost-xrdp shadowexplorer sidguesser smbbf smbmap spray365 spraycharles sprayingtoolkit trevorspray zackattack"
)

ALL_TOOLS=""
for cat in "${!categories[@]}"; do
  for tool in ${categories[$cat]}; do
    ALL_TOOLS+="$tool\n"
  done
done
ALL_TOOLS=$(echo -e "$ALL_TOOLS" | sort -u | grep -v '^$')

build_menu() {
  printf '%s\n' "${!categories[@]}" | sort
  echo "──────────────────────────────"
  echo -e "$ALL_TOOLS"
}

while true; do
  SELECTED=$(build_menu | rofi -dmenu \
    -window-icon "$ICON" \
    -p "󰣇  BlackArch" \
    -theme "$ROFI_THEME" \
    -matching fuzzy \
    -i \
    -no-sort \
    -lines 12)

  [ -z "$SELECTED" ] && break
  [[ "$SELECTED" == "──"* ]] && continue

  if [[ -n "${categories[$SELECTED]}" ]]; then
    while true; do
      TOOL=$(echo "${categories[$SELECTED]}" | tr ' ' '\n' | sort -u | grep -v '^$' | rofi -dmenu \
        -window-icon "$ICON" \
        -p "󰣇  $SELECTED" \
        -theme "$ROFI_THEME" \
        -matching fuzzy \
        -i \
        -lines 12 \
        -mesg "ESC = back")
      [ -z "$TOOL" ] && break
      launch_tool "$TOOL"
      break 2
    done
  else
    launch_tool "$SELECTED"
    break
  fi
done
