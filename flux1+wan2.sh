#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# ==================== 自定义部分 ====================

# 安装必要的自定义节点（可选，根据需要添加）
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"      
    "https://github.com/XLabs-AI/x-flux-comfyui"                # FLUX 相关增强（可选但推荐）
    "https://github.com/cubiq/ComfyUI_essentials"               # 常用基础节点
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"           # IPAdapter 支持（人物/风格一致性）
    "https://github.com/Mikubill/sd-webui-controlnet"           # ControlNet 支持（需配套模型）
    "https://github.com/Fannovel16/comfyui_controlnet_aux"      # ControlNet 预处理器
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"   # 视频相关节点（推荐）
    "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet" # 高级 ControlNet     # 强烈推荐安装，便于后续管理
)

# Flux Schnell 相关模型（推荐 fp8 版本，显存友好）
CHECKPOINT_MODELS=(
    # fp8 单文件版本（最推荐，开箱即用）
    "https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"
)

# 或者用原始完整版（需要额外 CLIP + VAE，显存要求更高）
UNET_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors"
)

CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
    # 如果显存很紧张，可换 fp8 版 t5
    # "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors"
)

# Flux Schnell 简单工作流 JSON（来自社区常用版本，匹配 fp8 或原始模型）
# 这里使用一个最简匹配 Flux schnell 的 workflow（你可以替换成其他）
WORKFLOW_URL="https://raw.githubusercontent.com/thinkdiffusion/ComfyUI-Workflows/main/flux/Flux-schnell-fp8.json"
# 或者官方示例风格的简化版（需手动匹配模型名）
# WORKFLOW_URL="https://example.com/flux-schnell-default.json"  # 如有更好来源可替换

# ==================== 以下不要修改 ====================

function provisioning_start() {
    provisioning_print_header
    provisioning_get_nodes
    provisioning_get_files "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
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
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
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
        # 或者直接放根目录
        # wget -qnc --show-progress "${WORKFLOW_URL}" -O "${COMFYUI_DIR}/flux-schnell-workflow.json"
        echo "Workflow saved to ${COMFYUI_DIR}/user/default_workflows/flux-schnell-default.json"
    fi
}

# 保留原有的下载函数、header 等
function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "#         Flux.1-schnell Provisioning         \n"
    printf "#       This will take some time...          \n"
    printf "##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nFlux Schnell provisioning complete!\n"
    printf "请启动 ComfyUI 后在菜单 -> Workflow -> Open (或直接拖入 json)\n\n"
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    fi
    if [[ -n $auth_token ]];then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

# 执行
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi