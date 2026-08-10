#!/bin/bash

set -e

# ============================================================================
# Remnawave Node Variants Generator - Interactive Version (original XTLS core)
# ============================================================================
# Version: 2.2.0-fixed
# Description: Interactive generator for remnawave node variants with custom Xray core support.
#              Uses the ORIGINAL, official Xray core from XTLS/Xray-core.
#              Includes the following fixes over the original rnode.sh:
#                - rw-core wrapper uses #!/bin/sh + plain exec (no 'exec -a',
#                  which is a bashism and needs a bash whose path is not
#                  guaranteed; a wrong shebang made exec fail with ENOENT);
#                - docker commands auto-prefix sudo when the user is not in the
#                  'docker' group;
#                - robust GitHub release version resolution.
#              Custom core install is OPTIONAL (default N); when declined, the
#              Xray core bundled in the remnawave/node base image is used.
# Xray core source: https://github.com/XTLS/Xray-core
# ============================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

VERSION="2.2.0-fixed"

# Источник ядра Xray — официальный репозиторий XTLS/Xray-core.
# Ядро скачивается из релизов (Xray-linux-<arch>.zip) и проверяется по SHA-256.
XRAY_REPO="XTLS/Xray-core"

# Маскировка артефактов ядра в директории проекта.
# Папка сборочного контекста называется нейтрально (как обычная часть
# Docker-проекта), а бинарник внутри неё — именем выбранного «легендного»
# процесса (nginx/traefik/...), а не "xray". Так в `ls` не видно ни "xray-core",
# ни голого "xray".
CORE_DIR_NAME="bin"

# ============================================================================
# СЛОВАРЬ ВАРИАНТОВ (100 штук)
# ============================================================================

declare -a VARIANTS=(
    "systemd|System and Service Manager|System initialization and service management daemon|System"
    "networkd|Network Manager Service|Network configuration management daemon|System"
    "journald|Journal Logging Service|System logging and journal management|System"
    "resolved|DNS Resolver Service|Network name resolution manager|System"
    "timesyncd|Time Synchronization Service|Network time synchronization daemon|System"
    "logind|Login Manager Service|User session and login management|System"
    "udevd|Device Manager Service|Dynamic device management daemon|System"
    "dbusd|Message Bus Service|Inter-process communication system|System"
    "polkitd|Policy Kit Service|Authorization and privilege management|System"
    "crond|Task Scheduler Service|Periodic command scheduler daemon|System"
    "sshd|SSH Server Service|Secure shell remote access daemon|Network"
    "ntpd|Network Time Service|Network time protocol daemon|Network"
    "dhcpd|DHCP Service|Dynamic host configuration protocol server|Network"
    "rpcbind|RPC Bind Service|Remote procedure call binding daemon|Network"
    "avahi-daemon|Avahi mDNS Service|Multicast DNS service discovery|Network"
    "firewalld|Firewall Service|Dynamic firewall management daemon|Network"
    "iptables|Packet Filter Service|Network packet filtering and NAT|Network"
    "NetworkManager|Network Connection Manager|Network connectivity management service|Network"
    "wpa_supplicant|WPA Authentication Service|Wireless network authentication daemon|Network"
    "openvpn|VPN Service|Virtual private network daemon|Network"
    "rsyslogd|System Logging Service|Enhanced system logging daemon|Monitoring"
    "auditd|Audit Service|System security auditing daemon|Monitoring"
    "collectd|Statistics Collection Service|System statistics collection daemon|Monitoring"
    "telegraf|Metrics Collection Service|Server monitoring and metrics agent|Monitoring"
    "prometheus|Monitoring Service|Systems monitoring and alerting toolkit|Monitoring"
    "grafana-server|Analytics Service|Metrics analytics and visualization|Monitoring"
    "node_exporter|Node Metrics Exporter|Hardware and OS metrics exporter|Monitoring"
    "zabbix_agentd|Monitoring Agent|Enterprise monitoring agent daemon|Monitoring"
    "snmpd|SNMP Service|Simple network management protocol daemon|Monitoring"
    "nagios|Infrastructure Monitoring|IT infrastructure monitoring service|Monitoring"
    "rsyncd|File Sync Service|Remote file synchronization daemon|Storage"
    "nfsd|NFS Service|Network file system daemon|Storage"
    "smbd|SMB Service|Samba file sharing daemon|Storage"
    "mountd|Mount Service|NFS mount protocol daemon|Storage"
    "glusterd|Cluster Storage Service|Distributed file system daemon|Storage"
    "ceph-mon|Ceph Monitor Service|Ceph cluster monitoring daemon|Storage"
    "lvmetad|LVM Metadata Service|Logical volume metadata cache daemon|Storage"
    "dockerd|Container Runtime Service|Container runtime daemon|Container"
    "containerd|Container Manager Service|Container lifecycle management|Container"
    "kubelet|Kubernetes Node Agent|Kubernetes node management agent|Container"
    "kube-proxy|Kubernetes Network Proxy|Kubernetes network proxy service|Container"
    "crio|CRI-O Runtime Service|OCI container runtime daemon|Container"
    "podman|Pod Manager Service|Container pod management daemon|Container"
    "libvirtd|Virtualization Service|Virtual machine management daemon|Virtualization"
    "qemu-system|QEMU Emulator Service|Hardware virtualization emulator|Virtualization"
    "redis-server|Cache Service|In-memory data structure store|Database"
    "memcached|Memory Cache Service|Distributed memory caching system|Database"
    "postgres|Database Service|Advanced relational database system|Database"
    "mysqld|MySQL Database Service|Relational database management system|Database"
    "mongod|MongoDB Service|Document database management system|Database"
    "cassandra|Distributed Database|Distributed NoSQL database system|Database"
    "elasticsearch|Search Engine Service|Distributed search and analytics engine|Database"
    "nginx|Web Server Service|High-performance HTTP server and reverse proxy|WebServer"
    "apache2|Apache Web Service|HTTP server daemon|WebServer"
    "httpd|HTTP Server Service|Web server daemon|WebServer"
    "php-fpm|PHP Process Manager|FastCGI process manager for PHP|Application"
    "node|Node.js Service|JavaScript runtime service|Application"
    "java|Java Runtime Service|Java application runtime|Application"
    "python3|Python Service|Python application runtime|Application"
    "gunicorn|WSGI Server Service|Python WSGI HTTP server|Application"
    "uwsgi|Application Server|Web application container server|Application"
    "fail2ban|Intrusion Prevention|Intrusion prevention framework|Security"
    "clamd|Antivirus Service|Antivirus daemon|Security"
    "aide|File Integrity Service|File and directory integrity checker|Security"
    "ossec|Host IDS Service|Host-based intrusion detection|Security"
    "apparmor|Security Module Service|Application security framework|Security"
    "selinux|Security Enhanced Linux|Mandatory access control system|Security"
    "rabbitmq|Message Queue Service|Message broker daemon|MessageQueue"
    "kafka|Stream Processing Service|Distributed streaming platform|MessageQueue"
    "activemq|Message Broker Service|Java message service broker|MessageQueue"
    "zeromq|Messaging Service|Distributed messaging library|MessageQueue"
    "bacula-fd|Backup Client Service|Backup file daemon|Backup"
    "borgbackup|Deduplicating Backup|Backup program with deduplication|Backup"
    "restic|Backup Service|Fast and secure backup program|Backup"
    "haproxy|Load Balancer Service|High availability load balancer|LoadBalancer"
    "traefik|Reverse Proxy Service|Modern HTTP reverse proxy|Proxy"
    "envoy|Service Proxy|Cloud-native edge and service proxy|Proxy"
    "squid|Caching Proxy Service|Web caching proxy server|Proxy"
    "varnish|HTTP Accelerator|HTTP accelerator and caching proxy|Proxy"
    "named|DNS Service|Domain name system daemon|DNS"
    "unbound|DNS Resolver Service|Validating DNS resolver|DNS"
    "dnsmasq|DNS/DHCP Service|Lightweight DNS forwarder and DHCP server|DNS"
    "postfix|Mail Transfer Agent|Mail transfer agent daemon|Mail"
    "dovecot|IMAP/POP3 Service|Mail delivery agent|Mail"
    "exim|Mail Service|Mail transfer agent|Mail"
    "acpid|ACPI Event Service|Advanced configuration and power interface daemon|System"
    "atd|Batch Job Service|Deferred task execution daemon|System"
    "bluetoothd|Bluetooth Service|Bluetooth protocol daemon|System"
    "cups|Printing Service|Common Unix printing system|System"
    "gdm|Display Manager Service|GNOME display manager|System"
    "accounts-daemon|Accounts Service|User account management daemon|System"
    "ModemManager|Modem Manager Service|Mobile broadband modem management|System"
    "thermald|Thermal Management|Thermal monitoring and control daemon|System"
    "irqbalance|IRQ Balance Service|IRQ load distribution daemon|System"
    "smartd|SMART Monitoring Service|Self-monitoring analysis reporting daemon|System"
    "lightdm|Display Manager|Lightweight display manager|System"
    "packagekitd|Package Management|Software installation service|System"
    "udisksd|Disk Manager|Disk management daemon|System"
    "upowerd|Power Management|Power management daemon|System"
    "colord|Color Management|Color management daemon|System"
    "fwupd|Firmware Update Service|Firmware update daemon|System"
    "switcheroo-control|GPU Switcher|GPU switching control service|System"
)

# ============================================================================
# ФУНКЦИИ ГЕНЕРАЦИИ ФАЙЛОВ
# ============================================================================

generate_dockerfile() {
    local process="$1"
    local title="$2"
    local description="$3"
    local vendor="$4"

    cat << EOF
FROM remnawave/node:latest

# Копируем папку сборки (если внутри есть бинарник — он заменит ядро образа)
COPY --chown=root:root ${CORE_DIR_NAME}/ /tmp/${CORE_DIR_NAME}/

# Переименовываем бинарник ядра и создаём wrapper rw-core.
# ВАЖНО: wrapper использует #!/bin/sh и ПРОСТОЙ exec, без 'exec -a'.
# Причина: 'exec -a' — bash-изм и требует bash, но путь к нему в образе не
# гарантирован. #!/usr/bin/bash может отсутствовать -> ядро ОС не находит
# интерпретатор и exec возвращает ENOENT ("supervisor: couldn't exec ...
# rw-core: ENOENT" / "rw-core: not found"). /bin/sh есть всегда.
# Маскировка ИМЕНИ процесса сохраняется за счёт переименования бинарника
# (comm = ${process}); теряется лишь подмена argv[0] на голое имя.
RUN if [ -f /tmp/${CORE_DIR_NAME}/${process} ]; then \\
        echo "Using bundled core..."; \\
        rm -f /usr/local/bin/xray; \\
        mv /tmp/${CORE_DIR_NAME}/${process} /usr/local/bin/xray; \\
        chmod +x /usr/local/bin/xray; \\
    fi && \\
    rm -rf /tmp/${CORE_DIR_NAME} && \\
    mv /usr/local/bin/xray /usr/local/bin/${process} && \\
    rm -f /usr/local/bin/rw-core && \\
    printf '#!/bin/sh\\nexec /usr/local/bin/${process} "\$@"\\n' \\
       > /usr/local/bin/rw-core && \\
    chmod +x /usr/local/bin/rw-core

# Путь к фактическому бинарнику после переименования
ENV RW_CORE_BINARY="/usr/local/bin/${process}"

# Правильный путь — туда куда смотрит ENTRYPOINT
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

LABEL org.opencontainers.image.title="${title}"
LABEL org.opencontainers.image.description="${description}"
LABEL org.opencontainers.image.vendor="${vendor}"
LABEL org.opencontainers.image.url=""
LABEL org.opencontainers.image.source=""
LABEL org.opencontainers.image.documentation=""
EOF
}

generate_docker_compose() {
    local process="$1"
    local service_name="${process//-/_}"
    service_name="${service_name//./_}"
    local container_name="svc_${service_name}"
    local hostname="svc-${process}"

    cat << EOF
services:
  ${service_name}:
    build:
      context: .
      dockerfile: .Dockerfile
    image: ${process}:stable

    container_name: ${container_name}
    hostname: ${hostname}

    network_mode: host
    restart: always

    cap_add:
      - NET_ADMIN

    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576

    environment:
      NODE_ENV: production
      NODE_PORT: \${EDGE_NODE_PORT}
      SECRET_KEY: \${EDGE_SECRET}
      XTLS_API_PORT: \${EDGE_API_PORT}
      NODE_OPTIONS: "--max-http-header-size=65536"
      UV_THREADPOOL_SIZE: "24"

    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

    security_opt:
      - no-new-privileges:true

    tmpfs:
      - /tmp:rw,noexec,nosuid,size=64m

    healthcheck:
      test: ["CMD-SHELL", "pidof node >/dev/null || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s
EOF
}

generate_entrypoint() {
    cat << 'EOF'
#!/bin/sh

rm -f /run/remnawave-internal-*.sock 2>/dev/null
rm -f /run/supervisord-*.sock 2>/dev/null
rm -f /run/supervisord-*.pid 2>/dev/null

echo "[Entrypoint] Starting entrypoint script..."

generate_random() {
    local length="${1:-64}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

RNDSTR=$(generate_random 10)
SUPERVISORD_USER=$(generate_random 64)
SUPERVISORD_PASSWORD=$(generate_random 64)
INTERNAL_REST_TOKEN=$(generate_random 64)

# Генерируем случайный префикс сокета вместо "remnawave-internal"
SOCK_PREFIX=$(generate_random 8)

INTERNAL_SOCKET_PATH=/run/${SOCK_PREFIX}-${RNDSTR}.sock
SUPERVISORD_SOCKET_PATH=/run/supervisord-${RNDSTR}.sock
SUPERVISORD_PID_PATH=/run/supervisord-${RNDSTR}.pid

export SUPERVISORD_USER
export SUPERVISORD_PASSWORD
export INTERNAL_REST_TOKEN
export INTERNAL_SOCKET_PATH
export SUPERVISORD_SOCKET_PATH
export SUPERVISORD_PID_PATH

echo "[Entrypoint] Getting Supervisord version..."
echo "[Entrypoint] Supervisord version: $(supervisord --version | head -n 1)"

supervisord -c /etc/supervisord.conf &
echo "[Entrypoint] Supervisord started successfully"
sleep 1


if [ -n "${CUSTOM_CORE_URL:-}" ]; then
    CORE_TARGET="${RW_CORE_BINARY:-/usr/local/bin/xray}"
    echo "[Entrypoint] CUSTOM_CORE_URL is set, downloading custom core to: $CORE_TARGET"
    rm -f "$CORE_TARGET"
    if wget -q -O "$CORE_TARGET" "$CUSTOM_CORE_URL"; then
        chmod +x "$CORE_TARGET"
        echo "[Entrypoint] Custom core downloaded and installed successfully"
    else
        echo "[Entrypoint] ERROR: Failed to download custom core from: $CUSTOM_CORE_URL"
        exit 1
    fi
fi

echo "[Entrypoint] Getting Xray version..."

XRAY_CORE_VERSION=$(/usr/local/bin/rw-core version | head -n 1)
export XRAY_CORE_VERSION

echo "[Entrypoint] Xray version: $XRAY_CORE_VERSION"
echo "[Ports] XTLS_API_PORT: $XTLS_API_PORT"

echo "[Entrypoint] Executing command: $@"
exec "$@"
EOF
}

generate_env_example() {
    cat << 'EOF'
EDGE_NODE_PORT=2222
EDGE_SECRET=your_secret_key_here
EDGE_API_PORT=36891
EOF
}

# ============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================================

# Функция для чтения ввода из /dev/tty (для работы с curl | bash)
read_input() {
    if [ -t 0 ]; then
        # Стандартный ввод доступен
        read "$@"
    else
        # Читаем из /dev/tty для работы с pipe
        read "$@" < /dev/tty
    fi
}

# Определяет, нужен ли sudo для обращения к docker.
# Возвращает "sudo " (с пробелом) либо пустую строку.
#   - root                          -> "" (sudo не нужен)
#   - есть прямой доступ к сокету    -> "" (пользователь в группе docker)
#   - иначе, если sudo доступен      -> "sudo "
get_docker_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        echo ""
    elif docker info &> /dev/null 2>&1; then
        echo ""
    elif command -v sudo &> /dev/null; then
        echo "sudo "
    else
        echo ""
    fi
}

# Функция для определения доступной команды docker compose.
# Автоматически добавляет префикс sudo, если он нужен для доступа к docker.
get_docker_compose_cmd() {
    local sudo_prefix
    sudo_prefix="$(get_docker_sudo)"

    if command -v docker-compose &> /dev/null; then
        echo "${sudo_prefix}docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        echo "${sudo_prefix}docker compose"
    else
        echo ""
    fi
}

get_variant_data() {
    local idx="$1"
    local field="$2"

    if [ "$idx" -lt 1 ] || [ "$idx" -gt "${#VARIANTS[@]}" ]; then
        echo "unknown"
        return
    fi

    local variant="${VARIANTS[$((idx-1))]}"
    IFS='|' read -r process title description vendor <<< "$variant"

    case "$field" in
        process) echo "$process" ;;
        title) echo "$title" ;;
        description) echo "$description" ;;
        vendor) echo "$vendor" ;;
        *) echo "unknown" ;;
    esac
}

get_variants_by_category() {
    local category="$1"
    local result=""

    for i in $(seq 1 ${#VARIANTS[@]}); do
        local vendor=$(get_variant_data "$i" "vendor")
        if [ "$vendor" = "$category" ]; then
            local process=$(get_variant_data "$i" "process")
            if [ -z "$result" ]; then
                result="$i:$process"
            else
                result="$result|$i:$process"
            fi
        fi
    done

    echo "$result"
}

get_categories() {
    echo "System Network Monitoring Storage Container Virtualization Database WebServer Application Security MessageQueue Backup LoadBalancer Proxy DNS Mail"
}

create_variant_files() {
    local target_dir="$1"
    local idx="$2"

    local process=$(get_variant_data "$idx" "process")
    local title=$(get_variant_data "$idx" "title")
    local description=$(get_variant_data "$idx" "description")
    local vendor=$(get_variant_data "$idx" "vendor")

    echo ""
    echo -e "${CYAN}Creating files in: ${BOLD}$target_dir${NC}"
    echo ""

    mkdir -p "$target_dir"

    # Создаём папку сборочного контекста с заглушкой для Docker COPY
    mkdir -p "$target_dir/$CORE_DIR_NAME"
    touch "$target_dir/$CORE_DIR_NAME/.keep"

    generate_dockerfile "$process" "$title" "$description" "$vendor" > "$target_dir/.Dockerfile"
    echo -e "${GREEN}✓${NC} .Dockerfile"

    generate_docker_compose "$process" > "$target_dir/docker-compose.yml"
    echo -e "${GREEN}✓${NC} docker-compose.yml"

    generate_entrypoint > "$target_dir/docker-entrypoint.sh"
    chmod +x "$target_dir/docker-entrypoint.sh"
    echo -e "${GREEN}✓${NC} docker-entrypoint.sh"

    generate_env_example > "$target_dir/.env.example"
    echo -e "${GREEN}✓${NC} .env.example"

    if [ ! -f "$target_dir/.env" ]; then
        cp "$target_dir/.env.example" "$target_dir/.env"
        echo -e "${GREEN}✓${NC} .env ${YELLOW}(created from example)${NC}"
    else
        echo -e "${YELLOW}⚠${NC} .env ${YELLOW}(already exists, skipped)${NC}"
    fi
}

# Определение архитектуры Xray asset
get_xray_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "64" ;;
        i386|i486|i586|i686) echo "32" ;;
        aarch64|arm64|armv8*) echo "arm64-v8a" ;;
        armv7l|armv7) echo "arm32-v7a" ;;
        armv6l) echo "arm32-v6" ;;
        armv5tel) echo "arm32-v5" ;;
        mips) echo "mips32" ;;
        mipsel|mipsle) echo "mips32le" ;;
        mips64) echo "mips64" ;;
        mips64el|mips64le) echo "mips64le" ;;
        ppc64) echo "ppc64" ;;
        ppc64le) echo "ppc64le" ;;
        riscv64) echo "riscv64" ;;
        s390x) echo "s390x" ;;
        loongarch64|loong64) echo "loong64" ;;
        *)
            echo -e "${RED}Unsupported architecture: $(uname -m)${NC}" >&2
            return 1
            ;;
    esac
}

# Получение тега релиза.
# latest — самый новый опубликованный релиз, включая pre-release.
# stable — последний стабильный релиз GitHub.
resolve_xray_version() {
    local requested="${1:-latest}"
    local api_url
    local response
    local version

    case "$requested" in
        latest|LATEST|Latest|"")
            api_url="https://api.github.com/repos/${XRAY_REPO}/releases?per_page=20"
            ;;
        stable|STABLE|Stable)
            api_url="https://api.github.com/repos/${XRAY_REPO}/releases/latest"
            ;;
        *)
            requested="${requested#v}"
            echo "v${requested}"
            return 0
            ;;
    esac

    echo -e "${CYAN}Resolving Xray version from GitHub...${NC}" >&2
    if ! response=$(curl -fsSL \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        -H 'Accept: application/vnd.github+json' \
        -H 'User-Agent: remnawave-node-variants-generator' \
        "$api_url"); then
        echo -e "${RED}Failed to query GitHub releases API${NC}" >&2
        return 1
    fi

    # ВНИМАНИЕ: grep -m1 ограничивает число совпадающих СТРОК, а не совпадений.
    # GitHub может вернуть компактный (однострочный) JSON — тогда grep -o выдаёт
    # сразу все теги, и версия становится многострочной. Берём первый (самый
    # новый) тег через head -n1 — корректно и для pretty, и для compact JSON.
    version=$(printf '%s\n' "$response" \
        | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | head -n1 \
        | sed -E 's/.*"([^"]+)"$/\1/' || true)

    if [ -z "$version" ]; then
        echo -e "${RED}Could not determine Xray release tag${NC}" >&2
        return 1
    fi

    echo "$version"
}

# Преобразует JSON GitHub Releases API в строки:
# tag<TAB>prerelease<TAB>published-date
parse_xray_releases() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json
import sys

try:
    releases = json.load(sys.stdin)
except Exception as exc:
    print(f"Cannot parse GitHub response: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(releases, list):
    print("Unexpected GitHub response format", file=sys.stderr)
    raise SystemExit(1)

for release in releases:
    if release.get("draft"):
        continue
    tag = release.get("tag_name")
    if not tag:
        continue
    prerelease = "true" if release.get("prerelease") else "false"
    published = (release.get("published_at") or "")[:10]
    print(f"{tag}\t{prerelease}\t{published}")
'
        return $?
    fi

    if command -v jq >/dev/null 2>&1; then
        jq -r '.[] | select(.draft == false) | [.tag_name, (.prerelease | tostring), ((.published_at // "")[0:10])] | @tsv'
        return $?
    fi

    echo -e "${RED}To display the release menu, install python3 or jq.${NC}" >&2
    return 1
}

# Загружает список опубликованных Xray-релизов.
fetch_xray_releases() {
    local limit="${1:-20}"
    local response
    local parsed

    if ! response=$(curl -fsSL \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        -H 'Accept: application/vnd.github+json' \
        -H 'User-Agent: remnawave-node-variants-generator' \
        "https://api.github.com/repos/${XRAY_REPO}/releases?per_page=${limit}"); then
        echo -e "${RED}Failed to load Xray releases from GitHub.${NC}" >&2
        return 1
    fi

    if ! parsed=$(printf '%s' "$response" | parse_xray_releases); then
        return 1
    fi

    if [ -z "$parsed" ]; then
        echo -e "${RED}GitHub returned an empty Xray release list.${NC}" >&2
        return 1
    fi

    printf '%s\n' "$parsed"
}

# Интерактивный выбор версии из списка GitHub.
# Результат сохраняется в SELECTED_XRAY_VERSION.
select_xray_version() {
    local release_data=""
    local choice=""
    local manual_version=""
    local index=1
    local tag=""
    local prerelease=""
    local published=""
    local label=""
    local -a tags=()
    local -a prereleases=()
    local -a dates=()

    SELECTED_XRAY_VERSION=""

    echo ""
    echo -e "${CYAN}Loading available Xray versions...${NC}"

    if release_data=$(fetch_xray_releases 20); then
        while IFS=$'\t' read -r tag prerelease published; do
            [ -n "$tag" ] || continue
            tags+=("$tag")
            prereleases+=("$prerelease")
            dates+=("$published")
        done <<< "$release_data"
    fi

    if [ "${#tags[@]}" -eq 0 ]; then
        echo -e "${YELLOW}Could not display the online version list.${NC}"
        read_input -p "Enter Xray version manually (example: v26.7.29, q = cancel): " manual_version
        if [[ "$manual_version" =~ ^[Qq]$ ]] || [ -z "$manual_version" ]; then
            return 1
        fi
        SELECTED_XRAY_VERSION="v${manual_version#v}"
        return 0
    fi

    echo ""
    echo -e "${BLUE}Available Xray versions (${XRAY_REPO}):${NC}"
    echo ""

    for ((index=0; index<${#tags[@]}; index++)); do
        if [ "${prereleases[$index]}" = "true" ]; then
            label="${YELLOW}pre-release${NC}"
        else
            label="${GREEN}stable${NC}"
        fi
        printf "  ${GREEN}%2d${NC}) ${BOLD}%-14s${NC} [%b]  %s\n" \
            "$((index + 1))" "${tags[$index]}" "$label" "${dates[$index]}"
    done

    echo ""
    echo -e "  ${CYAN}m${NC}) Enter version manually"
    echo -e "  ${CYAN}s${NC}) Latest stable release"
    echo -e "  ${RED}q${NC}) Cancel custom core installation"
    echo ""

    while true; do
        read_input -p "Select Xray version [1-${#tags[@]}] (default: 1): " choice
        choice="${choice:-1}"

        case "$choice" in
            q|Q)
                return 1
                ;;
            m|M)
                read_input -p "Enter Xray version (example: v26.7.29): " manual_version
                if [ -z "$manual_version" ]; then
                    echo -e "${RED}Version cannot be empty.${NC}"
                    continue
                fi
                SELECTED_XRAY_VERSION="v${manual_version#v}"
                return 0
                ;;
            s|S)
                SELECTED_XRAY_VERSION="stable"
                return 0
                ;;
        esac

        if [[ "$choice" =~ ^[0-9]+$ ]] \
            && [ "$choice" -ge 1 ] \
            && [ "$choice" -le "${#tags[@]}" ]; then
            SELECTED_XRAY_VERSION="${tags[$((choice - 1))]}"
            return 0
        fi

        echo -e "${RED}Invalid selection.${NC}"
    done
}

install_unzip_if_needed() {
    if command -v unzip >/dev/null 2>&1; then
        return 0
    fi

    local privilege=""
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            privilege="sudo"
        else
            echo -e "${RED}unzip is missing and root/sudo access is unavailable${NC}"
            return 1
        fi
    fi

    echo -e "${YELLOW}Installing unzip...${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        $privilege apt-get update -qq
        $privilege apt-get install -y unzip
    elif command -v dnf >/dev/null 2>&1; then
        $privilege dnf install -y unzip
    elif command -v pacman >/dev/null 2>&1; then
        $privilege pacman -S --noconfirm unzip
    elif command -v zypper >/dev/null 2>&1; then
        $privilege zypper --non-interactive install unzip
    else
        echo -e "${RED}Cannot install unzip automatically. Install it manually.${NC}"
        return 1
    fi
}

# Функция скачивания Xray ядра
# Поддерживает exact tag, latest (включая pre-release) и stable.
download_xray_core() {
    local target_dir="${1:-.}"
    local requested_version="${2:-latest}"
    local bin_name="${3:-xray}"
    [ -n "$bin_name" ] || bin_name="xray"
    local version
    local arch
    local zip_file
    local download_url
    local digest_url
    local core_dir="$target_dir/$CORE_DIR_NAME"
    local tmp_dir
    local expected_sha=""
    local actual_sha=""
    local detected_version=""

    install_unzip_if_needed || return 1

    version=$(resolve_xray_version "$requested_version") || return 1
    arch=$(get_xray_arch) || return 1
    zip_file="Xray-linux-${arch}.zip"
    download_url="https://github.com/${XRAY_REPO}/releases/download/${version}/${zip_file}"
    digest_url="${download_url}.dgst"

    tmp_dir=$(mktemp -d) || return 1
    mkdir -p "$tmp_dir/unpack"

    echo -e "${YELLOW}Downloading Xray ${version} (${arch})...${NC}"
    echo -e "${CYAN}${download_url}${NC}"

    if ! curl -fL \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        --progress-bar \
        -o "$tmp_dir/$zip_file" \
        "$download_url"; then
        echo -e "${RED}Failed to download Xray asset${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Проверка SHA-256, если GitHub digest-файл доступен.
    if command -v sha256sum >/dev/null 2>&1 \
        && curl -fsSL --retry 2 -o "$tmp_dir/$zip_file.dgst" "$digest_url"; then
        expected_sha=$(grep -ioE '[a-f0-9]{64}' "$tmp_dir/$zip_file.dgst" | head -n1 || true)
        if [ -n "$expected_sha" ]; then
            actual_sha=$(sha256sum "$tmp_dir/$zip_file" | awk '{print $1}')
            if [ "${actual_sha,,}" != "${expected_sha,,}" ]; then
                echo -e "${RED}SHA-256 mismatch for ${zip_file}${NC}"
                rm -rf "$tmp_dir"
                return 1
            fi
            echo -e "${GREEN}✓${NC} SHA-256 verified"
        fi
    fi

    if ! unzip -o -q "$tmp_dir/$zip_file" -d "$tmp_dir/unpack"; then
        echo -e "${RED}Failed to extract ${zip_file}${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi

    if [ ! -f "$tmp_dir/unpack/xray" ]; then
        echo -e "${RED}Archive does not contain xray binary${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi

    chmod 755 "$tmp_dir/unpack/xray"
    detected_version=$("$tmp_dir/unpack/xray" version 2>/dev/null | head -n1 || true)
    if [ -z "$detected_version" ]; then
        echo -e "${RED}Downloaded xray binary cannot be executed${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Заменяем старое ядро только после успешной загрузки и проверки.
    # Кладём ТОЛЬКО бинарник, переименованный в "$bin_name" (маскировка);
    # geoip/geosite/LICENSE/README из релиза не нужны — Dockerfile берёт из
    # папки лишь бинарник, а geo-файлы использует из базового образа.
    rm -rf "$core_dir"
    mkdir -p "$core_dir"
    cp -a "$tmp_dir/unpack/xray" "$core_dir/$bin_name"
    touch "$core_dir/.keep"
    rm -rf "$tmp_dir"

    echo -e "${GREEN}✓${NC} Installed: ${detected_version}"
    return 0
}

# Функция настройки кастомного ядра (отдельно от .env).
# Поведение ОРИГИНАЛЬНОЕ: установка опциональна (по умолчанию N). При отказе
# используется ядро Xray, уже вшитое в базовый образ remnawave/node. Скачивание
# из ${XRAY_REPO} нужно, только если хочешь зафиксировать конкретную версию ядра.
setup_custom_core() {
    local target_dir="${1:-.}"
    local process="${2:-xray}"
    local install_custom_core=""
    local xray_version=""

    echo ""
    echo -e "${CYAN}Custom Xray Core (optional, source: ${XRAY_REPO}):${NC}"
    read_input -p "Install custom Xray core? [y/N]: " install_custom_core

    if [[ ! "$install_custom_core" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Пропущено — будет использовано ядро из базового образа remnawave/node.${NC}"
        return 0
    fi

    if ! select_xray_version; then
        echo -e "${YELLOW}Custom Xray core installation cancelled.${NC}"
        return 0
    fi

    xray_version="$SELECTED_XRAY_VERSION"
    echo ""
    echo -e "${CYAN}Selected Xray version: ${BOLD}${xray_version}${NC}"

    # Бинарник кладётся в папку сборки под именем процесса (маскировка).
    if download_xray_core "$target_dir" "$xray_version" "$process"; then
        echo -e "${GREEN}✓${NC} Core downloaded to $target_dir/$CORE_DIR_NAME/$process"
        echo -e "${GREEN}✓${NC} Core will be embedded in Docker image during build"
    else
        echo -e "${RED}✗${NC} Failed to download Xray core from ${XRAY_REPO}"
        return 1
    fi
}

configure_env() {
    local target_dir="${1:-.}"

    echo ""
    echo -e "${CYAN}Configure environment:${NC}"
    read_input -p "EDGE_NODE_PORT (default: 2222): " node_port
    read_input -p "EDGE_API_PORT (default: 36891): " api_port

    while true; do
        read_input -sp "EDGE_SECRET (required): " secret_key
        echo ""
        if [ -n "$secret_key" ]; then
            break
        else
            echo -e "${RED}Error: EDGE_SECRET is required!${NC}"
        fi
    done

    node_port="${node_port:-2222}"
    api_port="${api_port:-36891}"

    cat > "$target_dir/.env" << EOF
EDGE_NODE_PORT=${node_port}
EDGE_SECRET=${secret_key}
EDGE_API_PORT=${api_port}
EOF

    echo -e "${GREEN}✓${NC} Environment configured"
}

# ============================================================================
# КОМАНДА: GENERATE (интерактивный выбор по категориям)
# ============================================================================

cmd_generate() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}  ${BOLD}Select Variant by Category${NC}                    ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
        echo ""

        # Показываем категории
        categories=($(get_categories))
        echo -e "${CYAN}Available categories:${NC}"
        echo ""

        for i in "${!categories[@]}"; do
            local cat="${categories[$i]}"
            local count=$(get_variants_by_category "$cat" | tr '|' '\n' | wc -l)
            printf "  ${GREEN}%2d${NC}. ${YELLOW}%-20s${NC} (${count} variants)\n" "$((i+1))" "$cat"
        done

        echo ""
        echo -e "${YELLOW}[q]${NC} Back to main menu"
        echo ""
        read_input -p "Select category [1-${#categories[@]}]: " cat_choice

        if [[ "$cat_choice" == "q" ]] || [[ "$cat_choice" == "Q" ]]; then
            return
        fi

        if ! [[ "$cat_choice" =~ ^[0-9]+$ ]] || [ "$cat_choice" -lt 1 ] || [ "$cat_choice" -gt "${#categories[@]}" ]; then
            echo -e "${RED}Invalid choice${NC}"
            sleep 1
            continue
        fi

        selected_category="${categories[$((cat_choice-1))]}"

        # Показываем варианты в категории
        while true; do
            clear
            echo -e "${CYAN}Category: ${BOLD}$selected_category${NC}"
            echo -e "${BLUE}─────────────────────────────────────────────────${NC}"
            echo ""

            variants_in_cat=$(get_variants_by_category "$selected_category")
            IFS='|' read -ra ITEMS <<< "$variants_in_cat"

            for item in "${ITEMS[@]}"; do
                idx=$(echo "$item" | cut -d':' -f1)
                proc=$(echo "$item" | cut -d':' -f2)
                title=$(get_variant_data "$idx" "title")
                printf "  ${GREEN}%3s${NC}. ${YELLOW}%-25s${NC} - ${CYAN}%s${NC}\n" "$idx" "$proc" "$title"
            done

            echo ""
            echo -e "${YELLOW}[q]${NC} Back to categories"
            echo ""
            read_input -p "Select variant number: " variant_num

            if [[ "$variant_num" == "q" ]] || [[ "$variant_num" == "Q" ]]; then
                break
            fi

            if ! [[ "$variant_num" =~ ^[0-9]+$ ]] || [ "$variant_num" -lt 1 ] || [ "$variant_num" -gt "${#VARIANTS[@]}" ]; then
                echo -e "${RED}Invalid variant number${NC}"
                sleep 1
                continue
            fi

            # Проверяем что вариант из этой категории
            if ! echo "$variants_in_cat" | grep -q "$variant_num:"; then
                echo -e "${RED}Variant #$variant_num is not in category $selected_category${NC}"
                sleep 1
                continue
            fi

            process=$(get_variant_data "$variant_num" "process")
            title=$(get_variant_data "$variant_num" "title")
            description=$(get_variant_data "$variant_num" "description")

            clear
            echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║${NC}  ${BOLD}Selected Variant${NC}                              ${GREEN}║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "  ${CYAN}Number:${NC}      #$variant_num"
            echo -e "  ${CYAN}Process:${NC}     ${YELLOW}$process${NC}"
            echo -e "  ${CYAN}Title:${NC}       $title"
            echo -e "  ${CYAN}Description:${NC} $description"
            echo ""

            # Выбор директории
            echo "Where to create files?"
            echo "  1) Current directory"
            echo "  2) New directory"
            echo ""
            echo -e "${YELLOW}[q]${NC} Back to variant list"
            echo ""
            read_input -p "Choice [1-2]: " dir_choice

            if [[ "$dir_choice" == "q" ]] || [[ "$dir_choice" == "Q" ]]; then
                continue
            fi

            case $dir_choice in
                1)
                    target_dir="."
                    ;;
                2)
                    read_input -p "Directory name (default: $process): " custom_dir
                    target_dir="${custom_dir:-$process}"
                    ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    sleep 1
                    continue
                    ;;
            esac

            # Создаем файлы
            create_variant_files "$target_dir" "$variant_num"

            # Конфигурация
            echo ""
            read_input -p "Configure .env now? [Y/n]: " config_now
            if [[ ! "$config_now" =~ ^[Nn]$ ]]; then
                configure_env "$target_dir"
            fi

            # Кастомное ядро (независимо от конфигурации .env)
            setup_custom_core "$target_dir" "$process"

            # Запуск
            echo ""
            read_input -p "Start container now? [y/N]: " start_now
            if [[ "$start_now" =~ ^[Yy]$ ]]; then
                echo ""
                echo "Starting container..."
                cd "$target_dir"

                DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
                if [ -z "$DOCKER_COMPOSE_CMD" ]; then
                    echo -e "${RED}Error: docker-compose or docker compose not found${NC}"
                    echo "Install Docker Compose first"
                    read_input -p "Press Enter to continue..."
                    return
                fi

                $DOCKER_COMPOSE_CMD up -d --build
                echo ""
                echo -e "${GREEN}✓${NC} Container started!"
                echo ""
                echo "Logs: $DOCKER_COMPOSE_CMD logs -f"
                echo "Stop: $DOCKER_COMPOSE_CMD down"
            else
                echo ""
                echo -e "${YELLOW}To start manually:${NC}"
                if [ "$target_dir" != "." ]; then
                    echo "  cd $target_dir"
                fi
                DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
                if [ -n "$DOCKER_COMPOSE_CMD" ]; then
                    echo "  $DOCKER_COMPOSE_CMD up -d --build"
                else
                    echo "  docker-compose up -d --build  # or: docker compose up -d --build"
                fi
            fi

            echo ""
            echo -e "${GREEN}✓${NC} Done!"
            echo ""
            read_input -p "Press Enter to continue..."
            return
        done
    done
}

# ============================================================================
# КОМАНДА: RANDOM (случайный выбор с reroll)
# ============================================================================

cmd_random() {
    local variant_num

    while true; do
        variant_num=$((RANDOM % ${#VARIANTS[@]} + 1))

        process=$(get_variant_data "$variant_num" "process")
        title=$(get_variant_data "$variant_num" "title")
        description=$(get_variant_data "$variant_num" "description")
        vendor=$(get_variant_data "$variant_num" "vendor")

        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}  ${BOLD}🎲 Random Variant${NC}                             ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}Number:${NC}      ${YELLOW}#$variant_num${NC}"
        echo -e "  ${CYAN}Process:${NC}     ${YELLOW}$process${NC}"
        echo -e "  ${CYAN}Title:${NC}       $title"
        echo -e "  ${CYAN}Description:${NC} $description"
        echo -e "  ${CYAN}Category:${NC}    ${MAGENTA}$vendor${NC}"
        echo ""

        echo "What to do?"
        echo "  1) Use this variant"
        echo "  2) Reroll (pick another)"
        echo ""
        echo -e "  ${YELLOW}q${NC}) Back to main menu"
        echo ""
        read_input -p "Choice: " choice

        case $choice in
            1)
                break
                ;;
            2)
                continue
                ;;
            q|Q)
                return
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                sleep 1
                continue
                ;;
        esac
    done

    # Выбор директории
    while true; do
        clear
        echo -e "${GREEN}Selected: ${YELLOW}$process${NC}"
        echo ""
        echo "Where to create files?"
        echo "  1) Current directory"
        echo "  2) New directory"
        echo ""
        echo -e "${YELLOW}[q]${NC} Back to reroll"
        echo ""
        read_input -p "Choice [1-2]: " dir_choice

        if [[ "$dir_choice" == "q" ]] || [[ "$dir_choice" == "Q" ]]; then
            cmd_random
            return
        fi

        case $dir_choice in
            1)
                target_dir="."
                break
                ;;
            2)
                read_input -p "Directory name (default: $process): " custom_dir
                target_dir="${custom_dir:-$process}"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                sleep 1
                ;;
        esac
    done

    # Создаем файлы
    create_variant_files "$target_dir" "$variant_num"

    # Конфигурация
    echo ""
    read_input -p "Configure .env now? [Y/n]: " config_now
    if [[ ! "$config_now" =~ ^[Nn]$ ]]; then
        configure_env "$target_dir"
    fi

    # Кастомное ядро (независимо от конфигурации .env)
    setup_custom_core "$target_dir" "$process"

    # Запуск
    echo ""
    read_input -p "Start container now? [y/N]: " start_now
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Starting container..."
        cd "$target_dir"

        DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
        if [ -z "$DOCKER_COMPOSE_CMD" ]; then
            echo -e "${RED}Error: docker-compose or docker compose not found${NC}"
            echo "Install Docker Compose first"
            read_input -p "Press Enter to continue..."
            return
        fi

        $DOCKER_COMPOSE_CMD up -d --build
        echo ""
        echo -e "${GREEN}✓${NC} Container started!"
        echo ""
        echo "Logs: $DOCKER_COMPOSE_CMD logs -f"
        echo "Stop: $DOCKER_COMPOSE_CMD down"
    else
        echo ""
        echo -e "${YELLOW}To start manually:${NC}"
        if [ "$target_dir" != "." ]; then
            echo "  cd $target_dir"
        fi
        DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
        if [ -n "$DOCKER_COMPOSE_CMD" ]; then
            echo "  $DOCKER_COMPOSE_CMD up -d --build"
        else
            echo "  docker-compose up -d --build  # or: docker compose up -d --build"
        fi
    fi

    echo ""
    echo -e "${GREEN}✓${NC} Done!"
    echo ""
    read_input -p "Press Enter to continue..."
}

# ============================================================================
# КОМАНДА: CHECK
# ============================================================================

cmd_check() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Dependency Check${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""

    ERRORS=0
    WARNINGS=0

    # Bash
    if [ -n "$BASH_VERSION" ]; then
        echo -e "${GREEN}✓${NC} Bash: $BASH_VERSION"
        bash_major=$(echo "$BASH_VERSION" | cut -d'.' -f1)
        if [ "$bash_major" -lt 4 ]; then
            echo -e "${YELLOW}  ⚠ Old version (recommend 4.0+)${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗${NC} Bash: not found"
        ((ERRORS++))
    fi

    # Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        if docker info &> /dev/null 2>&1; then
            echo -e "${GREEN}  → Daemon running${NC}"
        elif [ "$(id -u)" -ne 0 ] && command -v sudo &> /dev/null && sudo docker info &> /dev/null 2>&1; then
            echo -e "${GREEN}  → Daemon running${NC} ${YELLOW}(via sudo — user not in 'docker' group)${NC}"
        else
            echo -e "${YELLOW}  ⚠ Daemon not accessible${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗${NC} Docker: not found (REQUIRED)"
        ((ERRORS++))
    fi

    # Docker Compose
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker Compose (standalone): $(docker-compose --version | cut -d' ' -f3 | tr -d ',')"
    elif docker compose version &> /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Docker Compose (plugin): $(docker compose version | cut -d' ' -f3 | tr -d ',')"
    else
        echo -e "${RED}✗${NC} Docker Compose: not found (REQUIRED)"
        echo -e "${YELLOW}  Install: apt install docker-compose-plugin${NC}"
        ((ERRORS++))
    fi

    # Utilities
    for cmd in curl grep sed awk find tar chmod; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓${NC} $cmd"
        else
            echo -e "${RED}✗${NC} $cmd: not found"
            ((ERRORS++))
        fi
    done

    # JSON parser for the interactive Xray release menu
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✓${NC} python3 (GitHub release parser)"
    elif command -v jq &> /dev/null; then
        echo -e "${GREEN}✓${NC} jq (GitHub release parser)"
    else
        echo -e "${YELLOW}⚠${NC} python3/jq not found: online Xray version list will be unavailable"
        WARNINGS=$((WARNINGS + 1))
    fi

    echo ""
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ $ERRORS error(s) found${NC}"
        [ $WARNINGS -gt 0 ] && echo -e "${YELLOW}⚠ $WARNINGS warning(s)${NC}"
        exit 1
    fi
}

# ============================================================================
# КОМАНДА: CLEAN
# ============================================================================

cmd_clean() {
    clear
    echo -e "${YELLOW}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${BOLD}Clean Generated Files${NC}                         ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This will remove generated files in current directory:${NC}"
    echo "  - .Dockerfile"
    echo "  - docker-compose.yml"
    echo "  - docker-entrypoint.sh"
    echo "  - .env.example"
    echo ""
    read_input -p "Continue? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f .Dockerfile docker-compose.yml docker-entrypoint.sh .env.example
        echo -e "${GREEN}✓ Cleaned${NC}"
    else
        echo "Cancelled"
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    echo -e "${BOLD}Remnawave Node Variants Generator v${VERSION}${NC}"
    echo ""
    echo -e "${BOLD}USAGE:${NC}"
    echo "    $0 <command>"
    echo ""
    echo -e "${BOLD}COMMANDS:${NC}"
    echo -e "    ${GREEN}generate${NC}    Select variant by category (interactive)"
    echo -e "    ${GREEN}random${NC}      Random variant with reroll option"
    echo -e "    ${GREEN}check${NC}       Check system dependencies"
    echo -e "    ${GREEN}clean${NC}       Remove generated files"
    echo -e "    ${GREEN}help${NC}        Show this help"
    echo ""
    echo -e "${BOLD}WORKFLOW:${NC}"
    echo "    1. Run: $0 generate"
    echo "    2. Choose category and variant"
    echo "    3. Files created in selected directory"
    echo "    4. Configure and start"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "    $0 generate       # Browse and select variant"
    echo "    $0 random         # Get random variant (with reroll)"
    echo "    $0 check          # Verify dependencies"
    echo ""
}

# ============================================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================================

show_main_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}  ${BOLD}Remnawave Node Variants Generator v${VERSION}${NC}     ${BLUE}║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Select an option:${NC}"
        echo ""
        echo -e "  ${GREEN}1${NC}) Generate variant (by category)"
        echo -e "  ${GREEN}2${NC}) Random variant (with reroll)"
        echo -e "  ${GREEN}3${NC}) Check dependencies"
        echo -e "  ${GREEN}4${NC}) Clean generated files"
        echo ""
        echo -e "  ${YELLOW}h${NC}) Help"
        echo -e "  ${RED}q${NC}) Quit"
        echo ""
        read_input -p "Choice: " choice

        case "$choice" in
            1)
                cmd_generate
                ;;
            2)
                cmd_random
                ;;
            3)
                cmd_check
                read_input -p "Press Enter to continue..."
                ;;
            4)
                cmd_clean
                read_input -p "Press Enter to continue..."
                ;;
            h|H)
                clear
                show_help
                echo ""
                read_input -p "Press Enter to continue..."
                ;;
            q|Q)
                echo ""
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                sleep 1
                ;;
        esac
    done
}

main() {
    # Если команда передана - выполняем её напрямую (для curl | bash)
    if [ $# -gt 0 ]; then
        case "${1}" in
            generate|gen|g)
                cmd_generate
                ;;
            random|rand|r)
                cmd_random
                ;;
            check|c)
                cmd_check
                ;;
            clean)
                cmd_clean
                ;;
            help|h|-h|--help)
                show_help
                ;;
            *)
                echo -e "${RED}Unknown command: $1${NC}"
                echo ""
                show_help
                exit 1
                ;;
        esac
    else
        # Интерактивный режим
        show_main_menu
    fi
}

# Запуск
main "$@"
