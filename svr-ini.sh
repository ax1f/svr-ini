#!/bin/bash
# ==========================================
# Ubuntu 24.04 初始安全加固交互脚本（v1.1）
# ==========================================
echo "=== 🛡️ 远程主机初始化加固 ==="
# ① 修改 root 密码
read -sp "请输入新的 root 密码: " ROOT_PASS
echo
echo "root:${ROOT_PASS}" | sudo chpasswd
echo "[完成] ✅ root 密码已修改"
# ② 配置 SSH 心跳机制（防止空闲断开）
sudo sed -i '/^#*ClientAliveInterval/c\ClientAliveInterval 60' /etc/ssh/sshd_config
sudo sed -i '/^#*ClientAliveCountMax/c\ClientAliveCountMax 3' /etc/ssh/sshd_config
echo "[完成] ✅ SSH 心跳机制已配置"
# ③ 系统更新（可选）
read -p "是否执行系统更新？(y/n): " UPDATE_CHOICE
if [[ "$UPDATE_CHOICE" == "y" ]]; then
    sudo apt update -y && sudo apt upgrade -y
    echo "[完成] ✅ 系统已更新"
else
    echo "[跳过] ⏭️ 系统更新"
fi
# ④ 创建新用户（用于部署操作）
read -p "请输入新用户名: " NEW_USER
sudo useradd -m -s /bin/bash ${NEW_USER}
read -sp "请输入 ${NEW_USER} 的密码: " NEW_PASS
echo
echo "${NEW_USER}:${NEW_PASS}" | sudo chpasswd
echo "[完成] ✅ 用户 ${NEW_USER} 已创建"
# ⑤ 配置 sudo 权限（免密码执行）
echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${NEW_USER}
echo "[完成] ✅ 用户 ${NEW_USER} 已获得免密码 sudo 权限"
# ⑥ 修改 SSH 端口（提升隐蔽性）
read -p "请输入新的 SSH 端口号: " SSH_PORT
sudo sed -i "s/^#Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config
sudo sed -i "s/ListenStream=.*/ListenStream=${SSH_PORT}/" /lib/systemd/system/ssh.socket
echo "[完成] ✅ SSH 端口已修改为 ${SSH_PORT}"
# ⑦ 禁止 root 登录（可选）
read -p "是否禁止 root 登录？(y/n): " ROOT_LOGIN
if [[ "$ROOT_LOGIN" == "y" ]]; then
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    echo "[完成] ✅ 已禁止 root 远程登录"
else
    echo "[跳过] ⏭️ 禁止 root 登录"
fi
# ⑧ 重启 SSH 服务（应用配置）
sudo systemctl daemon-reload
sudo systemctl restart ssh.socket
echo "[完成] ✅ SSH 服务已重启"
# ⑨ 启用 BBR 拥塞控制（提升 TCP 性能）
read -p "是否启用 BBR 拥塞控制？(y/n): " BBR_CHOICE
if [[ "$BBR_CHOICE" == "y" ]]; then
    sudo modprobe tcp_bbr
    echo "tcp_bbr" | sudo tee /etc/modules-load.d/bbr.conf
    sudo sysctl -w net.core.default_qdisc=fq
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
    echo "[完成] ✅ BBR 拥塞控制已启用"
    echo "当前拥塞算法: $(sysctl net.ipv4.tcp_congestion_control)"
else
    echo "[跳过] ⏭️ BBR 启用"
fi
# ✅ 初始化完成提示
echo "=== ✅ 初始化完成 ==="
echo "请使用以下信息重新登录："
echo "用户: ${NEW_USER}"
echo "端口: ${SSH_PORT}"
