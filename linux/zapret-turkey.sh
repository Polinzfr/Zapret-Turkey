#!/usr/bin/env bash
# ============================================================
# Zapret Turkey - Linux (menu surumu)
# ============================================================
# Windows surumundeki winws.exe + WinDivert yerine nfqws + nftables
# (NFQUEUE) kullanir. Profiller, host listeleri, ayar dosyasi
# (config/settings.conf) ve dil dosyalari Windows surumuyle ortaktir:
#   <repo>/profiles/*.conf, target-hosts.txt, exclude-hosts.txt
#   <repo>/lang/en.lang, tr.lang          (ortak metinler)
#   <repo>/linux/lang/linux.en.lang, linux.tr.lang    (Linux'a ozel metinler)
#
# Kullanim:  ./zapret-turkey.sh          (menu)
#            ./zapret-turkey.sh help     (komutlar)
# ============================================================

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
LINUX_DIR="$(dirname "$SELF")"
ROOT="$(dirname "$LINUX_DIR")"
PROFILE_DIR="$ROOT/profiles"
LANG_DIR="$ROOT/lang"
LINUX_LANG_DIR="$LINUX_DIR/lang"
CONFIG_DIR="$ROOT/config"
CONFIG_FILE="$CONFIG_DIR/settings.conf"
LOG_DIR="$ROOT/logs"
ENGINE_DIR="$ROOT/engine/linux"
NFQWS="$ENGINE_DIR/nfqws"

RUN_DIR="/run/zapret-turkey"
NFT_TABLE="zapret_turkey"
QNUM=200
SERVICE_NAME="zapret-turkey"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TEST_HOSTS="discord.com roblox.com steampowered.com"
GENERAL_HOST="www.cloudflare.com"

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_GREEN=$'\033[92m'; C_RED=$'\033[91m'
    C_YELLOW=$'\033[93m'; C_CYAN=$'\033[96m'; C_GRAY=$'\033[90m'
else
    C_RESET=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_CYAN=""; C_GRAY=""
fi

# ------------------------------------------------------------
# Dil (ortak lang/*.lang + linux/lang/linux.*.lang)
# ------------------------------------------------------------
declare -A L

load_lang_file() {
    local f="$1" line key
    [ -f "$f" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in ''|'#'*) continue ;; esac
        key="${line%%=*}"
        [ "$key" = "$line" ] && continue
        L["$key"]="${line#*=}"
    done < "$f"
}

# Once English, sonra secilen dil: eksik anahtar Ingilizce'ye duser.
load_lang() {
    local code="$1"
    L=()
    load_lang_file "$LANG_DIR/en.lang"
    load_lang_file "$LINUX_LANG_DIR/linux.en.lang"
    if [ "$code" != "en" ]; then
        load_lang_file "$LANG_DIR/$code.lang"
        load_lang_file "$LINUX_LANG_DIR/linux.$code.lang"
    fi
}

t() { printf '%s' "${L[$1]:-$1}"; }

# ------------------------------------------------------------
# Yardimcilar
# ------------------------------------------------------------
say() { printf '%s\n' "$*"; }

clear_screen() { [ -t 1 ] && printf '\033[H\033[2J'; return 0; }

pause_() {
    if [ -t 0 ]; then
        local _x
        read -r -p "$(t LNX_PRESS_ENTER) " _x
    fi
    return 0
}

ask_yn() {
    local a
    read -r -p "$1 " a || return 1
    case "${a,,}" in y|yes|e|evet) return 0 ;; esac
    return 1
}

prompt_choice() {
    local _c
    read -r -p "$(t PROMPT_CHOICE) " _c || _c=0
    printf -v "$1" '%s' "$_c"
}

# sudo ile calisinca olusan dosyalarin sahibini gercek kullaniciya ver
fix_owner() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        chown -R "$SUDO_USER": "$@" 2>/dev/null
    fi
    return 0
}

need_root() {
    [ "$(id -u)" -eq 0 ] && return 0
    if ! command -v sudo >/dev/null 2>&1; then
        say "$(t REASON_NOT_ADMIN_HINT)"
        exit 1
    fi
    say "$(t LNX_NEED_ROOT)"
    exec sudo "$SELF" "$@"
}

ensure_dirs() {
    mkdir -p "$LOG_DIR" "$CONFIG_DIR" 2>/dev/null
    fix_owner "$LOG_DIR" "$CONFIG_DIR"
}

app_log() {
    ensure_dirs
    printf '[%s] %s\n' "$(date '+%d.%m.%Y %H:%M:%S')" "$*" >> "$LOG_DIR/app.log" 2>/dev/null
    fix_owner "$LOG_DIR/app.log"
}

valid_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }

# KEY=VALUE okur; dosyayi "source" etmez. CRLF ve sondaki bosluklar temizlenir.
profile_value() {
    grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2- | tr -d '\r' | sed 's/[[:space:]]*$//'
}

# ------------------------------------------------------------
# Ayarlar (config/settings.conf - Windows ile ayni 4 satir)
# ------------------------------------------------------------
load_settings() {
    CURRENT_PROFILE="stable"
    DNS_MODE="system"
    DEBUG="0"
    SAVED_LANG=""
    [ -f "$CONFIG_FILE" ] || return 0
    local k v
    while IFS='=' read -r k v || [ -n "$k" ]; do
        v="${v%$'\r'}"
        case "$k" in
            CURRENT_PROFILE) valid_name "$v" && CURRENT_PROFILE="$v" ;;
            DNS_MODE)        valid_name "$v" && DNS_MODE="$v" ;;
            DEBUG)           [[ "$v" =~ ^[01]$ ]] && DEBUG="$v" ;;
            LANG)            SAVED_LANG="$v" ;;
        esac
    done < "$CONFIG_FILE"
}

save_settings() {
    mkdir -p "$CONFIG_DIR"
    {
        printf 'CURRENT_PROFILE=%s\n' "$CURRENT_PROFILE"
        printf 'DNS_MODE=%s\n' "$DNS_MODE"
        printf 'DEBUG=%s\n' "$DEBUG"
        printf 'LANG=%s\n' "$UI_LANG"
    } > "$CONFIG_FILE"
    fix_owner "$CONFIG_DIR"
}

set_setting() {
    load_settings
    case "$1" in
        CURRENT_PROFILE) CURRENT_PROFILE="$2" ;;
        DNS_MODE)        DNS_MODE="$2" ;;
        DEBUG)           DEBUG="$2" ;;
        LANG)            UI_LANG="$2" ;;
    esac
    save_settings
}

choose_language() {
    local c
    load_lang en
    while true; do
        clear_screen
        say "$(t LANG_SELECT_TITLE)"
        say ""
        say "  $(t LANG_SELECT_OPT_TR)"
        say "  $(t LANG_SELECT_OPT_EN)"
        say ""
        read -r -p "$(t LANG_SELECT_PROMPT) " c || { UI_LANG="en"; return 0; }
        case "$c" in
            1) UI_LANG="tr"; return 0 ;;
            2) UI_LANG="en"; return 0 ;;
        esac
        say "$(t LANG_SELECT_INVALID)"
        sleep 1
    done
}

# $1 = interactive (menu): ilk calistirmada dil sorulur ve kaydedilir.
init_lang() {
    load_settings
    UI_LANG="$SAVED_LANG"
    if [ "$UI_LANG" != "tr" ] && [ "$UI_LANG" != "en" ]; then
        if [ "${1:-}" = "interactive" ] && [ -t 0 ]; then
            choose_language
            load_lang "$UI_LANG"
            ensure_dirs
            save_settings
            return 0
        fi
        UI_LANG="en"
    fi
    load_lang "$UI_LANG"
}

# ------------------------------------------------------------
# Profiller
# ------------------------------------------------------------
list_profiles() {
    PROFILE_IDS=()
    local id f
    for id in stable compatibility strong; do
        [ -f "$PROFILE_DIR/$id.conf" ] && PROFILE_IDS+=("$id")
    done
    for f in "$PROFILE_DIR"/*.conf; do
        [ -f "$f" ] || continue
        id="$(basename "$f" .conf)"
        case "$id" in stable|compatibility|strong) continue ;; esac
        valid_name "$id" && PROFILE_IDS+=("$id")
    done
}

display_name() {
    local id="$1" name key
    name="$(profile_value "$PROFILE_DIR/$id.conf" NAME)"
    key="PROFILE_$(printf '%s' "$id" | tr 'a-z' 'A-Z')_NAME"
    case "$id" in
        stable|compatibility|strong) [ -n "${L[$key]:-}" ] && name="${L[$key]}" ;;
    esac
    [ -n "$name" ] || name="$(t PROFILE_UNKNOWN_NAME) ($id)"
    printf '%s' "$name"
}

# Doldurur: ARGS_ARR, PORT. Hata: CORE_REASON ayarlar ve 1 doner.
load_profile() {
    local name="$1" pf raw words w
    if ! valid_name "$name" || [ ! -f "$PROFILE_DIR/$name.conf" ]; then
        CORE_REASON="PROFILE_NOT_FOUND"
        return 1
    fi
    pf="$PROFILE_DIR/$name.conf"
    CORE_CONFPATH="$pf"
    raw="$(profile_value "$pf" ARGS)"
    if [ -z "$raw" ]; then
        CORE_REASON="PROFILE_PARSE_FAILED"
        return 1
    fi
    PORT="$(profile_value "$pf" PORT_TCP)"
    [[ "$PORT" =~ ^[0-9]+$ ]] || PORT=443

    ARGS_ARR=()
    read -r -a words <<< "$raw"
    for w in "${words[@]}"; do
        case "$w" in
            --wf-*) continue ;;   # WinDivert'e ozel, Linux'ta karsiligi nft kurali
        esac
        ARGS_ARR+=("$w")
    done
    return 0
}

# Host listelerinin CRLF'siz kopyasini /run altina koyar, HOST_ARGS'i doldurur
prep_hostlists() {
    mkdir -p "$RUN_DIR"
    chmod 755 "$RUN_DIR"
    HOST_ARGS=()
    local src="$PROFILE_DIR/target-hosts.txt" dst="$RUN_DIR/target-hosts.txt"
    if [ -s "$src" ]; then
        tr -d '\r' < "$src" > "$dst"
        chmod 644 "$dst"
        HOST_ARGS+=("--hostlist=$dst")
    fi
    src="$PROFILE_DIR/exclude-hosts.txt"
    dst="$RUN_DIR/exclude-hosts.txt"
    if [ -s "$src" ]; then
        tr -d '\r' < "$src" > "$dst"
        chmod 644 "$dst"
        HOST_ARGS+=("--hostlist-exclude=$dst")
    fi
}

# ------------------------------------------------------------
# nftables
# ------------------------------------------------------------
# Giden 443 + sunucudan gelen SYN,ACK (autottl icin gerekli) NFQUEUE'ya gider.
nft_apply() {
    nft delete table inet "$NFT_TABLE" 2>/dev/null
    nft -f - <<EOF
table inet $NFT_TABLE {
    chain out {
        type filter hook postrouting priority 100; policy accept;
        meta mark and 0x40000000 == 0 tcp dport $PORT ct original packets 1-6 queue num $QNUM bypass
    }
    chain pre {
        type filter hook prerouting priority -101; policy accept;
        tcp sport $PORT tcp flags & (syn | ack) == (syn | ack) queue num $QNUM bypass
    }
}
EOF
}

nft_remove() {
    command -v nft >/dev/null 2>&1 && nft delete table inet "$NFT_TABLE" 2>/dev/null
    return 0
}

nft_present() {
    command -v nft >/dev/null 2>&1 && nft list table inet "$NFT_TABLE" >/dev/null 2>&1
}

# ------------------------------------------------------------
# Motor (nfqws)
# ------------------------------------------------------------
is_running() { pgrep -x nfqws >/dev/null 2>&1; }

build_engine() {
    local tmp
    say "$(t LNX_BUILD_INSTALLING)"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y build-essential git libnetfilter-queue-dev libnfnetlink-dev libmnl-dev zlib1g-dev libcap-dev nftables \
            || { say "$(t LNX_BUILD_FAIL)"; return 1; }
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y gcc make git zlib-devel libnetfilter_queue-devel libnfnetlink-devel libmnl-devel libcap-devel nftables \
            || { say "$(t LNX_BUILD_FAIL)"; return 1; }
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --needed --noconfirm base-devel git zlib libnetfilter_queue libnfnetlink libmnl libcap nftables \
            || { say "$(t LNX_BUILD_FAIL)"; return 1; }
    else
        say "$(t LNX_BUILD_NO_PM)"
        return 1
    fi

    tmp="$(mktemp -d)" || { say "$(t LNX_BUILD_FAIL)"; return 1; }
    say "$(t LNX_BUILD_DOWNLOADING)"
    git clone --depth 1 https://github.com/bol-van/zapret.git "$tmp/zapret" \
        || { rm -rf "$tmp"; say "$(t LNX_BUILD_FAIL)"; return 1; }
    say "$(t LNX_BUILD_COMPILING)"
    make -C "$tmp/zapret/nfq" || { rm -rf "$tmp"; say "$(t LNX_BUILD_FAIL)"; return 1; }
    mkdir -p "$ENGINE_DIR"
    install -m 755 "$tmp/zapret/nfq/nfqws" "$NFQWS" || { rm -rf "$tmp"; say "$(t LNX_BUILD_FAIL)"; return 1; }
    rm -rf "$tmp"
    fix_owner "$ROOT/engine"
    say "${C_GREEN}$(t LNX_BUILD_DONE)${C_RESET} $NFQWS"
    return 0
}

stop_engine_core() {
    nft_remove
    pkill -x nfqws 2>/dev/null
    local i
    for i in 1 2 3 4 5 6; do
        is_running || break
        sleep 0.5
    done
    return 0
}

# Sonuc degiskenleri (Windows ENGINE_START_CORE ile ayni adlar):
#   CORE_OK, CORE_REASON, CORE_CONFPATH, CORE_CMDLINE, CORE_STDERR_TAIL
engine_start_core() {
    local prof="$1" i
    CORE_OK=0; CORE_REASON=""; CORE_CMDLINE=""; CORE_STDERR_TAIL=""
    CORE_CONFPATH="$PROFILE_DIR/$prof.conf"

    load_profile "$prof" || return 1
    if [ ! -x "$NFQWS" ]; then CORE_REASON="ENGINE_MISSING"; return 1; fi
    if [ "$(id -u)" -ne 0 ]; then CORE_REASON="NOT_ADMIN"; return 1; fi
    if ! command -v nft >/dev/null 2>&1; then CORE_REASON="NFT_MISSING"; return 1; fi

    # ayni anda baska bir kopya calismasin
    stop_engine_core
    prep_hostlists
    modprobe nfnetlink_queue 2>/dev/null
    sysctl -w net.netfilter.nf_conntrack_acct=1 >/dev/null 2>&1

    ensure_dirs
    rm -f "$LOG_DIR/engine_stderr.log" "$LOG_DIR/engine_stdout.log"
    CORE_CMDLINE="$NFQWS --qnum=$QNUM ${ARGS_ARR[*]} ${HOST_ARGS[*]}"

    setsid "$NFQWS" --qnum="$QNUM" "${ARGS_ARR[@]}" "${HOST_ARGS[@]}" \
        > "$LOG_DIR/engine_stdout.log" 2> "$LOG_DIR/engine_stderr.log" < /dev/null &
    disown 2>/dev/null
    fix_owner "$LOG_DIR"

    for i in 1 2; do
        sleep 1
        if ! is_running; then
            CORE_REASON="ENGINE_EXITED"
            CORE_STDERR_TAIL="$(tail -n 1 "$LOG_DIR/engine_stderr.log" 2>/dev/null)"
            return 1
        fi
    done

    if ! nft_apply; then
        stop_engine_core
        CORE_REASON="NFT_FAILED"
        return 1
    fi
    CORE_OK=1
    CORE_REASON="OK"
    return 0
}

# systemd servisi icin: nfqws'i arka plana ATMADAN, ana surec olarak calistirir.
# (Eski oneshot yapisinda systemd, arka plandaki nfqws'i kapatiyordu.)
cmd_run() {
    local prof
    load_settings
    prof="$CURRENT_PROFILE"
    ensure_dirs
    CORE_REASON=""
    if ! load_profile "$prof"; then
        app_log "SERVICE RUN FAILED profile=$prof reason=$CORE_REASON"
        echo "zapret-turkey: profile problem ($CORE_REASON): $prof" >&2
        return 1
    fi
    if [ ! -x "$NFQWS" ]; then
        app_log "SERVICE RUN FAILED profile=$prof reason=ENGINE_MISSING"
        echo "zapret-turkey: engine missing: $NFQWS" >&2
        return 1
    fi
    if ! command -v nft >/dev/null 2>&1; then
        app_log "SERVICE RUN FAILED profile=$prof reason=NFT_MISSING"
        echo "zapret-turkey: nft not found" >&2
        return 1
    fi
    # menuden elle baslatilmis bir nfqws varsa temizle
    stop_engine_core
    prep_hostlists
    modprobe nfnetlink_queue 2>/dev/null
    sysctl -w net.netfilter.nf_conntrack_acct=1 >/dev/null 2>&1
    # Kural once eklenir: 'bypass' sayesinde nfqws acilana kadar trafik normal akar.
    if ! nft_apply; then
        app_log "SERVICE RUN FAILED profile=$prof reason=NFT_FAILED"
        echo "zapret-turkey: nftables rule could not be added" >&2
        return 1
    fi
    app_log "SERVICE RUN profile=$prof"
    exec "$NFQWS" --qnum="$QNUM" "${ARGS_ARR[@]}" "${HOST_ARGS[@]}" 2>> "$LOG_DIR/engine_stderr.log"
    return 1
}

print_start_failure() {
    say "${C_RED}$(t START_FAILED)${C_RESET}"
    say "$(t START_FAILED_PROFILE_LABEL) $CURRENT_PROFILE"
    say "$(t START_FAILED_REASON_LABEL) $CORE_REASON"
    case "$CORE_REASON" in
        PROFILE_NOT_FOUND)
            say "$(t START_FAILED_PATH_LABEL) $CORE_CONFPATH" ;;
        PROFILE_PARSE_FAILED)
            say "$(t START_FAILED_PATH_LABEL) $CORE_CONFPATH"
            say "$(t REASON_PROFILE_PARSE_FAILED_HINT)" ;;
        ENGINE_MISSING)
            say "$(t REASON_ENGINE_MISSING_HINT) $NFQWS" ;;
        NOT_ADMIN)
            say "$(t REASON_NOT_ADMIN_HINT)" ;;
        NFT_MISSING)
            say "$(t REASON_NFT_MISSING_HINT)" ;;
        NFT_FAILED)
            say "$(t REASON_NFT_FAILED_HINT)" ;;
        ENGINE_EXITED)
            say "$(t REASON_ENGINE_EXITED_CMDLINE_LABEL) $CORE_CMDLINE"
            say "$(t REASON_ENGINE_EXITED_STDERR_LABEL) $CORE_STDERR_TAIL"
            say "$(t REASON_ENGINE_EXITED_FULL_LOG) $LOG_DIR/engine_stderr.log" ;;
        *)
            say "$(t REASON_UNKNOWN_STATE_1)"
            say "$(t REASON_UNKNOWN_STATE_2)" ;;
    esac
}

# Menuden ve komut satirindan ortak Baslat. 0 = basarili.
start_engine() {
    load_settings
    if [ ! -x "$NFQWS" ] && [ -t 0 ]; then
        if ask_yn "$(t LNX_BUILD_PROMPT)"; then
            build_engine || { pause_; return 1; }
        fi
    fi
    engine_start_core "$CURRENT_PROFILE"
    if [ "$CORE_OK" = "1" ]; then
        say "${C_GREEN}$(t START_OK)${C_RESET}"
        say "$(t START_CMDLINE_LABEL) $CORE_CMDLINE"
        say "$(t START_RESTART_HINT)"
        app_log "START OK profile=$CURRENT_PROFILE"
        pause_
        return 0
    fi
    print_start_failure
    app_log "START FAILED profile=$CURRENT_PROFILE reason=$CORE_REASON"
    pause_
    return 1
}

stop_engine() {
    local was=0
    is_running && was=1
    stop_engine_core
    if [ "$was" = "1" ]; then
        say "${C_GREEN}$(t STOP_OK)${C_RESET}"
        app_log "STOP"
    else
        say "${C_GRAY}$(t STOP_ALREADY_STOPPED)${C_RESET}"
    fi
    pause_
    return 0
}

# ------------------------------------------------------------
# Profil menusu
# ------------------------------------------------------------
change_profile() {
    local n ch id mark
    load_settings
    clear_screen
    list_profiles
    if [ "${#PROFILE_IDS[@]}" -eq 0 ]; then
        say "$(t LNX_PROFILE_NONE) $PROFILE_DIR"
        pause_
        return 0
    fi
    say "  $(t LBL_PROFILE) : $CURRENT_PROFILE ($(display_name "$CURRENT_PROFILE"))"
    say ""
    say "$(t CHANGE_PROFILE_PROMPT)"
    say ""
    n=1
    for id in "${PROFILE_IDS[@]}"; do
        mark=""
        [ "$id" = "$CURRENT_PROFILE" ] && mark="  ${C_GREEN}<-- $(t LNX_CURRENT_MARK)${C_RESET}"
        printf '  [%d] %-14s - %s%s\n' "$n" "$id" "$(display_name "$id")" "$mark"
        n=$((n + 1))
    done
    say "  [0] $(t CHANGE_PROFILE_CANCEL)"
    say ""
    prompt_choice ch
    [[ "$ch" =~ ^[0-9]+$ ]] || return 0
    [ "$ch" -ge 1 ] && [ "$ch" -le "${#PROFILE_IDS[@]}" ] || return 0
    id="${PROFILE_IDS[$((ch - 1))]}"
    set_setting CURRENT_PROFILE "$id"
    say "${C_GREEN}$(t CHANGE_PROFILE_DONE) $id${C_RESET}"
    if is_running; then
        if ask_yn "$(t CHANGE_PROFILE_RESTART_PROMPT)"; then
            start_engine
            return 0
        fi
    fi
    pause_
}

profile_menu() {
    local ch
    while true; do
        load_settings
        clear_screen
        say "${C_CYAN}$(t PMENU_TITLE)${C_RESET}"
        say "  $(t LBL_PROFILE) : $CURRENT_PROFILE ($(display_name "$CURRENT_PROFILE"))"
        say ""
        say "  $(t PMENU_OPT_CHANGE)"
        say "  $(t PMENU_OPT_EXPORT)"
        say "  $(t PMENU_OPT_IMPORT)"
        say "  $(t PMENU_OPT_REPORT)"
        say "  $(t SVC_MENU_BACK)"
        say ""
        prompt_choice ch
        case "$ch" in
            1) change_profile ;;
            2|3|4) say "$(t LNX_NOT_YET)"; pause_ ;;
            0) return 0 ;;
        esac
    done
}

# ------------------------------------------------------------
# Tanilama
# ------------------------------------------------------------
# Varsayilan rotanin cikis arayuzu (ornek: wlp3s0b1). Tailscale/VPN gibi
# ek arayuzler DNS ve IPv6 tespitini karistirmasin diye hep bunun uzerinden bakilir.
default_dev() {
    ip route show default 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit }}'
}

first_dns() {
    local d="" dev out
    dev="$(default_dev)"
    if command -v resolvectl >/dev/null 2>&1; then
        if [ -n "$dev" ]; then out="$(resolvectl status "$dev" 2>/dev/null)"; else out="$(resolvectl status 2>/dev/null)"; fi
        d="$(printf '%s\n' "$out" | sed -n 's/^ *Current DNS Server: *//p' | head -n 1)"
        if [ -z "$d" ]; then
            d="$(printf '%s\n' "$out" | sed -n 's/^ *DNS Servers: *//p' | head -n 1 | awk '{print $1}')"
        fi
    fi
    [ -n "$d" ] || d="$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)"
    printf '%s' "${d%%%*}"
}

is_private_addr() {
    case "$1" in
        10.*|192.168.*|169.254.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|fe80:*|fc*|fd*) return 0 ;;
    esac
    return 1
}

sys_lookup() {
    getent ahostsv4 "$1" 2>/dev/null | awk '{print $1}' | sort -u
}

# 1.1.1.1 uzerinden A kaydi: dig -> nslookup -> DNS-over-HTTPS (curl)
cf_lookup() {
    local out=""
    if command -v dig >/dev/null 2>&1; then
        out="$(dig +short +time=2 +tries=1 @1.1.1.1 A "$1" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')"
    fi
    if [ -z "$out" ] && command -v nslookup >/dev/null 2>&1; then
        out="$(nslookup -timeout=2 "$1" 1.1.1.1 2>/dev/null | awk '/^Name:/{f=1; next} f && /^Address/{print $NF}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')"
    fi
    if [ -z "$out" ] && command -v curl >/dev/null 2>&1; then
        out="$(curl -s -m 5 -H 'accept: application/dns-json' "https://1.1.1.1/dns-query?name=$1&type=A" 2>/dev/null \
            | grep -o '"data":"[0-9.]*"' | cut -d'"' -f4)"
    fi
    printf '%s\n' "$out" | sed '/^$/d' | sort -u
}

overlap() {
    local a b
    for a in $1; do
        for b in $2; do
            [ "$a" = "$b" ] && return 0
        done
    done
    return 1
}

curl_hint() {
    case "$1" in
        60|51|35|58|59|83)
            if [ "$1" = "60" ]; then t LNX_DIAG_HINT_CERT; else t LNX_DIAG_HINT_RESET; fi ;;
        56|52) t LNX_DIAG_HINT_RESET ;;
        28) t LNX_DIAG_HINT_TIMEOUT ;;
        6) t LNX_DIAG_HINT_DNS ;;
    esac
}

diag_test_line() { # $1=label-key $2=host
    local rc hint
    curl -sS -o /dev/null -m 8 "https://$2" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        say "  $(t "$1") ${C_GREEN}$(t DIAG_TEST_OK)${C_RESET}"
    else
        hint="$(curl_hint "$rc")"
        say "  $(t "$1") ${C_RED}$(t DIAG_TEST_FAIL)${C_RESET}  ${C_GRAY}${hint}${C_RESET}"
    fi
}

diag_dns() {
    local first h sys cf diff_discord=0 diff_other=0 sys_any=0 priv=0
    say "$(t DIAG_DNS_SECTION)"
    first="$(first_dns)"
    say "$(t DIAG_DNS_FIRST_SERVER_LABEL) ${first:-?}"
    if [ -z "$(cf_lookup discord.com)" ]; then
        say "$(t DIAG_DNS_UNREACHABLE)"
        return 0
    fi
    for h in $TEST_HOSTS; do
        sys="$(sys_lookup "$h" | tr '\n' ' ')"
        cf="$(cf_lookup "$h" | tr '\n' ' ')"
        if [ -z "$sys" ]; then
            printf '  %-18s %s\n' "$h" "[$(t DIAG_TEST_UNKNOWN)]"
            [ "$h" = "discord.com" ] && diff_discord=1
            continue
        fi
        sys_any=1
        if overlap "$sys" "$cf"; then
            printf '  %-18s %s\n' "$h" "[${C_GREEN}$(t DIAG_DNS_MATCH)${C_RESET}]"
        else
            printf '  %-18s %s\n' "$h" "[${C_RED}$(t DIAG_DNS_DIFFERENT)${C_RESET}]"
            say "      $(t DIAG_DNS_SYSTEM_LABEL): $sys"
            say "      $(t DIAG_DNS_CLOUDFLARE_LABEL): $cf"
            if [ "$h" = "discord.com" ]; then diff_discord=1; else diff_other=1; fi
        fi
    done
    [ "$sys_any" = "1" ] || return 0
    is_private_addr "$first" && priv=1
    if [ "$diff_discord" = "1" ]; then
        if [ "$priv" = "1" ]; then
            say "${C_RED}$(t DIAG_DNS_VERDICT_MODEM_BAD)${C_RESET}"
        else
            say "${C_YELLOW}$(t DIAG_DNS_VERDICT_OTHER_DIFF)${C_RESET}"
        fi
    elif [ "$priv" = "1" ]; then
        say "${C_YELLOW}$(t DIAG_DNS_VERDICT_MODEM_OK)${C_RESET}"
    else
        say "${C_GREEN}$(t DIAG_DNS_VERDICT_OK)${C_RESET}"
    fi
    [ "$diff_other" = "1" ] && say "${C_GRAY}$(t DIAG_DNS_CDN_NOTE)${C_RESET}"
    return 0
}

diagnostics() {
    local a4 a6 dev conflicts=() c u
    load_settings
    clear_screen
    say "${C_CYAN}$(t DIAG_TITLE)${C_RESET}"
    say ""
    if [ "$(id -u)" -eq 0 ]; then
        say "$(t DIAG_ADMIN_LABEL) ${C_GREEN}$(t DEBUG_YES)${C_RESET}"
    else
        say "$(t DIAG_ADMIN_LABEL) ${C_RED}$(t DEBUG_NO)${C_RESET}"
    fi
    if [ -x "$NFQWS" ]; then
        say "$(t DIAG_ENGINE_LABEL) ${C_GREEN}$(t DIAG_STATUS_PRESENT)${C_RESET}"
    else
        say "$(t DIAG_ENGINE_LABEL) ${C_RED}$(t DIAG_STATUS_MISSING)${C_RESET}"
    fi
    if nft_present; then
        say "$(t LNX_DIAG_NFT_LABEL) ${C_GREEN}$(t LNX_DIAG_PRESENT)${C_RESET}"
    else
        say "$(t LNX_DIAG_NFT_LABEL) ${C_GRAY}$(t LNX_DIAG_ABSENT)${C_RESET}"
    fi
    say "$(t DIAG_PROFILE_LABEL) $CURRENT_PROFILE"
    say "$(t DIAG_DNSMODE_LABEL) $DNS_MODE"
    if is_running; then
        say "$(t DIAG_WINWS_STATUS_LABEL) ${C_GREEN}$(t STATUS_RUNNING)${C_RESET}"
    else
        say "$(t DIAG_WINWS_STATUS_LABEL) ${C_RED}$(t STATUS_STOPPED)${C_RESET}"
    fi
    if svc_installed; then
        say "$(t DIAG_SVC_STATUS_LABEL) $(t SVC_INSTALLED)"
    else
        say "$(t DIAG_SVC_STATUS_LABEL) $(t SVC_NOT_INSTALLED)"
    fi

    say ""
    say "$(t DIAG_CONFLICT_SECTION)"
    if command -v systemctl >/dev/null 2>&1; then
        for u in zapret zapret2; do
            systemctl is-active --quiet "$u" 2>/dev/null && conflicts+=("systemd: $u")
        done
    fi
    if command -v nft >/dev/null 2>&1 && nft list tables 2>/dev/null | grep -qE ' (zapret|zapret2)$'; then
        conflicts+=("nftables: zapret")
    fi
    pgrep -x tpws >/dev/null 2>&1 && conflicts+=("process: tpws")
    if [ "${#conflicts[@]}" -eq 0 ]; then
        say "$(t DIAG_CONFLICT_NONE)"
    else
        for c in "${conflicts[@]}"; do
            say "${C_YELLOW}$(t DIAG_CONFLICT_FOUND)${C_RESET} $c"
        done
        say "$(t DIAG_CONFLICT_HINT)"
    fi

    say ""
    say "$(t DIAG_CONN_SECTION)"
    dev="$(default_dev)"
    if [ -n "$dev" ]; then
        a4="$(ip -4 -o addr show dev "$dev" scope global 2>/dev/null | awk '{print $4; exit}')"
        a6="$(ip -6 -o addr show dev "$dev" scope global 2>/dev/null | awk '{print $4; exit}')"
    else
        a4=""; a6=""
    fi
    say "$(t DIAG_IPV4_LABEL) ${a4:-$(t DIAG_STATUS_NONE)}"
    say "$(t DIAG_IPV6_LABEL) ${a6:-$(t DIAG_STATUS_NONE)}"

    say ""
    diag_dns

    say ""
    say "$(t DIAG_TEST_SECTION)"
    if ! command -v curl >/dev/null 2>&1; then
        say "$(t DIAG_CURL_MISSING)"
    else
        diag_test_line DIAG_REPORT_DISCORD_LABEL discord.com
        diag_test_line DIAG_REPORT_ROBLOX_LABEL roblox.com
        diag_test_line DIAG_REPORT_STEAM_LABEL steampowered.com
        diag_test_line DIAG_REPORT_HTTPS_LABEL "$GENERAL_HOST"
    fi
    say ""
    pause_
}

# ------------------------------------------------------------
# Hizmet (systemd)
# ------------------------------------------------------------
svc_installed() { [ -f "$SERVICE_FILE" ]; }

svc_install() {
    say "${C_CYAN}$(t SVC_INSTALL_TITLE)${C_RESET}"
    command -v systemctl >/dev/null 2>&1 || { say "$(t LNX_NO_SYSTEMD)"; return 1; }
    if [ ! -x "$NFQWS" ]; then
        say "${C_RED}$(t REASON_ENGINE_MISSING_HINT)${C_RESET} $NFQWS"
        return 1
    fi
    load_settings
    say "$(t SVC_SELECTED_PROFILE_LABEL) $CURRENT_PROFILE"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Zapret Turkey (nfqws)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart="$SELF" run
ExecStopPost="$SELF" nft-clean
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    if ! systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || ! systemctl restart "$SERVICE_NAME"; then
        say "${C_RED}$(t SVC_ERR_CREATE_FAILED)${C_RESET}"
        systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload >/dev/null 2>&1
        return 1
    fi
    sleep 3
    if is_running; then
        say "${C_GREEN}$(t SVC_INSTALLED_LABEL)${C_RESET} $SERVICE_NAME"
        app_log "SERVICE INSTALLED profile=$CURRENT_PROFILE"
        return 0
    fi
    say "${C_RED}$(t LNX_SVC_NOT_RUNNING)${C_RESET}"
    say "  journalctl -u $SERVICE_NAME -n 30 --no-pager"
    app_log "SERVICE INSTALLED BUT NFQWS NOT RUNNING profile=$CURRENT_PROFILE"
    return 1
}

svc_uninstall() {
    say "${C_CYAN}$(t SVC_UNINSTALL_TITLE)${C_RESET}"
    command -v systemctl >/dev/null 2>&1 || { say "$(t LNX_NO_SYSTEMD)"; return 1; }
    if ! svc_installed; then
        say "$(t SVC_NOT_INSTALLED_MSG)"
        return 0
    fi
    systemctl disable --now "$SERVICE_NAME" 2>/dev/null
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    stop_engine_core
    say "${C_GREEN}$(t SVC_UNINSTALLED_OK)${C_RESET} $SERVICE_NAME"
    app_log "SERVICE REMOVED"
    return 0
}

svc_control() { # $1 = start|stop
    if ! svc_installed; then
        say "$(t SVC_NOT_INSTALLED_MSG)"
        return 0
    fi
    systemctl "$1" "$SERVICE_NAME" || { say "${C_RED}$(t SVC_ERR_CREATE_FAILED)${C_RESET}"; return 1; }
    if [ "$1" = "start" ]; then
        sleep 2
        is_running || say "${C_RED}$(t LNX_SVC_NOT_RUNNING)${C_RESET}"
    fi
}

service_menu() {
    local ch st
    while true; do
        clear_screen
        if svc_installed; then st="$(t SVC_INSTALLED)"; else st="$(t SVC_NOT_INSTALLED)"; fi
        say "${C_CYAN}$(t SVC_MENU_TITLE)${C_RESET}"
        say "$(t SVC_MENU_STATUS_LABEL) $st"
        say ""
        say "  $(t SVC_MENU_INSTALL)"
        say "  $(t SVC_MENU_UNINSTALL)"
        say "  $(t SVC_MENU_START)"
        say "  $(t SVC_MENU_STOP)"
        say "  $(t SVC_MENU_BACK)"
        say ""
        prompt_choice ch
        case "$ch" in
            1) svc_install; pause_ ;;
            2) svc_uninstall; pause_ ;;
            3) svc_control start; pause_ ;;
            4) svc_control stop; pause_ ;;
            0) return 0 ;;
        esac
    done
}

# ------------------------------------------------------------
# DNS Yardimcisi (NetworkManager / nmcli)
# ------------------------------------------------------------
dns_nm_ready() {
    command -v nmcli >/dev/null 2>&1 && nmcli -t -f RUNNING general 2>/dev/null | grep -qx running
}

# Aktif ethernet/wifi baglantilari (varsayilan rota arayuzu en basta).
# Doldurur: NM_UUIDS, NM_NAMES, NM_DEVS
nm_active_connections() {
    NM_UUIDS=(); NM_NAMES=(); NM_DEVS=()
    local uuid type cdev name defdev
    defdev="$(default_dev)"
    while IFS=: read -r uuid type cdev name; do
        [ -n "$uuid" ] || continue
        case "$type" in
            802-3-ethernet|802-11-wireless|ethernet|wifi) ;;
            *) continue ;;
        esac
        if [ -n "$defdev" ] && [ "$cdev" = "$defdev" ]; then
            NM_UUIDS=("$uuid" "${NM_UUIDS[@]}")
            NM_NAMES=("$name" "${NM_NAMES[@]}")
            NM_DEVS=("$cdev" "${NM_DEVS[@]}")
        else
            NM_UUIDS+=("$uuid")
            NM_NAMES+=("$name")
            NM_DEVS+=("$cdev")
        fi
    done < <(nmcli -t -f UUID,TYPE,DEVICE,NAME con show --active 2>/dev/null)
}

# Doldurur: SEL_UUID, SEL_NAME, SEL_DEV. Iptal/basarisizlik: 1 doner.
choose_connection() {
    local ch i n name
    SEL_UUID=""; SEL_NAME=""; SEL_DEV=""
    say "$(t DNS_ASSIST_DETECTING)"
    nm_active_connections
    n="${#NM_UUIDS[@]}"
    if [ "$n" -eq 1 ]; then
        say "$(t DNS_ASSIST_FOUND_ONE) ${NM_NAMES[0]} (${NM_DEVS[0]})"
        if ask_yn "$(t DNS_CLOUDFLARE_CONFIRM)"; then
            SEL_UUID="${NM_UUIDS[0]}"; SEL_NAME="${NM_NAMES[0]}"; SEL_DEV="${NM_DEVS[0]}"
            return 0
        fi
    elif [ "$n" -gt 1 ]; then
        say "$(t DNS_ASSIST_FOUND_MULTI)"
        for i in $(seq 0 $((n - 1))); do
            printf '  [%d] %s (%s)\n' "$((i + 1))" "${NM_NAMES[$i]}" "${NM_DEVS[$i]}"
        done
        say "  $(t DNS_PROVIDER_CANCEL)"
        prompt_choice ch
        if [[ "$ch" =~ ^[0-9]+$ ]] && [ "$ch" -ge 1 ] && [ "$ch" -le "$n" ]; then
            SEL_UUID="${NM_UUIDS[$((ch - 1))]}"; SEL_NAME="${NM_NAMES[$((ch - 1))]}"; SEL_DEV="${NM_DEVS[$((ch - 1))]}"
            return 0
        fi
        return 1
    else
        say "$(t DNS_ASSIST_NONE_FOUND)"
    fi
    read -r -p "$(t DNS_ASSIST_MANUAL_FALLBACK) " name || return 1
    [ -n "$name" ] || return 1
    SEL_UUID="$(nmcli -g connection.uuid con show "$name" 2>/dev/null | head -n 1)"
    if [ -z "$SEL_UUID" ]; then
        say "${C_RED}$(t LNX_DNS_CONN_UNKNOWN)${C_RESET} $name"
        return 1
    fi
    SEL_NAME="$name"
    SEL_DEV="$(nmcli -g connection.interface-name con show "$name" 2>/dev/null | head -n 1)"
    return 0
}

dns_apply_and_verify() { # $1=uuid  (nmcli ayarlari zaten yapildi)
    if ! nmcli con up uuid "$1" >/dev/null 2>&1; then
        say "${C_YELLOW}$(t LNX_DNS_UP_FAILED)${C_RESET}"
    fi
    resolvectl flush-caches >/dev/null 2>&1
    sleep 2
}

dns_assist() {
    local ch prov d4 d6 set6=0 has6=0 dev v6_4 v6_6
    clear_screen
    if ! dns_nm_ready; then
        say "${C_YELLOW}$(t LNX_DNS_NO_NM)${C_RESET}"
        pause_
        return 0
    fi
    say "${C_YELLOW}$(t DNS_CLOUDFLARE_WARN)${C_RESET}"
    say "$(t DNS_CLOUDFLARE_INFO_1)"
    say "$(t DNS_CLOUDFLARE_INFO_2)"
    say ""
    choose_connection || { pause_; return 0; }

    say ""
    say "$(t DNS_PROVIDER_PROMPT)"
    say "  $(t DNS_PROVIDER_CLOUDFLARE)"
    say "  $(t DNS_PROVIDER_GOOGLE)"
    say "  $(t DNS_PROVIDER_CANCEL)"
    prompt_choice ch
    case "$ch" in
        1) prov="cloudflare"; d4="1.1.1.1 1.0.0.1"; d6="2606:4700:4700::1111 2606:4700:4700::1001" ;;
        2) prov="google";     d4="8.8.8.8 8.8.4.4"; d6="2001:4860:4860::8888 2001:4860:4860::8844" ;;
        *) return 0 ;;
    esac

    dev="${SEL_DEV:-$(default_dev)}"
    if [ -n "$dev" ] && ip -6 -o addr show dev "$dev" scope global 2>/dev/null | grep -q .; then has6=1; fi
    if [ "$has6" = "1" ]; then
        say "$(t DNS_IPV6_DETECTED)"
        ask_yn "$(t DNS_IPV6_OFFER_PROMPT)" && set6=1
    else
        say "${C_GRAY}$(t DNS_IPV6_NONE)${C_RESET}"
    fi

    say "$(t DNS_ASSIST_APPLYING)"
    say "${C_GRAY}$(t LNX_DNS_RECONNECT_NOTE)${C_RESET}"
    if ! nmcli con mod uuid "$SEL_UUID" ipv4.ignore-auto-dns yes ipv4.dns "$d4"; then
        say "${C_RED}$(t LNX_DNS_APPLY_FAILED)${C_RESET}"
        pause_
        return 1
    fi
    # Modemin (olmayan) IPv6 DNS'i her zaman listeden cikar; sadece gercek IPv6 varsa kendi IPv6 DNS'imizi ekle.
    if [ "$set6" = "1" ]; then
        nmcli con mod uuid "$SEL_UUID" ipv6.ignore-auto-dns yes ipv6.dns "$d6"
    else
        nmcli con mod uuid "$SEL_UUID" ipv6.ignore-auto-dns yes ipv6.dns ""
    fi
    dns_apply_and_verify "$SEL_UUID"

    say "$(t DNS_ASSIST_VERIFY_TITLE)"
    say "$(t DNS_ASSIST_VERIFY_LABEL) $(sys_lookup discord.com | tr '\n' ' ')"
    set_setting DNS_MODE "$prov"
    app_log "DNS ASSISTANT provider=$prov connection=$SEL_NAME ipv6=$set6"
    say "${C_GREEN}$(t DNS_CLOUDFLARE_DONE)${C_RESET}"
    say "$(t DNS_ASSIST_DONE)"
    pause_
}

dns_reset() {
    clear_screen
    if ! dns_nm_ready; then
        say "${C_YELLOW}$(t LNX_DNS_NO_NM)${C_RESET}"
        pause_
        return 0
    fi
    choose_connection || { pause_; return 0; }
    say "$(t DNS_ASSIST_APPLYING)"
    say "${C_GRAY}$(t LNX_DNS_RECONNECT_NOTE)${C_RESET}"
    if ! nmcli con mod uuid "$SEL_UUID" ipv4.ignore-auto-dns no ipv4.dns "" ipv6.ignore-auto-dns no ipv6.dns ""; then
        say "${C_RED}$(t LNX_DNS_APPLY_FAILED)${C_RESET}"
        pause_
        return 1
    fi
    dns_apply_and_verify "$SEL_UUID"
    set_setting DNS_MODE system
    app_log "DNS RESET connection=$SEL_NAME"
    say "${C_GREEN}$(t DNS_DHCP_DONE)${C_RESET}"
    pause_
}

# ------------------------------------------------------------
# Otomatik Test
# ------------------------------------------------------------
# Her profili sirayla baslatir, Discord/Roblox/Steam'e curl ile baglanmayi dener.
auto_test() {
    local id host rc passed sys cf svc_was=0
    local res_ids=() res_vals=() first_pass=""
    clear_screen
    say "${C_CYAN}$(t AUTOTEST_TITLE)${C_RESET}"
    say "$(t AUTOTEST_INFO_1)"
    say "$(t AUTOTEST_INFO_2)"
    say "$(t AUTOTEST_INFO_3)"
    say "$(t AUTOTEST_INFO_4)"
    say ""
    if ! command -v curl >/dev/null 2>&1; then
        say "${C_RED}$(t AUTOTEST_CURL_MISSING)${C_RESET}"
        pause_
        return 0
    fi
    list_profiles
    if [ "${#PROFILE_IDS[@]}" -eq 0 ]; then
        say "$(t LNX_PROFILE_NONE) $PROFILE_DIR"
        pause_
        return 0
    fi
    if [ ! -x "$NFQWS" ]; then
        say "${C_RED}$(t REASON_ENGINE_MISSING_HINT)${C_RESET} $NFQWS"
        pause_
        return 0
    fi
    # Sahte DNS testi bozar: baslamadan once uyar
    sys="$(sys_lookup discord.com | tr '\n' ' ')"
    cf="$(cf_lookup discord.com | tr '\n' ' ')"
    if [ -n "$cf" ] && ! overlap "$sys" "$cf"; then
        say "${C_YELLOW}$(t LNX_AUTOTEST_DNS_WARN)${C_RESET}"
        say ""
    fi
    ask_yn "$(t AUTOTEST_CONTINUE_PROMPT)" || return 0

    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        svc_was=1
    fi

    for id in "${PROFILE_IDS[@]}"; do
        say ""
        say "${C_CYAN}$(t AUTOTEST_TESTING_LABEL) $id ($(display_name "$id")) ---${C_RESET}"
        engine_start_core "$id"
        if [ "$CORE_OK" != "1" ]; then
            say "${C_RED}$(t AUTOTEST_START_FAILED_LABEL)${C_RESET} $CORE_REASON"
            res_ids+=("$id"); res_vals+=("FAIL")
            continue
        fi
        say "$(t AUTOTEST_CONNECTING)"
        passed=1
        for host in $TEST_HOSTS; do
            curl -sS -o /dev/null -m 6 "https://$host" >/dev/null 2>&1
            rc=$?
            if [ "$rc" -eq 0 ]; then
                say "  $host : ${C_GREEN}$(t DIAG_TEST_OK)${C_RESET}"
            else
                say "  $host : ${C_RED}$(t DIAG_TEST_FAIL)${C_RESET}"
                passed=0
            fi
        done
        stop_engine_core
        if [ "$passed" = "1" ]; then
            say "${C_GREEN}$(t AUTOTEST_PASS)${C_RESET}"
            res_ids+=("$id"); res_vals+=("PASS")
            [ -n "$first_pass" ] || first_pass="$id"
        else
            say "${C_RED}$(t AUTOTEST_FAIL)${C_RESET}"
            res_ids+=("$id"); res_vals+=("FAIL")
        fi
    done
    stop_engine_core

    say ""
    say "${C_CYAN}================= $(t AUTOTEST_RESULTS_TITLE) =================${C_RESET}"
    local i
    for i in "${!res_ids[@]}"; do
        printf '  %-14s = %s\n' "${res_ids[$i]}" "${res_vals[$i]}"
        app_log "AUTOTEST ${res_ids[$i]}=${res_vals[$i]}"
    done
    say ""
    if [ -n "$first_pass" ]; then
        say "${C_GREEN}$(t AUTOTEST_RECOMMENDED)${C_RESET} $first_pass"
        if ask_yn "$(t AUTOTEST_SAVE_PROMPT)"; then
            set_setting CURRENT_PROFILE "$first_pass"
            say "$(t AUTOTEST_SAVED)"
        fi
    else
        say "${C_RED}$(t AUTOTEST_NONE_PASSED)${C_RESET}"
        say "$(t AUTOTEST_NONE_PASSED_HINT)"
    fi

    # Hizmet calisiyorduysa test bitince eski haline dondur
    if [ "$svc_was" = "1" ]; then
        systemctl restart "$SERVICE_NAME" >/dev/null 2>&1
    fi
    pause_
}

# ------------------------------------------------------------
# Ayarlar ve Gunlukler
# ------------------------------------------------------------
settings_menu() {
    local ch newlang
    while true; do
        load_settings
        clear_screen
        say "${C_CYAN}$(t SETTINGS_TITLE)${C_RESET}"
        say "  $(t SETTINGS_DNS_LABEL) $DNS_MODE  $(t SETTINGS_DNS_DEFAULT_NOTE)"
        say "  $(t SETTINGS_DEBUG_LABEL) $DEBUG"
        say "  $(t SETTINGS_LANG_LABEL) $UI_LANG"
        say ""
        say "  $(t SETTINGS_OPT_DNS_LEAVE)"
        say "  $(t SETTINGS_OPT_DNS_CLOUDFLARE)"
        say "  $(t SETTINGS_OPT_DNS_DHCP)"
        say "  $(t SETTINGS_OPT_DEBUG_TOGGLE)"
        say "  $(t SETTINGS_OPT_LANG)"
        say "  $(t SETTINGS_BACK)"
        say ""
        prompt_choice ch
        case "$ch" in
            1) set_setting DNS_MODE system
               say "$(t SETTINGS_DNS_TAG_UPDATED)"; pause_ ;;
            2) dns_assist ;;
            3) dns_reset ;;
            4) if [ "$DEBUG" = "1" ]; then
                   set_setting DEBUG 0; say "$(t DEBUG_TAG_OFF)"
               else
                   set_setting DEBUG 1; say "$(t DEBUG_TAG_ON)"
               fi
               pause_ ;;
            5) if [ "$UI_LANG" = "tr" ]; then newlang="en"; else newlang="tr"; fi
               set_setting LANG "$newlang"
               load_lang "$UI_LANG"
               say "$(t LNX_LANG_CHANGED) $UI_LANG"; pause_ ;;
            0) return 0 ;;
        esac
    done
}

show_tail() { # $1 dosya  $2 bos-mesaj-anahtari  $3 (ops.) grep deseni
    if [ ! -s "$1" ]; then
        say "$(t "$2")"
    elif [ -n "${3:-}" ]; then
        grep -iE "$3" "$1" | tail -n 30
    else
        tail -n 30 "$1"
    fi
}

logs_menu() {
    local ch
    while true; do
        clear_screen
        say "${C_CYAN}$(t LOGS_TITLE)${C_RESET}"
        say ""
        say "  $(t LOGS_OPT_SHOW)"
        say "  $(t LOGS_OPT_OPEN_FOLDER)"
        say "  $(t LOGS_OPT_ERRORS)"
        say "  $(t LOGS_OPT_STDERR)"
        say "  $(t LOGS_BACK)"
        say ""
        prompt_choice ch
        case "$ch" in
            1) show_tail "$LOG_DIR/app.log" LOGS_NONE_YET; pause_ ;;
            2) mkdir -p "$LOG_DIR"
               if command -v xdg-open >/dev/null 2>&1 && \
                  { if [ -n "${SUDO_USER:-}" ]; then sudo -u "$SUDO_USER" xdg-open "$LOG_DIR" >/dev/null 2>&1 & else xdg-open "$LOG_DIR" >/dev/null 2>&1 & fi; }; then
                   :
               else
                   say "$(t LNX_OPEN_FOLDER_FAIL) $LOG_DIR"; pause_
               fi ;;
            3) show_tail "$LOG_DIR/app.log" LOGS_NONE_YET 'fail|error'; pause_ ;;
            4) show_tail "$LOG_DIR/engine_stderr.log" LOGS_STDERR_NONE_YET; pause_ ;;
            0) return 0 ;;
        esac
    done
}

# ------------------------------------------------------------
# Araclar (Tools) - Adim 3
# ------------------------------------------------------------
# "https://Ornek.com/yol?x" -> "ornek.com"
norm_host() {
    local s="$1"
    s="${s,,}"
    s="${s//[[:space:]]/}"
    s="${s#*://}"
    s="${s%%[/?#]*}"
    s="${s##*@}"
    s="${s%%:*}"
    printf '%s' "$s"
}

valid_host() { [[ "$1" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; }

# Liste degisince: servis ya da elle baslatilmis nfqws calisiyorsa yeniden baslatmayi sorar
sitelist_restart_if_running() {
    local svc=0
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        svc=1
    elif ! is_running; then
        return 0
    fi
    ask_yn "$(t SITELIST_RESTART_PROMPT)" || return 0
    if [ "$svc" = "1" ]; then
        if systemctl restart "$SERVICE_NAME" 2>/dev/null; then
            sleep 2
            if is_running; then
                say "${C_GREEN}$(t SITELIST_RESTART_DONE)${C_RESET}"
            else
                say "${C_RED}$(t LNX_SVC_NOT_RUNNING)${C_RESET}"
            fi
        else
            say "${C_RED}$(t START_FAILED)${C_RESET}"
        fi
    else
        load_settings
        engine_start_core "$CURRENT_PROFILE"
        if [ "$CORE_OK" = "1" ]; then
            say "${C_GREEN}$(t SITELIST_RESTART_DONE)${C_RESET}"
            app_log "RESTART (site list) profile=$CURRENT_PROFILE"
        else
            print_start_failure
            app_log "RESTART FAILED (site list) reason=$CORE_REASON"
        fi
    fi
}

# $1 = dosya yolu
edit_list_show() {
    echo
    if [ -s "$1" ]; then
        tr -d '\r' < "$1"
    else
        say "$(t SITELIST_EMPTY)"
    fi
    echo
    pause_
}

edit_list_add() {
    local f="$1" site eol=$'\n'
    read -r -p "$(t SITELIST_ADD_PROMPT) " site || site=""
    site="$(norm_host "$site")"
    if [ -z "$site" ]; then
        say "$(t TESTSITE_EMPTY)"; pause_; return 0
    fi
    if ! valid_host "$site"; then
        say "${C_RED}$(t LNX_SITE_INVALID)${C_RESET} $site"; pause_; return 0
    fi
    if [ -f "$f" ] && tr -d '\r' < "$f" | grep -qixF -- "$site"; then
        say "$(t SITELIST_ADD_DUPLICATE) $site"; pause_; return 0
    fi
    # dosya CRLF ise ayni satir sonunu kullan (git'te gereksiz fark olusmasin)
    grep -q $'\r' "$f" 2>/dev/null && eol=$'\r\n'
    if [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ]; then
        printf '%s' "$eol" >> "$f"
    fi
    if ! printf '%s%s' "$site" "$eol" >> "$f" 2>/dev/null; then
        say "${C_RED}$(t LNX_SITELIST_SAVE_FAIL)${C_RESET} $f"; pause_; return 0
    fi
    fix_owner "$f"
    app_log "SITELIST ADD $(basename "$f") $site"
    say "$(t SITELIST_ADD_DONE) $site"
    sitelist_restart_if_running
    pause_
}

edit_list_remove() {
    local f="$1" lines=() nums=() i k=0 n del ln site
    if [ ! -s "$f" ]; then
        say "$(t SITELIST_EMPTY)"; pause_; return 0
    fi
    mapfile -t lines < <(tr -d '\r' < "$f")
    for i in "${!lines[@]}"; do
        [ -n "${lines[$i]//[[:space:]]/}" ] || continue
        k=$((k + 1))
        nums[$k]=$((i + 1))
        say "  [$k] ${lines[$i]}"
    done
    if [ "$k" -eq 0 ]; then
        say "$(t SITELIST_EMPTY)"; pause_; return 0
    fi
    echo
    read -r -p "$(t SITELIST_REMOVE_PROMPT) " del || del=""
    if [ -z "$del" ]; then
        say "$(t TESTSITE_EMPTY)"; pause_; return 0
    fi
    if ! [[ "$del" =~ ^[0-9]+$ ]] || [ "$del" -lt 1 ] || [ "$del" -gt "$k" ]; then
        say "$(t SITELIST_REMOVE_INVALID) $del"; pause_; return 0
    fi
    ln="${nums[$del]}"
    site="${lines[$((ln - 1))]}"
    if ! sed -i "${ln}d" "$f" 2>/dev/null; then
        say "${C_RED}$(t LNX_SITELIST_SAVE_FAIL)${C_RESET} $f"; pause_; return 0
    fi
    fix_owner "$f"
    app_log "SITELIST REMOVE $(basename "$f") $site"
    say "$(t SITELIST_REMOVE_DONE) $site"
    sitelist_restart_if_running
    pause_
}

# $1 = dosya yolu, $2 = baslik
edit_list() {
    local f="$1" name="$2" ch
    while true; do
        clear_screen
        say "${C_CYAN}============================================================${C_RESET}"
        say "  $name"
        say "${C_CYAN}============================================================${C_RESET}"
        say ""
        say "  $(t SITELIST_OPT_SHOW)"
        say "  $(t SITELIST_OPT_ADD)"
        say "  $(t SITELIST_OPT_REMOVE)"
        say "  $(t SVC_MENU_BACK)"
        say ""
        prompt_choice ch
        case "$ch" in
            1) edit_list_show "$f" ;;
            2) edit_list_add "$f" ;;
            3) edit_list_remove "$f" ;;
            0) return 0 ;;
        esac
    done
}

site_list_menu() {
    local ch
    while true; do
        clear_screen
        say "${C_CYAN}============================================================${C_RESET}"
        say "  $(t TOOLS_OPT_SITELIST)"
        say "${C_CYAN}============================================================${C_RESET}"
        say "  ${C_CYAN}[1]${C_RESET}  $(t SITELIST_TARGET_LABEL)"
        say "  ${C_CYAN}[2]${C_RESET}  $(t SITELIST_EXCLUDE_LABEL)"
        say "  $(t SVC_MENU_BACK)"
        say ""
        prompt_choice ch
        case "$ch" in
            1) edit_list "$PROFILE_DIR/target-hosts.txt" "$(t SITELIST_TARGET_LABEL)" ;;
            2) edit_list "$PROFILE_DIR/exclude-hosts.txt" "$(t SITELIST_EXCLUDE_LABEL)" ;;
            0) return 0 ;;
        esac
    done
}

test_site() {
    local site rc hint
    clear_screen
    say "${C_CYAN}============================================================${C_RESET}"
    say "  $(t TESTSITE_TITLE)"
    say "${C_CYAN}============================================================${C_RESET}"
    say ""
    if ! command -v curl >/dev/null 2>&1; then
        say "${C_RED}$(t AUTOTEST_CURL_MISSING)${C_RESET}"; pause_; return 0
    fi
    read -r -p "$(t TESTSITE_PROMPT) " site || site=""
    site="$(norm_host "$site")"
    if [ -z "$site" ]; then
        say "$(t TESTSITE_EMPTY)"; pause_; return 0
    fi
    if ! valid_host "$site"; then
        say "${C_RED}$(t LNX_SITE_INVALID)${C_RESET} $site"; pause_; return 0
    fi
    is_running || say "${C_YELLOW}$(t TESTSITE_NOT_RUNNING_WARN)${C_RESET}"
    say ""
    say "$(t TESTSITE_TESTING) $site"
    curl -sS -o /dev/null -m 6 "https://$site" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        say "${C_GREEN}$(t TESTSITE_PASS)${C_RESET}"
    else
        hint="$(curl_hint "$rc")"
        say "${C_RED}$(t TESTSITE_FAIL)${C_RESET}  ${C_GRAY}${hint}${C_RESET}"
    fi
    say ""
    pause_
}

debug_panel() {
    local conf args port yn
    clear_screen
    load_settings
    say "${C_CYAN}============================================================${C_RESET}"
    say "  $(t DEBUG_TITLE)"
    say "${C_CYAN}============================================================${C_RESET}"
    say "$(t DEBUG_ROOT_LABEL) $ROOT"
    say "$(t DEBUG_ENGINE_DIR_LABEL) $ENGINE_DIR"
    say "$(t DEBUG_PROFILE_DIR_LABEL) $PROFILE_DIR"
    say "$(t DEBUG_LOG_DIR_LABEL) $LOG_DIR"
    say ""
    say "$(t DEBUG_PROFILE_ID_LABEL) $CURRENT_PROFILE"
    say "$(t DEBUG_PROFILE_NAME_LABEL) $(display_name "$CURRENT_PROFILE")"
    conf="$PROFILE_DIR/$CURRENT_PROFILE.conf"
    say "$(t DEBUG_PROFILE_FILE_LABEL) $conf"
    if [ -f "$conf" ]; then say "$(t DEBUG_FILE_EXISTS)"; else say "$(t DEBUG_FILE_MISSING)"; fi
    args="$(profile_value "$conf" ARGS)"
    port="$(profile_value "$conf" PORT_TCP)"
    [ -n "$port" ] || port=443
    say "$(t DEBUG_PARSED_PORT_LABEL) $port"
    say "$(t DEBUG_PARSED_ARGS_LABEL) $args"
    say ""
    if [ "$(id -u)" -eq 0 ]; then yn="$(t DEBUG_YES)"; else yn="$(t DEBUG_NO)"; fi
    say "$(t DEBUG_ADMIN_LABEL) $yn"
    if is_running; then
        say "$(t DEBUG_WINWS_STATUS_LABEL) $(t DEBUG_WINWS_RUNNING)"
    else
        say "$(t DEBUG_WINWS_STATUS_LABEL) $(t DEBUG_WINWS_NOT_RUNNING)"
    fi
    if nft_present; then yn="$(t LNX_DIAG_PRESENT)"; else yn="$(t LNX_DIAG_ABSENT)"; fi
    say "$(t LNX_DIAG_NFT_LABEL) $yn"
    if svc_installed; then yn="$(t SVC_INSTALLED)"; else yn="$(t SVC_NOT_INSTALLED)"; fi
    say "$(t DEBUG_SVC_STATUS_LABEL) $yn"
    say ""
    say "$(t DEBUG_LAST_CALL_TITLE)"
    if [ -n "${CORE_CMDLINE:-}" ]; then
        say "$(t DEBUG_CMDLINE_LABEL) $CORE_CMDLINE"
        say "$(t DEBUG_RESULT_LABEL) ${CORE_REASON:-}"
        [ -z "${CORE_STDERR_TAIL:-}" ] || say "$(t DEBUG_STDERR_LABEL) $CORE_STDERR_TAIL"
    else
        say "$(t DEBUG_NO_CALL_YET)"
    fi
    say ""
    say "$(t DEBUG_LOG_FILES_LABEL) $LOG_DIR"
    say "${C_CYAN}============================================================${C_RESET}"
    pause_
}

tools_menu() {
    local ch
    while true; do
        clear_screen
        say "${C_CYAN}============================================================${C_RESET}"
        say "  $(t TOOLS_TITLE)"
        say "${C_CYAN}============================================================${C_RESET}"
        say "  $(t TOOLS_OPT_SITELIST)"
        say "  $(t TOOLS_OPT_TESTSITE)"
        say "  $(t TOOLS_OPT_DEBUG)"
        say "  $(t SVC_MENU_BACK)"
        say ""
        prompt_choice ch
        case "$ch" in
            1) site_list_menu ;;
            2) test_site ;;
            3) debug_panel ;;
            0) return 0 ;;
        esac
    done
}

# ------------------------------------------------------------
# Ana menu
# ------------------------------------------------------------
exit_app() {
    clear_screen
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        say "$(t EXIT_SERVICE_CONTINUES)"
    elif is_running; then
        if ask_yn "$(t EXIT_WINWS_STILL_RUNNING)"; then
            stop_engine_core
            say "$(t STOP_OK)"
        fi
    fi
    say "$(t EXIT_DNS_UNTOUCHED)"
    say "$(t EXIT_CLOSING)"
}

main_menu() {
    local ch run_disp svc_disp pname
    while true; do
        load_settings
        clear_screen
        pname="$(display_name "$CURRENT_PROFILE")"
        if is_running; then
            run_disp="${C_GREEN}$(t STATUS_RUNNING)${C_RESET}"
        else
            run_disp="${C_RED}$(t STATUS_STOPPED)${C_RESET}"
        fi
        if svc_installed; then svc_disp="$(t SVC_INSTALLED)"; else svc_disp="$(t SVC_NOT_INSTALLED)"; fi

        say "${C_CYAN}============================================================${C_RESET}"
        say "${C_CYAN}   $(t APP_TITLE)${C_RESET}"
        say "${C_CYAN}============================================================${C_RESET}"
        say "  $(t LBL_STATUS) : $run_disp"
        say "  $(t LBL_PROFILE) : $CURRENT_PROFILE ($pname)"
        say "  $(t LBL_DNS_MODE) : $DNS_MODE"
        say "  $(t LBL_SERVICE) : $svc_disp"
        say "${C_CYAN}------------------------------------------------------------${C_RESET}"
        say "  ${C_CYAN}[1]${C_RESET}  $(t MENU_START)"
        say "  ${C_CYAN}[2]${C_RESET}  $(t MENU_STOP)"
        say "  ${C_CYAN}[3]${C_RESET}  $(t MENU_CHANGE_PROFILE)"
        say "  ${C_CYAN}[4]${C_RESET}  $(t MENU_AUTO_TEST)"
        say "  ${C_CYAN}[5]${C_RESET}  $(t MENU_SERVICE_SETTINGS)"
        say "  ${C_CYAN}[6]${C_RESET}  $(t MENU_DIAGNOSTICS)"
        say "  ${C_CYAN}[7]${C_RESET}  $(t MENU_SETTINGS)"
        say "  ${C_CYAN}[8]${C_RESET}  $(t MENU_LOGS)"
        say "  ${C_CYAN}[9]${C_RESET}  $(t MENU_TOOLS)"
        say "  ${C_CYAN}[0]${C_RESET}  $(t MENU_EXIT)"
        say "${C_CYAN}------------------------------------------------------------${C_RESET}"
        say ""
        prompt_choice ch
        case "$ch" in
            1) start_engine ;;
            2) stop_engine ;;
            3) profile_menu ;;
            4) auto_test ;;
            9) tools_menu ;;
            5) service_menu ;;
            6) diagnostics ;;
            7) settings_menu ;;
            8) logs_menu ;;
            0) exit_app; return 0 ;;
        esac
    done
}

# ------------------------------------------------------------
# Komut satiri
# ------------------------------------------------------------
cmd_help() {
    cat <<EOF
Zapret Turkey - Linux

Kullanim / Usage: $(basename "$0") [komut]

  (komut yok)         Menuyu acar / opens the menu
  start               Baslatir (nfqws + nftables kurali)
  stop                Durdurur
  restart             Yeniden baslatir
  status              Kisa durum
  profile [ad]        Profilleri listeler / secer
  diagnostics         Tanilama
  build               nfqws'i derler
  install-service     systemd servisi kurar
  uninstall-service   Servisi kaldirir
EOF
}

cmd_status() {
    load_settings
    say "$(t LBL_PROFILE)  : $CURRENT_PROFILE"
    if [ -x "$NFQWS" ]; then say "$(t DIAG_ENGINE_LABEL) $(t DIAG_STATUS_PRESENT)"; else say "$(t DIAG_ENGINE_LABEL) $(t DIAG_STATUS_MISSING)"; fi
    if is_running; then say "$(t DIAG_WINWS_STATUS_LABEL) $(t STATUS_RUNNING)"; else say "$(t DIAG_WINWS_STATUS_LABEL) $(t STATUS_STOPPED)"; fi
    if nft_present; then say "$(t LNX_DIAG_NFT_LABEL) $(t LNX_DIAG_PRESENT)"; else say "$(t LNX_DIAG_NFT_LABEL) $(t LNX_DIAG_ABSENT)"; fi
    if svc_installed; then say "$(t DIAG_SVC_STATUS_LABEL) $(t SVC_INSTALLED)"; else say "$(t DIAG_SVC_STATUS_LABEL) $(t SVC_NOT_INSTALLED)"; fi
}

cmd_profile() {
    local id
    if [ -z "${1:-}" ]; then
        load_settings
        list_profiles
        for id in "${PROFILE_IDS[@]}"; do
            if [ "$id" = "$CURRENT_PROFILE" ]; then
                printf '  * %-14s - %s\n' "$id" "$(display_name "$id")"
            else
                printf '    %-14s - %s\n' "$id" "$(display_name "$id")"
            fi
        done
        return 0
    fi
    if ! valid_name "$1" || [ ! -f "$PROFILE_DIR/$1.conf" ]; then
        say "$(t IMPORT_PROFILE_MISSING) $1"
        return 1
    fi
    set_setting CURRENT_PROFILE "$1"
    say "$(t CHANGE_PROFILE_DONE) $1"
    if is_running; then
        start_engine
    fi
}

case "${1:-menu}" in
    menu)
        init_lang interactive
        need_root
        ensure_dirs
        main_menu
        ;;
    run)               init_lang; need_root "$@"; cmd_run; exit $? ;;
    nft-clean)         need_root "$@"; nft_remove; exit 0 ;;
    start)             init_lang; need_root "$@"; ensure_dirs; start_engine; exit $? ;;
    stop)              init_lang; need_root "$@"; stop_engine; exit $? ;;
    restart)           init_lang; need_root "$@"; stop_engine_core; start_engine; exit $? ;;
    status)            init_lang; cmd_status ;;
    profile)
        init_lang
        [ -n "${2:-}" ] && need_root "$@"
        cmd_profile "${2:-}"
        exit $?
        ;;
    diagnostics|diag)  init_lang; need_root "$@"; diagnostics ;;
    build)             init_lang; need_root "$@"; build_engine; exit $? ;;
    install-service)   init_lang; need_root "$@"; svc_install; exit $? ;;
    uninstall-service) init_lang; need_root "$@"; svc_uninstall; exit $? ;;
    help|-h|--help)    cmd_help ;;
    *)                 cmd_help; exit 1 ;;
esac
