# 快速开始 - 最小可用性配置

本教程将指导您用最简单的方式配置 Xboard-Mihomo 客户端，只需要两步即可完成！

##  最小配置步骤

### 第一步：修改并托管 `remote.config.example.json`

**只需要配置一个面板地址、客服地址（目前客服系统还没开源，先随意填写）和代理地址（强烈建议配置以支持过墙）。**

> ℹ️ **提示**：项目中的 `assets/config/remote.config.example.json` 是完整配置示例。对于最小配置，请参考下方简化示例，删除不需要的字段。

```json
{
    "panelType": "xboard", // 支持 "xboard" 或 "v2board"
    "panels": {
        "mihomo": [ // "mihomo" 可以是任意名称，但必须与本地 xboard.config.yaml 中的 provider 保持一致
            {
                "url": "https://your-panel.com",
                "description": "主面板"
            }
        ]
    },
    "onlineSupport": [
        {
            "url": "https://chat.example.com",
            "description": "在线客服",
            "apiBaseUrl": "https://chat.example.com",
            "wsBaseUrl": "wss://chat.example.com"
        }
    ],
    "proxy": [
        {
            "url": "socks5://username:password@proxy.example.com:38769",
            "description": "代理服务器(强烈建议配置)",
            "protocol": "s5"
        }
    ]
}
```

**说明：**
- `panelType`: 面板类型，支持 `xboard` 和 `v2board`。
- `panels.mihomo`: 面板列表。`mihomo` 是提供商名称，**必须与本地配置文件 `xboard.config.yaml` 中的 `provider` 字段值完全一致**。
- `proxy`: **强烈建议配置**。目前仅支持 `s5` (SOCKS5) 代理，用于帮助面板和订阅地址绕过网络限制。
- `onlineSupport`: 客服系统配置（必填，但地址可随意填写）。

---

### 第二步：配置客户端 `xboard.config.yaml`

1. 复制示例配置文件：`cp assets/config/xboard.config.example.yaml assets/config/xboard.config.yaml`
2. 编辑 `assets/config/xboard.config.yaml`，**只需配置主源地址**：

```yaml
xboard:
  # 后端提供商类型
  # 必须与 remote.config.json 中的 panels 键名一致（例如: mihomo）
  provider: mihomo
  
  # 远程配置源
  remote_config:
    sources:
      # 主配置源（重定向服务）
      - name: redirect
        url: https://your-domain.com/config.json
        priority: 100
      
  # 应用信息
  app:
    title: YourAppName
    website: example.com
  
  # 订阅配置
  subscription:
    prefer_encrypt: false 
```

**说明：**
- `provider`: 必须与 `config.json` 中的 `panels` 键名一致。
- `remote_config.sources[0].url`: 指向您托管的 `config.json` 文件地址。

> 💡 **多站点切换**：如果您有多个站点，可以在远程配置的 `panels` 中添加另一个站点（例如 `"site2": [...]`），然后只需修改本地 `xboard.config.yaml` 中的 `provider: site2` 即可切换。

## 🎯 工作原理

```
客户端启动 → 读取 xboard.config.yaml → 获取主源地址 → 下载 config.json → 解析面板地址 → 连接服务器
```

## ❓ 常见问题

**Q: config.json 必须放在哪里？**
A: 必须托管在一个可访问的 HTTP/HTTPS 地址上（如 GitHub/Gitee Raw 地址、自己的服务器或 CDN）。

**Q: provider 名称能自定义吗？**
A: 可以，但必须保持一致：`config.json` 中的 `"panels": { "your_name": [...] }` 必须对应 `xboard.config.yaml` 中的 `provider: your_name`。


