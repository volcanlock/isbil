# ==========================================
# 第一阶段：构建层 (Builder)
# ==========================================
FROM node:18-slim AS builder
WORKDIR /app

# 安装工具
RUN apt-get update && apt-get install -y curl tar

# 下载 Camoufox
ARG CAMOUFOX_URL
RUN if [ -z "$CAMOUFOX_URL" ]; then echo "Error: URL is empty"; exit 1; fi && \
    curl -sSL ${CAMOUFOX_URL} -o camoufox.tar.gz && \
    tar -xzf camoufox.tar.gz && \
    chmod +x camoufox-linux/camoufox

# 安装 NPM 依赖
COPY package*.json ./
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=true
RUN npm install --omit=dev

# ==========================================
# 第二阶段：运行层 (Final)
# ==========================================
FROM node:18-slim
WORKDIR /app

# 1. 安装系统依赖 (这一层约 300MB)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates fonts-liberation libasound2 libatk-bridge2.0-0 \
    libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 \
    libfontconfig1 libgbm1 libgcc1 libglib2.0-0 libgtk-3-0 libnspr4 \
    libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 \
    libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 \
    libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 \
    lsb-release wget xdg-utils xvfb \
    && rm -rf /var/lib/apt/lists/*

# 2. 【核心修改】COPY 同时修改权限，避免双倍占用！
# 使用 --chown=node:node 参数
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/camoufox-linux ./camoufox-linux
COPY --chown=node:node package*.json ./
COPY --chown=node:node unified-server.js black-browser.js ./

# 3. 创建 auth 目录（因为是空的，这里 chown 没关系，或者直接用 mkdir -m）
RUN mkdir -p ./auth && chown node:node ./auth

# 4. 启动配置
USER node
EXPOSE 7860 9998
ENV CAMOUFOX_EXECUTABLE_PATH=/app/camoufox-linux/camoufox
CMD ["node", "unified-server.js"]
