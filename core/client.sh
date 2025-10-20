#!/usr/bin/env bash
#
# Copyright (C) 2025 zxcvos
#
# Xray-script:
#   https://github.com/ArtemKiyashko/Xray-script
# =============================================================================
# 注释: 通过 Qwen3-Coder 生成。
# 脚本名称: client.sh
# 功能描述: 管理 Xray VLESS Vision 客户端配置的 CRUD 操作。
#           支持添加、删除、列出客户端以及生成分享链接。
#           仅支持 Vision/VLESS 协议的客户端管理。
# 作者: zxcvos
# 时间: 2025-07-25  
# 版本: 1.0.0
# 依赖: bash, jq, sed
# 配置:
#   - ${XRAY_CONFIG_PATH}: Xray 服务端配置文件 (用于读取和修改客户端配置)
#   - ${SCRIPT_CONFIG_PATH}: 脚本自身配置文件 (用于读取协议类型等)
#   - ${I18N_DIR}/${lang}.json: 国际化文件 (用于显示多语言提示)
# =============================================================================

# set -Eeuxo pipefail

# --- 环境与常量设置 ---
# 将常用路径添加到 PATH 环境变量，确保脚本能在不同环境中找到所需命令
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/snap/bin
export PATH

# 定义颜色代码，用于在终端输出带颜色的信息
readonly GREEN='\033[32m'  # 绿色
readonly YELLOW='\033[33m' # 黄色
readonly RED='\033[31m'    # 红色
readonly NC='\033[0m'      # 无颜色（重置）

# 获取当前脚本的目录、文件名（不含扩展名）和项目根目录的绝对路径
readonly CUR_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)" # 当前脚本所在目录
readonly CUR_FILE="$(basename "$0" | sed 's/\..*//')"         # 当前脚本文件名 (不含扩展名)
readonly PROJECT_ROOT="$(cd -P -- "${CUR_DIR}/.." && pwd -P)" # 项目根目录

# 定义配置文件和相关目录的路径
readonly SCRIPT_CONFIG_DIR="${HOME}/.xray-script"              # 主配置文件目录
readonly I18N_DIR="${PROJECT_ROOT}/i18n"                       # 国际化文件目录
readonly GENERATE_PATH="${CUR_DIR}/generate.sh"                # 项目中的 generate.sh 脚本路径
readonly SHARE_PATH="${CUR_DIR}/share.sh"                      # 项目中的 share.sh 脚本路径
readonly XRAY_CONFIG_PATH="${XRAY_CONFIG_PATH:-/usr/local/etc/xray/config.json}"    # Xray 服务端配置文件路径
readonly SCRIPT_CONFIG_PATH="${SCRIPT_CONFIG_DIR}/config.json" # 脚本主要配置文件路径

# --- 全局变量声明 ---
# 声明用于存储语言参数、国际化数据和配置信息的全局变量
declare I18N_DATA=''        # 存储从 i18n JSON 文件中读取的全部数据
declare XRAY_CONFIG         # 存储 Xray 配置文件的全部 JSON 内容
declare SCRIPT_CONFIG       # 存储脚本配置文件的全部 JSON 内容

# =============================================================================
# 函数名称: load_i18n
# 功能描述: 加载国际化 (i18n) 数据。
#           1. 从 config.json 读取语言设置。
#           2. 如果设置为 "auto"，则尝试从系统环境变量 $LANG 推断语言。
#           3. 根据确定的语言，加载对应的 JSON i18n 文件。
#           4. 将文件内容读入全局变量 I18N_DATA。
# 参数: 无
# 返回值: 无 (直接修改全局变量 I18N_DATA)
# 退出码: 如果 i18n 文件不存在，则输出错误信息并退出脚本 (exit 1)
# =============================================================================
function load_i18n() {
    # 从脚本配置文件中读取语言设置
    local lang="$(jq -r '.language' "${SCRIPT_CONFIG_PATH}")"

    # 如果语言设置为 "auto"，则使用系统环境变量 LANG 的第一部分作为语言代码
    if [[ "$lang" == "auto" ]]; then
        lang=$(echo "$LANG" | cut -d'_' -f1)
    fi

    # 构造 i18n 文件的完整路径
    local i18n_file="${I18N_DIR}/${lang}.json"

    # 检查 i18n 文件是否存在
    if [[ ! -f "${i18n_file}" ]]; then
        # 文件不存在时，根据语言输出不同的错误信息
        if [[ "$lang" == "zh" ]]; then
            echo -e "${RED}[错误]${NC} 文件不存在: ${i18n_file}" >&2
        else
            echo -e "${RED}[Error]${NC} File Not Found: ${i18n_file}" >&2
        fi
        # 退出脚本，错误码为 1
        exit 1
    fi

    # 读取 i18n 文件的全部内容到全局变量 I18N_DATA
    I18N_DATA="$(jq '.' "${i18n_file}")"
}

# =============================================================================
# 函数名称: cache_json_data
# 功能描述: 将 Xray 和脚本的配置文件内容读取到全局变量中进行缓存，
#           避免重复读取文件，提高脚本执行效率。
# 参数: 无
# 返回值: 无 (直接修改全局变量 XRAY_CONFIG 和 SCRIPT_CONFIG)
# =============================================================================
function cache_json_data() {
    # 读取 Xray 配置文件的完整 JSON 内容到全局变量 XRAY_CONFIG
    if [[ ! -f "${XRAY_CONFIG_PATH}" ]]; then
        echo -e "${RED}[Error]${NC} Xray config file not found: ${XRAY_CONFIG_PATH}" >&2
        exit 1
    fi
    
    XRAY_CONFIG="$(jq '.' "${XRAY_CONFIG_PATH}" 2>/dev/null)"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[Error]${NC} Invalid JSON in Xray config file: ${XRAY_CONFIG_PATH}" >&2
        exit 1
    fi
    
    # 读取脚本配置文件的完整 JSON 内容到全局变量 SCRIPT_CONFIG
    if [[ -f "${SCRIPT_CONFIG_PATH}" ]]; then
        SCRIPT_CONFIG="$(jq '.' "${SCRIPT_CONFIG_PATH}" 2>/dev/null)"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}[Error]${NC} Invalid JSON in script config file: ${SCRIPT_CONFIG_PATH}" >&2
            exit 1
        fi
    else
        SCRIPT_CONFIG="{}"
    fi
}

# =============================================================================
# 函数名称: get_vision_inbound_index
# 功能描述: 查找 Xray 配置中 Vision VLESS 协议的 inbound 索引。
#           通过检查协议类型和 flow 参数来确定 Vision 配置。
# 参数: 无
# 返回值: Vision inbound 的索引号，如果未找到返回 -1
# =============================================================================
function get_vision_inbound_index() {
    local inbound_count=$(echo "${XRAY_CONFIG}" | jq '.inbounds | length')
    
    for ((i=0; i<inbound_count; i++)); do
        local protocol=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$i" '.inbounds[$i].protocol // empty')
        local flow=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$i" '.inbounds[$i].settings.clients[0].flow // empty')
        
        # 检查是否为 VLESS 协议且使用 Vision flow
        if [[ "$protocol" == "vless" && "$flow" == "xtls-rprx-vision" ]]; then
            echo "$i"
            return 0
        fi
    done
    
    echo "-1"
    return 1
}

# =============================================================================
# 函数名称: list_clients
# 功能描述: 列出所有 Vision VLESS 客户端配置。
# 参数: 无
# 返回值: 无 (直接打印客户端列表)
# =============================================================================
function list_clients() {
    local inbound_index=$(get_vision_inbound_index)
    
    if [[ "$inbound_index" == "-1" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Vision VLESS inbound not found" >&2
        return 1
    fi
    
    local clients_count=$(echo "${XRAY_CONFIG}" | jq --argjson i "$inbound_index" '.inbounds[$i].settings.clients | length')
    
    if [[ "$clients_count" -eq 0 ]]; then
        echo -e "${YELLOW}[$(echo "$I18N_DATA" | jq -r '.title.info')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.list.no_clients')" >&2
        return 0
    fi
    
    echo -e "------------------ $(echo "$I18N_DATA" | jq -r '.client_management.list.header') ------------------" >&2
    
    # 获取shortIds数组长度
    local short_ids_count=$(echo "${XRAY_CONFIG}" | jq --argjson i "$inbound_index" '.inbounds[$i].streamSettings.realitySettings.shortIds | length')
    
    for ((j=0; j<clients_count; j++)); do
        local client_id=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$inbound_index" --argjson j "$j" '.inbounds[$i].settings.clients[$j].id')
        local client_email=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$inbound_index" --argjson j "$j" '.inbounds[$i].settings.clients[$j].email // "client-" + ($j + 1 | tostring)')
        
        # 获取对应的shortId (按索引匹配)
        local short_id=""
        if [[ $j -lt $short_ids_count ]]; then
            short_id=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$inbound_index" --argjson j "$j" '.inbounds[$i].streamSettings.realitySettings.shortIds[$j]')
        else
            short_id="N/A"
        fi
        
        echo -e "${GREEN}$((j+1)).${NC} $client_email" >&2
        echo -e "   UUID: $client_id" >&2
        echo -e "   ShortID: $short_id" >&2
        echo >&2
    done
    
    echo -e "------------------------------------------------------" >&2
}

# =============================================================================
# 函数名称: add_client
# 功能描述: 添加新的 Vision VLESS 客户端配置。
# 参数:
#   $1: 客户端名称
# 返回值: 成功返回 0，失败返回 1
# =============================================================================
function add_client() {
    local client_name="$1"
    
    if [[ -z "$client_name" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Client name cannot be empty" >&2
        return 1
    fi
    
    local inbound_index=$(get_vision_inbound_index)
    
    if [[ "$inbound_index" == "-1" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Vision VLESS inbound not found" >&2
        return 1
    fi
    
    # 检查客户端名称是否已存在
    local existing_client=$(echo "${XRAY_CONFIG}" | jq --argjson i "$inbound_index" --arg name "$client_name" '.inbounds[$i].settings.clients[] | select(.email == $name)')
    
    if [[ -n "$existing_client" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.add.name_exists')" >&2
        return 1
    fi
    
    # 生成新的 UUID
    local new_uuid=$(bash "${GENERATE_PATH}" '--uuid')
    
    if [[ -z "$new_uuid" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Failed to generate UUID" >&2
        return 1
    fi
    
    # 生成新的 shortId (максимальная длина 8 байт)
    local new_short_id=$(bash "${GENERATE_PATH}" '--short-id' '8')
    
    if [[ -z "$new_short_id" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Failed to generate shortId" >&2
        return 1
    fi
    
    # 创建新客户端配置
    local new_client=$(cat <<EOF
{
    "id": "$new_uuid",
    "flow": "xtls-rprx-vision",
    "email": "$client_name",
    "level": 0
}
EOF
)
    
    # 添加新客户端到配置中并同时添加新的shortId
    local updated_config=$(echo "${XRAY_CONFIG}" | jq \
        --argjson i "$inbound_index" \
        --argjson client "$new_client" \
        --arg short_id "$new_short_id" \
        '.inbounds[$i].settings.clients += [$client] | .inbounds[$i].streamSettings.realitySettings.shortIds += [$short_id]' 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$updated_config" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.add.fail')" >&2
        return 1
    fi
    
    # 验证更新后的配置是否有效
    echo "$updated_config" | jq '.' >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Generated invalid configuration during addition" >&2
        return 1
    fi
    
    # 写入配置文件
    echo "$updated_config" | jq '.' > "${XRAY_CONFIG_PATH}"
    
    if [[ $? -eq 0 ]]; then
        # 重新加载配置缓存
        XRAY_CONFIG="$updated_config"
        echo -e "${GREEN}[$(echo "$I18N_DATA" | jq -r '.title.info')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.add.success')" >&2
        echo -e "Client: $client_name" >&2
        echo -e "UUID: $new_uuid" >&2
        echo -e "ShortID: $new_short_id" >&2
        return 0
    else
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.add.fail')" >&2
        return 1
    fi
}

# =============================================================================
# 函数名称: get_client_name_by_index
# 功能描述: 根据索引获取客户端名称。
# 参数:
#   $1: 客户端索引 (从 1 开始)
# 返回值: 成功返回客户端名称，失败返回空字符串
# =============================================================================
function get_client_name_by_index() {
    local client_index="$1"
    
    if [[ ! "$client_index" =~ ^[0-9]+$ ]] || [[ "$client_index" -lt 1 ]]; then
        echo ""
        return 1
    fi
    
    local inbound_index=$(get_vision_inbound_index)
    
    if [[ "$inbound_index" == "-1" ]]; then
        echo ""
        return 1
    fi
    
    local clients_count=$(echo "${XRAY_CONFIG}" | jq --argjson i "$inbound_index" '.inbounds[$i].settings.clients | length')
    
    if [[ "$client_index" -gt "$clients_count" ]]; then
        echo ""
        return 1
    fi
    
    # 获取客户端名称
    echo "${XRAY_CONFIG}" | jq -r --argjson i "$inbound_index" --argjson j "$((client_index-1))" '.inbounds[$i].settings.clients[$j].email // "client-" + ($j + 1 | tostring)'
}

# =============================================================================
# 函数名称: delete_client
# 功能描述: 删除指定的 Vision VLESS 客户端配置。
# 参数:
#   $1: 客户端索引 (从 1 开始)
# 返回值: 成功返回 0，失败返回 1
# =============================================================================
function delete_client() {
    local client_index="$1"
    
    if [[ ! "$client_index" =~ ^[0-9]+$ ]] || [[ "$client_index" -lt 1 ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Invalid client index" >&2
        return 1
    fi
    
    local inbound_index=$(get_vision_inbound_index)
    
    if [[ "$inbound_index" == "-1" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Vision VLESS inbound not found" >&2
        return 1
    fi
    
    local clients_count=$(echo "${XRAY_CONFIG}" | jq --argjson i "$inbound_index" '.inbounds[$i].settings.clients | length')
    
    if [[ "$client_index" -gt "$clients_count" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.delete.not_found')" >&2
        return 1
    fi
    
    # 获取要删除的客户端名称
    local client_name=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$inbound_index" --argjson j "$((client_index-1))" '.inbounds[$i].settings.clients[$j].email // "client-" + ($j + 1 | tostring)')
    
    # 删除客户端配置 (注意：shortIds 不会被删除，以保持索引对应关系)
    local updated_config=$(echo "${XRAY_CONFIG}" | jq --argjson i "$inbound_index" --argjson j "$((client_index-1))" 'del(.inbounds[$i].settings.clients[$j])' 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$updated_config" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.delete.fail')" >&2
        return 1
    fi
    
    # 验证更新后的配置是否有效
    echo "$updated_config" | jq '.' >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Generated invalid configuration during deletion" >&2
        return 1
    fi
    
    # 写入配置文件
    echo "$updated_config" | jq '.' > "${XRAY_CONFIG_PATH}"
    
    if [[ $? -eq 0 ]]; then
        # 重新加载配置缓存
        XRAY_CONFIG="$updated_config"
        echo -e "${GREEN}[$(echo "$I18N_DATA" | jq -r '.title.info')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.delete.success')" >&2
        echo -e "Deleted client: $client_name" >&2
        echo -e "${YELLOW}[$(echo "$I18N_DATA" | jq -r '.title.info')]${NC} ShortIds array preserved to maintain index correspondence" >&2
        return 0
    else
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.delete.fail')" >&2
        return 1
    fi
}

# =============================================================================
# 函数名称: generate_share_link
# 功能描述: 为指定的客户端生成分享链接。
# 参数:
#   $1: 客户端索引 (从 1 开始)
# 返回值: 成功返回 0，失败返回 1
# =============================================================================
function generate_share_link() {
    local client_index="$1"
    
    if [[ ! "$client_index" =~ ^[0-9]+$ ]] || [[ "$client_index" -lt 1 ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Invalid client index" >&2
        return 1
    fi
    
    local inbound_index=$(get_vision_inbound_index)
    
    if [[ "$inbound_index" == "-1" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Vision VLESS inbound not found" >&2
        return 1
    fi
    
    local clients_count=$(echo "${XRAY_CONFIG}" | jq --argjson i "$inbound_index" '.inbounds[$i].settings.clients | length')
    
    if [[ "$client_index" -gt "$clients_count" ]]; then
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.share.not_found')" >&2
        return 1
    fi
    
    # 获取客户端信息
    local client_uuid=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$inbound_index" --argjson j "$((client_index-1))" '.inbounds[$i].settings.clients[$j].id')
    local client_name=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$inbound_index" --argjson j "$((client_index-1))" '.inbounds[$i].settings.clients[$j].email // "client-" + ($j + 1 | tostring)')
    
    echo -e "${GREEN}[$(echo "$I18N_DATA" | jq -r '.title.info')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.share.generating')" >&2
    echo -e "Client: $client_name" >&2
    echo -e "UUID: $client_uuid" >&2
    
    # 获取对应的shortId
    local client_short_id=$(echo "${XRAY_CONFIG}" | jq -r --argjson i "$inbound_index" --argjson j "$((client_index-1))" '.inbounds[$i].streamSettings.realitySettings.shortIds[$j] // "00"')
    
    echo -e "ShortID: $client_short_id" >&2
    
    # 临时修改 Xray 配置，只保留选定的客户端和对应的shortId
    local temp_config=$(echo "${XRAY_CONFIG}" | jq \
        --argjson i "$inbound_index" \
        --argjson j "$((client_index-1))" \
        --arg short_id "$client_short_id" \
        '.inbounds[$i].settings.clients = [.inbounds[$i].settings.clients[$j]] | .inbounds[$i].streamSettings.realitySettings.shortIds = [$short_id]')
    
    # 创建临时配置文件
    local temp_config_file=$(mktemp)
    echo "$temp_config" > "$temp_config_file"
    
    # 备份原配置文件
    local backup_file="${XRAY_CONFIG_PATH}.backup"
    cp "${XRAY_CONFIG_PATH}" "$backup_file"
    
    # 使用临时配置
    cp "$temp_config_file" "${XRAY_CONFIG_PATH}"
    
    # 调用 share.sh 生成分享链接
    bash "${SHARE_PATH}"
    local share_result=$?
    
    # 恢复原配置文件
    mv "$backup_file" "${XRAY_CONFIG_PATH}"
    
    # 清理临时文件
    rm -f "$temp_config_file"
    
    return $share_result
}

# =============================================================================
# 函数名称: main
# 功能描述: 脚本的主入口函数。
# 参数:
#   $1: 操作类型 (list|add|delete|share)
#   $2: 操作参数 (客户端名称或索引)
# 返回值: 无 (协调调用其他函数完成整个流程)
# =============================================================================
function main() {
    # 加载国际化数据
    load_i18n

    # 缓存 Xray 和脚本配置数据
    cache_json_data

    # 根据第一个参数选择操作
    case "$1" in
    list)
        list_clients
        ;;
    add)
        if [[ -z "$2" ]]; then
            echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.add.enter_name')" >&2
            exit 1
        fi
        add_client "$2"
        ;;
    delete)
        if [[ -z "$2" ]]; then
            echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.delete.select_client')" >&2
            exit 1
        fi
        delete_client "$2"
        ;;
    share)
        if [[ -z "$2" ]]; then
            echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} $(echo "$I18N_DATA" | jq -r '.client_management.share.select_client')" >&2
            exit 1
        fi
        generate_share_link "$2"
        ;;
    get-name)
        if [[ -z "$2" ]]; then
            echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Client index required" >&2
            exit 1
        fi
        get_client_name_by_index "$2"
        ;;
    *)
        echo -e "${RED}[$(echo "$I18N_DATA" | jq -r '.title.error')]${NC} Invalid operation: $1" >&2
        echo "Usage: $0 {list|add|delete|share|get-name} [client_name|client_index]" >&2
        exit 1
        ;;
    esac
}

# --- 脚本执行入口 ---
# 将脚本接收到的所有参数传递给 main 函数开始执行
main "$@"