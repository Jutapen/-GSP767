# GSP767 - Exploring Cost-optimization for GKE Virtual Machines

Skrip bash otomatis untuk lab **GSP767** (Google Cloud Skills Boost), dijalankan langsung di Cloud Shell.
Skrip berhenti di setiap tugas yang punya tombol **Check my progress**, sehingga Anda bisa mengeceknya dulu sebelum lanjut.

**Credit: Jutapen** | https://github.com/Jutapen

## Cara pakai (satu baris)

1. Mulai lab, tunggu provisioning selesai (cluster `hello-demo-cluster` sekitar 2-5 menit).
2. Login ke Google Cloud Console dengan akun student dari panel lab, lalu buka **Cloud Shell**.
3. Jalankan:

```bash
curl -fsSL https://raw.githubusercontent.com/Jutapen/GSP767/main/gsp767.sh | bash
```

Project ID, zone, dan region diambil otomatis dari `gcloud`. Kalau zone atau region tidak terdeteksi, skrip akan menanyakannya.

Jeda "Check my progress" muncul di sini (klik tombolnya di halaman lab, lalu tekan ENTER di Cloud Shell):

| Jeda | Tombol yang diklik |
|------|--------------------|
| 1 | Scale Up Hello App |
| 2 | Create node pool |
| 3 | Check Pod Creation |
| 4 | Simulate Traffic (di akhir) |

## Langkah manual di GUI

Bagian flow logs, sink, dan BigQuery dikerjakan di console, sesuai instruksi lab. Skrip akan berhenti dan menampilkan panduan ini sementara ping antar-pod berjalan di latar belakang:

1. **VPC Network > VPC Flow Logs**, klik **Enable the Network Management API**.
2. Klik **Add VPC flow logs configuration > Add a configuration for subnets**. Di tab *Subnets in current project*, centang VPC **default**, klik **OK**. Pilih subnet di region lab, klik **Manage flow logs > Add new configuration**, lalu **Add a configuration > Done > Save**.
3. Buka **Logs Explorer**, klik **All log names**, pilih **vpc_flows**, lalu **Apply**. Kalau belum muncul, tunggu 1-2 menit dan refresh. Kalau log kosong, ganti `/` sebelum `vpc_flows` dengan `%2F`.
4. Klik **Actions > Create sink**. Nama: `FlowLogsSample`, **Next**. Pilih **BigQuery dataset > Create new BigQuery dataset**, Dataset ID `us_flow_logs`, **Create dataset**, lalu **Create sink**.
5. Buka **BigQuery**, pilih dataset `us_flow_logs`, klik tabel `compute_googleapis_com_vpc_flows_xxx` lalu **Query**. Tempel teks ini di antara `SELECT` dan `FROM`, lalu **Run**:

```
jsonPayload.src_instance.zone AS src_zone, jsonPayload.src_instance.vm_name AS src_vm, jsonPayload.dest_instance.zone AS dest_zone, jsonPayload.dest_instance.vm_name
```

6. Cari beberapa baris dengan `src_zone` dan `dest_zone` berbeda, lalu kembali ke Cloud Shell dan tekan ENTER agar skrip memindahkan pod-2.

## Yang normal terjadi

- Setelah `kubectl scale`, pod `hello-server` kedua bisa `Pending` dengan alasan *Insufficient cpu*. Ini wajar, lalu node pool di-resize ke 4 node. Di sebagian versi Kubernetes error ini tidak muncul sama sekali.
- `my-node-pool` sengaja di-cordon, di-drain, lalu **dihapus** setelah `larger-pool` dibuat. Itu bagian instruksi lab.
- Pembuatan cluster `regional-demo` memakan waktu beberapa menit.
- Ping antar-zona (pod di node berbeda) lebih lambat. Setelah pod-2 dipindah ke node yang sama dengan pod-1, ping lebih cepat.
- Skrip aman dijalankan ulang: node pool, cluster, dan pod yang sudah ada dilewati. Kalau pod-2 sudah satu node dengan pod-1, fase flow logs dilewati.
- Skrip menjalankan `get-credentials` untuk `regional-demo` supaya `kubectl` menunjuk ke cluster yang benar. Itu tidak tertulis di lab, tetapi tidak membuat resource baru.
- Warna dan efek ketik hanya aktif kalau output berupa terminal.

## Disclaimer

Proyek ini hanya untuk tujuan edukasi dan tidak berafiliasi dengan Google. Gunakan hanya dengan akun student yang diberikan lab, bukan akun Google Cloud pribadi. Anda bertanggung jawab memahami isi skrip sebelum menjalankannya.

## Lisensi

MIT. Lihat berkas [LICENSE](LICENSE).
