# MNIST 推理服务

这是一个最小可行的 MNIST 手写数字识别部署服务，使用 FastAPI 对外提供 HTTP 接口，并通过 Docker Compose 启动。

## 目录结构

```text
mnist_service/
  app.py
  inference.py
  model.py
  models/
    mnist_cnn.pt
  Dockerfile
  docker-compose.yml
  start.sh
  requirements.txt
```

## 部署方式

当前采用“代码打进镜像，模型目录挂载”的方式：

```yaml
volumes:
  - ./models:/app/models:ro
```

好处是模型更新后不需要把模型文件重新打进镜像。`start.sh` 会重建并强制重启容器，服务启动时会重新加载挂载目录里的 `models/mnist_cnn.pt`。

## 接口

健康检查：

```text
GET /health
```

图片预测：

```text
POST /predict
```

请求格式是 `multipart/form-data`，字段名是 `file`。

返回示例：

```json
{
  "prediction": 1,
  "confidence": 0.9853,
  "probabilities": {
    "0": 0.001,
    "1": 0.9853,
    "2": 0.002,
    "3": 0.001,
    "4": 0.001,
    "5": 0.001,
    "6": 0.001,
    "7": 0.004,
    "8": 0.002,
    "9": 0.002
  }
}
```

## 前端页面

项目提供了一个无需构建的静态页面：

```text
frontend/index.html
```

使用方式：

```bash
cd mnist_service
```

先启动模型服务：

```bash
./start.sh
```

然后在浏览器中打开：

```text
frontend/index.html
```

页面支持填写服务地址和端口，例如：

```text
http://127.0.0.1
8000
```

上传图片后点击“开始识别”，页面会调用：

```text
POST http://127.0.0.1:8000/predict
```

并展示预测数字、置信度、请求耗时和 0-9 概率柱状图。

## 新 Linux 服务器部署流程

### 1. 安装 Docker

Ubuntu 示例：

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin git curl
sudo systemctl enable docker
sudo systemctl start docker
```

确认安装：

```bash
docker --version
docker compose version
```

如果希望当前用户不用 `sudo` 执行 Docker：

```bash
sudo usermod -aG docker $USER
```

执行后需要退出 SSH 并重新登录。

### 2. 获取项目代码

```bash
git clone https://github.com/liangzj-lab/NDT-AI.git
cd NDT-AI/mnist_service
```

确认模型文件存在：

```bash
ls models/mnist_cnn.pt
```

如果模型文件没有提交到仓库，需要手动上传到：

```text
mnist_service/models/mnist_cnn.pt
```

### 3. 授权启动脚本

```bash
chmod +x start.sh
```

### 4. 启动服务

```bash
./start.sh
```

脚本会执行这些动作：

```text
检查 GitHub 远程仓库是否有更新
如果有更新，执行 git pull --ff-only
检查 Docker 和 Docker Compose
检查 models/mnist_cnn.pt 是否存在
执行 docker compose up -d --build --force-recreate
```

使用 `--force-recreate` 是为了保证模型文件更新后，容器会重启并重新加载模型。

### 5. 查看运行状态

```bash
docker compose ps
docker compose logs -f mnist-service
```

健康检查：

```bash
curl http://127.0.0.1:8000/health
```

浏览器访问接口文档：

```text
http://服务器IP:8000/docs
```

### 6. 调用预测接口

服务器本机测试：

```bash
curl -X POST "http://127.0.0.1:8000/predict" \
  -F "file=@/path/to/digit.png"
```

外部机器访问：

```bash
curl -X POST "http://服务器IP:8000/predict" \
  -F "file=@/path/to/digit.png"
```

如果外部无法访问，需要检查云服务器安全组和 Linux 防火墙是否开放 `8000/tcp`。

Ubuntu 防火墙示例：

```bash
sudo ufw allow 8000/tcp
```

## 接口或模型更新后的部署

如果接口代码或模型文件已经推送到 GitHub，服务器上只需要执行：

```bash
cd NDT-AI/mnist_service
./start.sh
```

`start.sh` 会检查当前分支对应的 `origin/<branch>` 是否有新提交：

- 没有更新：直接重建并重启服务。
- 有更新：自动 `git pull --ff-only`，然后重建并重启服务。
- 本地有未提交改动：停止执行，避免覆盖服务器上的本地修改。

如果只替换了服务器本地的 `models/mnist_cnn.pt`，也执行：

```bash
./start.sh
```

容器会被强制重建/重启，服务会加载新的模型文件。

## 常用运维命令

停止服务：

```bash
docker compose down
```

重启服务：

```bash
docker compose restart
```

查看日志：

```bash
docker compose logs -f mnist-service
```

查看镜像：

```bash
docker images | grep mnist-service
```

查看容器：

```bash
docker ps
```
