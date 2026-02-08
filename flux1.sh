#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# ==================== 自定义部分 ====================

# Token 设置说明（强烈推荐通过环境变量传入，避免硬编码）
# 在 vast.ai 启动实例时，添加以下环境变量：
#   HF_TOKEN=你的 huggingface read token
#   CIVITAI_TOKEN=你的 civitai api key
# 获取方式：
#   HF: https://huggingface.co/settings/tokens
#   Civitai: 登录 https://civitai.com → Account → API Keys → Create new key

# 安装必要的自定义节点（可选，根据需要添加）
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"      
    "https://github.com/XLabs-AI/x-flux-comfyui"                # FLUX 相关增强（可选但推荐）
    "https://github.com/cubiq/ComfyUI_essentials"               # 常用基础节点
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"           # IPAdapter 支持（人物/风格一致性）
    "https://github.com/Mikubill/sd-webui-controlnet"           # ControlNet 支持（需配套模型）
    "https://github.com/Fannovel16/comfyui_controlnet_aux"      # ControlNet 预处理器
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"   # 视频相关节点（推荐）
    "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet" # 高级 ControlNet
)

# Flux.1-schnell 相关模型（推荐 fp8 版本，显存友好）
CHECKPOINT_MODELS=(
    # fp8 单文件版本（最推荐，开箱即用）
    "https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"
    # 如果想用原始完整版，可注释上面一行，启用下面
    # "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors"
)

# 如果使用原始 UNET 模式（非 checkpoint 单文件）
UNET_MODELS=(
    # "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors"
)

CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
    # 显存紧张时可换 fp8 版 t5xxl（质量略降）
    # "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors"
)

# LoRA 示例（Civitai 下载会自动附加 token，如果需要登录）
# 示例：NSFW MASTER FLUX、UltraRealistic 等（替换为实际模型 ID）
LORA_MODELS=(
    # "https://civitai.com/api/download/models/667086"     # NSFW MASTER FLUX 示例
    # "https://civitai.com/api/download/models/796382"     # UltraRealistic 示例
    # "https://civitai.com/api/download/models/1157318"    # Photorealistic Skin 示例
)

# Flux Schnell 简单工作流 JSON（来自社区常用版本）
WORKFLOW_URL="https://raw.githubusercontent.com/thinkdiffusion/ComfyUI-Workflows/main/flux/Flux-schnell-fp8.json"
# 其他可选 workflow 来源
# WORKFLOW_URL="https://raw.githubusercontent.com/comfyanonymous/ComfyUI_examples/main/flux/flux_schnell.json"

# ==================== 以下不要修改 ====================

function provisioning_start() {
    provisioning_print_header
    provisioning_get_nodes
    provisioning_get_files "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}"
    provisioning_get_workflow
    provisioning_print_end
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s file(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_get_workflow() {
    if [[ -n $WORKFLOW_URL ]]; then
        echo "Downloading Flux Schnell default workflow..."
        mkdir -p "${COMFYUI_DIR}/user/default_workflows"
        wget -qnc --show-progress "${WORKFLOW_URL}" -O "${COMFYUI_DIR}/user/default_workflows/flux-schnell-default.json"
        echo "Workflow saved to ${COMFYUI_DIR}/user/default_workflows/flux-schnell-default.json"
    fi
}

function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "#         Flux.1-schnell Provisioning         \n"
    printf "#       This will take some time...          \n"
    printf "##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nFlux Schnell provisioning complete!\n"
    printf "请启动 ComfyUI 后在菜单 -> Workflow -> Open (或直接拖入 json)\n"
    printf "已支持 HF_TOKEN 和 CIVITAI_TOKEN 下载（环境变量传入）\n\n"
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local final_url="$url"
    local auth_header=""

    # Hugging Face token 处理
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_header="Authorization: Bearer $HF_TOKEN"
    fi

    # Civitai token 处理（追加 ?token= 或 &token=）
    if [[ -n $CIVITAI_TOKEN && $url =~ ^https://civitai\.com/api/download ]]; then
        if [[ $url =~ \? ]]; then
            final_url="${url}&token=$CIVITAI_TOKEN"
        else
            final_url="${url}?token=$CIVITAI_TOKEN"
        fi
    fi

    # 执行下载
    if [[ -n $auth_header ]]; then
        wget --header="$auth_header" \
             -qnc --content-disposition --show-progress \
             -e dotbytes="${3:-4M}" \
             -P "$dir" "$final_url"
    else
        wget -qnc --content-disposition --show-progress \
             -e dotbytes="${3:-4M}" \
             -P "$dir" "$final_url"
    fi
}

# 执行
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi