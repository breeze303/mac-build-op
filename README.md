````markdown
# OpenWrt Podman Build Environment

这是一个用于在 macOS / Linux 上通过 Podman 容器编译 OpenWrt 的轻量构建环境。

本项目的目标是：

- OpenWrt 源码保留在本机
- Git、VS Code、Cursor 等编辑操作都在本机完成
- 只在执行 `feeds`、`menuconfig`、`make` 编译时使用容器
- 避免在本机安装大量 OpenWrt 编译依赖
- 尽量保持构建环境干净、可复现

---

## 适用场景

适合以下用户：

- 使用 macOS，尤其是 MacBook / Apple Silicon 用户
- 不想直接污染本机环境
- 想用本机编辑器管理 OpenWrt 源码
- 只希望容器提供编译依赖
- 需要编译 OpenWrt / ImmortalWrt / 自定义 OpenWrt 源码

---

## 目录结构建议

推荐将本项目和 OpenWrt 源码放在同一级目录：

```text
~/test/
├── openwrt/        # OpenWrt 源码目录
└── qsdk-docker/    # 本项目目录
````

其中：

```text
~/test/openwrt
```

是你的 OpenWrt 源码目录。

```text
~/test/qsdk-docker
```

是本项目目录，里面包含：

```text
Dockerfile
docker-compose.yml
.env
```

---

## 1. 准备 Podman

请先确保本机已经安装 Podman。

macOS 用户需要先启动 Podman Machine：

```bash
podman machine init
podman machine start
```

检查 Podman 是否可用：

```bash
podman info
```

---

## 2. 克隆 OpenWrt 源码

如果你还没有 OpenWrt 源码，可以在本机执行：

```bash
mkdir -p ~/test
cd ~/test

git clone https://github.com/openwrt/openwrt.git openwrt
```

如果你使用 ImmortalWrt，可以改成：

```bash
git clone https://github.com/immortalwrt/immortalwrt.git openwrt
```

检查源码目录：

```bash
ls -la ~/test/openwrt
```

正常应该能看到类似文件：

```text
Makefile
scripts/
package/
target/
feeds.conf.default
```

---

## 3. 配置 .env

进入本项目目录：

```bash
cd ~/test/qsdk-docker
```

创建 `.env` 文件：

```bash
cat > .env <<EOF
OPENWRT_DIR=${HOME}/test/openwrt
LOCAL_UID=$(id -u)
LOCAL_GID=$(id -g)
EOF
```

查看配置：

```bash
cat .env
```

示例：

```env
OPENWRT_DIR=/Users/breeze/test/openwrt
LOCAL_UID=501
LOCAL_GID=20
```

说明：

| 变量            | 说明              |
| ------------- | --------------- |
| `OPENWRT_DIR` | 本机 OpenWrt 源码路径 |
| `LOCAL_UID`   | 当前用户 UID        |
| `LOCAL_GID`   | 当前用户 GID        |

`LOCAL_UID` 和 `LOCAL_GID` 用于让容器内生成的文件尽量匹配本机用户权限，减少文件权限问题。

---

## 4. 构建容器镜像

执行：

```bash
podman compose build
```

如果需要强制重新构建：

```bash
podman compose build --no-cache
```

构建完成后，会生成镜像：

```text
openwrt-build:latest
```

---

## 5. 验证源码挂载

执行：

```bash
podman compose run --rm openwrt-build bash -lc 'pwd && ls -la | head && test -f Makefile && test -x scripts/feeds && echo OK'
```

正常输出中应该包含：

```text
/home/builder/openwrt
OK
```

如果提示：

```text
./scripts/feeds: No such file or directory
```

说明 `.env` 里的 `OPENWRT_DIR` 没有指向 OpenWrt 源码根目录。

---

## 6. 更新 feeds

```bash
podman compose run --rm openwrt-build bash -lc './scripts/feeds update -a && ./scripts/feeds install -a'
```

---

## 7. 打开 menuconfig

```bash
podman compose run --rm -e TERM=xterm-256color openwrt-build bash -lc 'make menuconfig'
```

保存后，配置文件会写入本机 OpenWrt 源码目录：

```text
~/test/openwrt/.config
```

也就是说，虽然 `menuconfig` 是在容器中运行的，但实际修改的是你本机源码目录里的 `.config`。

---

## 8. 下载源码包

```bash
podman compose run --rm openwrt-build bash -lc 'make download -j$(nproc)'
```

---

## 9. 开始编译

```bash
podman compose run --rm openwrt-build bash -lc 'make -j$(nproc) V=s'
```

如果想限制线程数量，例如 4 线程：

```bash
podman compose run --rm openwrt-build bash -lc 'make -j4 V=s'
```

---

## 10. 常用命令

### 更新 feeds

```bash
podman compose run --rm openwrt-build bash -lc './scripts/feeds update -a && ./scripts/feeds install -a'
```

### 打开 menuconfig

```bash
podman compose run --rm -e TERM=xterm-256color openwrt-build bash -lc 'make menuconfig'
```

### 下载依赖源码

```bash
podman compose run --rm openwrt-build bash -lc 'make download -j$(nproc)'
```

### 编译固件

```bash
podman compose run --rm openwrt-build bash -lc 'make -j$(nproc) V=s'
```

### 清理编译产物

```bash
podman compose run --rm openwrt-build bash -lc 'make clean'
```

### 深度清理

```bash
podman compose run --rm openwrt-build bash -lc 'make dirclean'
```

### 清理单个包

例如清理 `luci`：

```bash
podman compose run --rm openwrt-build bash -lc 'make package/luci/clean V=s'
```

---

## 11. 推荐快捷脚本

可以在项目目录创建一个脚本 `owrt.sh`：

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

这样就不用每次输入完整的 `podman compose run` 命令。

---

## 12. 不需要 podman compose up

本项目不是一个长期运行的服务，因此通常不需要执行：

```bash
podman compose up
```

如果执行后看到：

```text
Attaching to openwrt-build-1
```

这不是卡死，而是容器启动后没有默认编译命令，正在等待。

推荐使用：

```bash
podman compose run --rm openwrt-build bash -lc 'make -j$(nproc) V=s'
```

如果已经启动了后台容器，可以停止：

```bash
podman compose down
```

---

## 13. 在其他目录执行命令

如果当前不在本项目目录，可以指定 compose 文件和 env 文件：

```bash
podman compose \
  -f ~/test/qsdk-docker/docker-compose.yml \
  --env-file ~/test/qsdk-docker/.env \
  run --rm openwrt-build \
  bash -lc 'make -j$(nproc) V=s'
```

否则可能会出现：

```text
no configuration file provided: not found
```

---

## 14. 本机编辑源码

源码仍然在本机，所以你可以正常使用 Git 和编辑器：

```bash
cd ~/test/openwrt

git status
git pull
code .
```

容器只负责执行编译环境相关命令。

---

## 15. 常见问题

### OPENWRT_DIR variable is not set

报错示例：

```text
The "OPENWRT_DIR" variable is not set
invalid spec: :/home/builder/openwrt
```

原因：

`.env` 文件不存在，或者不在 `docker-compose.yml` 同一目录。

解决：

```bash
cd ~/test/qsdk-docker

cat > .env <<EOF
OPENWRT_DIR=${HOME}/test/openwrt
LOCAL_UID=$(id -u)
LOCAL_GID=$(id -g)
EOF
```

---

### ./scripts/feeds: No such file or directory

原因：

`OPENWRT_DIR` 没有指向 OpenWrt 源码根目录。

检查：

```bash
cat .env
ls -la ~/test/openwrt
ls -la ~/test/openwrt/scripts/feeds
```

`OPENWRT_DIR` 指向的目录必须包含：

```text
Makefile
scripts/
package/
target/
feeds.conf.default
```

---

### no configuration file provided: not found

原因：

你没有在 `docker-compose.yml` 所在目录执行命令。

解决：

```bash
cd ~/test/qsdk-docker
```

然后重新执行命令。

或者使用：

```bash
podman compose \
  -f ~/test/qsdk-docker/docker-compose.yml \
  --env-file ~/test/qsdk-docker/.env \
  run --rm openwrt-build bash -lc 'make menuconfig'
```

---

### podman compose up 一直停在 Attaching

原因：

容器没有默认编译命令，启动后会等待输入。

解决：

不要使用：

```bash
podman compose up
```

改用：

```bash
podman compose run --rm openwrt-build bash -lc 'make -j$(nproc) V=s'
```

---

### Unable to locate package libncursesw-dev

原因：

Ubuntu latest 当前可能没有 `libncursesw-dev` 这个包名。

解决：

Dockerfile 中不要安装：

```text
libncursesw-dev
```

保留：

```text
libncurses-dev
```

---

## 16. 推荐完整流程

首次使用：

```bash
mkdir -p ~/test
cd ~/test

git clone https://github.com/openwrt/openwrt.git openwrt
git clone <your-repo-url> qsdk-docker

cd qsdk-docker

cat > .env <<EOF
OPENWRT_DIR=${HOME}/test/openwrt
LOCAL_UID=$(id -u)
LOCAL_GID=$(id -g)
EOF

podman compose build
```

日常编译：

```bash
cd ~/test/qsdk-docker

podman compose run --rm openwrt-build bash -lc './scripts/feeds update -a && ./scripts/feeds install -a'

podman compose run --rm -e TERM=xterm-256color openwrt-build bash -lc 'make menuconfig'

podman compose run --rm openwrt-build bash -lc 'make download -j$(nproc)'

podman compose run --rm openwrt-build bash -lc 'make -j$(nproc) V=s'
```

---

## 17. 设计思路

本项目的核心思路是：

```text
本机：源码、Git、编辑器
容器：OpenWrt 编译依赖和 make 环境
```

这样可以避免在本机安装复杂依赖，同时又不影响本机正常管理 OpenWrt 源码。

```
```
