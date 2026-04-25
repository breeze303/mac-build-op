# MAC-Build-OpenWrt

使用 Podman/Docker 容器在 macOS 上编译 OpenWrt。

特点：

- OpenWrt 源码放在本机
- Git / 编辑器在本机使用
- 编译命令在容器中执行
- 不需要在本机安装 OpenWrt 编译依赖

---

## 1. 准备 OpenWrt 源码

```bash
git clone https://github.com/openwrt/openwrt.git openwrt
````

如果使用 ImmortalWrt：

```bash
git clone https://github.com/immortalwrt/immortalwrt.git openwrt
```

---

## 2. 进入本项目目录

```bash
cd ~/mac-build-op
```

---

## 3. 配置 .env

```bash
cat > .env <<EOF
OPENWRT_DIR=${HOME}/openwrt
LOCAL_UID=$(id -u)
LOCAL_GID=$(id -g)
EOF
```

查看配置：

```bash
cat .env
```

`OPENWRT_DIR` 必须指向 OpenWrt 源码目录。

---

## 4. 构建编译镜像

使用的是docker只需要把podman改成docker即可

```bash
podman compose build
```

如果需要重新构建：

```bash
podman compose build --no-cache
```

---

## 5. 更新 feeds

```bash
podman compose run --rm openwrt-build bash -lc './scripts/feeds update -a && ./scripts/feeds install -a'
```

---

## 6. 配置固件

```bash
podman compose run --rm -e TERM=xterm-256color openwrt-build bash -lc 'make menuconfig'
```

如果要编译 x86_64，在菜单里选择：

```text
Target System  ---> x86
Subtarget      ---> x86_64
Target Profile ---> Generic
```

保存退出后，会在本机 OpenWrt 源码目录生成 `.config`。

---

## 7. 下载源码包

```bash
podman compose run --rm openwrt-build bash -lc 'make download -j$(nproc)'
```

---

## 8. 开始编译

```bash
podman compose run --rm openwrt-build bash -lc 'make -j$(nproc) V=s'
```

如果想限制线程，比如 4 线程：

```bash
podman compose run --rm openwrt-build bash -lc 'make -j4 V=s'
```

---

## 9. 查看编译结果

编译完成后，固件会在 OpenWrt 源码目录下：

```bash
ls ~/openwrt/bin/targets/
```

x86_64 固件一般在：

```bash
ls ~/openwrt/bin/targets/x86/64/
```

---

## 10. 常用命令

清理编译产物：

```bash
podman compose run --rm openwrt-build bash -lc 'make clean'
```

深度清理：

```bash
podman compose run --rm openwrt-build bash -lc 'make dirclean'
```

清理单个包：

```bash
podman compose run --rm openwrt-build bash -lc 'make package/包名/clean V=s'
```

重新编译单个包：

```bash
podman compose run --rm openwrt-build bash -lc 'make package/包名/compile V=s'
```

---

## 11. 可选：创建快捷脚本

创建 `owrt.sh`：

```bash
cat > owrt.sh <<'EOF'
#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

podman compose run --rm -e TERM=xterm-256color openwrt-build bash -lc "$*"
EOF

chmod +x owrt.sh
```

之后可以这样使用：

```bash
./owrt.sh './scripts/feeds update -a && ./scripts/feeds install -a'
./owrt.sh 'make menuconfig'
./owrt.sh 'make download -j$(nproc)'
./owrt.sh 'make -j$(nproc) V=s'
```

---

## 注意

一般不需要执行：

```bash
podman compose up
```

本项目不是长期运行的服务，推荐使用：

```bash
podman compose run --rm openwrt-build bash -lc '命令'
```

# 玩得愉快