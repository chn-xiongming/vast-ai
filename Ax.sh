#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# ==================== 自定义部分 - 质量优先 ====================

# 安装必要的自定义节点
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"                  # 节点管理器
    "https://github.com/XLabs-AI/x-flux-comfyui"                   # Flux 增强节点（可选但推荐）
    "https://github.com/cubiq/ComfyUI_essentials"                  # 基础节点
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"              # IPAdapter（人物一致性）
    "https://github.com/Mikubill/sd-webui-controlnet"              # ControlNet 支持
    "https://github.com/Fannovel16/comfyui_controlnet_aux"         # ControlNet 预处理器
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"      # 视频辅助（可选）
)

# Flux.1-schnell 相关模型（推荐 fp8 版本，显存友好）
CHECKPOINT_MODELS=(
    # fp8 单文件版本（最推荐，开箱即用）
    #"https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"
    # 如果想用原始完整版，可注释上面一行，启用下面
    # "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors"
    # Ax
    "https://civitai.com/api/download/models/324619?type=Model&format=SafeTensor&size=pruned&fp=fp16"
)

# Flux.1-dev 模型（质量最高，非 schnell）
UNET_MODELS=(
    #"https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"   # 原始版，质量最佳
    # 或者 fp8 版（如果想稍省显存但质量接近）："https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors"
)

VAE_MODELS=(
    #"https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
    # Ax
    "https://civitai.com/api/download/models/290640?type=VAE&format=SafeTensor"
)

CLIP_MODELS=(
    
)

# 最佳质量 LoRA 搭配（下载到 loras 目录）
LORA_MODELS=(
)

# 高质量 Flux dev 工作流（支持双/多 LoRA 加载）
#WORKFLOW_URL="https://raw.githubusercontent.com/comfyanonymous/ComfyUI_examples/main/flux/flux_dev_fp8.json"  # 官方示例，改成你喜欢的
# 或者社区高质量版（含 LoRA 示例）："https://raw.githubusercontent.com/ltdrdata/ComfyUI-Manager/main/workflows/flux_dev_lora_example.json"
WORKFLOW_URL="https://raw.githubusercontent.com/chn-xiongming/vast-ai/refs/heads/main/Ax.json"

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
        echo "Downloading high-quality Flux dev workflow..."
        mkdir -p "${COMFYUI_DIR}/user/workflows"
        wget -qnc --show-progress "${WORKFLOW_URL}" -O "${COMFYUI_DIR}/user/default/workflows/Ax.json"
        echo "Workflow saved to ${COMFYUI_DIR}/user/default/workflows/Ax.json"
    fi
}

function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "#     Flux.1-dev + Best Quality LoRA Setup    \n"
    printf "#     Quality First - Large Downloads Ahead   \n"
    printf "##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete! High quality Flux dev + LoRA ready.\n"
    printf "建议 workflow 使用方式：\n"
    printf "1. Load UNET: flux1-dev.safetensors (或 fp8)\n"
    printf "2. 加多个 Load LoRA 节点：\n"
    printf "   - XLabs Realism @ 0.7-1.0\n"
    printf "   - NSFW MASTER @ 0.8-1.1\n"
    printf "   - UltraRealistic @ 0.6-0.9 (clip & model)\n"
    printf "3. t5xxl prompt 用详细自然语言，clip_l 用标签\n"
    printf "4. Steps 25-35, CFG 3.0-3.5, Sampler: Euler\n\n"
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
