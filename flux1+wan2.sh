#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# 如果你想完全禁用自动更新节点，设为 false
AUTO_UPDATE=${AUTO_UPDATE:-true}

APT_PACKAGES=(
    # "libgl1" "libglib2.0-0" 等如果需要可加，通常已预装
)

PIP_PACKAGES=(
    # 如果某些节点需要额外依赖，可在这里加
    # "xformers"   # 如果想加速（视 CUDA 版本）
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"               # 必须：节点管理器
    "https://github.com/XLabs-AI/x-flux-comfyui"                # FLUX 相关增强（可选但推荐）
    "https://github.com/cubiq/ComfyUI_essentials"               # 常用基础节点
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"           # IPAdapter 支持（人物/风格一致性）
    "https://github.com/Mikubill/sd-webui-controlnet"           # ControlNet 支持（需配套模型）
    "https://github.com/Fannovel16/comfyui_controlnet_aux"      # ControlNet 预处理器
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"   # 视频相关节点（推荐）
    "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet" # 高级 ControlNet
)

# 默认工作流（可选，可放 json 到 workflows/ 目录）
WORKFLOWS=()

CHECKPOINT_MODELS=(
    # FLUX.2 dev（最高质量，需要 HF_TOKEN + 接受协议）
    #"https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"
    
    # 如果 dev 下载失败或不想用 token，可切换到 schnell（已注释）
    "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors"
    
    # SD3.5 Large（生态党可选，注释掉默认不下载，节省空间）
    # "https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/sd3.5_large.safetensors"
)

UNET_MODELS=(
    # 如果 FLUX 使用 fp8 量化版（显存更省，可选）
    #"https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev-fp8.safetensors"
)

LORA_MODELS=(
    # 示例：FLUX 常用 LoRA（自行替换你喜欢的）
    # "https://civitai.com/api/download/models/xxxxxx?type=Model&format=SafeTensor"
)

VAE_MODELS=(
    # FLUX 自带 vae，但有时单独放一个保险
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
)

ESRGAN_MODELS=()

CONTROLNET_MODELS=(
    # FLUX 的 ControlNet（如果有社区版已出，可加）
    # 目前 FLUX ControlNet 还在快速发展，可后续通过 Manager 安装
    
    # SD3.5 / SDXL 通用 ControlNet（可选）
    # "https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/diffusers_xl_canny_full.safetensors"
)

# Wan2.2 系列视频模型（图生视频 & 文生视频）
# 注意：A14B 模型很大，建议至少 40GB+ 显存机器
# 路径：通常放 diffusers 格式或 safetensors 到 models/diffusion_models 或 models/wan
WAN_MODELS=(
    # Wan2.2 图生视频 A14B（推荐）
    "https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B/resolve/main/Wan2.2-I2V-A14B.safetensors"
    
    # Wan2.2 文生视频 A14B
    "https://huggingface.co/Wan-AI/Wan2.2-T2V-A14B/resolve/main/Wan2.2-T2V-A14B.safetensors"
    
    # 如果有 fp8 / fp16 量化版，可替换为更省显存的版本
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    
    # 图片基础模型
    provisioning_get_files "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/unet"       "${UNET_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/lora"       "${LORA_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/vae"        "${VAE_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_files "${COMFYUI_DIR}/models/esrgan"     "${ESRGAN_MODELS[@]}"
    
    # Wan 视频模型建议放这里（根据实际节点加载路径调整）
    provisioning_get_files "${COMFYUI_DIR}/models/diffusion_models" "${WAN_MODELS[@]}"
    # 或者放自定义目录
    # provisioning_get_files "${COMFYUI_DIR}/models/wan" "${WAN_MODELS[@]}"
    
    provisioning_print_end
}

# ---------------- 以下函数保持原样 ----------------

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
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

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]];then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi