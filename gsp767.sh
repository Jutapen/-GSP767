#!/usr/bin/env bash
# ==============================================================
#  GSP767 - Exploring Cost-optimization for GKE Virtual Machines
#  Skrip otomatis untuk Google Cloud Skills Boost (jalankan di Cloud Shell)
#  Credit : Jutapen
#  GitHub : https://github.com/Jutapen
# ==============================================================
set -e

# ---------- warna (nonaktif jika output bukan terminal) ----------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  USE_COLOR=1
  C_RST=$'\033[0m'; C_BLUE=$'\033[1;34m'; C_GRN=$'\033[1;32m'
  C_YEL=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_CYN=$'\033[1;36m'
else
  USE_COLOR=0
  C_RST=""; C_BLUE=""; C_GRN=""; C_YEL=""; C_RED=""; C_CYN=""
fi

info() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RST" "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YEL" "$C_RST" "$*"; }
err()  { printf '%s[ERR ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; }

step() { printf '\n%s== %s ==%s\n' "$C_CYN" "$*" "$C_RST"; }

# Semua read memakai /dev/tty supaya tetap jalan lewat: curl ... | bash
pause() {
  printf '\n'
  read -rp "${C_YEL}>>> Klik 'Check my progress' untuk: $1, lalu tekan ENTER untuk lanjut... ${C_RST}" _ </dev/tty
}

ask_value() {
  local __var="$1" __prompt="$2" __val=""
  read -rp "$__prompt" __val </dev/tty
  printf -v "$__var" '%s' "$__val"
}

typeout() {
  local s="$1" i
  if [ "$USE_COLOR" -eq 1 ]; then
    for ((i = 0; i < ${#s}; i++)); do
      printf '%s' "${s:i:1}"
      sleep 0.03
    done
    printf '\n'
  else
    printf '%s\n' "$s"
  fi
}

show_header() {
  printf '%s==============================================================%s\n' "$C_CYN" "$C_RST"
  printf '%s GSP767 - Exploring Cost-optimization for GKE Virtual Machines%s\n' "$C_GRN" "$C_RST"
  printf ' Credit : Jutapen\n'
  printf ' GitHub : https://github.com/Jutapen\n'
  printf '%s==============================================================%s\n' "$C_CYN" "$C_RST"
}

ping_avg() {
  local out
  out="$(kubectl exec pod-1 -- ping -c 5 "$1" 2>&1)" || true
  printf '%s\n' "$out" >&2
  printf '%s' "$out" | awk '/min\/avg\/max/ { split($0, a, "="); split(a[2], b, "/"); print b[2] " ms" }'
}

finish() {
  local banner=(
    ' ____   ___  _   _ _____ '
    '|  _ \ / _ \| \ | | ____|'
    '| | | | | | |  \| |  _|  '
    '| |_| | |_| | |\  | |___ '
    '|____/ \___/|_| \_|_____|'
  )
  local colors=(51 45 39 33 27)
  local i
  printf '\n'
  for i in "${!banner[@]}"; do
    if [ "$USE_COLOR" -eq 1 ]; then
      printf '\033[1;38;5;%sm%s\033[0m\n' "${colors[$i]}" "${banner[$i]}"
    else
      printf '%s\n' "${banner[$i]}"
    fi
  done

  printf '\n%sExploring Cost-optimization for GKE Virtual Machines (GSP767)%s\n\n' "$C_CYN" "$C_RST"

  printf '%s ✔%s Hello app di-scale ke 2 replika dan node pool di-resize\n' "$C_GRN" "$C_RST"
  printf '%s ✔%s Node pool larger-pool (e2-standard-2) dibuat\n' "$C_GRN" "$C_RST"
  printf '%s ✔%s my-node-pool di-cordon, di-drain, lalu dihapus\n' "$C_GRN" "$C_RST"
  printf '%s ✔%s Cluster regional-demo dibuat di %s\n' "$C_GRN" "$C_RST" "$REGION"
  printf '%s ✔%s pod-1 dan pod-2 dibuat, lalu pod-2 dipindah ke node yang sama\n' "$C_GRN" "$C_RST"

  printf '\n Hasil penting:\n'
  printf '   Project         : %s\n' "$PROJECT"
  printf '   Zone / Region   : %s / %s\n' "$ZONE" "$REGION"
  printf '   Node pool aktif : %s\n' "${POOLS:--}"
  printf '   Node pod-1      : %s\n' "${NODE1:--}"
  printf '   Node pod-2      : %s\n' "${NODE2:--}"
  printf '   Ping antar-node : %s\n' "${PING_BEFORE:--}"
  printf '   Ping satu node  : %s\n' "${PING_AFTER:--}"
  printf '   Service URL     : - (lab ini tidak membuat service publik)\n\n'

  if [ "$USE_COLOR" -eq 1 ]; then printf '\033[1;38;5;220m'; fi
  typeout "Jangan lupa mampir ke GitHub saya: https://github.com/Jutapen"
  if [ "$USE_COLOR" -eq 1 ]; then printf '\033[0m'; fi
  printf '%sCredit: Jutapen%s\n\n' "$C_GRN" "$C_RST"
}

main() {
  show_header

  command -v gcloud >/dev/null 2>&1 || { err "gcloud tidak ditemukan. Jalankan di Cloud Shell."; exit 1; }
  command -v kubectl >/dev/null 2>&1 || { err "kubectl tidak ditemukan. Jalankan di Cloud Shell."; exit 1; }

  # ---------- Project, zone, region: semua otomatis ----------
  PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
  PROJECT="${PROJECT:-${GOOGLE_CLOUD_PROJECT:-${DEVSHELL_PROJECT_ID:-}}}"
  if [ -z "$PROJECT" ]; then
    err "Project ID tidak terdeteksi. Pastikan Cloud Shell memakai akun student lab."
    exit 1
  fi
  info "Project: $PROJECT"

  local detected
  detected="$(gcloud container clusters list --filter='name=hello-demo-cluster' --format='value(location)' 2>/dev/null | head -n1 || true)"
  if [ -n "$detected" ]; then
    ZONE="$detected"
  else
    ZONE="${ZONE:-$(gcloud config get-value compute/zone 2>/dev/null || true)}"
  fi
  if [ -z "$ZONE" ]; then
    ask_value ZONE "Zone hello-demo-cluster tidak terdeteksi. Masukkan zone (lihat panel lab): "
  fi

  REGION="${ZONE%-*}"
  if [ -z "$REGION" ] || [ "$REGION" = "$ZONE" ]; then
    REGION="$(gcloud config get-value compute/region 2>/dev/null || true)"
  fi
  if [ -z "$REGION" ]; then
    ask_value REGION "Masukkan region lab (contoh format: xx-yyyyN): "
  fi
  info "Zone: $ZONE | Region: $REGION"

  if ! gcloud container clusters describe hello-demo-cluster --zone "$ZONE" >/dev/null 2>&1; then
    err "hello-demo-cluster belum ada di zone $ZONE. Tunggu provisioning lab selesai (2-5 menit), lalu jalankan ulang."
    exit 1
  fi

  pool_exists() {
    local list
    list="$(gcloud container node-pools list --cluster hello-demo-cluster --zone "$ZONE" --format='value(name)')"
    grep -qx "$1" <<<"$list"
  }

  PING_PID=""
  stop_ping() {
    if [ -n "$PING_PID" ]; then kill "$PING_PID" 2>/dev/null || true; PING_PID=""; fi
  }
  trap stop_ping EXIT

  ############################################
  step "Task 2: Scale up Hello app"
  ############################################
  gcloud container clusters get-credentials hello-demo-cluster --zone "$ZONE"
  kubectl scale deployment hello-server --replicas=2
  pause "Scale Up Hello App"

  if pool_exists my-node-pool; then
    info "Resize my-node-pool menjadi 4 node..."
    gcloud container clusters resize hello-demo-cluster --node-pool my-node-pool \
      --num-nodes 4 --zone "$ZONE" --quiet
  else
    warn "my-node-pool sudah tidak ada, langkah resize dilewati."
  fi

  ############################################
  step "Migrate to optimized node pool"
  ############################################
  if ! pool_exists larger-pool; then
    gcloud container node-pools create larger-pool \
      --cluster=hello-demo-cluster \
      --machine-type=e2-standard-2 \
      --num-nodes=1 \
      --zone="$ZONE"
  else
    warn "larger-pool sudah ada, dilewati."
  fi
  pause "Create node pool"

  if pool_exists my-node-pool; then
    info "Cordon my-node-pool..."
    for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
      kubectl cordon "$node"
    done
    info "Drain my-node-pool..."
    for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
      kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node"
    done
  fi

  kubectl get pods -o=wide

  if pool_exists my-node-pool; then
    info "Menghapus my-node-pool..."
    gcloud container node-pools delete my-node-pool \
      --cluster hello-demo-cluster --zone "$ZONE" --quiet
  fi
  POOLS="$(gcloud container node-pools list --cluster hello-demo-cluster --zone "$ZONE" --format='value(name)' | paste -sd, -)"

  ############################################
  step "Task 3: Managing a regional cluster"
  ############################################
  if ! gcloud container clusters describe regional-demo --region="$REGION" >/dev/null 2>&1; then
    info "Membuat cluster regional-demo (beberapa menit)..."
    gcloud container clusters create regional-demo --region="$REGION" --num-nodes=1
  else
    warn "regional-demo sudah ada, dilewati."
  fi
  gcloud container clusters get-credentials regional-demo --region="$REGION"

  mkdir -p "$HOME/gsp767-work"
  cd "$HOME/gsp767-work"

cat << 'EOF' > pod-1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-1
  labels:
    security: demo
spec:
  containers:
  - name: container-1
    image: wbitt/network-multitool
EOF

cat << 'EOF' > pod-2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-2
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - demo
        topologyKey: "kubernetes.io/hostname"
  containers:
  - name: container-2
    image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
EOF

  kubectl apply -f pod-1.yaml
  if ! kubectl get pod pod-2 >/dev/null 2>&1; then
    kubectl apply -f pod-2.yaml
  fi
  kubectl wait --for=condition=Ready pod/pod-1 pod/pod-2 --timeout=300s
  kubectl get pod pod-1 pod-2 --output wide
  pause "Check Pod Creation"

  # Fase 1: pod di node berbeda (anti-affinity) -> ping + flow logs
  if kubectl get pod pod-2 -o jsonpath='{.spec.affinity.podAntiAffinity}' | grep -q .; then
    local pod2_ip
    pod2_ip="$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}')"
    info "IP pod-2: $pod2_ip"
    info "Latensi ping pod-1 -> pod-2 (catat rata-ratanya):"
    PING_BEFORE="$(ping_avg "$pod2_ip")"

    # Ping tetap berjalan di latar belakang supaya ada traffic untuk flow logs
    kubectl exec pod-1 -- ping -c 1200 "$pod2_ip" </dev/null >/tmp/gsp767-ping.log 2>&1 &
    PING_PID=$!

    printf '\n%s=============================================================%s\n' "$C_YEL" "$C_RST"
    printf ' LANGKAH MANUAL DI CONSOLE (ikuti instruksi lab), ping masih berjalan:\n'
    printf ' 1. VPC Network > VPC Flow Logs > Enable the Network Management API\n'
    printf ' 2. Add VPC flow logs configuration > Add a configuration for subnets\n'
    printf '    > VPC networks: default > OK > pilih subnet di region %s\n' "$REGION"
    printf '    > Manage flow logs > Add new configuration > Add a configuration\n'
    printf '    > Done > Save\n'
    printf ' 3. Logs Explorer > All log names > vpc_flows > Apply\n'
    printf ' 4. Actions > Create Sink: nama FlowLogsSample > Next\n'
    printf '    > BigQuery dataset > Create new dataset: us_flow_logs > Create sink\n'
    printf ' 5. BigQuery: tabel compute_googleapis_com_vpc_flows_xxx > Query,\n'
    printf '    tempel kolom src_zone, src_vm, dest_zone, dest_vm lalu Run\n'
    printf '%s=============================================================%s\n' "$C_YEL" "$C_RST"
    read -rp "${C_YEL}>>> Setelah selesai melihat flow logs, tekan ENTER untuk memindahkan pod... ${C_RST}" _ </dev/tty

    stop_ping
    kubectl exec pod-1 -- pkill ping 2>/dev/null || true

    info "Memindahkan pod-2 ke node yang sama dengan pod-1..."
    sed -i 's/podAntiAffinity/podAffinity/g' pod-2.yaml
    kubectl delete pod pod-2
    kubectl create -f pod-2.yaml
    kubectl wait --for=condition=Ready pod/pod-2 --timeout=300s
  fi

  kubectl get pod pod-1 pod-2 --output wide
  local ip2
  ip2="$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}')"
  info "Latensi ping setelah satu node (harusnya lebih kecil):"
  PING_AFTER="$(ping_avg "$ip2")"
  NODE1="$(kubectl get pod pod-1 -o jsonpath='{.spec.nodeName}')"
  NODE2="$(kubectl get pod pod-2 -o jsonpath='{.spec.nodeName}')"
  pause "Simulate Traffic"

  ok "Semua langkah lab selesai. Cek skor di panel lab."
  finish
}

# main dipanggil paling akhir agar seluruh skrip terbaca penuh (aman untuk curl | bash)
main "$@"
